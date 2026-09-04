import BassoCore
import Combine
import Foundation

public struct OperationError: Equatable, Identifiable, Sendable {
    public let id = UUID()
    public let message: String
    public let technicalDetails: String

    public init(error: Error) {
        message = error.localizedDescription
        technicalDetails = String(reflecting: error)
    }
}

@MainActor
public final class AppModel: ObservableObject {
    @Published public private(set) var state: DeviceState?
    @Published public private(set) var connectedProfile: DeviceProfileInfo?
    @Published public private(set) var lastError: OperationError?
    @Published public private(set) var isManualRefreshing = false
    @Published public private(set) var isWriting = false

    private let service: any DeviceServicing
    private let monitor: any DeviceMonitoring
    private var operation: Task<Void, Never>?
    private var generation = 0

    public init(
        service: any DeviceServicing = DeviceControlService(),
        monitor: any DeviceMonitoring = HIDDeviceMonitor()
    ) {
        self.service = service
        self.monitor = monitor
        monitor.eventHandler = { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        monitor.start()
    }

    deinit {
        operation?.cancel()
        monitor.stop()
    }

    public func manualRefresh() {
        guard let profile = connectedProfile, !isWriting else { return }
        reload(profile: profile, showManualSpinner: true)
    }

    public func refreshAfterWake() {
        guard let profile = connectedProfile, !isWriting else { return }
        reload(profile: profile, showManualSpinner: false)
    }

    public func apply(_ change: SettingChange) {
        guard let profile = connectedProfile, var currentState = state, !isWriting else { return }
        guard profile.supports(change.capability) else {
            lastError = OperationError(error: DongleError.unsupportedCapability(change.capability))
            return
        }

        generation += 1
        let expectedGeneration = generation
        isWriting = true
        lastError = nil
        let service = self.service
        operation = Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result { try service.apply(change, to: profile) }
            }.value
            guard expectedGeneration == generation, !Task.isCancelled else { return }
            isWriting = false
            switch result {
            case let .success(update):
                switch update {
                case let .filters(filters): currentState.settings.filters = filters
                case let .main(main): currentState.settings.main = main
                }
                state = currentState
            case let .failure(error):
                lastError = OperationError(error: error)
            }
        }
    }

    public func dismissError() {
        lastError = nil
    }

    public func waitForIdle() async {
        await operation?.value
    }

    func handle(_ event: DeviceConnectionEvent) {
        switch event {
        case let .connected(profile):
            connectedProfile = profile
            reload(profile: profile, showManualSpinner: false)
        case let .disconnected(profile):
            guard connectedProfile?.id == profile.id else { return }
            generation += 1
            operation?.cancel()
            operation = nil
            connectedProfile = nil
            state = nil
            isManualRefreshing = false
            isWriting = false
        }
    }

    private func reload(profile: DeviceProfileInfo, showManualSpinner: Bool) {
        generation += 1
        let expectedGeneration = generation
        operation?.cancel()
        isManualRefreshing = showManualSpinner
        lastError = nil
        let service = self.service
        operation = Task {
            let result = await Task.detached(priority: .userInitiated) {
                Result { try service.loadState(for: profile) }
            }.value
            guard expectedGeneration == generation, !Task.isCancelled else { return }
            isManualRefreshing = false
            switch result {
            case let .success(loaded): state = loaded
            case let .failure(error): lastError = OperationError(error: error)
            }
        }
    }
}
