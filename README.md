# DC Elite Control

Unofficial macOS control utility for the iBasso DC Elite.

This repository is currently at the hardware-validation stage. The first CLI build is deliberately read-only and sends only the three known settings/version query reports.

This project is not affiliated with or endorsed by iBasso Audio.  
iBasso and DC Elite are trademarks of their respective owners.

## Requirements

- macOS 13 or later
- Xcode 16 or later
- iBasso DC Elite connected over USB

## Build and run

```shell
swift build
swift run dc-elite info --debug
swift run dc-elite settings --debug
```

The core library uses `IOHIDManager` / `IOHIDDevice` directly. It matches VID `0x2FC6` and PID `0xF0B5`; the serial number is read from the connected device and is never hard-coded.

## Safety

The current build has no settings-write API or CLI command. Requests are serialized, responses must be exactly eight bytes, time out when the expected sequence is not received, and can be logged as raw hexadecimal TX/RX frames with `--debug`.

## License

MIT
