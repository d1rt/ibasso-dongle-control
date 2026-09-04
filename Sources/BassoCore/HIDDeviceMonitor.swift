import Foundation
import IOKit.hid

public enum DeviceConnectionEvent: Equatable, Sendable {
    case connected(DeviceProfileInfo)
    case disconnected(DeviceProfileInfo)
}

public protocol DeviceMonitoring: AnyObject, Sendable {
    var eventHandler: (@Sendable (DeviceConnectionEvent) -> Void)? { get set }
    func start()
    func stop()
}

public final class HIDDeviceMonitor: DeviceMonitoring, @unchecked Sendable {
    private let manager: IOHIDManager
    private let profiles: [DeviceProfileInfo]
    private let queue = DispatchQueue(label: "app.donglecontrol.hid.monitor")
    private let cancellationSemaphore = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var devices: [UInt: DeviceProfileInfo] = [:]
    private var handler: (@Sendable (DeviceConnectionEvent) -> Void)?
    private var started = false

    public var eventHandler: (@Sendable (DeviceConnectionEvent) -> Void)? {
        get { lock.withLock { handler } }
        set { lock.withLock { handler = newValue } }
    }

    public init(profiles: [DeviceProfileInfo] = DeviceRegistry.profiles) {
        self.profiles = profiles
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        DeviceDiscovery.configure(manager, profiles: profiles)
    }

    deinit {
        stop()
    }

    public func start() {
        let shouldStart = lock.withLock { () -> Bool in
            guard !started else { return false }
            started = true
            return true
        }
        guard shouldStart else { return }

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, Self.matchingCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, Self.removalCallback, context)
        IOHIDManagerSetDispatchQueue(manager, queue)
        IOHIDManagerSetCancelHandler(manager) { [cancellationSemaphore] in
            cancellationSemaphore.signal()
        }
        IOHIDManagerActivate(manager)

        for (device, profile) in DeviceDiscovery.supportedDevices(in: manager, profiles: profiles) {
            handleConnected(device, profile: profile)
        }
    }

    public func stop() {
        let shouldStop = lock.withLock { () -> Bool in
            guard started else { return false }
            started = false
            return true
        }
        guard shouldStop else { return }
        IOHIDManagerCancel(manager)
        _ = cancellationSemaphore.wait(timeout: .now() + 1)
    }

    private func handleConnected(_ device: IOHIDDevice, profile: DeviceProfileInfo? = nil) {
        guard let profile = profile ?? DeviceDiscovery.profile(for: device, profiles: profiles) else {
            return
        }
        let key = Self.key(for: device)
        let callback = lock.withLock { () -> (@Sendable (DeviceConnectionEvent) -> Void)? in
            guard devices[key] == nil else { return nil }
            devices[key] = profile
            return handler
        }
        callback?(.connected(profile))
    }

    private func handleDisconnected(_ device: IOHIDDevice) {
        let key = Self.key(for: device)
        let removed = lock.withLock { () -> (DeviceProfileInfo, (@Sendable (DeviceConnectionEvent) -> Void)?)? in
            guard let profile = devices.removeValue(forKey: key) else { return nil }
            return (profile, handler)
        }
        if let (profile, callback) = removed {
            callback?(.disconnected(profile))
        }
    }

    private static func key(for device: IOHIDDevice) -> UInt {
        UInt(bitPattern: Unmanaged.passUnretained(device).toOpaque())
    }

    private static let matchingCallback: IOHIDDeviceCallback = { context, result, _, device in
        guard result == kIOReturnSuccess, let context else { return }
        Unmanaged<HIDDeviceMonitor>.fromOpaque(context).takeUnretainedValue()
            .handleConnected(device)
    }

    private static let removalCallback: IOHIDDeviceCallback = { context, _, _, device in
        guard let context else { return }
        Unmanaged<HIDDeviceMonitor>.fromOpaque(context).takeUnretainedValue()
            .handleDisconnected(device)
    }
}
