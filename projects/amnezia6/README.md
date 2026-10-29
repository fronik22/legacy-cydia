# Amnezia6

Minimal native UIKit AmneziaWG client for jailbroken iOS4.3–7.x devices.
Current release1.2.1. App/daemon/CLI use armv7 (including the iOS7 32-bit
compatibility runtime); the SpringBoard badge includes armv7+arm64 slices.
Device validation: iPad2,2/iOS6.1.3 and iPad4,5/iOS7.1.2. The latter's shared
engine completed a real handshake, HTTP response and configured-DNS query through
a bounded opaque UDP relay. Direct endpoint access on that LAN remains unproven;
see ../../notes/AMNEZIA-IOS7.md. iOS4.3/5 and final1.2.1 UIKit controls remain untested.

## Use

Install the `.deb` with `dpkg -i`, then open Amnezia6 and use its VPN switch.
The existing profile is preserved at
`/var/mobile/Library/Preferences/Amnezia6/amnezia6.conf` (mobile, mode 0600).
The Configuration screen edits this profile; saving replaces it atomically.
The root daemon owns UTUN, routes and DNS. The app communicates via a local
Unix socket. The daemon starts idle: opening the app never connects by itself.

A SpringBoard extension displays the native VPN badge while the daemon reports
connected. It queries off the UI thread and hides the badge after daemon death;
its getter override is scoped to the VPN item, and the Wi-Fi glyph is preserved.
The extension is activated on the next SpringBoard restart after installation;
the current device was activated live through the existing injection tool.

IPv4 full-tunnel operation is supported. Saved profiles and server selection are available through the Servers button. IPv6 is not
protected. No kill switch: disconnect or failure returns traffic to Wi-Fi.
Do not enable another VPN simultaneously or reuse this profile on two clients.

## Artwork

The oak-and-brass artwork is stored in artwork/Icon-source.png. `make app`
exports the five native icon sizes with transparent rounded corners. The
pre-rendered flag preserves the baked-in lighting without another gloss layer.

## Build

Use `make device app deb` with an external armv7-capable compiler/SDK and ldid.
Override SDK, DEVCLANG and LDID as needed. Legacy builds also require Apple's
crt1.3.1.o and libgcc_s.1.tbd under toolchain/oldlibs; these SDK files are not
redistributed with the source archive. Current paths are local build defaults.

`make test` runs offline cryptography, DNS cleanup, route ownership and atomic
configuration-save tests without changing host network settings.
`make test-live CONFIG=/private/profile.conf` talks to the configured server;
stop the iPad tunnel first to avoid competing sessions using the same identity.
`make deb` validates the finished Debian archive and excludes user profiles.

## Startup and recovery

The package installs `/Library/LaunchDaemons/com.mak.amnezia6d.plist` for boot.
Some legacy jailbreak SSH bootstraps reject `launchctl load`; installation then
uses `amnezia6d --daemonize`. This fallback is not supervised until reboot.
The daemon can be restarted as root with the same command. Boot after reboot
has not been tested in this session.

DNS/service entries use SCDynamicStoreAddTemporaryValue and disappear on process
death. configd derives and restores global network state; the daemon no longer
writes snapshots over the system's global DNS/IPv4 configuration.

## License

GNU GPL v2; see LICENSE and THIRD_PARTY.md. Monocypher notices are retained.

## Status badge hardware check

The optional tests/status_snapshot.m diagnostic bundle captures the complete
SpringBoard screen and reports native VPN getter scope, Wi-Fi primary state and
data connection type. On the tested iOS 6 device, the badge appears only while
connected, Wi-Fi stays visible (type 8), and the VPN getter outside item updates
remains false. This helper is not installed by the package.

## 1.0.3 network and rotation repair

New connections use the current physical gateway and repair a proven stale static endpoint exception from a departed LAN. UDP sockets open after route setup; send errors include the system reason, failed sends respect retry deadlines, and cleanup clears route ownership. All three screens support landscape, including the configuration keyboard. Native iPad2/iOS6.1.3 hotspot, stale-route reproduction, VPN traffic and Blastron startup checks passed. Other OS versions/carriers and seamless roaming are untested. See NETWORK-REPAIR-20261023.md for evidence and rejected attempts.

## 1.0.4 switch reliability

Status polls no longer rebuild the switch cell or reset its value when the backend state is unchanged. Touch/child-gesture tracking defers UI updates; command generations reject stale poll results after ON/OFF. A completed command forces one fresh status reconciliation, including rollback on failure. Start/stop accept only an actual OK acknowledgement; empty responses and I/O failures are errors. The optional native regression target in tests/TOGGLE-REGRESSION.md is excluded from the installed package. Full evidence is TOGGLE-REPAIR-20261023.md.

Final1.0.4 validation:5/5 native timing/cell regressions and9/9 real input gestures passed (one command each). A later independent connectivity failure affected even numeric TCP with the VPN down; its AP/upstream cause is unresolved. Do not interpret successful control/handshake tests as proof of final Internet availability. See TOGGLE-REPAIR-20261023.md.

## 1.0.5 automatic recovery

