# XR Control

An iOS app for controlling a DumaOS router from your phone, built and targeted at
the **NETGEAR Nighthawk XR500**.

It is an unofficial client. NETGEAR and Netduma publish no API; everything here
is built against the endpoints the router's own web interface uses.

<sub>Not affiliated with, endorsed by, or supported by NETGEAR or Netduma.</sub>

## What it does

| Screen | Backed by |
| --- | --- |
| **Dashboard** — live WAN throughput chart, CPU, memory, flash, uptime, device count | `systeminfo` |
| **Geo-Filter** — map of every host the router has seen, draggable radius, Spectating/Filtering, Ping Assist, strict mode | `geofilter` |
| **Bandwidth** — connection speeds, Anti-Bufferbloat, per-device allocation pie, traffic prioritisation, hardware acceleration | `qos` |
| **Devices** — full device list with rename, block, signal strength and link rate | `devicemanager` + NETGEAR SOAP |
| **Traffic Controller** — read and toggle allow/block/reject rules | `trafficcontroller` |
| **Settings** — router identity, reboot, and an RPC explorer for calling any procedure directly | `systeminfo`, all |

There is also a **demo mode** on the sign-in screen that runs the whole app
against canned data, so you can look around without a router on the network.

## Getting started

Requirements: Xcode 15+, iOS 17+ device or simulator.

```sh
open ios/XRControl.xcodeproj
```

Pick the `XRControl` scheme and run. On first launch, enter:

- **Address** — your router's LAN address (`192.168.1.1` by default)
- **Username / Password** — the same admin credentials you use for the DumaOS web
  interface

The password is stored in the iOS keychain; nothing leaves your device.

> **Local Network permission.** iOS asks for consent the first time the app
> contacts your router. If you decline, every request fails with a transport
> error — re-enable it under Settings → XR Control → Local Network.

> **Simulator note.** The simulator shares the Mac's network, so it can reach the
> router if the Mac is on the same LAN. A physical device must be on the router's
> Wi-Fi, not cellular.

### Regenerating the project

`XRControl.xcodeproj` is generated and committed so the app opens with no extra
tooling. After adding or removing source files, regenerate it:

```sh
cd ios && python3 scripts/generate_xcodeproj.py
```

