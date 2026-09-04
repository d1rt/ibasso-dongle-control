import Foundation
import Testing
@testable import BassoCore

@Test func dcEliteExposesOnlyConfirmedCapabilities() {
    let profile = DCEliteProfile().info
    #expect(profile.capabilities == [
        .pcmFilter,
        .dsdFilter,
        .pcmVolumeReduction,
        .volumeMatch,
        .coax
    ])
    #expect(!profile.supports(.offScreenVolumeKnob))
}

@Test func reservedBytesSurviveReadModifyWriteUnchanged() throws {
    let transport = MockTransport(responses: [
        try HIDPacket(validating: [0x62, 0, 0, 0, 0, 2, 1, 0xA5]),
        try HIDPacket(validating: [0x19, 0, 0xFF, 0, 1, 2, 1, 0xA5]),
        try HIDPacket(validating: [0x62, 0, 0, 0, 1, 2, 1, 0xA5])
    ])
    let update = try DongleClient(transport: transport).apply(.coax(true))
    #expect(update == .main(MainSettings(
        coaxEnabled: true,
        pcmReduction: .minusTwoDB,
        volumeMatchEnabled: true,
        opaqueReservedByte: 0xA5
    )))
    #expect(transport.sentPackets[1].bytes == [0x19, 0x30, 0xCF, 0, 1, 2, 1, 0xA5])
}

@Test func successfulWriteReadsBackOnlyRelevantGroup() throws {
    let transport = MockTransport(responses: [
        try HIDPacket(validating: [0x59, 0, 0xFF, 0, 0, 2, 0x11, 0x22]),
        try HIDPacket(validating: [0x11, 0, 0xFF, 0, 1, 2, 0x11, 0x22]),
        try HIDPacket(validating: [0x59, 0, 0xFF, 0, 1, 2, 0x11, 0x22])
    ])
    _ = try DongleClient(transport: transport).apply(.pcmFilter(.slowRollOff))
    #expect(transport.sentPackets.map(\.sequence) == [0x59, 0x11, 0x59])
}

@Test func unsupportedCapabilityIsRejectedBeforeHIDTraffic() throws {
    let transport = MockTransport(responses: [])
    let client = DongleClient(transport: transport)
    #expect(throws: DongleError.unsupportedCapability(.offScreenVolumeKnob)) {
        try client.apply(.offScreenVolumeKnob(true))
    }
    #expect(transport.sentPackets.isEmpty)
}

private final class MockTransport: HIDTransporting, @unchecked Sendable {
    let profile = DCEliteProfile().info
    let deviceInfo = DeviceInfo(
        manufacturer: "iBasso",
        product: "iBasso DC-Elite",
        serialNumber: "test",
        vendorID: 0x2FC6,
        productID: 0xF0B5,
        primaryUsagePage: 0x0C,
        primaryUsage: 1,
        maxInputReportSize: 8,
        maxOutputReportSize: 8
    )

    private let lock = NSLock()
    private var responses: [HIDPacket]
    private(set) var sentPackets: [HIDPacket] = []

    init(responses: [HIDPacket]) {
        self.responses = responses
    }

    func exchange(
        packet: HIDPacket,
        expectedSequence: UInt8,
        alternateTag: UInt8?,
        timeout: TimeInterval
    ) throws -> HIDPacket {
        try lock.withLock {
            sentPackets.append(packet)
            guard !responses.isEmpty else { throw DongleError.timeout(sequence: expectedSequence) }
            return responses.removeFirst()
        }
    }
}
