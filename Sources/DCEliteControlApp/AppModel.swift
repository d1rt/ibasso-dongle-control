import AppKit
import DCEliteCore
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var connected = false
    @Published private(set) var audioDetected = false
    @Published private(set) var deviceInfo: DeviceInfo?
    @Published private(set) var version: DeviceVersion?
    @Published private(set) var settings: DCEliteSettings?
    @Published private(set) var lastError: String?
    @Published private(set) var busy = false

    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?

    init() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        guard !busy else { return }
        busy = true
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Self.loadSnapshot()
            }.value
            apply(result)
            busy = false
        }
    }

    func setPCMFilter(_ value: PCMFilter) { perform(.pcmFilter(value)) }
    func setDSDFilter(_ value: DSDFilter) { perform(.dsdFilter(value)) }
    func setPCMReduction(_ value: PCMReduction) { perform(.pcmReduction(value)) }
    func setVolumeMatch(_ value: Bool) { perform(.volumeMatch(value)) }
    func setCoax(_ value: Bool) { perform(.coax(value)) }
    func setOffscreenKnob(_ value: Bool) { perform(.offscreenKnob(value)) }

    private func perform(_ change: SettingChange) {
        guard connected, !busy else { return }
        busy = true
        lastError = nil
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                Self.apply(change)
            }.value
            apply(result)
            busy = false
        }
    }

    private func apply(_ result: SnapshotResult) {
        audioDetected = result.audioDetected
        switch result.value {
        case let .success(snapshot):
            connected = true
            deviceInfo = snapshot.info
            version = snapshot.version
            settings = snapshot.settings
            lastError = nil
        case let .failure(failure):
            connected = false
            deviceInfo = nil
            version = nil
            settings = nil
            lastError = failure.message
        }
    }

    nonisolated private static func loadSnapshot() -> SnapshotResult {
        let audioDetected = AudioDeviceDiscovery.primaryPlayInterfaceDetected()
        do {
            let transport = try HIDTransport()
            let client = DCEliteClient(transport: transport)
            let (version, _) = try client.readVersion()
            let settings = try client.readSettings()
            return SnapshotResult(
                audioDetected: audioDetected,
                value: .success(Snapshot(info: client.deviceInfo, version: version, settings: settings))
            )
        } catch {
            return SnapshotResult(
                audioDetected: audioDetected,
                value: .failure(SnapshotFailure(message: error.localizedDescription))
            )
        }
    }

    nonisolated private static func apply(_ change: SettingChange) -> SnapshotResult {
        let audioDetected = AudioDeviceDiscovery.primaryPlayInterfaceDetected()
        do {
            let transport = try HIDTransport()
            let client = DCEliteClient(transport: transport)
            switch change {
            case let .pcmFilter(value): _ = try client.setPCMFilter(value)
            case let .dsdFilter(value): _ = try client.setDSDFilter(value)
            case let .pcmReduction(value): _ = try client.setPCMReduction(value)
            case let .volumeMatch(value): _ = try client.setVolumeMatch(value)
            case let .coax(value): _ = try client.setCoax(value)
            case let .offscreenKnob(value): _ = try client.setOffscreenKnob(value)
            }
            let (version, _) = try client.readVersion()
            let settings = try client.readSettings()
            return SnapshotResult(
                audioDetected: audioDetected,
                value: .success(Snapshot(info: client.deviceInfo, version: version, settings: settings))
            )
        } catch {
            return SnapshotResult(
                audioDetected: audioDetected,
                value: .failure(SnapshotFailure(message: error.localizedDescription))
            )
        }
    }
}

private enum SettingChange: Sendable {
    case pcmFilter(PCMFilter)
    case dsdFilter(DSDFilter)
    case pcmReduction(PCMReduction)
    case volumeMatch(Bool)
    case coax(Bool)
    case offscreenKnob(Bool)
}

private struct Snapshot: Sendable {
    let info: DeviceInfo
    let version: DeviceVersion
    let settings: DCEliteSettings
}

private struct SnapshotResult: Sendable {
    let audioDetected: Bool
    let value: Result<Snapshot, SnapshotFailure>
}

private struct SnapshotFailure: Error, Sendable {
    let message: String
}
