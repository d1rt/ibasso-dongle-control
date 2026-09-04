import Foundation
import IOKit

public enum DCEliteError: Error, Equatable, Sendable {
    case deviceNotFound
    case deviceOpenFailed(code: Int32)
    case invalidPacketLength(actual: Int)
    case invalidCommandComplement(command: UInt8, complement: UInt8)
    case outputReportFailed(code: Int32)
    case timeout(sequence: UInt8)
    case deviceDisconnected
    case unexpectedResponse(expectedSequence: UInt8, actualSequence: UInt8)
    case unsupportedValue(field: String, value: UInt8)
    case writeVerificationFailed(group: String)
}

extension DCEliteError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "DC Elite is not connected or its HID interface is unavailable."
        case let .deviceOpenFailed(code):
            return "Could not open the DC Elite HID interface (IOReturn \(Self.hex(code)))."
        case let .invalidPacketLength(actual):
            return "Expected an 8-byte HID packet, received \(actual) bytes."
        case let .invalidCommandComplement(command, complement):
            return String(
                format: "Invalid command/complement pair: %02X/%02X.",
                command,
                complement
            )
        case let .outputReportFailed(code):
            return "Sending the HID output report failed (IOReturn \(Self.hex(code)))."
        case let .timeout(sequence):
            return String(format: "Timed out waiting for response 0x%02X.", sequence)
        case .deviceDisconnected:
            return "DC Elite was disconnected."
        case let .unexpectedResponse(expected, actual):
            return String(
                format: "Expected response 0x%02X, received 0x%02X.",
                expected,
                actual
            )
        case let .unsupportedValue(field, value):
            return String(format: "Unsupported %@ value: 0x%02X.", field, value)
        case let .writeVerificationFailed(group):
            return "The device did not confirm the requested \(group) settings."
        }
    }

    private static func hex(_ value: Int32) -> String {
        String(format: "0x%08X", UInt32(bitPattern: value))
    }
}
