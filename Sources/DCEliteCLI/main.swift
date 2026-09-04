import DCEliteCore
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
      dc-elite info [--debug]
      dc-elite settings [--debug]
      dc-elite set pcm-filter sharp|slow [--debug]
      dc-elite set dsd-filter low|medium|high [--debug]
      dc-elite set pcm-reduction 0|-1|-2|-3 [--debug]
      dc-elite set volume-match on|off [--debug]
      dc-elite set coax on|off [--debug]
      dc-elite set offscreen-knob on|off [--debug]
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

private func runSet(_ values: ArraySlice<String>, client: DCEliteClient) throws {
    guard values.count == 2, let field = values.first, let value = values.last else {
        printUsage()
        exit(EXIT_FAILURE)
    }

    switch field {
    case "pcm-filter":
        let parsed: PCMFilter?
        switch value {
        case "sharp": parsed = .sharpRollOff
        case "slow": parsed = .slowRollOff
        default: parsed = nil
        }
        guard let parsed else { printUsage(); exit(EXIT_FAILURE) }
        let confirmed = try client.setPCMFilter(parsed)
        print("PCM filter: \(confirmed.pcmFilter.displayName)")

    case "dsd-filter":
        let parsed: DSDFilter?
        switch value {
        case "low": parsed = .low
        case "medium": parsed = .medium
        case "high": parsed = .high
        default: parsed = nil
        }
        guard let parsed else { printUsage(); exit(EXIT_FAILURE) }
        let confirmed = try client.setDSDFilter(parsed)
        print("DSD filter: \(confirmed.dsdFilter.displayName)")

    case "pcm-reduction":
        let parsed: PCMReduction?
        switch value {
        case "0": parsed = .zeroDB
        case "-1": parsed = .minusOneDB
        case "-2": parsed = .minusTwoDB
        case "-3": parsed = .minusThreeDB
        default: parsed = nil
        }
        guard let parsed else { printUsage(); exit(EXIT_FAILURE) }
        let confirmed = try client.setPCMReduction(parsed)
        print("PCM volume reduction: \(confirmed.pcmReduction.displayName)")

    case "volume-match":
        guard let parsed = parseToggle(value) else { printUsage(); exit(EXIT_FAILURE) }
        let confirmed = try client.setVolumeMatch(parsed)
        print("PCM/DSD volume match: \(onOff(confirmed.volumeMatchEnabled))")

    case "coax":
        guard let parsed = parseToggle(value) else { printUsage(); exit(EXIT_FAILURE) }
        let confirmed = try client.setCoax(parsed)
        print("Coax: \(onOff(confirmed.coaxEnabled))")

    case "offscreen-knob":
        guard let parsed = parseToggle(value) else { printUsage(); exit(EXIT_FAILURE) }
        let confirmed = try client.setOffscreenKnob(parsed)
        print("Off-screen volume knob: \(onOff(confirmed.offscreenKnobEnabled))")

    default:
        printUsage()
        exit(EXIT_FAILURE)
    }
}

private let arguments = Arguments(Array(CommandLine.arguments.dropFirst()))

guard let command = arguments.values.first,
      command == "info" || command == "settings" || command == "set" else {
    printUsage()
    exit(arguments.values.first == nil ? EXIT_SUCCESS : EXIT_FAILURE)
}

do {
    let logger: HIDTransport.DebugLogger?
    if arguments.debug {
        logger = debugLog
    } else {
        logger = nil
    }
    let transport = try HIDTransport(debugLogger: logger)
    let client = DCEliteClient(transport: transport)

    switch command {
    case "info":
        let info = client.deviceInfo
        let (version, raw) = try client.readVersion()
        print("Connection: Connected")
        print("Manufacturer: \(info.manufacturer)")
        print("Product: \(info.product)")
        print(String(format: "VID/PID: %04X:%04X", info.vendorID, info.productID))
        print("Serial: \(info.serialNumber ?? "Unavailable")")
        print(String(format: "HID usage: %04X:%04X", info.primaryUsagePage, info.primaryUsage))
        print("Reports: input \(info.maxInputReportSize) bytes, output \(info.maxOutputReportSize) bytes")
        print("Device / FPGA version: \(version.displayValue)")
        if arguments.debug {
            print("Raw version response: \(raw.hex)")
        }

    case "settings":
        let settings = try client.readSettings()
        print("PCM filter: \(settings.filters.pcmFilter.displayName)")
        print("DSD filter: \(settings.filters.dsdFilter.displayName)")
        print("PCM volume reduction: \(settings.main.pcmReduction.displayName)")
        print("PCM/DSD volume match: \(onOff(settings.main.volumeMatchEnabled))")
        print("Coax: \(onOff(settings.main.coaxEnabled))")
        print("Off-screen volume knob: \(onOff(settings.main.offscreenKnobEnabled))")

    case "set":
        try runSet(arguments.values.dropFirst(), client: client)

    default:
        break
    }
} catch {
    FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
    exit(EXIT_FAILURE)
}
