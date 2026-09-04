import Foundation
import IOKit.hid

public protocol HIDTransporting: AnyObject, Sendable {
    var deviceInfo: DeviceInfo { get }
    var profile: DeviceProfileInfo { get }

    func exchange(
        packet: HIDPacket,
        expectedSequence: UInt8,
        alternateTag: UInt8?,
        timeout: TimeInterval
    ) throws -> HIDPacket
}

public final class HIDTransport: HIDTransporting, @unchecked Sendable {
    public typealias DebugLogger = @Sendable (String) -> Void

    private struct PendingRequest {
        let expectedSequence: UInt8
        let alternateTag: UInt8?
        var response: HIDPacket?

        func matches(_ packet: HIDPacket) -> Bool {
            if packet.sequence == expectedSequence { return true }
            return packet.sequence == 0
                && alternateTag != nil
                && packet.bytes[1] == alternateTag
        }
    }

    private let manager: IOHIDManager
    private let device: IOHIDDevice
    private let callbackQueue = DispatchQueue(label: "app.donglecontrol.hid.callback")
    private let cancellationSemaphore = DispatchSemaphore(value: 0)
    private let exchangeLock = NSLock()
    private let responseCondition = NSCondition()
    private let inputBuffer: UnsafeMutablePointer<UInt8>
    private let debugLogger: DebugLogger?
    private var pending: PendingRequest?
    private var disconnected = false
    private var activated = false

    public let deviceInfo: DeviceInfo
    public let profile: DeviceProfileInfo

    public convenience init(
        profile: DeviceProfileInfo,
        debugLogger: DebugLogger? = nil
    ) throws {
        try self.init(profiles: [profile], debugLogger: debugLogger)
    }

    public init(
        profiles: [DeviceProfileInfo] = DeviceRegistry.profiles,
        debugLogger: DebugLogger? = nil
    ) throws {
        self.debugLogger = debugLogger
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        DeviceDiscovery.configure(manager, profiles: profiles)

        let managerResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard managerResult == kIOReturnSuccess else {
            throw DongleError.deviceOpenFailed(code: managerResult)
        }

        guard let match = DeviceDiscovery.supportedDevices(in: manager, profiles: profiles).first else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            throw DongleError.deviceNotFound
        }
        device = match.0
        profile = match.1

