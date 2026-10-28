# Support and verification matrix

Last updated: 2026-10-28.

This page records what was actually exercised on hardware. A package appearing in
the repository does not imply that every feature works on every declared
firmware version. The `Depends` line in the package is the installation gate;
this page is the support statement.

## Test devices

| Name | Model | Firmware | Jailbreak / tools |
|---|---|---|---|
| iPad 2 (GSM) | `iPad2,2` | 6.1.3 (10B329) | Cydia 1.1.30, MobileSubstrate, OpenSSH, AppSync Unified |
| iPad mini 2 | `iPad4,5` | 7.1.2 (11D257) | Cydia 1.1.30, MobileSubstrate 0.9.6301, OpenSSH |

Both devices are armv7-capable; the iPad mini 2 has a 64-bit SpringBoard and a
32-bit compatibility runtime. No firmware was changed during testing. Existing
apps, profiles, saves and the disabled HUD/logger states were preserved.

## Package matrix

### Amnezia6 1.2.0 — `com.mak.amnezia6`

Declared: `firmware (>= 4.3), firmware (<< 8.0), mobilesubstrate`.

| Check | iOS 6.1.3 | iOS 7.1.2 |
|---|---|---|
| Package install / upgrade via `dpkg -i` | Verified | Verified |
| App bundle, daemon and CLI present | Verified | Verified |
| Root daemon starts under launchd | Verified | Verified |
| UTUN creation, address and default route | Verified | Verified |
| Status / start / stop over control socket | Verified | Verified |
| SpringBoard VPN badge hook loaded | Verified (armv7) | Verified (universal armv7 + arm64) |
| SpringBoard survives respawn with hook | Verified | Verified, no crash report |
| Full tunnel handshake and traffic | Verified earlier | **Not verified in this session** |

iOS 7 detail: the app, daemon and CLI are `armv7` and run under the 32-bit
runtime. The status hook is a universal `armv7 + arm64` dylib because SpringBoard
is 64-bit on `iPad4,5`. After installation the daemon started, created `utun0`,
installed the route and answered `status`. The handshake stayed in `connecting`
because the test LAN could not reach `83.171.227.17` over UDP 443 from either
iPad; a host-side handshake with the same profile succeeded from a different WAN
address. This isolates the failure to the network path, not the package, but the
end-to-end tunnel on iOS 7 remains unproven.

The existing profile is not shipped in the package. Upgrading preserves
`/var/mobile/Library/Preferences/Amnezia6/amnezia6.conf`.

### Performance Overlay 0.1.9 — `local.perfoverlay`

Declared: `firmware (>= 4.3), firmware (<< 10.0), mobilesubstrate,
preferenceloader`.

| Check | iOS 6.1.3 | iOS 7.1.2 |
|---|---|---|
| Install | Verified (0.1.8) | Verified (0.1.9) |
| Universal dylib | armv7 only in 0.1.8 | armv7 + arm64 |
| Hook loads into SpringBoard | Verified | Verified |
| SpringBoard stable after respawn | Verified | Verified, no crash report |
| HUD visually confirmed | Verified on iOS 6 | **Not captured** |

Screenshots on iOS 7 require a mounted Developer Disk Image and the
`screenshotr` service, which was not available. The iOS 7 evidence is therefore
"hook loaded and SpringBoard stable", not "HUD pixels confirmed".

### Power Logger 1.1.0 — `local.legacypower`

Declared: `firmware (>= 6.0), firmware (<< 8.0), preferenceloader`.

| Check | iOS 6.1.3 | iOS 7.1.2 |
|---|---|---|
| Install | Verified (1.0.0) | Verified (1.1.0) |
| Universal daemon | armv7 only in 1.0.0 | armv7 + arm64 |
| launchd starts daemon | Verified | Verified (`com.local.legacypowerd`) |
| Writes `/var/mobile/Library/Logs/LegacyPower/status.json` | Verified | Verified |
| Preference bundle opens | Verified | **Not exercised** |
| Logging is off by default | Verified | Verified |

The logger does not enable itself on install. Existing disabled state is
preserved.

### Legacy Game FPS 0.2.1 — `local.legacy-game-fps`

Declared: `firmware (>= 6.0), firmware (<< 8.0), mobilesubstrate,
preferenceloader`.

| Check | iOS 6.1.3 | iOS 7.1.2 |
|---|---|---|
| Install | Verified (0.2.0) | Not run |
| Supported game builds launch with hook | Verified (0.2.0) | **Untested** |
| 30/60 FPS pacing measured | Verified (0.2.0) | **Untested** |
| Settings pane | Verified (0.2.0) | **Untested** |

0.2.1 adds an explicit `iOS 6 or 7` runtime guard and an arm64 preference bundle;
the game hook itself remains armv7 and is restricted to the exact executable
hashes in `projects/game-fps/SUPPORTED-BUILDS.json`. The supported games
(WORMS 2, WORMS 3, Minigore HD, Minigore 2) are not installed on the iOS 7 test
device, so no iOS 7 game session has been measured. **Do not treat 0.2.1 as
iOS 7-verified.**

