public enum DCEliteReadCommand: Sendable {
    case filters
    case mainSettings
    case version

    public var request: HIDPacket {
        switch self {
        case .filters: try! HIDPacket.command(sequence: 0x59, command: 0x21)
        case .mainSettings: try! HIDPacket.command(sequence: 0x62, command: 0x31)
        case .version: try! HIDPacket.command(sequence: 0x58, command: 0xF1)
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

public enum DCEliteWriteCommand: Sendable {
    case filters(FilterSettings)
    case mainSettings(MainSettings)

    public var request: HIDPacket {
        switch self {
        case let .filters(settings):
            try! HIDPacket.command(sequence: 0x11, command: 0x20, payload: settings.rawPayload)
        case let .mainSettings(settings):
            try! HIDPacket.command(sequence: 0x19, command: 0x30, payload: settings.rawPayload)
        }
    }
}

public enum DCEliteProtocol {
    public static func parseFilters(_ packet: HIDPacket) throws -> FilterSettings {
        try validateResponse(packet, for: .filters)
        return try FilterSettings(rawPayload: Array(packet.payload))
    }

    public static func parseMainSettings(_ packet: HIDPacket) throws -> MainSettings {
        try validateResponse(packet, for: .mainSettings)
        return try MainSettings(rawPayload: Array(packet.payload))
    }

    public static func parseVersion(_ packet: HIDPacket) throws -> DeviceVersion {
        try validateResponse(packet, for: .version)
        return DeviceVersion(bytes: packet.bytes)
    }

    public static func validateResponse(_ packet: HIDPacket, for command: DCEliteReadCommand) throws {
        if packet.sequence == command.request.sequence { return }
        if let alternateTag = command.alternateReportTag,
           packet.sequence == 0,
           packet.bytes[1] == alternateTag { return }
        throw DongleError.unexpectedResponse(
            expectedSequence: command.request.sequence,
            actualSequence: packet.sequence
        )
    }
}

public struct DeviceVersion: Equatable, Sendable {
    public let bytes: [UInt8]

    public init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    public var displayValue: String {
        let majorNibble = (bytes[4] >> 4) & 0x0F
        if majorNibble == 0 {
            return "1.\(bytes[5]).\(String(bytes[6], radix: 16, uppercase: false))"
        }
        return "\(String(majorNibble, radix: 16)).\(String(bytes[5], radix: 16)).\(String(bytes[6], radix: 16))"
    }
}
