public struct DeviceState: Equatable, Sendable {
    public let profile: DeviceProfileInfo
    public let deviceInfo: DeviceInfo
    public let version: DeviceVersion
    public var settings: DongleSettings
    public let audioDetected: Bool

    public init(
        profile: DeviceProfileInfo,
        deviceInfo: DeviceInfo,
        version: DeviceVersion,
        settings: DongleSettings,
        audioDetected: Bool
    ) {
        self.profile = profile
        self.deviceInfo = deviceInfo
        self.version = version
        self.settings = settings
        self.audioDetected = audioDetected
    }
}
