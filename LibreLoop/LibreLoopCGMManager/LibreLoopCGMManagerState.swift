import Foundation

public struct LibreLoopCGMManagerState: RawRepresentable, Equatable {
    public typealias RawValue = [String: Any]

    public var receiverID: Data?
    public var sensorSerial: String?
    public var bleAddress: String?
    /// The BLE PIN the sensor returned with the last activation/switch-receiver
    /// response. Each successful A8 *changes* this value, so it must be
    /// persisted the moment NFC succeeds (before BLE auth is attempted).
    /// Losing this PIN means the sensor can't be authenticated again without
    /// another A8, which would burn yet another PIN.
    public var blePIN: Data?
    /// CBPeripheral.identifier captured at pair time. Reconnect uses this to
    /// match the right discovery instead of accepting any nearby sensor.
    public var peripheralID: UUID?
    public var activatedAt: Date?
    public var latestReadingTimestamp: Date?

    public init() {}

    public init?(rawValue: RawValue) {
        self.receiverID = rawValue["receiverID"] as? Data
        self.sensorSerial = rawValue["sensorSerial"] as? String
        self.bleAddress = rawValue["bleAddress"] as? String
        self.blePIN = rawValue["blePIN"] as? Data
        self.peripheralID = (rawValue["peripheralID"] as? String).flatMap(UUID.init(uuidString:))
        self.activatedAt = rawValue["activatedAt"] as? Date
        self.latestReadingTimestamp = rawValue["latestReadingTimestamp"] as? Date
    }

    public var rawValue: RawValue {
        var raw: RawValue = [:]
        raw["receiverID"] = receiverID
        raw["sensorSerial"] = sensorSerial
        raw["bleAddress"] = bleAddress
        raw["blePIN"] = blePIN
        raw["peripheralID"] = peripheralID?.uuidString
        raw["activatedAt"] = activatedAt
        raw["latestReadingTimestamp"] = latestReadingTimestamp
        return raw
    }
}
