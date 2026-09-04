import AppKit
import BassoCore
import DongleControlFeature
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel
    @State private var diagnosticsExpanded = false
    @State private var errorDetailsExpanded = false

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.connectedProfile?.displayName ?? "No supported device")
                        .font(.title2.weight(.semibold))
                    HStack(spacing: 7) {
                        Circle()
                            .fill(model.connectedProfile == nil ? Color.secondary : Color.green)
                            .frame(width: 9, height: 9)
                        Text(model.connectedProfile == nil ? "Disconnected" : "Connected")
                        Spacer()
                        Text("Device version: \(model.state?.version.displayValue ?? "—")")
                            .foregroundStyle(.secondary)
                    }
                    if let audioName = model.connectedProfile?.audioDeviceName {
                        LabeledContent("Audio", value: audioStatus(name: audioName))
                    }
                }
            } header: {
                Text("Dongle Control for iBasso")
            }

            if let profile = model.connectedProfile, let settings = model.state?.settings {
                Section("Settings") {
                    if profile.supports(.pcmFilter) {
                        Picker("PCM Filter", selection: binding(
                            value: settings.filters.pcmFilter,
                            change: SettingChange.pcmFilter
                        )) {
                            ForEach(PCMFilter.allCases, id: \.rawValue) { value in
                                Text(value.displayName).tag(value)
                            }
                        }
                    }

                    if profile.supports(.dsdFilter) {
                        Picker("DSD Filter", selection: binding(
                            value: settings.filters.dsdFilter,
                            change: SettingChange.dsdFilter
                        )) {
                            ForEach(DSDFilter.allCases, id: \.rawValue) { value in
                                Text(value.displayName).tag(value)
                            }
                        }
                    }

                    if profile.supports(.pcmVolumeReduction) {
                        Picker("PCM Volume Reduction", selection: binding(
                            value: settings.main.pcmReduction,
                            change: SettingChange.pcmVolumeReduction
                        )) {
                            ForEach(PCMReduction.allCases, id: \.rawValue) { value in
                                Text(value.displayName).tag(value)
                            }
                        }
                    }

                    if profile.supports(.volumeMatch) {
                        Toggle("PCM/DSD Volume Match", isOn: binding(
                            value: settings.main.volumeMatchEnabled,
                            change: SettingChange.volumeMatch
                        ))
                    }

                    if profile.supports(.coax) {
                        Toggle("Coax", isOn: binding(
                            value: settings.main.coaxEnabled,
                            change: SettingChange.coax
                        ))
                    }

                    if profile.supports(.offScreenVolumeKnob) {
                        Toggle("Off-screen volume knob", isOn: binding(
                            value: settings.main.rawPayload[3] == 1,
                            change: SettingChange.offScreenVolumeKnob
                        ))
                    }
                }
                .disabled(model.isWriting)
            }

            if let error = model.lastError {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text(error.message).textSelection(.enabled)
                            Spacer()
                            Button("Dismiss") { model.dismissError() }
                                .buttonStyle(.link)
                        }
                        DisclosureGroup("Technical details", isExpanded: $errorDetailsExpanded) {
                            Text(error.technicalDetails)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

            Section {
                HStack {
                    Button {
                        model.manualRefresh()
                    } label: {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                                .opacity(model.isManualRefreshing ? 1 : 0)
                            Text("Refresh")
                        }
                        .frame(minWidth: 82)
                    }
                    .disabled(model.connectedProfile == nil || model.isWriting || model.isManualRefreshing)
                    Spacer()
                }

                DisclosureGroup("Diagnostics", isExpanded: $diagnosticsExpanded) {
                    VStack(alignment: .leading, spacing: 7) {
                        LabeledContent(
                            "USB/HID",
                            value: model.connectedProfile == nil ? "Disconnected" : "Connected"
                        )
                        LabeledContent("Audio", value: diagnosticsAudioStatus)
                        LabeledContent("VID/PID", value: vidPID)
                        LabeledContent("Serial", value: model.state?.deviceInfo.serialNumber ?? "—")
                        if let notes = model.connectedProfile?.notes {
                            Text(notes).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 6)
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, idealWidth: 520, minHeight: 470, idealHeight: 560)
        .onReceive(NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification)) { _ in
            model.refreshAfterWake()
        }
    }

    private func binding<Value>(
        value: Value,
        change: @escaping (Value) -> SettingChange
    ) -> Binding<Value> {
        Binding(get: { value }, set: { model.apply(change($0)) })
    }

    private func audioStatus(name: String) -> String {
        model.state?.audioDetected == true ? name : "Not detected"
    }

    private var diagnosticsAudioStatus: String {
        guard let name = model.connectedProfile?.audioDeviceName else { return "Not specified" }
        return model.state?.audioDetected == true ? "\(name) detected" : "\(name) not detected"
    }

    private var vidPID: String {
        guard let profile = model.connectedProfile else { return "—" }
        return String(format: "%04X:%04X", profile.vendorID, profile.productID)
    }
}
