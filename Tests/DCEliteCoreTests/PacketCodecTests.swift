import Testing
@testable import DCEliteCore

@Test func encodesKnownReadCommands() {
    #expect(ReadCommand.filters.request.bytes == [0x59, 0x21, 0xDE, 0, 0, 0, 0, 0])
    #expect(ReadCommand.mainSettings.request.bytes == [0x62, 0x31, 0xCE, 0, 0, 0, 0, 0])
    #expect(ReadCommand.version.request.bytes == [0x58, 0xF1, 0x0E, 0, 0, 0, 0, 0])
}

@Test func encodesKnownWriteCommands() {
    let filters = FilterSettings(pcmFilter: .slowRollOff, dsdFilter: .high)
    #expect(WriteCommand.filters(filters).request.bytes == [0x11, 0x20, 0xDF, 0, 1, 2, 0, 0])

    let main = MainSettings(
        coaxEnabled: true,
        pcmReduction: .minusTwoDB,
        volumeMatchEnabled: true,
        offscreenKnobEnabled: false
    )
    #expect(WriteCommand.mainSettings(main).request.bytes == [0x19, 0x30, 0xCF, 0, 1, 2, 1, 0])
}

@Test func validatesCommandComplement() throws {
    let packet = try HIDPacket(validating: [0x59, 0x21, 0xDE, 0, 0, 0, 0, 0])
    #expect(packet.hasValidCommandComplement)
    try packet.validateCommandComplement()
}

@Test func rejectsBadCommandComplement() throws {
    let packet = try HIDPacket(validating: [0x59, 0x21, 0x00, 0, 0, 0, 0, 0])
    #expect(throws: DCEliteError.self) {
        try packet.validateCommandComplement()
    }
}

@Test func rejectsMalformedPacketLengths() {
    #expect(throws: DCEliteError.self) {
        try HIDPacket(validating: [0, 1, 2])
    }
    #expect(throws: DCEliteError.self) {
        try HIDPacket(validating: Array(repeating: 0, count: 9))
    }
}
