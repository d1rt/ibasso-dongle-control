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
    public var pcmFilter: PCMFilter
    public var dsdFilter: DSDFilter
}

public struct MainSettings: Equatable, Sendable {
    public var coaxEnabled: Bool
    public var pcmReduction: PCMReduction
    public var volumeMatchEnabled: Bool
    public var offscreenKnobEnabled: Bool
}

public struct DCEliteSettings: Equatable, Sendable {
    public var filters: FilterSettings
    public var main: MainSettings
}

public extension FilterSettings {
    func changingPCMFilter(to value: PCMFilter) -> FilterSettings {
        var copy = self
        copy.pcmFilter = value
        return copy
    }

    func changingDSDFilter(to value: DSDFilter) -> FilterSettings {
        var copy = self
        copy.dsdFilter = value
        return copy
    }
}

public extension MainSettings {
    func changingPCMReduction(to value: PCMReduction) -> MainSettings {
        var copy = self
        copy.pcmReduction = value
        return copy
    }

    func changingVolumeMatch(to value: Bool) -> MainSettings {
        var copy = self
        copy.volumeMatchEnabled = value
        return copy
    }

    func changingCoax(to value: Bool) -> MainSettings {
        var copy = self
        copy.coaxEnabled = value
        return copy
    }

    func changingOffscreenKnob(to value: Bool) -> MainSettings {
        var copy = self
        copy.offscreenKnobEnabled = value
        return copy
    }
}

public struct DeviceVersion: Equatable, Sendable {
    public let bytes: [UInt8]

    public var displayValue: String {
        let majorNibble = (bytes[4] >> 4) & 0x0F
        if majorNibble == 0 {
            return "1.\(bytes[5]).\(String(bytes[6], radix: 16, uppercase: false))"
        }
        return "\(String(majorNibble, radix: 16)).\(String(bytes[5], radix: 16)).\(String(bytes[6], radix: 16))"
    }
}
