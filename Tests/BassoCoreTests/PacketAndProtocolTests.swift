import Testing
@testable import BassoCore

@Test func encodesKnownReadCommands() {
    #expect(DCEliteReadCommand.filters.request.bytes == [0x59, 0x21, 0xDE, 0, 0, 0, 0, 0])
    #expect(DCEliteReadCommand.mainSettings.request.bytes == [0x62, 0x31, 0xCE, 0, 0, 0, 0, 0])
    #expect(DCEliteReadCommand.version.request.bytes == [0x58, 0xF1, 0x0E, 0, 0, 0, 0, 0])
}

@Test func validatesCommandComplement() throws {
    let packet = try HIDPacket(validating: [0x59, 0x21, 0xDE, 0, 0, 0, 0, 0])
    #expect(packet.hasValidCommandComplement)
    try packet.validateCommandComplement()
}

@Test func rejectsBadCommandComplement() throws {
    let packet = try HIDPacket(validating: [0x59, 0x21, 0, 0, 0, 0, 0, 0])
    #expect(throws: DongleError.self) { try packet.validateCommandComplement() }
}

@Test func rejectsMalformedPacketLengths() {
    #expect(throws: DongleError.self) { try HIDPacket(validating: [0, 1, 2]) }
    #expect(throws: DongleError.self) {
        try HIDPacket(validating: Array(repeating: 0, count: 9))
    }
}

@Test func parsesAllSettingMappings() throws {
    let filters = try DCEliteProtocol.parseFilters(
        HIDPacket(validating: [0x59, 0, 0, 0, 1, 2, 0xA4, 0xB5])
    )
    #expect(filters.pcmFilter == .slowRollOff)
    #expect(filters.dsdFilter == .high)

    let main = try DCEliteProtocol.parseMainSettings(
        HIDPacket(validating: [0x62, 0, 0, 0, 1, 3, 1, 0xA5])
    )
    #expect(main.coaxEnabled)
    #expect(main.pcmReduction == .minusThreeDB)
    #expect(main.volumeMatchEnabled)
    #expect(main.opaqueReservedByte == 0xA5)
}

@Test func rejectsUnknownTypedValuesButAcceptsOpaqueByte() throws {
    #expect(throws: DongleError.self) {
        try DCEliteProtocol.parseFilters(
            HIDPacket(validating: [0x59, 0, 0, 0, 9, 0, 0, 0])
        )
    }
    let main = try DCEliteProtocol.parseMainSettings(
        HIDPacket(validating: [0x62, 0, 0, 0, 0, 0, 0, 0xFE])
    )
    #expect(main.opaqueReservedByte == 0xFE)
}

@Test func rejectsUnexpectedResponseSequence() throws {
    let packet = try HIDPacket(validating: [0x99, 0, 0, 0, 0, 0, 0, 0])
    #expect(throws: DongleError.self) { try DCEliteProtocol.parseVersion(packet) }
}
