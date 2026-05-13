import Foundation
import CoreBluetooth
import LibreCRKit
import os.log

private let log = Logger(subsystem: "org.loopkit.LibreLoop", category: "Monitor")

/// Wraps a live `SensorSession` after pairing has succeeded. Decrypts
/// glucose-channel notifications using the session keys (`kEnc`/`ivEnc`)
/// and surfaces usable readings via a callback.
///
/// Lifetime: monitor is alive only while the underlying BLE session is
/// connected. LibreCRKit has no reconnect-with-saved-keys API, so an
/// app kill or out-of-range disconnect requires a re-pair to resume.
public final class LibreLoopSensorMonitor: @unchecked Sendable {
    public typealias ReadingHandler = @Sendable (LibreLoopGlucoseSample) -> Void
    public typealias DisconnectHandler = @Sendable () -> Void

    private let session: SensorSession
    // Held strongly so the underlying CBCentralManager survives past pairing.
    // SensorScanner owns the central manager + a [UUID: SensorSession] strong
    // map; dropping it tears the BLE connection down.
    private let scanner: SensorScanner
    private let decoder: DataPlaneDecoder
    private let assembler = DataPlaneNotificationAssembler()
    private let lock = NSLock()

    private var task: Task<Void, Never>?
    private var readingHandler: ReadingHandler?
    private var disconnectHandler: DisconnectHandler?

    init(scanner: SensorScanner, session: SensorSession, kEnc: Data, ivEnc: Data) throws {
        self.scanner = scanner
        self.session = session
        let crypto = try DataPlaneCrypto(kEnc: kEnc, ivEnc: ivEnc)
        self.decoder = DataPlaneDecoder(crypto: crypto)
    }

    public func setHandlers(onReading: @escaping ReadingHandler,
                            onDisconnect: @escaping DisconnectHandler) {
        lock.lock()
        defer { lock.unlock() }
        self.readingHandler = onReading
        self.disconnectHandler = onDisconnect
    }

    public func start() {
        lock.lock()
        let alreadyRunning = task != nil
        lock.unlock()
        guard !alreadyRunning else { return }

        let newTask = Task { [weak self] in
            guard let self else { return }
            log.info("monitor starting; refreshing post-auth notifications")
            await self.refreshPostAuthNotifications()
            log.info("monitor consuming session.notifications()")
            var eventCount = 0
            for await event in self.session.notifications() {
                eventCount += 1
                log.debug("notify #\(eventCount) char=\(event.characteristic.uuidString) len=\(event.fragment.count)")
                self.handle(event)
                if Task.isCancelled { break }
            }
            log.warning("monitor notification stream ended after \(eventCount) events")
            self.lock.lock()
            let handler = self.disconnectHandler
            self.lock.unlock()
            handler?()
        }
        lock.lock()
        task = newTask
        lock.unlock()
    }

    /// After Phase 6 the sensor's data-plane characteristics need a CCCD
    /// off→on cycle before the sensor will start streaming. Without this
    /// the BLE session stays open but no glucose notifications arrive, and
    /// eventually iOS or the sensor drops the link. Mirrors the upstream
    /// PoC's `refreshFirstPairPostAuthNotifications`.
    private func refreshPostAuthNotifications() async {
        let chars: [(String, CBUUID)] = [
            ("patchControl", LibreSensorGATT.Char.patchControl),
            ("eventLog",     LibreSensorGATT.Char.eventLog),
            ("factoryData",  LibreSensorGATT.Char.factoryData),
            ("glucoseData",  LibreSensorGATT.Char.glucoseData),
            ("patchStatus",  LibreSensorGATT.Char.patchStatus),
        ]
        for (name, uuid) in chars {
            do {
                log.info("CCCD \(name) off")
                try await session.setNotify(false, for: uuid, timeout: 8)
                try? await Task.sleep(nanoseconds: 90_000_000)
                log.info("CCCD \(name) on")
                try await session.setNotify(true, for: uuid, timeout: 8)
                try? await Task.sleep(nanoseconds: 90_000_000)
            } catch {
                log.error("CCCD \(name) refresh failed: \(String(describing: error))")
            }
        }
        log.info("CCCD refresh complete")
    }

    public func stop() {
        lock.lock()
        let t = task
        task = nil
        lock.unlock()
        t?.cancel()
    }

    private func handle(_ event: NotifyEvent) {
        guard let channel = DataPlaneChannel(uuidString: event.characteristic.uuidString) else {
            log.debug("notify on unmapped char \(event.characteristic.uuidString)")
            return
        }
        guard let fullFrame = assembler.feed(fragment: event.fragment, channel: channel) else {
            log.debug("\(channel.rawValue) partial fragment buffered, waiting for completion")
            return
        }
        do {
            let frame = try DataFrame.parse(fullFrame)
            let packet = try decoder.decrypt(frame: frame, channel: channel)
            switch packet.payload {
            case .realtimeGlucose(let reading):
                if let sample = Self.makeSample(from: reading, receivedAt: event.receivedAt) {
                    log.info("glucose \(Int(sample.valueMgDL)) mg/dL lifeCount=\(sample.lifeCount) trend=\(String(describing: sample.trend))")
                    lock.lock()
                    let handler = readingHandler
                    lock.unlock()
                    handler?(sample)
                } else {
                    log.info("glucose reading not actionable; skipped")
                }
            default:
                log.debug("\(channel.rawValue) packet kind=\(packet.kind.rawValue) (no sample)")
            }
        } catch {
            log.error("\(channel.rawValue) decode failed: \(String(describing: error))")
        }
    }

    private static func makeSample(from reading: RealtimeGlucoseReading, receivedAt: Date) -> LibreLoopGlucoseSample? {
        guard reading.isCurrentGlucoseUsable, let mgdl = reading.currentGlucoseMgDL else {
            return nil
        }
        return LibreLoopGlucoseSample(
            date: receivedAt,
            valueMgDL: Double(mgdl),
            trend: mapTrend(reading.trendKind),
            rateOfChangeMgDLPerMinute: reading.rateOfChangeMgDLPerMinute.map(Double.init),
            lifeCount: reading.lifeCount,
            sensorTemperatureRaw: reading.temperature,
            isActionable: reading.actionability == .actionable
        )
    }

    private static func mapTrend(_ libre: Libre3Trend) -> LibreLoopGlucoseSample.Trend {
        switch libre {
        case .notDetermined: return .notDetermined
        case .fallingQuickly: return .fallingQuickly
        case .falling: return .falling
        case .stable: return .stable
        case .rising: return .rising
        case .risingQuickly: return .risingQuickly
        case .raw: return .notDetermined
        }
    }
}

extension LibreLoopSensorMonitor {
    /// Internal builder used by `LibreLoopPairingService`.
    static func make(scanner: SensorScanner, session: SensorSession, kEnc: Data, ivEnc: Data) throws -> LibreLoopSensorMonitor {
        try LibreLoopSensorMonitor(scanner: scanner, session: session, kEnc: kEnc, ivEnc: ivEnc)
    }
}
