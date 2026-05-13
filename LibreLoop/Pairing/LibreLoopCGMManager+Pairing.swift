import Foundation
import HealthKit
import LoopKit
import os.log

private let log = Logger(subsystem: "org.loopkit.LibreLoop", category: "CGMManager")

extension LibreLoopCGMManager {
    /// Saves the NFC half of pairing the instant it completes successfully,
    /// before any BLE work. Per LibreCRKit author guidance: a successful A8
    /// burns the previous BLE PIN and issues a new one in the response, so
    /// the new PIN MUST be persisted before we touch BLE -- a crash or
    /// handshake failure must not leave the sensor stranded.
    public func applyNFCResponse(_ response: LibreLoopPairingService.NFCResponse) {
        log.info("NFC response applied: serial=\(response.sensorSerial) bleAddress=\(response.bleAddress ?? "nil") blePIN bytes=\(response.blePIN.count)")
        cancelReconnect()
        var newState = state
        newState.receiverID = withUnsafeBytes(of: response.receiverID.littleEndian) { Data($0) }
        newState.sensorSerial = response.sensorSerial
        newState.bleAddress = response.bleAddress
        newState.blePIN = response.blePIN
        newState.activatedAt = response.activatedAt
        setState(newState)
    }

    /// Completes pairing after BLE handshake succeeds: persists session keys
    /// to Keychain and adopts the live monitor. NFC fields are already in
    /// state by this point (see applyNFCResponse).
    public func applyPairingOutcome(_ outcome: LibreLoopPairingService.PairOutcome) throws {
        log.info("pairing outcome applied: serial=\(outcome.result.sensorSerial) peripheral=\(outcome.peripheralID.uuidString); adopting monitor")
        try LibreLoopKeychain.save(
            LibreLoopKeychain.SessionKeys(kEnc: outcome.result.kEnc, ivEnc: outcome.result.ivEnc),
            forSensorSerial: outcome.result.sensorSerial
        )

        var newState = state
        newState.peripheralID = outcome.peripheralID
        setState(newState)

        adopt(monitor: outcome.monitor)
    }

    func adopt(monitor: LibreLoopSensorMonitor) {
        self.monitor = monitor
        monitor.setHandlers(
            onReading: { [weak self] sample in self?.ingest(sample) },
            onDisconnect: { [weak self] in self?.handleMonitorDisconnect() }
        )
        monitor.start()
    }

    func ingest(_ sample: LibreLoopGlucoseSample) {
        recordSample(sample)

        var updated = state
        updated.latestReadingTimestamp = sample.date
        // Back-derive activation timestamp from the sensor's own age counter
        // (lifeCount, minutes since activation). Only set it once -- later
        // readings shouldn't shift it (small drift would otherwise jitter the
        // lifecycle bar).
        if updated.activatedAt == nil {
            updated.activatedAt = sample.date.addingTimeInterval(-TimeInterval(sample.lifeCount) * 60)
        }
        setState(updated)

        notifyStateObservers()

        let newSample = NewGlucoseSample(
            date: sample.date,
            quantity: HKQuantity(unit: .milligramsPerDeciliter, doubleValue: sample.valueMgDL),
            condition: nil,
            trend: Self.mapTrend(sample.trend),
            trendRate: sample.rateOfChangeMgDLPerMinute.map {
                HKQuantity(unit: .milligramsPerDeciliterPerMinute, doubleValue: $0)
            },
            isDisplayOnly: false,
            wasUserEntered: false,
            syncIdentifier: "libreloop-\(state.sensorSerial ?? "unknown")-\(sample.lifeCount)",
            syncVersion: 1,
            device: device
        )

        delegateQueue?.async { [weak self] in
            guard let self else { return }
            self.cgmManagerDelegate?.cgmManager(self, hasNew: .newData([newSample]))
        }
    }

    private func handleMonitorDisconnect() {
        log.warning("monitor reported disconnect; clearing and scheduling reconnect")
        self.monitor = nil
        scheduleReconnect(attempt: 0)
    }

    /// Backoff schedule (seconds) for unattended reconnect after a BLE drop.
    /// Mirrors the G7BluetoothManager pattern: short initial delay then a
    /// climbing series, capping at a minute and repeating indefinitely until
    /// a session establishes or the user deletes the CGM.
    private static let reconnectBackoff: [TimeInterval] = [2, 5, 15, 30, 60]

    private static let reconnectTaskKey = "LibreLoop.reconnectTask"
    private static var reconnectTasks: [ObjectIdentifier: Task<Void, Never>] = [:]

    func scheduleReconnect(attempt: Int) {
        cancelReconnect()
        let delay = Self.reconnectBackoff[min(attempt, Self.reconnectBackoff.count - 1)]
        log.info("reconnect: scheduling attempt #\(attempt + 1) in \(Int(delay))s")
        let task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard let self else { return }
            guard !Task.isCancelled else { return }
            await self.runReconnect(attempt: attempt)
        }
        Self.reconnectTasks[ObjectIdentifier(self)] = task
    }

    func cancelReconnect() {
        let key = ObjectIdentifier(self)
        if let task = Self.reconnectTasks[key] {
            task.cancel()
            Self.reconnectTasks.removeValue(forKey: key)
        }
    }

    private func runReconnect(attempt: Int) async {
        guard monitor == nil else {
            log.info("reconnect: already connected; aborting attempt")
            return
        }
        guard let blePIN = state.blePIN, let serial = state.sensorSerial else {
            log.error("reconnect: missing saved state; manual re-pair required")
            return
        }
        let expectedPeripheral = state.peripheralID
        log.info("reconnect: attempt #\(attempt + 1) starting (peripheralID=\(expectedPeripheral?.uuidString ?? "any"))")
        do {
            let outcome = try await LibreLoopPairingService().reconnect(
                blePIN: blePIN,
                expectedPeripheralID: expectedPeripheral
            ) { stage in
                log.info("reconnect stage: \(String(describing: stage))")
            }
            try LibreLoopKeychain.save(
                LibreLoopKeychain.SessionKeys(kEnc: outcome.kEnc, ivEnc: outcome.ivEnc),
                forSensorSerial: serial
            )
            await MainActor.run {
                self.adopt(monitor: outcome.monitor)
            }
            log.info("reconnect: succeeded on attempt #\(attempt + 1)")
        } catch {
            log.error("reconnect: attempt #\(attempt + 1) failed: \(String(describing: error)) - rescheduling")
            scheduleReconnect(attempt: attempt + 1)
        }
    }

    /// Manual "Reconnect now" entry point used by the settings UI.
    public func reconnectIfPossible() async {
        cancelReconnect()
        await runReconnect(attempt: 0)
    }

    private static func mapTrend(_ trend: LibreLoopGlucoseSample.Trend) -> GlucoseTrend? {
        switch trend {
        case .notDetermined: return nil
        case .risingQuickly:  return .upUp
        case .rising:         return .up
        case .stable:         return .flat
        case .falling:        return .down
        case .fallingQuickly: return .downDown
        }
    }

    func setState(_ newState: LibreLoopCGMManagerState) {
        state = newState
        delegateQueue?.async { [weak self] in
            guard let self else { return }
            self.cgmManagerDelegate?.cgmManagerDidUpdateState(self)
        }
        notifyStateObservers()
    }
}
