import BassoCore
import Darwin
import Foundation

private struct Arguments {
    let values: [String]
    let debug: Bool

    init(_ values: [String]) {
        debug = values.contains("--debug")
        self.values = values.filter { !$0.hasPrefix("--") }
    }
}

private func printUsage() {
    print("""
    Usage:
      ibasso-dongle info [--debug]
      ibasso-dongle settings [--debug]
      ibasso-dongle set pcm-filter sharp|slow [--debug]
      ibasso-dongle set dsd-filter low|medium|high [--debug]
      ibasso-dongle set pcm-reduction 0|-1|-2|-3 [--debug]
      ibasso-dongle set volume-match on|off [--debug]
      ibasso-dongle set coax on|off [--debug]
    """)
}

private func onOff(_ value: Bool) -> String { value ? "On" : "Off" }

private func debugLog(_ message: String) {
    FileHandle.standardError.write(Data("[HID] \(message)\n".utf8))
}

private func parseToggle(_ value: String) -> Bool? {
    switch value {
    case "on": true
    case "off": false
    default: nil
    }
}

private func runSet(_ values: ArraySlice<String>, client: DongleClient) throws {
    guard values.count == 2, let field = values.first, let value = values.last else {
        printUsage(); exit(EXIT_FAILURE)
    }
    let change: SettingChange
    switch (field, value) {
    case ("pcm-filter", "sharp"): change = .pcmFilter(.sharpRollOff)
    case ("pcm-filter", "slow"): change = .pcmFilter(.slowRollOff)
    case ("dsd-filter", "low"): change = .dsdFilter(.low)
    case ("dsd-filter", "medium"): change = .dsdFilter(.medium)
    case ("dsd-filter", "high"): change = .dsdFilter(.high)
    case ("pcm-reduction", "0"): change = .pcmVolumeReduction(.zeroDB)
    case ("pcm-reduction", "-1"): change = .pcmVolumeReduction(.minusOneDB)
    case ("pcm-reduction", "-2"): change = .pcmVolumeReduction(.minusTwoDB)
    case ("pcm-reduction", "-3"): change = .pcmVolumeReduction(.minusThreeDB)
    case ("volume-match", let value), ("coax", let value):
        guard let enabled = parseToggle(value) else { printUsage(); exit(EXIT_FAILURE) }
        change = field == "volume-match" ? .volumeMatch(enabled) : .coax(enabled)
    default:
        printUsage(); exit(EXIT_FAILURE)
    }

    let update = try client.apply(change)
    switch update {
    case let .filters(filters):
        print("PCM filter: \(filters.pcmFilter.displayName)")
        print("DSD filter: \(filters.dsdFilter.displayName)")
    case let .main(main):
        print("PCM volume reduction: \(main.pcmReduction.displayName)")
        print("PCM/DSD volume match: \(onOff(main.volumeMatchEnabled))")
        print("Coax: \(onOff(main.coaxEnabled))")
    }
}

private let arguments = Arguments(Array(CommandLine.arguments.dropFirst()))
guard let command = arguments.values.first,
      command == "info" || command == "settings" || command == "set" else {
    printUsage()
    exit(arguments.values.first == nil ? EXIT_SUCCESS : EXIT_FAILURE)
}

do {
    let logger: HIDTransport.DebugLogger? = arguments.debug ? debugLog : nil
    let transport = try HIDTransport(debugLogger: logger)
    let client = DongleClient(transport: transport)

    switch command {
    case "info":
        let (version, raw) = try client.readVersion()
        print("Connection: Connected")
        print("Profile: \(client.profile.displayName)")
        print("Product: \(client.deviceInfo.product)")
        print(String(format: "VID/PID: %04X:%04X", client.deviceInfo.vendorID, client.deviceInfo.productID))
        print("Serial: \(client.deviceInfo.serialNumber ?? "Unavailable")")
        print("Device version: \(version.displayValue)")
        if arguments.debug { print("Raw version response: \(raw.hex)") }
    case "settings":
        let settings = try client.readSettings()
        print("PCM filter: \(settings.filters.pcmFilter.displayName)")
        print("DSD filter: \(settings.filters.dsdFilter.displayName)")
        print("PCM volume reduction: \(settings.main.pcmReduction.displayName)")
        print("PCM/DSD volume match: \(onOff(settings.main.volumeMatchEnabled))")
        print("Coax: \(onOff(settings.main.coaxEnabled))")
    case "set":
        try runSet(arguments.values.dropFirst(), client: client)
    default: break
    }
} catch {
    FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
    exit(EXIT_FAILURE)
}
