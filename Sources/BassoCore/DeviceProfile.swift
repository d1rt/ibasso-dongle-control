import Foundation

public enum DeviceCapability: String, CaseIterable, Hashable, Sendable {
    case pcmFilter
    case dsdFilter
    case pcmVolumeReduction
    case volumeMatch
    case coax
    case offScreenVolumeKnob
}

public enum ControllerFamily: String, Sendable {
    case dcEliteHIDV1
}

public struct DeviceProfileInfo: Equatable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let vendorID: Int
    public let productID: Int
    public let controllerFamily: ControllerFamily
    public let capabilities: Set<DeviceCapability>
    public let audioDeviceName: String?
    public let audioManufacturer: String?
    public let notes: String?

    public init(
        id: String,
        displayName: String,
        vendorID: Int,
        productID: Int,
        controllerFamily: ControllerFamily,
        capabilities: Set<DeviceCapability>,
        audioDeviceName: String? = nil,
        audioManufacturer: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.vendorID = vendorID
        self.productID = productID
        self.controllerFamily = controllerFamily
        self.capabilities = capabilities
        self.audioDeviceName = audioDeviceName
        self.audioManufacturer = audioManufacturer
        self.notes = notes
    }

    public func supports(_ capability: DeviceCapability) -> Bool {
        capabilities.contains(capability)
    }
}

public protocol DeviceProfile: Sendable {
    var info: DeviceProfileInfo { get }
}

public enum DeviceRegistry {
    public static let profiles: [DeviceProfileInfo] = [DCEliteProfile().info]

    public static func profile(vendorID: Int, productID: Int) -> DeviceProfileInfo? {
        profiles.first { $0.vendorID == vendorID && $0.productID == productID }
    }
}
