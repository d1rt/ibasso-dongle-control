import Testing
@testable import DCEliteCore

@Test func parsesFilterMappings() throws {
    let response = try HIDPacket(validating: [0x59, 0, 0, 0, 1, 2, 0, 0])
    let settings = try DCEliteProtocol.parseFilters(response)
    #expect(settings.pcmFilter == .slowRollOff)
    #expect(settings.dsdFilter == .high)
}

@Test func parsesMainSettingsMappings() throws {
    let response = try HIDPacket(validating: [0x62, 0, 0, 0, 1, 3, 0, 1])
    let settings = try DCEliteProtocol.parseMainSettings(response)
    #expect(settings.coaxEnabled)
    #expect(settings.pcmReduction == .minusThreeDB)
    #expect(!settings.volumeMatchEnabled)
    #expect(settings.offscreenKnobEnabled)
}

@Test func parsesAlternateNativeReports() throws {
    let filters = try HIDPacket(validating: [0, 0x22, 0, 0, 0, 1, 0, 0])
    let main = try HIDPacket(validating: [0, 0x32, 0, 0, 0, 2, 1, 0])
    #expect(try DCEliteProtocol.parseFilters(filters).dsdFilter == .medium)
    #expect(try DCEliteProtocol.parseMainSettings(main).pcmReduction == .minusTwoDB)
}

@Test func rejectsUnknownSettingValues() throws {
    let badFilter = try HIDPacket(validating: [0x59, 0, 0, 0, 9, 0, 0, 0])
    #expect(throws: DCEliteError.self) {
        try DCEliteProtocol.parseFilters(badFilter)
    }

    let badBoolean = try HIDPacket(validating: [0x62, 0, 0, 0, 2, 0, 0, 0])
    #expect(throws: DCEliteError.self) {
        try DCEliteProtocol.parseMainSettings(badBoolean)
    }
}

@Test func rejectsUnexpectedResponseSequence() throws {
    let packet = try HIDPacket(validating: [0x99, 0, 0, 0, 0, 0, 0, 0])
    #expect(throws: DCEliteError.self) {
        try DCEliteProtocol.parseVersion(packet)
    }
}

@Test func readModifyWriteModelPreservesSiblingFields() {
    let filters = FilterSettings(pcmFilter: .sharpRollOff, dsdFilter: .high)
    #expect(filters.changingPCMFilter(to: .slowRollOff) == FilterSettings(
        pcmFilter: .slowRollOff,
        dsdFilter: .high
    ))

    let main = MainSettings(
        coaxEnabled: true,
        pcmReduction: .minusThreeDB,
        volumeMatchEnabled: false,
        offscreenKnobEnabled: true
    )
    #expect(main.changingVolumeMatch(to: true) == MainSettings(
        coaxEnabled: true,
        pcmReduction: .minusThreeDB,
        volumeMatchEnabled: true,
        offscreenKnobEnabled: true
    ))
}
