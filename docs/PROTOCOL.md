# DC Elite HID protocol

This document describes only the settings protocol implemented for the tested iBasso DC Elite profile. It is based on independent interoperability analysis and was validated against retail hardware on macOS.

## HID interface

- Vendor ID: `0x2FC6`
- Product ID: `0xF0B5`
- Usage page / usage: `0x000C / 0x0001`
- Report ID: `0`
- Input report size: 8 bytes
- Output report size: 8 bytes

Serial numbers identify individual units and are read at runtime; they are never used for matching.

## Packet format

All implemented packets are exactly eight bytes:

```text
[sequence, command, command XOR FF, 00, payload0, payload1, payload2, payload3]
```

Responses are correlated by sequence. The transport permits only one request at a time and rejects reports whose length or sequence does not match the pending exchange.

## Read commands

| Purpose | Output report | Payload in response |
|---|---|---|
| Filters | `59 21 DE 00 00 00 00 00` | bytes 4–7 |
| Main settings | `62 31 CE 00 00 00 00 00` | bytes 4–7 |
| Device version | `58 F1 0E 00 00 00 00 00` | bytes 4–6 |

## Confirmed DC Elite controls

Filters are written as:

```text
11 20 DF 00 PP DD RR RR
```

- `PP`: PCM filter (`0` sharp roll-off, `1` slow roll-off)
- `DD`: DSD filter (`0` low, `1` medium, `2` high)
- `RR`: opaque bytes preserved from the preceding read

Main settings are written as:

```text
19 30 CF 00 CC TT MM RR
```

- `CC`: coax (`0` off, `1` on)
- `TT`: PCM reduction (`0` 0 dB, `1` -1 dB, `2` -2 dB, `3` -3 dB)
- `MM`: PCM/DSD volume match (`0` off, `1` on)
- `RR`: opaque byte preserved from the preceding read

The opaque fields are not exposed as DC Elite capabilities. Their contents are retained byte-for-byte rather than interpreted or replaced with defaults.

Every write follows:

```text
read complete group → change one confirmed field → write complete group → read the same group → compare
```

## Hardware validation

The following reports were captured through `IOHIDDevice` on macOS:

```text
TX  58 F1 0E 00 00 00 00 00
RX  58 00 FF 00 10 98 73 00

TX  59 21 DE 00 00 00 00 00
RX  59 00 FF 00 00 00 00 00

TX  62 31 CE 00 00 00 00 00
RX  62 00 FF 00 00 00 00 00
```

PCM Filter, DSD Filter, PCM Volume Reduction, PCM/DSD Volume Match, and Coax were each changed, confirmed by read-back, and restored to their original value on the connected unit.
