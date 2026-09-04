import DCEliteCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section {
                HStack {
                    Circle()
                        .fill(model.connected ? Color.green : Color.secondary)
                        .frame(width: 9, height: 9)
                    Text(model.connected ? "Connected" : "Disconnected")
                    Spacer()
                    if model.busy { ProgressView().controlSize(.small) }
                    Button("Refresh") { model.refresh() }
                }
                LabeledContent("Device / FPGA version", value: model.version?.displayValue ?? "—")
            } header: {
                Text("DC Elite")
            }

            Section("Sound") {
                Picker("PCM Filter", selection: Binding(
                    get: { model.settings?.filters.pcmFilter ?? .sharpRollOff },
                    set: { model.setPCMFilter($0) }
                )) {
                    Text("Sharp Roll-Off").tag(PCMFilter.sharpRollOff)
                    Text("Slow Roll-Off").tag(PCMFilter.slowRollOff)
                }

                Picker("DSD Filter", selection: Binding(
                    get: { model.settings?.filters.dsdFilter ?? .low },
                    set: { model.setDSDFilter($0) }
                )) {
                    Text("Low").tag(DSDFilter.low)
                    Text("Medium").tag(DSDFilter.medium)
                    Text("High").tag(DSDFilter.high)
                }

                Picker("PCM Volume Reduction", selection: Binding(
                    get: { model.settings?.main.pcmReduction ?? .zeroDB },
                    set: { model.setPCMReduction($0) }
                )) {
                    ForEach(PCMReduction.allCases, id: \.rawValue) { value in
                        Text(value.displayName).tag(value)
                    }
                }

                Toggle("PCM/DSD Volume Match", isOn: Binding(
                    get: { model.settings?.main.volumeMatchEnabled ?? false },
                    set: { model.setVolumeMatch($0) }
                ))
                Toggle("Coax", isOn: Binding(
                    get: { model.settings?.main.coaxEnabled ?? false },
                    set: { model.setCoax($0) }
                ))
                Toggle("Off-screen volume knob", isOn: Binding(
                    get: { model.settings?.main.offscreenKnobEnabled ?? false },
                    set: { model.setOffscreenKnob($0) }
                ))
            }
            .disabled(!model.connected || model.busy)

            Section("Diagnostics") {
                LabeledContent("USB/HID", value: model.connected ? "Connected" : "Disconnected")
                LabeledContent(
                    "Audio",
                    value: model.audioDetected
                        ? "Primary Play Interface detected"
                        : "Primary Play Interface not detected"
                )
                LabeledContent("VID/PID", value: vidPID)
                LabeledContent("Serial", value: model.deviceInfo?.serialNumber ?? "—")
                if let error = model.lastError, error != DCEliteError.deviceNotFound.localizedDescription {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last HID/protocol error").foregroundStyle(.secondary)
                        Text(error).foregroundStyle(.red).textSelection(.enabled)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, idealWidth: 520, minHeight: 540, idealHeight: 590)
    }

    private var vidPID: String {
        guard let info = model.deviceInfo else { return "2FC6:F0B5" }
        return String(format: "%04X:%04X", info.vendorID, info.productID)
    }
}