        let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            throw DongleError.deviceOpenFailed(code: openResult)
        }

        deviceInfo = DeviceInfo(
            manufacturer: DeviceDiscovery.stringProperty(device, key: kIOHIDManufacturerKey) ?? "Unknown",
            product: DeviceDiscovery.stringProperty(device, key: kIOHIDProductKey) ?? "Unknown",
            serialNumber: DeviceDiscovery.stringProperty(device, key: kIOHIDSerialNumberKey),
            vendorID: DeviceDiscovery.intProperty(device, key: kIOHIDVendorIDKey) ?? 0,
            productID: DeviceDiscovery.intProperty(device, key: kIOHIDProductIDKey) ?? 0,
            primaryUsagePage: DeviceDiscovery.intProperty(device, key: kIOHIDPrimaryUsagePageKey) ?? 0,
            primaryUsage: DeviceDiscovery.intProperty(device, key: kIOHIDPrimaryUsageKey) ?? 0,
            maxInputReportSize: DeviceDiscovery.intProperty(device, key: kIOHIDMaxInputReportSizeKey) ?? 0,
            maxOutputReportSize: DeviceDiscovery.intProperty(device, key: kIOHIDMaxOutputReportSizeKey) ?? 0
        )

        guard deviceInfo.maxInputReportSize == HIDPacket.length,
              deviceInfo.maxOutputReportSize == HIDPacket.length else {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            throw DongleError.invalidPacketLength(
                actual: max(deviceInfo.maxInputReportSize, deviceInfo.maxOutputReportSize)
            )
        }

        inputBuffer = .allocate(capacity: HIDPacket.length)
        inputBuffer.initialize(repeating: 0, count: HIDPacket.length)

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDDeviceRegisterInputReportCallback(
            device,
            inputBuffer,
            HIDPacket.length,
            Self.inputReportCallback,
            context
        )
        IOHIDDeviceRegisterRemovalCallback(device, Self.removalCallback, context)
        IOHIDDeviceSetDispatchQueue(device, callbackQueue)
        IOHIDDeviceSetCancelHandler(device) { [cancellationSemaphore] in
            cancellationSemaphore.signal()
        }
        IOHIDDeviceActivate(device)
        activated = true
    }

    deinit {
        if activated {
            IOHIDDeviceCancel(device)
            _ = cancellationSemaphore.wait(timeout: .now() + 1)
        }
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        inputBuffer.deinitialize(count: HIDPacket.length)
        inputBuffer.deallocate()
    }

    public func exchange(
        packet: HIDPacket,
        expectedSequence: UInt8,
        alternateTag: UInt8? = nil,
        timeout: TimeInterval = 0.5
    ) throws -> HIDPacket {
        try packet.validateCommandComplement()
        exchangeLock.lock()
        defer { exchangeLock.unlock() }

        responseCondition.lock()
        guard !disconnected else {
            responseCondition.unlock()
            throw DongleError.deviceDisconnected
        }
        pending = PendingRequest(
            expectedSequence: expectedSequence,
            alternateTag: alternateTag,
            response: nil
        )
        responseCondition.unlock()

        debugLogger?("TX  \(packet.hex)")
        let result = packet.bytes.withUnsafeBufferPointer { buffer in
            IOHIDDeviceSetReport(
                device,
                kIOHIDReportTypeOutput,
                0,
                buffer.baseAddress!,
                buffer.count
            )
        }
        guard result == kIOReturnSuccess else {
            clearPending()
            throw DongleError.outputReportFailed(code: result)
        }

        let deadline = Date().addingTimeInterval(timeout)
        responseCondition.lock()
        defer {
            pending = nil
            responseCondition.unlock()
        }
        while pending?.response == nil && !disconnected {
            if !responseCondition.wait(until: deadline) { break }
        }
        if disconnected { throw DongleError.deviceDisconnected }
        guard let response = pending?.response else {
            throw DongleError.timeout(sequence: expectedSequence)
        }
        return response
    }

    private func clearPending() {
        responseCondition.lock()
        pending = nil
        responseCondition.unlock()
    }

    private func receive(report: UnsafeMutablePointer<UInt8>?, length: CFIndex) {
        guard let report else { return }
        let bytes = Array(UnsafeBufferPointer(start: report, count: length))
        debugLogger?("RX  \(bytes.map { String(format: "%02X", $0) }.joined(separator: " "))")
        guard let packet = try? HIDPacket(validating: bytes) else {
            debugLogger?("RX rejected: expected exactly 8 bytes")
            return
        }

        responseCondition.lock()
        if var request = pending, request.matches(packet) {
            request.response = packet
            pending = request
            responseCondition.signal()
        } else {
            debugLogger?("RX ignored: does not match the pending request")
        }
        responseCondition.unlock()
    }

    private func markDisconnected() {
        responseCondition.lock()
        disconnected = true
        responseCondition.broadcast()
        responseCondition.unlock()
    }

    private static let inputReportCallback: IOHIDReportCallback = {
        context, result, _, _, _, report, reportLength in
        guard result == kIOReturnSuccess, let context else { return }
        Unmanaged<HIDTransport>.fromOpaque(context).takeUnretainedValue()
            .receive(report: report, length: reportLength)
    }

    private static let removalCallback: IOHIDCallback = { context, _, _ in
        guard let context else { return }
        Unmanaged<HIDTransport>.fromOpaque(context).takeUnretainedValue().markDisconnected()
    }
}
