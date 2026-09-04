# DC Elite Control

Unofficial macOS control utility for the iBasso DC Elite.

DC Elite Control is a small native SwiftUI application and command-line tool for reading and changing the device's HID settings on macOS. It has no local server, web UI, or third-party runtime.

This project is not affiliated with or endorsed by iBasso Audio.  
iBasso and DC Elite are trademarks of their respective owners.

## Features

- Native macOS application built with SwiftUI
- Shared `DCEliteCore` library using `IOHIDManager` and `IOHIDDevice`
- Device discovery by VID `0x2FC6` and PID `0xF0B5`
- Device / FPGA version and raw HID diagnostics
- PCM and DSD filter controls
- PCM volume reduction control
- PCM/DSD volume match, coax, and off-screen knob toggles
- Read-modify-write-readback for every setting change
- Automatic connection refresh and wake-from-sleep refresh
- Native CoreAudio detection for `Primary Play Interface`
- Strict eight-byte packets, serialized exchanges, response validation, and timeouts

Analog volume, balance, and gain controls are intentionally absent because no verified DC Elite HID commands are known for them.

## Requirements

- macOS 13 or later
- Xcode 16 or later
- iBasso DC Elite connected over USB

## Build the application

Open `DCEliteControl.xcodeproj`, select the **DC Elite Control** scheme, and run it on **My Mac**.

The generated Xcode project is committed, so XcodeGen is not required. If you modify `project.yml`, regenerate it with:

```shell
brew install xcodegen
xcodegen generate
```

For a command-line build:

```shell
xcodebuild \
  -project DCEliteControl.xcodeproj \
  -scheme "DC Elite Control" \
  -destination "platform=macOS" \
  build
```

## CLI

Build and inspect the connected device:

```shell
swift build
swift run dc-elite info --debug
swift run dc-elite settings --debug
```

Change one setting:

```shell
swift run dc-elite set pcm-filter sharp
swift run dc-elite set pcm-filter slow
swift run dc-elite set dsd-filter low
swift run dc-elite set dsd-filter medium
swift run dc-elite set dsd-filter high
swift run dc-elite set pcm-reduction 0
swift run dc-elite set pcm-reduction -1
swift run dc-elite set pcm-reduction -2
swift run dc-elite set pcm-reduction -3
swift run dc-elite set volume-match on
swift run dc-elite set volume-match off
swift run dc-elite set coax on
swift run dc-elite set coax off
swift run dc-elite set offscreen-knob on
swift run dc-elite set offscreen-knob off
```

Every `set` command first reads the complete settings group, changes one field, writes the complete group, reads it again, and fails unless the device confirms the requested state.

## Tests

```shell
swift test
```

The tests cover packet length and command-complement checks, known read/write encodings, all setting mappings, malformed replies, and preservation of sibling fields during a read-modify-write operation.

## Protocol

The independently documented HID protocol and hardware-validated captures are in [`docs/PROTOCOL.md`](docs/PROTOCOL.md).

No iBasso application, decompiled source, branded artwork, or proprietary binary is included in this repository.

## License

MIT
