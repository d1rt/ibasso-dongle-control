import Foundation
import IOKit.hid

public final class HIDTransport: @unchecked Sendable {
    public typealias DebugLogger = @Sendable (String) -> Void

    private struct PendingRequest {
        let sequence: UInt8
        let alternateTag: UInt8?
        var response: HIDPacket?

        func matches(_ packet: HIDPacket) -> Bool {
            if packet.sequence == sequence {
                return true
            }
            return packet.sequence == 0
                && alternateTag != nil
                && packet.bytes[1] == alternateTag
        }
    }

    private let manager: IOHIDManager
    private let device: IOHIDDevice
    private let callbackQueue = DispatchQueue(label: "dev.dcelite.hid.callback")
    private let exchangeLock = NSLock()
    private let responseCondition = NSCondition()
    private let inputBuffer: UnsafeMutablePointer<UInt8>
    private let debugLogger: DebugLogger?
    private var pending: PendingRequest?
    private var disconnected = false
    private var activated = false

    public let deviceInfo: DeviceInfo

    public init(debugLogger: DebugLogger? = nil) throws {
        self.debugLogger = debugLogger
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        let matching: [String: Any] = [
            kIOHIDVendorIDKey as String: DeviceInfo.vendorID,
            kIOHIDProductIDKey as String: DeviceInfo.productID
        ]
        IOHIDManagerSetDeviceMatching(manager, matching as CFDictionary)

        let managerResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard managerResult == kIOReturnSuccess else {
            throw DCEliteError.deviceOpenFailed(code: managerResult)
        }

        guard let deviceSet = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>,
              let matchedDevice = deviceSet.first(where: {
                  Self.intProperty($0, key: kIOHIDVendorIDKey) == DeviceInfo.vendorID
                      && Self.intProperty($0, key: kIOHIDProductIDKey) == DeviceInfo.productID
              }) else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            throw DCEliteError.deviceNotFound
        }
        device = matchedDevice

        let openResult = IOHIDDeviceOpen(device, IOOptionBits(kIOHIDOptionsTypeNone))
        guard openResult == kIOReturnSuccess else {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            throw DCEliteError.deviceOpenFailed(code: openResult)
        }

        deviceInfo = DeviceInfo(
            manufacturer: Self.stringProperty(device, key: kIOHIDManufacturerKey) ?? "Unknown",
            product: Self.stringProperty(device, key: kIOHIDProductKey) ?? "Unknown",
            serialNumber: Self.stringProperty(device, key: kIOHIDSerialNumberKey),
            vendorID: Self.intProperty(device, key: kIOHIDVendorIDKey) ?? 0,
            productID: Self.intProperty(device, key: kIOHIDProductIDKey) ?? 0,
            primaryUsagePage: Self.intProperty(device, key: kIOHIDPrimaryUsagePageKey) ?? 0,
            primaryUsage: Self.intProperty(device, key: kIOHIDPrimaryUsageKey) ?? 0,
            maxInputReportSize: Self.intProperty(device, key: kIOHIDMaxInputReportSizeKey) ?? 0,
            maxOutputReportSize: Self.intProperty(device, key: kIOHIDMaxOutputReportSizeKey) ?? 0
        )

        guard deviceInfo.maxInputReportSize == HIDPacket.length,
              deviceInfo.maxOutputReportSize == HIDPacket.length else {
            IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
            throw DCEliteError.invalidPacketLength(
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
        IOHIDDeviceActivate(device)
        activated = true
    }

    deinit {
        if activated {
            IOHIDDeviceCancel(device)
        }
        IOHIDDeviceClose(device, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        inputBuffer.deinitialize(count: HIDPacket.length)
        inputBuffer.deallocate()
    }

    public func exchange(
        _ command: ReadCommand,
        timeout: TimeInterval = 0.5
    ) throws -> HIDPacket {
        try exchange(
            packet: command.request,
            alternateTag: command.alternateReportTag,
            timeout: timeout
        )
    }

    public func exchange(
        _ command: WriteCommand,
        timeout: TimeInterval = 0.5
    ) throws -> HIDPacket {
        try exchange(packet: command.request, alternateTag: nil, timeout: timeout)
    }

    private func exchange(
        packet: HIDPacket,
        alternateTag: UInt8?,
        timeout: TimeInterval
    ) throws -> HIDPacket {
        try packet.validateCommandComplement()

        exchangeLock.lock()
        defer { exchangeLock.unlock() }

        responseCondition.lock()
        guard !disconnected else {
            responseCondition.unlock()
            throw DCEliteError.deviceDisconnected
        }
        pending = PendingRequest(
            sequence: packet.sequence,
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
            throw DCEliteError.outputReportFailed(code: result)
        }

        let deadline = Date().addingTimeInterval(timeout)
        responseCondition.lock()
        defer {
            pending = nil
            responseCondition.unlock()
        }
        while pending?.response == nil && !disconnected {
            if !responseCondition.wait(until: deadline) {
                break
            }
        }
        if disconnected {
            throw DCEliteError.deviceDisconnected
        }
        guard let response = pending?.response else {
            throw DCEliteError.timeout(sequence: packet.sequence)
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
            debugLogger?("RX ignored: does not match the pending read request")
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
        Unmanaged<HIDTransport>
            .fromOpaque(context)
            .takeUnretainedValue()
            .receive(report: report, length: reportLength)
    }

    private static let removalCallback: IOHIDCallback = { context, _, _ in
        guard let context else { return }
        Unmanaged<HIDTransport>
            .fromOpaque(context)
            .takeUnretainedValue()
            .markDisconnected()
    }

    private static func intProperty(_ device: IOHIDDevice, key: String) -> Int? {
        (IOHIDDeviceGetProperty(device, key as CFString) as? NSNumber)?.intValue
    }

    private static func stringProperty(_ device: IOHIDDevice, key: String) -> String? {
        IOHIDDeviceGetProperty(device, key as CFString) as? String
    }
}
