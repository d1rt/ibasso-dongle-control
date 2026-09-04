# DC Elite HID protocol

This document describes only the small settings protocol implemented by this project. It is based on independent interoperability analysis and was validated against a retail DC Elite on macOS.

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

The second and third bytes of every known command are bitwise complements. Responses are correlated by the first byte. The transport permits only one request at a time and rejects reports whose length or sequence does not match the pending exchange.

## Read commands

| Purpose | Output report | Payload in response |
|---|---|---|
| Filters | `59 21 DE 00 00 00 00 00` | bytes 4–5 |
| Main settings | `62 31 CE 00 00 00 00 00` | bytes 4–7 |
| Device / FPGA version | `58 F1 0E 00 00 00 00 00` | bytes 4–6 |

Some device-family implementations can emit unsolicited-style filter and main-setting reports with sequence `00` and tags `22` or `32`. The parser accepts those documented forms, while normal request/response operation requires sequences `59` and `62` respectively.

## Write commands

Filters:

```text
11 20 DF 00 PP DD 00 00
```

- `PP`: PCM filter (`0` sharp roll-off, `1` slow roll-off)
- `DD`: DSD filter (`0` low, `1` medium, `2` high)

Main settings:

```text
19 30 CF 00 CC TT MM KK
```

- `CC`: coax (`0` off, `1` on)
- `TT`: PCM reduction (`0` 0 dB, `1` -1 dB, `2` -2 dB, `3` -3 dB)
- `MM`: PCM/DSD volume match (`0` off, `1` on)
- `KK`: off-screen volume knob (`0` off, `1` on)

Settings share group packets. A client must never replace unknown sibling values with defaults. DC Elite Control always performs:

```text
read complete group → change one field → write complete group → read complete group → compare
```

## Hardware validation

The following reports were captured through `IOHIDDevice` on macOS. The connected unit had all exposed settings at their zero-valued choices.

```text
TX  58 F1 0E 00 00 00 00 00
RX  58 00 FF 00 10 98 73 00

TX  59 21 DE 00 00 00 00 00
RX  59 00 FF 00 00 00 00 00

TX  62 31 CE 00 00 00 00 00
RX  62 00 FF 00 00 00 00 00
```

An intentionally reversible PCM-filter test was also completed. The filter was changed from sharp to slow, verified, and then restored to sharp and verified again:

```text
TX  11 20 DF 00 01 00 00 00
RX  11 00 FF 00 01 00 00 00
TX  59 21 DE 00 00 00 00 00
RX  59 00 FF 00 01 00 00 00

TX  11 20 DF 00 00 00 00 00
RX  11 00 FF 00 00 00 00 00
TX  59 21 DE 00 00 00 00 00
RX  59 00 FF 00 00 00 00 00
```
