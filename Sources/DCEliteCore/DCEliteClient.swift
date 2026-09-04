import Foundation

public final class DCEliteClient: @unchecked Sendable {
    private let transport: HIDTransport
    private let transactionLock = NSRecursiveLock()

    public init(transport: HIDTransport) {
        self.transport = transport
    }

    public var deviceInfo: DeviceInfo { transport.deviceInfo }

    public func readVersion() throws -> (DeviceVersion, HIDPacket) {
        transactionLock.lock()
        defer { transactionLock.unlock() }
        let packet = try transport.exchange(.version)
        return (try DCEliteProtocol.parseVersion(packet), packet)
    }

    public func readFilters() throws -> (FilterSettings, HIDPacket) {
        transactionLock.lock()
        defer { transactionLock.unlock() }
        let packet = try transport.exchange(.filters)
        return (try DCEliteProtocol.parseFilters(packet), packet)
    }

    public func readMainSettings() throws -> (MainSettings, HIDPacket) {
        transactionLock.lock()
        defer { transactionLock.unlock() }
        let packet = try transport.exchange(.mainSettings)
        return (try DCEliteProtocol.parseMainSettings(packet), packet)
    }

    public func readSettings() throws -> DCEliteSettings {
        transactionLock.lock()
        defer { transactionLock.unlock() }
        let (filters, _) = try readFilters()
        let (main, _) = try readMainSettings()
        return DCEliteSettings(filters: filters, main: main)
    }

    @discardableResult
    public func setPCMFilter(_ value: PCMFilter) throws -> FilterSettings {
        try updateFilters { $0.changingPCMFilter(to: value) }
    }

    @discardableResult
    public func setDSDFilter(_ value: DSDFilter) throws -> FilterSettings {
        try updateFilters { $0.changingDSDFilter(to: value) }
    }

    @discardableResult
    public func setPCMReduction(_ value: PCMReduction) throws -> MainSettings {
        try updateMainSettings { $0.changingPCMReduction(to: value) }
    }

    @discardableResult
    public func setVolumeMatch(_ value: Bool) throws -> MainSettings {
        try updateMainSettings { $0.changingVolumeMatch(to: value) }
    }

    @discardableResult
    public func setCoax(_ value: Bool) throws -> MainSettings {
        try updateMainSettings { $0.changingCoax(to: value) }
    }

    @discardableResult
    public func setOffscreenKnob(_ value: Bool) throws -> MainSettings {
        try updateMainSettings { $0.changingOffscreenKnob(to: value) }
    }

    private func updateFilters(
        _ mutation: (FilterSettings) -> FilterSettings
    ) throws -> FilterSettings {
        transactionLock.lock()
        defer { transactionLock.unlock() }

        let (current, _) = try readFilters()
        let requested = mutation(current)
        if requested != current {
            _ = try transport.exchange(.filters(requested))
        }
        let (confirmed, _) = try readFilters()
        guard confirmed == requested else {
            throw DCEliteError.writeVerificationFailed(group: "filter")
        }
        return confirmed
    }

    private func updateMainSettings(
        _ mutation: (MainSettings) -> MainSettings
    ) throws -> MainSettings {
        transactionLock.lock()
        defer { transactionLock.unlock() }

        let (current, _) = try readMainSettings()
        let requested = mutation(current)
        if requested != current {
            _ = try transport.exchange(.mainSettings(requested))
        }
        let (confirmed, _) = try readMainSettings()
        guard confirmed == requested else {
            throw DCEliteError.writeVerificationFailed(group: "main")
        }
        return confirmed
    }
}