ON now remains CONNECTING after transient network/setup or key-renewal failure and retries with bounded1–30second backoff. Expired session keys are wiped; a departed source IPv4 triggers fresh socket/route selection. OFF cancels all retries. Rekey attempts obey their deadline even after a failed send or exhausted round. Status/logs expose the retry reason, source and attempt count. No kill switch: traffic may use the physical network during recovery. See DISCONNECT-REPAIR-20261023.md for device evidence and limits.

## 1.0.6 connection timer and server identity

The connection duration starts at the first successful handshake and survives routine key renewal. A real reconnect starts a new timer and clears traffic counters. The Server row shows the resolved IPv4:port while connected and the saved peer Endpoint while disconnected. The saved display value is read on screen appearance, not on every periodic status query. One active profile is still supported. Regression tests cover successful rekey preserving the timestamp/counters, real reconnect resetting them, and peer-only endpoint display parsing.

The native protocol engine implements WireGuard plus AmneziaWG obfuscation including 3.1 header protection, random trailers, additional content padding and configurable timing ranges; older profiles can disable these features. This is not a claim of complete upstream conformance: the current parser accepts a single numeric ContentPaddingAddition, not its range form, and the initiator does not implement cookie-challenge responses. Cross-server/version interoperability remains limited to tested profiles. Protocol reference: https://docs.amnezia.org/documentation/amnezia-wg/.

1.0.6 installation and real-rekey evidence: SESSION-REPAIR-20261025.md. Exact protocol coverage and limits: PROTOCOL-SUPPORT.md.

## 1.1.0 profiles, imports and protocol additions

Open **Серверы → +** to add a profile from clipboard, a file, a photographed QR code, a saved QR image, or manual text. Imports accept plain WireGuard/AmneziaWG configuration, `vpn://`/`.vpn` exports and supported Amnezia JSON bundles. The app shows an editable draft before Save. It never connects solely because an external URL/file was opened. The first saved profile is selected if there was none, while VPN remains OFF.

Tap a server to select it. Selection persists across app sessions. An active VPN reconnects using the selected profile; OFF remains OFF. The detail button edits its name/configuration. Swipe an inactive profile to delete it; select another profile before deleting the current one. Existing amnezia6.conf is migrated without changing its keys. Edits to a selected profile apply through the same serialized stop/save/start operation, with rollback after command/persistence failure.

Profiles are saved atomically in profiles.plist under the existing private Amnezia6 preferences directory (directory0700/files0600). If an interrupted two-file update leaves an unmatched active configuration, startup preserves it as another profile instead of discarding either configuration. UI metadata reads use a short separate lock and do not wait for network/control operations.

File import uses iOS4-compatible **Open In Amnezia6** integration and a native browser. Direct-import location: `/var/mobile/Documents/Amnezia6`; Documents/Inbox and Downloads are also accessible through the browser when present. QR uses quirc, with the system camera/photo picker; photograph the code then confirm the image. Camera runs only while its picker is open; no background scanner or location-service dependency was added.

ContentPaddingAddition accepts a single value or a range0–65535. Selection follows Senko/upstream bounded random padding behavior and observed UDP window, capped by configured MTU, wire overhead and output capacity. Authenticated inbound cookie challenges produce a short-lived MAC2 cookie for subsequent handshake retries, including rekey; malformed/stale/duplicate challenges cannot trigger immediate resend loops. DisableCookies does not disable processing incoming challenges (this client does not act as a handshake responder). Cookie crypto was checked against an independent libsodium vector.

Current limits: IPv4 full tunnel; one peer per profile; bounded2048-byte datagrams/Jmax and Jc<=128; profile text<=128KiB, imported input<=768KiB and supported decoded bundles<=512KiB. This is not a claim of complete upstream conformance or arbitrary server availability. See PROFILES-RESULTS-20261026.md for actual hardware tests and remaining verification limits.

## 1.2.1 audit corrections

The control socket now binds privately before root:mobile0660 ownership/mode is
established. Missing mobile group or failed ownership/mode/listen setup aborts
and removes the socket; there is no world-writable fallback. A requested tunnel
DNS setup failure tears down the attempted tunnel and enters bounded retry
before any handshake is sent; it no longer continues using a physical resolver.
This is setup failure handling, not a kill switch or DNS-server health monitor.

The parser rejects IPv6 tunnel Address/DNS/Endpoint and unsupported split-route
requests instead of silently ignoring them. A common dual default AllowedIPs
list (`0.0.0.0/0, ::/0`) remains accepted without rewriting the saved profile,
but **only IPv4 is tunneled**. Physical IPv6 remains unprotected, even with an
IPv4-only profile. The app always states this and the absence of a kill switch.
For multiple IPv4 DNS entries, the current engine selects the first; it does
not provide resolver failover. One IPv4 tunnel address is supported.

Offline checks: `make test`; native diagnostic targets
`build/test_protocol-device`, `build/test_profiles-device`,
`build/device_control_probe`, and `build/device_tunnel_probe`. The last target
is root-only and changes routes/DNS temporarily: coordinate idle VPN state,
use a private configuration and bounded duration, and verify cleanup. These
probes are not installed by the Debian package. Public source contains no live
VPN profile, endpoint, credential, SDK or original device dump.
