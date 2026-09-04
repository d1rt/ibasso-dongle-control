import Foundation
import IOKit.hid

public enum DeviceDiscovery {
    static func configure(_ manager: IOHIDManager, profiles: [DeviceProfileInfo]) {
        let matches = profiles.map { profile in
            [
                kIOHIDVendorIDKey as String: profile.vendorID,
                kIOHIDProductIDKey as String: profile.productID
            ] as [String: Any]
        }
        IOHIDManagerSetDeviceMatchingMultiple(manager, matches as CFArray)
    }

    static func profile(for device: IOHIDDevice, profiles: [DeviceProfileInfo]) -> DeviceProfileInfo? {
        guard let vendorID = intProperty(device, key: kIOHIDVendorIDKey),
              let productID = intProperty(device, key: kIOHIDProductIDKey) else { return nil }
        return profiles.first { $0.vendorID == vendorID && $0.productID == productID }
    }

    static func supportedDevices(
        in manager: IOHIDManager,
        profiles: [DeviceProfileInfo]
    ) -> [(IOHIDDevice, DeviceProfileInfo)] {
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return []
        }
        return devices.compactMap { device in
            profile(for: device, profiles: profiles).map { (device, $0) }
        }
    }

    static func intProperty(_ device: IOHIDDevice, key: String) -> Int? {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue
    }

    static func stringProperty(_ device: IOHIDDevice, key: String) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }
}
