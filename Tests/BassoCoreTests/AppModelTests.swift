import BassoCore
import Foundation
import Testing
@testable import DongleControlFeature

@MainActor
@Test func viewModelDoesNotSchedulePeriodicRefresh() async throws {
    let monitor = FakeMonitor()
    let service = FakeService()
    _ = AppModel(service: service, monitor: monitor)
    try await Task.sleep(for: .seconds(2.1))
    #expect(monitor.startCount == 1)
    #expect(service.loadCount == 0)
}

@MainActor
@Test func reconnectTriggersOneRefresh() async {
    let monitor = FakeMonitor()
    let service = FakeService()
    let model = AppModel(service: service, monitor: monitor)

    monitor.emit(.connected(DCEliteProfile().info))
    await Task.yield()
    await model.waitForIdle()
    monitor.emit(.disconnected(DCEliteProfile().info))
    await Task.yield()
    monitor.emit(.connected(DCEliteProfile().info))
    await Task.yield()
    await model.waitForIdle()

    #expect(service.loadCount == 2)
    #expect(model.state?.profile.id == "ibasso.dc-elite")
}

@MainActor
@Test func manualRefreshTriggersOneRefresh() async {
    let monitor = FakeMonitor()
    let service = FakeService()
    let model = AppModel(service: service, monitor: monitor)
    monitor.emit(.connected(DCEliteProfile().info))
    await Task.yield()
    await model.waitForIdle()
    let initialCount = service.loadCount

    model.manualRefresh()
    await model.waitForIdle()
    #expect(service.loadCount == initialCount + 1)
}

@MainActor
@Test func successfulWriteDoesNotTriggerFullRefresh() async {
    let monitor = FakeMonitor()
    let service = FakeService()
    let model = AppModel(service: service, monitor: monitor)
    monitor.emit(.connected(DCEliteProfile().info))
    await Task.yield()
    await model.waitForIdle()
    let loadCount = service.loadCount

    model.apply(.pcmFilter(.slowRollOff))
    await model.waitForIdle()
    #expect(service.applyCount == 1)
    #expect(service.loadCount == loadCount)
    #expect(model.state?.settings.filters.pcmFilter == .slowRollOff)
}

@MainActor
@Test func unsupportedCapabilityCannotBeInvokedThroughViewModel() async {
    let monitor = FakeMonitor()
    let service = FakeService()
    let model = AppModel(service: service, monitor: monitor)
    monitor.emit(.connected(DCEliteProfile().info))
    await Task.yield()
    await model.waitForIdle()

    model.apply(.offScreenVolumeKnob(true))
    #expect(service.applyCount == 0)
    #expect(model.lastError?.message.contains("does not support") == true)
}

private final class FakeMonitor: DeviceMonitoring, @unchecked Sendable {
    var eventHandler: (@Sendable (DeviceConnectionEvent) -> Void)?
    private(set) var startCount = 0

    func start() { startCount += 1 }
    func stop() {}
    func emit(_ event: DeviceConnectionEvent) { eventHandler?(event) }
}

private final class FakeService: DeviceServicing, @unchecked Sendable {
    private let lock = NSLock()
    private var loads = 0
    private var applies = 0

    var loadCount: Int { lock.withLock { loads } }
    var applyCount: Int { lock.withLock { applies } }

    func loadState(for profile: DeviceProfileInfo) throws -> DeviceState {
        lock.withLock { loads += 1 }
        return sampleState(profile: profile)
    }

    func apply(_ change: SettingChange, to profile: DeviceProfileInfo) throws -> SettingsUpdate {
        lock.withLock { applies += 1 }
        switch change {
        case let .pcmFilter(value):
            return .filters(FilterSettings(pcmFilter: value, dsdFilter: .low))
        case let .dsdFilter(value):
            return .filters(FilterSettings(pcmFilter: .sharpRollOff, dsdFilter: value))
        case let .pcmVolumeReduction(value):
            return .main(MainSettings(coaxEnabled: false, pcmReduction: value, volumeMatchEnabled: false))
        case let .volumeMatch(value):
            return .main(MainSettings(coaxEnabled: false, pcmReduction: .zeroDB, volumeMatchEnabled: value))
        case let .coax(value):
            return .main(MainSettings(coaxEnabled: value, pcmReduction: .zeroDB, volumeMatchEnabled: false))
        case .offScreenVolumeKnob:
            throw DongleError.unsupportedCapability(.offScreenVolumeKnob)
        }
    }

    private func sampleState(profile: DeviceProfileInfo) -> DeviceState {
        DeviceState(
            profile: profile,
            deviceInfo: DeviceInfo(
                manufacturer: "iBasso",
                product: "iBasso DC-Elite",
                serialNumber: "test",
                vendorID: profile.vendorID,
                productID: profile.productID,
                primaryUsagePage: 0x0C,
                primaryUsage: 1,
                maxInputReportSize: 8,
                maxOutputReportSize: 8
            ),
            version: DeviceVersion(bytes: [0x58, 0, 0xFF, 0, 0x10, 0x98, 0x73, 0]),
            settings: DongleSettings(
                filters: FilterSettings(pcmFilter: .sharpRollOff, dsdFilter: .low),
                main: MainSettings(coaxEnabled: false, pcmReduction: .zeroDB, volumeMatchEnabled: false)
            ),
            audioDetected: true
        )
    }
}
