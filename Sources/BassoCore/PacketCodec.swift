import Foundation

public struct HIDPacket: Equatable, Sendable {
    public static let length = 8
    public let bytes: [UInt8]

    public init(validating bytes: [UInt8]) throws {
        guard bytes.count == Self.length else {
            throw DongleError.invalidPacketLength(actual: bytes.count)
        }
        self.bytes = bytes
    }

    public var sequence: UInt8 { bytes[0] }
    public var command: UInt8 { bytes[1] }
    public var commandComplement: UInt8 { bytes[2] }
    public var payload: ArraySlice<UInt8> { bytes[4...7] }
    public var hex: String { bytes.map { String(format: "%02X", $0) }.joined(separator: " ") }
    public var hasValidCommandComplement: Bool { command ^ commandComplement == 0xFF }

    public func validateCommandComplement() throws {
        guard hasValidCommandComplement else {
            throw DongleError.invalidCommandComplement(command: command, complement: commandComplement)
        }
    }

    public static func command(
        sequence: UInt8,
        command: UInt8,
        payload: [UInt8] = [0, 0, 0, 0]
    ) throws -> HIDPacket {
        guard payload.count == 4 else {
            throw DongleError.invalidPacketLength(actual: payload.count + 4)
        }
        return try HIDPacket(validating: [sequence, command, ~command, 0] + payload)
    }
}
