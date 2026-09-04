public enum PCMFilter: UInt8, CaseIterable, Sendable {
    case sharpRollOff = 0
    case slowRollOff = 1

    public var displayName: String {
        switch self {
        case .sharpRollOff: "Sharp Roll-Off"
        case .slowRollOff: "Slow Roll-Off"
        }
    }
}

public enum DSDFilter: UInt8, CaseIterable, Sendable {
    case low = 0
    case medium = 1
    case high = 2

    public var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}

public enum PCMReduction: UInt8, CaseIterable, Sendable {
    case zeroDB = 0
    case minusOneDB = 1
    case minusTwoDB = 2
    case minusThreeDB = 3

    public var decibels: Int { -Int(rawValue) }
    public var displayName: String { "\(decibels) dB" }
}

public struct FilterSettings: Equatable, Sendable {
    public let pcmFilter: PCMFilter
    public let dsdFilter: DSDFilter
    public private(set) var rawPayload: [UInt8]

    public init(rawPayload: [UInt8]) throws {
        guard rawPayload.count == 4 else {
            throw DongleError.invalidPacketLength(actual: rawPayload.count + 4)
        }
        guard let pcmFilter = PCMFilter(rawValue: rawPayload[0]) else {
            throw DongleError.unsupportedValue(field: "PCM filter", value: rawPayload[0])
        }
        guard let dsdFilter = DSDFilter(rawValue: rawPayload[1]) else {
            throw DongleError.unsupportedValue(field: "DSD filter", value: rawPayload[1])
        }
        self.pcmFilter = pcmFilter
        self.dsdFilter = dsdFilter
        self.rawPayload = rawPayload
    }

    public init(
        pcmFilter: PCMFilter,
        dsdFilter: DSDFilter,
        reservedBytes: [UInt8] = [0, 0]
    ) {
        precondition(reservedBytes.count == 2)
        self.pcmFilter = pcmFilter
        self.dsdFilter = dsdFilter
        rawPayload = [pcmFilter.rawValue, dsdFilter.rawValue] + reservedBytes
    }

    public func changingPCMFilter(to value: PCMFilter) -> FilterSettings {
        var bytes = rawPayload
        bytes[0] = value.rawValue
        return try! FilterSettings(rawPayload: bytes)
    }

    public func changingDSDFilter(to value: DSDFilter) -> FilterSettings {
        var bytes = rawPayload
        bytes[1] = value.rawValue
        return try! FilterSettings(rawPayload: bytes)
    }
}

public struct MainSettings: Equatable, Sendable {
    public let coaxEnabled: Bool
    public let pcmReduction: PCMReduction
    public let volumeMatchEnabled: Bool
    public private(set) var rawPayload: [UInt8]

    public var opaqueReservedByte: UInt8 { rawPayload[3] }

    public init(rawPayload: [UInt8]) throws {
        guard rawPayload.count == 4 else {
            throw DongleError.invalidPacketLength(actual: rawPayload.count + 4)
        }
        coaxEnabled = try Self.parseBoolean(rawPayload[0], field: "Coax")
        guard let pcmReduction = PCMReduction(rawValue: rawPayload[1]) else {
            throw DongleError.unsupportedValue(field: "PCM reduction", value: rawPayload[1])
        }
        self.pcmReduction = pcmReduction
        volumeMatchEnabled = try Self.parseBoolean(rawPayload[2], field: "Volume match")
        self.rawPayload = rawPayload
    }

    public init(
        coaxEnabled: Bool,
        pcmReduction: PCMReduction,
        volumeMatchEnabled: Bool,
        opaqueReservedByte: UInt8 = 0
    ) {
        self.coaxEnabled = coaxEnabled
        self.pcmReduction = pcmReduction
        self.volumeMatchEnabled = volumeMatchEnabled
        rawPayload = [
            coaxEnabled.byteValue,
            pcmReduction.rawValue,
            volumeMatchEnabled.byteValue,
            opaqueReservedByte
        ]
    }

    public func changingPCMReduction(to value: PCMReduction) -> MainSettings {
        changingByte(at: 1, to: value.rawValue)
    }

    public func changingVolumeMatch(to value: Bool) -> MainSettings {
        changingByte(at: 2, to: value.byteValue)
    }

    public func changingCoax(to value: Bool) -> MainSettings {
        changingByte(at: 0, to: value.byteValue)
    }

    func changingOffScreenVolumeKnob(to value: Bool) -> MainSettings {
        changingByte(at: 3, to: value.byteValue)
    }

    private func changingByte(at index: Int, to value: UInt8) -> MainSettings {
        var bytes = rawPayload
        bytes[index] = value
        return try! MainSettings(rawPayload: bytes)
    }

    private static func parseBoolean(_ value: UInt8, field: String) throws -> Bool {
        switch value {
        case 0: false
        case 1: true
        default: throw DongleError.unsupportedValue(field: field, value: value)
        }
    }
}

public struct DongleSettings: Equatable, Sendable {
    public var filters: FilterSettings
    public var main: MainSettings

    public init(filters: FilterSettings, main: MainSettings) {
        self.filters = filters
        self.main = main
    }
}

public enum SettingChange: Equatable, Sendable {
    case pcmFilter(PCMFilter)
    case dsdFilter(DSDFilter)
    case pcmVolumeReduction(PCMReduction)
    case volumeMatch(Bool)
    case coax(Bool)
    case offScreenVolumeKnob(Bool)

    public var capability: DeviceCapability {
        switch self {
        case .pcmFilter: .pcmFilter
        case .dsdFilter: .dsdFilter
        case .pcmVolumeReduction: .pcmVolumeReduction
        case .volumeMatch: .volumeMatch
        case .coax: .coax
        case .offScreenVolumeKnob: .offScreenVolumeKnob
        }
    }
}

public enum SettingsUpdate: Equatable, Sendable {
    case filters(FilterSettings)
    case main(MainSettings)
}

private extension Bool {
    var byteValue: UInt8 { self ? 1 : 0 }
}
