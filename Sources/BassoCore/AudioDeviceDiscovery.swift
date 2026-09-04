import AudioToolbox
import Foundation

public enum AudioDeviceDiscovery {
    public static func isDetected(for profile: DeviceProfileInfo) -> Bool {
        guard let expectedName = profile.audioDeviceName else { return false }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize
        ) == noErr else { return false }

        var devices = Array(
            repeating: AudioDeviceID(0),
            count: Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        )
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &devices
        ) == noErr else { return false }

        return devices.contains { device in
            guard stringProperty(device, selector: kAudioObjectPropertyName) == expectedName else {
                return false
            }
            guard let expectedManufacturer = profile.audioManufacturer else { return true }
            return stringProperty(device, selector: kAudioObjectPropertyManufacturer) == expectedManufacturer
        }
    }

    private static func stringProperty(
        _ objectID: AudioObjectID,
        selector: AudioObjectPropertySelector
    ) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: CFString?
        var dataSize = UInt32(MemoryLayout<CFString?>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(objectID, &address, 0, nil, &dataSize, pointer)
        }
        guard status == noErr else { return nil }
        return value as String?
    }
}