### Veteris Native iPad 1.2.0 — `local.codex.veteris-ipad`

Declared: `firmware (>= 5.0), firmware (<< 8.0), mobilesubstrate,
com.victorlobe.veteris (= 4)`.

| Check | iOS 6.1.3 | iOS 7.1.2 |
|---|---|---|
| Install | Verified (1.1.0) | Not run |
| Native iPad layout | Verified | **Untested** |
| Background download / suspension fix | Verified | **Untested** |
| iOS 7 shader-cache guard | n/a | Added in 1.2.0, **untested** |

Veteris 4 is not installed on the iOS 7 device. The 1.2.0 guard sets
`SGX_MAX_SHADER_CACHE_SIZE=0` only for iOS 7 and only inside Veteris; it has not
been exercised against the iOS 7 graphics stack. The package pins Veteris to
version 4 on purpose.

### LocalSend 6 0.5.7 — `com.unlocalsend.ios6`

Declared: `firmware (>= 6.0)` (no upper cap).

| Check | iOS 6.1.3 | iOS 7.1.2 |
|---|---|---|
| Install | Verified | Not run |
| Launch and device discovery | Verified | **Untested** |
| File transfer | Verified | **Untested** |
| arm64 slice | Not applicable | No; runs as armv7 under the 32-bit runtime |

The missing upper cap means Cydia will offer 0.5.7 on iOS 7 even though it has
not been run there. This is recorded as untested, not as supported.

### Blastron Revival 0.1.15 — `local.codex.blastron-revival`

Declared: `firmware (>= 6.0), firmware (<< 7.0), mobilesubstrate`.

Tested only on iPad2,2 / iOS 6.1.3 against the exact Blastron build recorded in
the project. The package is deliberately capped below iOS 7. It contains no
original game assets or game executables; the dylib applies hooks to an
already-installed copy of the game.

### Legacy Timezone Update 2026e-1 — `local.codex.legacy-timezone`

Declared: `firmware (>= 4.3), firmware (<< 7.0), gsc.armv7`.

Tested on iPad2,2 / iOS 6.1.3 (and iOS 4.3.3 in the original project). The
installer verifies the iOS 4–6 ICU layout, keeps a backup and refuses iOS 7
because the ICU 49 resource layout and the `zoneinfo64.res` patch differ. A
separate iOS 7 ICU adapter is required before this cap can move. The package
contains IANA timezone data and generated ICU resources, not Apple SDK files.

### Legacy Device Access 1.0.1 — `local.codex.device-access`

Declared: `firmware (>= 4.3), firmware (<< 7.0), mobilesubstrate`.

The CLI accepts exactly iOS 4.3.3 and 6.1.3. It is a one-shot, root-operated
diagnostic helper with no daemon, listener or boot hook; it refuses configured
passcodes. It is not an iOS 7 package.

## Known test limitations

- The home LAN could not reach the VPS at `83.171.227.17` (TCP 28064 and UDP 443
  timed out from both iPads). The host-side AmneziaWG handshake succeeded from a
  different WAN address, so the server and profile are valid; the iOS 7 tunnel
  handshake is still unproven.
- iOS 7 app launching from SSH is blocked: `SBSLaunchApplicationWithIdentifier`
  returns error 9 for every app, including Settings, and `uicache` reports
  `cannot open cache file. incorrect user?`. This prevents automated UI tests.
- iOS 7 screenshots require a mounted Developer Disk Image and the
  `screenshotr` service, which was unavailable. Visual claims are limited to
  what could be confirmed through process state and logs.
- iOS 7 arm64 SpringBoard requires a 64-bit hook slice; an armv7-only dylib will
  not load there. This is why Amnezia6 and Performance Overlay ship universal
  dylibs.
- Power Logger, Performance Overlay and Amnezia6 keep their logs off or idle
  until explicitly enabled. Do not interpret an idle status as a failure.
- No long-duration, battery, thermal, multiplayer or every-device test was run.

## Reporting a problem

Open an issue at <https://github.com/fronik22/legacy-cydia/issues> and include:

1. Device model (`iPad2,2`, `iPad4,5`, …) and firmware build.
2. Package name and version from `dpkg -l`.
3. Whether the package was installed by Cydia or `dpkg -i`.
4. The exact command or screen that failed.
5. Relevant lines from the package log (`/var/log/amnezia6d.log`,
   `/var/log/legacypower.log`, or the crash report name).

Do not post VPN private keys, profiles, Apple ID credentials or device dumps.
Redact endpoints and keys before attaching logs.

## Out of scope

- iOS 8 and later are not a target for the legacy-only packages. Performance
  Overlay declares up to iOS 9, but only the iOS 4–7 paths were exercised here.
- 64-bit native apps and arm64-only devices below iOS 7 do not exist; arm64
  slices are present only where a 64-bit system process needs to load them.
- Senko and the Wi-Fi monitoring service are not part of this repository and
  will not be reinstalled by any package here.
- Original games, App Store IPAs, Apple SDKs, signing identities and private
  device data are not distributed.
