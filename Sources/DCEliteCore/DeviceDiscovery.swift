import Foundation
import IOKit.hid

public enum DeviceDiscovery {
    public static func isConnected() -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        configure(manager)
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else {
            return false
        }
        defer { IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone)) }
        return firstDevice(in: manager) != nil
    }

    static func configure(_ manager: IOHIDManager) {
        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: DeviceInfo.vendorID,
            kIOHIDProductIDKey as String: DeviceInfo.productID
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)
    }

    static func firstDevice(in manager: IOHIDManager) -> IOHIDDevice? {
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else {
            return nil
        }
        return devices.first { device in
            intProperty(device, key: kIOHIDVendorIDKey) == DeviceInfo.vendorID
                && intProperty(device, key: kIOHIDProductIDKey) == DeviceInfo.productID
        }
    }

    private static func intProperty(_ device: IOHIDDevice, key: String) -> Int? {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue
    }
}
