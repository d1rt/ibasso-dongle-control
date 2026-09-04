import Foundation

public final class DongleClient: @unchecked Sendable {
    private let transport: any HIDTransporting
    private let transactionLock = NSRecursiveLock()

    public init(transport: any HIDTransporting) {
        self.transport = transport
    }

    public var profile: DeviceProfileInfo { transport.profile }
    public var deviceInfo: DeviceInfo { transport.deviceInfo }

    public func readVersion() throws -> (DeviceVersion, HIDPacket) {
        transactionLock.lock()
        defer { transactionLock.unlock() }
        try validateControllerFamily()
        let command = DCEliteReadCommand.version
        let packet = try exchange(command)
        return (try DCEliteProtocol.parseVersion(packet), packet)
    }

    public func readFilters() throws -> (FilterSettings, HIDPacket) {
        transactionLock.lock()
        defer { transactionLock.unlock() }
        try validateControllerFamily()
        let command = DCEliteReadCommand.filters
        let packet = try exchange(command)
        return (try DCEliteProtocol.parseFilters(packet), packet)
    }

    public func readMainSettings() throws -> (MainSettings, HIDPacket) {
        transactionLock.lock()
        defer { transactionLock.unlock() }
        try validateControllerFamily()
        let command = DCEliteReadCommand.mainSettings
        let packet = try exchange(command)
        return (try DCEliteProtocol.parseMainSettings(packet), packet)
    }

    public func readSettings() throws -> DongleSettings {
        transactionLock.lock()
        defer { transactionLock.unlock() }
        let (filters, _) = try readFilters()
        let (main, _) = try readMainSettings()
        return DongleSettings(filters: filters, main: main)
    }

    @discardableResult
    public func apply(_ change: SettingChange) throws -> SettingsUpdate {
        transactionLock.lock()
        defer { transactionLock.unlock() }

        guard profile.supports(change.capability) else {
            throw DongleError.unsupportedCapability(change.capability)
        }

        switch change {
        case let .pcmFilter(value):
            return .filters(try updateFilters { $0.changingPCMFilter(to: value) })
        case let .dsdFilter(value):
            return .filters(try updateFilters { $0.changingDSDFilter(to: value) })
        case let .pcmVolumeReduction(value):
            return .main(try updateMain { $0.changingPCMReduction(to: value) })
        case let .volumeMatch(value):
            return .main(try updateMain { $0.changingVolumeMatch(to: value) })
        case let .coax(value):
            return .main(try updateMain { $0.changingCoax(to: value) })
        case let .offScreenVolumeKnob(value):
            return .main(try updateMain { $0.changingOffScreenVolumeKnob(to: value) })
        }
    }

    private func updateFilters(
        _ mutation: (FilterSettings) -> FilterSettings
    ) throws -> FilterSettings {
        let (current, _) = try readFilters()
        let requested = mutation(current)
        if requested != current {
            let command = DCEliteWriteCommand.filters(requested)
            _ = try transport.exchange(
                packet: command.request,
                expectedSequence: command.request.sequence,
                alternateTag: nil,
                timeout: 0.5
            )
        }
        let (confirmed, _) = try readFilters()
        guard confirmed == requested else {
            throw DongleError.writeVerificationFailed(group: "filter")
        }
        return confirmed
    }

    private func updateMain(
        _ mutation: (MainSettings) -> MainSettings
    ) throws -> MainSettings {
        let (current, _) = try readMainSettings()
        let requested = mutation(current)
        if requested != current {
            let command = DCEliteWriteCommand.mainSettings(requested)
            _ = try transport.exchange(
                packet: command.request,
                expectedSequence: command.request.sequence,
                alternateTag: nil,
                timeout: 0.5
            )
        }
        let (confirmed, _) = try readMainSettings()
        guard confirmed == requested else {
            throw DongleError.writeVerificationFailed(group: "main")
        }
        return confirmed
    }

    private func exchange(_ command: DCEliteReadCommand) throws -> HIDPacket {
        try transport.exchange(
            packet: command.request,
            expectedSequence: command.request.sequence,
            alternateTag: command.alternateReportTag,
            timeout: 0.5
        )
    }

    private func validateControllerFamily() throws {
        switch profile.controllerFamily {
        case .dcEliteHIDV1:
            return
        }
    }
}
