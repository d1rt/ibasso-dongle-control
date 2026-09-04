public protocol DeviceServicing: Sendable {
    func loadState(for profile: DeviceProfileInfo) throws -> DeviceState
    func apply(_ change: SettingChange, to profile: DeviceProfileInfo) throws -> SettingsUpdate
}

public final class DeviceControlService: DeviceServicing, @unchecked Sendable {
    private let debugLogger: HIDTransport.DebugLogger?

    public init(debugLogger: HIDTransport.DebugLogger? = nil) {
        self.debugLogger = debugLogger
    }

    public func loadState(for profile: DeviceProfileInfo) throws -> DeviceState {
        let transport = try HIDTransport(profile: profile, debugLogger: debugLogger)
        let client = DongleClient(transport: transport)
        let (version, _) = try client.readVersion()
        let settings = try client.readSettings()
        return DeviceState(
            profile: profile,
            deviceInfo: client.deviceInfo,
            version: version,
            settings: settings,
            audioDetected: AudioDeviceDiscovery.isDetected(for: profile)
        )
    }

    public func apply(
        _ change: SettingChange,
        to profile: DeviceProfileInfo
    ) throws -> SettingsUpdate {
        let transport = try HIDTransport(profile: profile, debugLogger: debugLogger)
        return try DongleClient(transport: transport).apply(change)
    }
}