An [XcodeGen](https://github.com/yonaskolb/XcodeGen) spec (`project.yml`) is also
provided if you prefer that toolchain (`xcodegen generate`).

## How it talks to the router

The XR500 exposes two separate HTTP APIs, and the app uses both.

### 1. DumaOS JSON-RPC — the main API

Everything DumaOS adds lives behind a per-package JSON-RPC 2.0 endpoint:

```
POST http://<router>/apps/<package-id>/rpc/
Content-Type: application/json-rpc
Authorization: Basic <base64 admin:password>

{"jsonrpc":"2.0","method":"get_cpu_info","id":1,"params":[]}
```

Three details matter, and all three are enforced by the router:

1. **`params` is always an array.** A bare value is rejected.
2. **`result` is also always an array.** The router's browser client spreads it
   across a callback's arguments, so a procedure returning one object returns it
   as `result[0]`.
3. **Errors can arrive with HTTP 200.** Failure is signalled by an `eid`/`msg`
   pair in the body, with a JSON-RPC style numeric `error` code. HTTP **418** and
   **419** are DumaOS's non-standard "log in again" statuses.

Packages and their procedures, as registered by XR-series firmware:

| Package | Procedures used by this app |
| --- | --- |
| `com.netdumasoftware.systeminfo` | `get_system_info`, `get_cpu_info`, `get_ram_info`, `get_flash_info`, `get_network_statistics`, `get_wan_ip`, `read_log`, `reboot`, `factory_reset` |
| `com.netdumasoftware.devicemanager` | `get_all_devices`, `get_device`, `get_types`, `set_device_name`, `set_device_type`, `block_device`, `delete_all_offline`, `get_network_view` |
| `com.netdumasoftware.geofilter` | `get_all`, `get_all_hosts`, `mode`, `strict`, `distance`, `pingass`, `home`, `get_polygons`, `save_polygons`, `upsert_host`, `remove_host` |
| `com.netdumasoftware.qos` | `get_bandwidth`, `set_bandwidth`, `get_link_throttle`, `set_link_throttle`, `get_bandwidth_dist_tree`, `set_bandwidth_dist_tree`, `get_acceleration`, `set_acceleration`, `get_hyperlane_services` |
| `com.netdumasoftware.trafficcontroller` | `get_rules`, `get_rule`, `add_rule`, `update_rule`, `delete_rule`, `reorder_rule`, `get_log` |
| `com.netdumasoftware.networkmonitor` | `filter_connections` |

Many procedures are **dual-purpose getters and setters**: calling one with an
empty `params` array reads the current value, calling it with a single argument
writes it. `mode`, `strict`, `distance` and `pingass` all work this way.

### 2. NETGEAR SOAP — the firmware API

Underneath DumaOS is the stock NETGEAR SOAP service, which knows things DumaOS
does not expose — Wi-Fi signal strength and link rate:

```
POST http://<router>:5000/soap/server_sa/
SOAPAction: urn:NETGEAR-ROUTER:service:DeviceInfo:1#GetAttachDevice2
```

Sign-in is `DeviceConfig:1#SOAPLogin`, falling back to
`ParentalControl:1#Authenticate` on older firmware. Success is
`<ResponseCode>000</ResponseCode>`; `401` means the session is not authenticated.

The app treats this API as strictly supplementary — if it fails, the device list
still renders, just without signal bars.

## Accuracy and what still needs confirming

Endpoint paths, the wire format, package identifiers and procedure names are all
taken from the DumaOS client and R-App bundles, so they are solid.

What is **inferred** is the exact argument shape of a few *setters*, because the
procedure bodies ship as compiled Lua bytecode. Specifically:

- `geofilter.home` — assumed to take `{lat, long}`
- `geofilter.distance` — assumed to be metres (the app converts from km)
- `qos.set_link_throttle` — assumed to take `{enabled, dthrottle, uthrottle}`
- `qos.set_bandwidth_dist_tree` — assumed to take a `{children: [...]}` tree
- `devicemanager.block_device` — assumed to take `(deviceID, blocked)`

Reads are unaffected; a wrong setter shape fails cleanly with an error banner
rather than corrupting settings.

**To confirm any of these against your own router**, use the built-in RPC
explorer (Settings → RPC explorer). Call the getter, read the exact JSON your
firmware returns, and mirror that shape back into the setter. The explorer is
there precisely so you never need a laptop and a proxy for this.

## Project layout

```
ios/
├── XRControl/
│   ├── App/              AppModel — connection state, service vending
│   ├── Models/           Lenient parsers for the router's JSON
│   ├── Networking/       DumaRPCClient, NetgearSOAPClient, RouterServicing
│   ├── Features/         One folder per screen (view + view model)
│   ├── Support/          Theme, shared components, formatters
│   └── Resources/        Info.plist, asset catalog
├── XRControlTests/       Protocol encode/decode and model parsing tests
├── scripts/              Xcode project generator
└── project.yml           XcodeGen spec
```

`RouterServicing` is the seam: `LiveRouterService` talks to a real XR500,
`MockRouterService` serves canned data. Views only ever see the protocol, which
is what makes demo mode and previews work.

### Parsing philosophy

DumaOS field names drift between firmware revisions, so every model uses a
lenient `init(json:)` that tries the spellings observed in the shipped R-Apps and
falls back rather than failing the whole response. One renamed key costs you one
field, not the screen. Device detail keeps the untouched payload behind a "Raw
router payload" disclosure so nothing is ever hidden from you.

## Tests

`⌘U` in Xcode, or:

```sh
xcodebuild test -project ios/XRControl.xcodeproj -scheme XRControl \
  -destination 'platform=iOS Simulator,name=iPhone 15'
```

Coverage is on the parts that break silently: JSON-RPC envelope encoding, error
mapping (including the 200-with-`eid` case), SOAP envelope construction and
escaping, `GetAttachDevice2` parsing, throughput derivation across a counter
reset, and the lenient model parsers.

## Safety notes

- **Reboot** is behind a confirmation dialog. There is no factory-reset button in
  the UI, deliberately — the procedure exists, but a mis-tap on a phone is too
  expensive.
- **Hardware acceleration** bypasses QoS for accelerated flows; the toggle says
  so.
- Bandwidth allocation shares are normalised to 100% before being sent, because
  the router rejects a tree whose proportions do not sum.
