# Dongle Control for iBasso

Unofficial macOS control utility for supported iBasso USB DAC/AMP dongles.

Dongle Control for iBasso is a small native SwiftUI application and command-line tool. It has no local server, web UI, or third-party runtime.

This project is not affiliated with or endorsed by iBasso Audio.  
iBasso and DC Elite are trademarks of their respective owners.

## Currently tested hardware

| Device | Status |
|---|---|
| iBasso DC Elite | Tested |

No other device is currently claimed as supported.

Device support is profile-based. Controls are only exposed when a capability has been verified for that model. The tested DC Elite profile exposes PCM Filter, DSD Filter, PCM Volume Reduction, PCM/DSD Volume Match, and Coax.

## Features

- Native macOS application built with SwiftUI
- Shared `BassoCore` library using `IOHIDManager` and `IOHIDDevice`
- Profile registry keyed by USB VID/PID and explicit capabilities
- Event-driven connect, disconnect, and reconnect handling
- Device version and raw HID diagnostics
- Read-modify-write-readback for every setting change
- Native CoreAudio device detection
- Strict eight-byte packets, serialized exchanges, response validation, and timeouts
- Opaque protocol bytes preserved byte-for-byte during setting changes

Analog volume, balance, and gain controls are intentionally absent because no verified DC Elite HID commands are known for them.

## Requirements

- macOS 13 or later
- Xcode 16 or later
- A supported device connected over USB

## Build the application

Open `IBassoDongleControl.xcodeproj`, select the **Dongle Control for iBasso** scheme, and run it on **My Mac**.

The generated Xcode project is committed, so XcodeGen is not required. If you modify `project.yml`, regenerate it with:

```shell
brew install xcodegen
xcodegen generate
```

For a command-line build:

```shell
xcodebuild \
  -project IBassoDongleControl.xcodeproj \
  -scheme "Dongle Control for iBasso" \
  -destination "platform=macOS" \
  build
```

## CLI

Build and inspect the connected device:

```shell
swift build
swift run ibasso-dongle info --debug
swift run ibasso-dongle settings --debug
```

Change a confirmed DC Elite setting:

```shell
swift run ibasso-dongle set pcm-filter sharp
swift run ibasso-dongle set pcm-filter slow
swift run ibasso-dongle set dsd-filter low
swift run ibasso-dongle set dsd-filter medium
swift run ibasso-dongle set dsd-filter high
swift run ibasso-dongle set pcm-reduction 0
swift run ibasso-dongle set pcm-reduction -1
swift run ibasso-dongle set pcm-reduction -2
swift run ibasso-dongle set pcm-reduction -3
swift run ibasso-dongle set volume-match on
swift run ibasso-dongle set volume-match off
swift run ibasso-dongle set coax on
swift run ibasso-dongle set coax off
```

Every `set` command reads the complete relevant group, changes one confirmed field, writes the complete group, reads only that group back, and fails unless the device confirms the requested state.

## Architecture

- `BassoCore`: discovery, HID transport, device profiles, capabilities, protocol implementations, state, and settings service
- `BassoCore/Devices`: model-specific profiles and protocol implementations
- `DongleControlFeature`: event-driven application ViewModel, independent of SwiftUI views
- `DongleControlApp`: native SwiftUI presentation
- `BassoCLI`: command-line frontend using the same core

The UI does not infer capabilities from packet fields. It renders a control only when the active `DeviceProfile` explicitly includes that capability.

## Adding support for another device

1. Verify the device and its protocol against real hardware.
2. Add a model-specific `DeviceProfile` with the exact VID/PID and only confirmed capabilities.
3. Add or reuse a controller family implementation for parsing and writing.
4. Register the profile in `DeviceRegistry`.
5. Add packet, capability, preservation, and hardware-validation tests.

Do not enable a capability merely because another model has a similarly positioned protocol field.

## Tests

```shell
swift test
```

Tests cover packets and mappings, DC Elite capabilities, opaque-byte preservation, capability rejection, relevant-group read-back, event-driven reconnect, manual refresh, and the absence of periodic refresh scheduling.

## Protocol

The independently documented and hardware-validated DC Elite HID protocol is in [`docs/PROTOCOL.md`](docs/PROTOCOL.md).

No iBasso application, decompiled source, branded artwork, or proprietary binary is included in this repository.

## License

MIT
