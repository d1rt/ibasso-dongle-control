public enum ReadCommand: Sendable {
    case filters
    case mainSettings
    case version

    public var request: HIDPacket {
        switch self {
        case .filters:
            try! HIDPacket.command(sequence: 0x59, command: 0x21)
        case .mainSettings:
            try! HIDPacket.command(sequence: 0x62, command: 0x31)
        case .version:
            try! HIDPacket.command(sequence: 0x58, command: 0xF1)
        }
    }

    public var alternateReportTag: UInt8? {
        switch self {
        case .filters: 0x22
        case .mainSettings: 0x32
        case .version: nil
        }
    }
}

public enum WriteCommand: Sendable {
    case filters(FilterSettings)
    case mainSettings(MainSettings)

    public var request: HIDPacket {
        switch self {
        case let .filters(settings):
            try! HIDPacket.command(
                sequence: 0x11,
                command: 0x20,
                payload: [settings.pcmFilter.rawValue, settings.dsdFilter.rawValue, 0, 0]
            )
        case let .mainSettings(settings):
            try! HIDPacket.command(
                sequence: 0x19,
                command: 0x30,
                payload: [
                    settings.coaxEnabled.byteValue,
                    settings.pcmReduction.rawValue,
                    settings.volumeMatchEnabled.byteValue,
                    settings.offscreenKnobEnabled.byteValue
                ]
            )
        }
    }
}

public enum DCEliteProtocol {
    public static func parseFilters(_ packet: HIDPacket) throws -> FilterSettings {
        try validateResponse(packet, for: .filters)
        guard let pcm = PCMFilter(rawValue: packet.bytes[4]) else {
            throw DCEliteError.unsupportedValue(field: "PCM filter", value: packet.bytes[4])
        }
        guard let dsd = DSDFilter(rawValue: packet.bytes[5]) else {
            throw DCEliteError.unsupportedValue(field: "DSD filter", value: packet.bytes[5])
        }
        return FilterSettings(pcmFilter: pcm, dsdFilter: dsd)
    }

    public static func parseMainSettings(_ packet: HIDPacket) throws -> MainSettings {
        try validateResponse(packet, for: .mainSettings)
        guard let pcmReduction = PCMReduction(rawValue: packet.bytes[5]) else {
            throw DCEliteError.unsupportedValue(
                field: "PCM reduction",
                value: packet.bytes[5]
            )
        }
        return MainSettings(
            coaxEnabled: try parseBoolean(packet.bytes[4], field: "Coax"),
            pcmReduction: pcmReduction,
            volumeMatchEnabled: try parseBoolean(packet.bytes[6], field: "Volume match"),
            offscreenKnobEnabled: try parseBoolean(packet.bytes[7], field: "Off-screen knob")
        )
    }

    public static func parseVersion(_ packet: HIDPacket) throws -> DeviceVersion {
        try validateResponse(packet, for: .version)
        return DeviceVersion(bytes: packet.bytes)
    }

    public static func validateResponse(_ packet: HIDPacket, for command: ReadCommand) throws {
        if packet.sequence == command.request.sequence {
            return
        }
        if let alternateTag = command.alternateReportTag,
           packet.sequence == 0,
           packet.bytes[1] == alternateTag {
            return
        }
        throw DCEliteError.unexpectedResponse(
            expectedSequence: command.request.sequence,
            actualSequence: packet.sequence
        )
    }

    private static func parseBoolean(_ value: UInt8, field: String) throws -> Bool {
        switch value {
        case 0: false
        case 1: true
        default: throw DCEliteError.unsupportedValue(field: field, value: value)
        }
    }
}

private extension Bool {
    var byteValue: UInt8 { self ? 1 : 0 }
}
