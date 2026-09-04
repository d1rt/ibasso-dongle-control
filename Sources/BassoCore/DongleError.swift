import Foundation
import IOKit

public enum DongleError: Error, Equatable, Sendable {
    case deviceNotFound
    case deviceOpenFailed(code: Int32)
    case invalidPacketLength(actual: Int)
    case invalidCommandComplement(command: UInt8, complement: UInt8)
    case outputReportFailed(code: Int32)
    case timeout(sequence: UInt8)
    case deviceDisconnected
    case unexpectedResponse(expectedSequence: UInt8, actualSequence: UInt8)
    case unsupportedValue(field: String, value: UInt8)
    case unsupportedCapability(DeviceCapability)
    case writeVerificationFailed(group: String)

    public var technicalDetails: String {
        String(describing: self)
    }
}

extension DongleError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            "No supported iBasso dongle is connected, or its HID interface is unavailable."
        case let .deviceOpenFailed(code):
            "Could not open the device HID interface (IOReturn \(Self.hex(code)))."
        case let .invalidPacketLength(actual):
            "Expected an 8-byte HID packet, received \(actual) bytes."
        case let .invalidCommandComplement(command, complement):
            String(format: "Invalid command/complement pair: %02X/%02X.", command, complement)
        case let .outputReportFailed(code):
            "Sending the HID output report failed (IOReturn \(Self.hex(code)))."
        case let .timeout(sequence):
            String(format: "Timed out waiting for response 0x%02X.", sequence)
        case .deviceDisconnected:
            "The device was disconnected."
        case let .unexpectedResponse(expected, actual):
            String(format: "Expected response 0x%02X, received 0x%02X.", expected, actual)
        case let .unsupportedValue(field, value):
            String(format: "Unsupported %@ value: 0x%02X.", field, value)
        case let .unsupportedCapability(capability):
            "This device profile does not support \(capability.rawValue)."
        case let .writeVerificationFailed(group):
            "The device did not confirm the requested \(group) settings."
        }
    }

    private static func hex(_ value: Int32) -> String {
        String(format: "0x%08X", UInt32(bitPattern: value))
    }
}
