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

### Amnezia6 1.2.1 — `com.mak.amnezia6`

Declared: `firmware (>= 4.3), firmware (<< 8.0), mobilesubstrate`.

| Check | iOS 6.1.3 | iOS 7.1.2 |
|---|---|---|
| Package install / upgrade via `dpkg -i` | Verified (1.2.0; 1.2.1 not installed) | Verified (1.2.1 over 1.2.0) |
| App bundle, daemon and CLI present | Verified | Verified |
| Root daemon starts under launchd | Verified | Verified |
| Control socket permissions | Not re-run | Verified `0660 root:mobile` |
| UTUN creation, address and default route | Verified | Verified |
| Status / start / stop over control socket | Verified | Verified, idle state |
| SpringBoard VPN badge hook loaded | Verified (armv7) | Verified (universal armv7 + arm64) |
| SpringBoard survives respawn with hook | Verified | Verified, no crash report |
| Full tunnel handshake and traffic | Verified earlier | **Engine test passed; direct path unproven** |

iOS 7 detail: the app, daemon and CLI are `armv7` and run under the 32-bit
runtime. The status hook is a universal `armv7 + arm64` dylib because SpringBoard
is 64-bit on `iPad4,5`. 1.2.1 adds a fail-closed DNS path, rejects unsupported
IPv6/split routes and will not fall back to a world-writable control socket.

The same 1.2.1 engine was linked into an isolated root diagnostic and completed a
handshake plus 9 transmitted / 7 received IP packets through a temporary Mac UDP
relay (10 out / 9 in opaque datagrams). That exercises the real iOS 7 UTUN,
crypto, route and DNS paths. A direct handshake to the same endpoint from the
test LAN still times out, so the direct network path remains unlocalised. The
normal daemon stayed idle and the existing profile was preserved byte-for-byte.

The 1.2.1 package was installed only on 7.1.2; the iOS 6 device remains on 1.2.0.
The fixes are shared code, but iOS 6 was not re-run against this exact build.

The existing profile is not shipped in the package. Upgrading preserves
`/var/mobile/Library/Preferences/Amnezia6/amnezia6.conf`.

### Performance Overlay 0.1.10 — `local.perfoverlay`

Declared: `firmware (>= 4.3), firmware (<< 10.0), mobilesubstrate,
preferenceloader`.

| Check | iOS 6.1.3 | iOS 7.1.2 |
|---|---|---|
| Install | Verified (0.1.8) | Verified (0.1.10 over 0.1.9) |
| Universal dylib | armv7 only in 0.1.8 | armv7 + arm64 |
| Hook loads into SpringBoard | Verified | Verified |
| SpringBoard stable after respawn | Verified | Verified, no crash report |
| HUD stays disabled by default | Verified | Verified (`Enabled = false`) |
| HUD visually confirmed | Verified on iOS 6 | **Not captured** |

0.1.10 fixes the A7 page-size reading: the arm64 task uses 16 KiB pages while
the kernel VM counters remain 4 KiB, which previously produced a fake 2293 MiB
used on a 976 MiB device. Native probes now read about 576 MiB and reject
impossible totals; the Settings bundle loads under the 64-bit Preferences
framework. Screenshots on iOS 7 require a mounted Developer Disk Image and the
`screenshotr` service, which was not available. The iOS 7 evidence is therefore
"hook loaded, metrics corrected and SpringBoard stable", not "HUD pixels
confirmed".

### Power Logger 1.1.1 — `local.legacypower`

Declared: `firmware (>= 6.0), firmware (<< 8.0), preferenceloader`.

| Check | iOS 6.1.3 | iOS 7.1.2 |
|---|---|---|
| Install | Verified (1.0.0) | Verified (1.1.1 over 1.1.0) |
| Universal daemon | armv7 only in 1.0.0 | armv7 + arm64 |
| launchd starts daemon | Verified | Verified (`com.local.legacypowerd`) |
| Writes `/var/mobile/Library/Logs/LegacyPower/status.json` | Verified | Verified, reports 1.1.1 |
| Native arm64 sampling | n/a | Verified: 85 processes, 84 CPU deltas, 0 taskinfo errors |
| Preference bundle loader | Verified | Verified under 64-bit Preferences |
| Logging is off by default | Verified | Verified (`enabled = false`) |

The logger does not enable itself on install. 1.1.1 validates the 96-byte
`PROC_PIDTASKINFO` layout, calibrates CPU on both 32- and 64-bit hosts and
removes the unrestricted `dynamic_lookup` link. Interactive pane taps and a
long unplugged battery run were not performed.

### Legacy Game FPS 0.2.2 — `local.legacy-game-fps`

Declared: `firmware (>= 6.0), firmware (<< 8.0), mobilesubstrate,
preferenceloader`.

| Check | iOS 6.1.3 | iOS 7.1.2 |
|---|---|---|
| Install | Verified (0.2.0) | Verified (0.2.2) |
| Arm64 Settings bundle loads | n/a | Verified |
| Supported game builds launch with hook | Verified (0.2.0) | **Untested** |
| 30/60 FPS pacing measured | Verified (0.2.0) | **Untested** |
| Settings pane | Verified (0.2.0) | Loader only, **not exercised** |

0.2.2 adds an explicit `iOS 6 or 7` runtime guard and an arm64 preference bundle;
the game hook itself remains armv7 and is restricted to the exact executable
hashes in `projects/game-fps/SUPPORTED-BUILDS.json`. The supported games
(WORMS 2, WORMS 3, Minigore HD, Minigore 2) are not installed on the iOS 7 test
device, so no iOS 7 game session has been measured. **Do not treat 0.2.2 as
gameplay-verified on iOS 7.**

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
`SGX_MAX_SHADER_CACHE_SIZE=0` only for iOS 6 and only inside Veteris. iOS 7 deliberately skips that driver-specific workaround; its background behavior remains untested. The package pins Veteris to
version 4 on purpose.

### Historical LocalSend 6 0.5.7 — withdrawn from active index

This obsolete direct `/Applications` package has been removed from the current catalog to prevent a duplicate app bundle ID. Existing installs are not removed automatically. The supported delivery is the current IPA installer described below. Historical observations follow.

Declared: `firmware (>= 6.0)` (no upper cap).

| Check | iOS 6.1.3 | iOS 7.1.2 |
|---|---|---|
| Install | Verified | Not run |
| Launch and device discovery | Verified | **Untested** |
| File transfer | Verified | **Untested** |
| arm64 slice | Not applicable | No; runs as armv7 under the 32-bit runtime |

The missing upper cap means Cydia will offer 0.5.7 on iOS 7 even though it has
not been run there. This is recorded as untested, not as supported. The newer
IPA installer package below uses the platform installer and is the preferred
path when `appinst` is available; it refuses to overwrite an existing
`/Applications/LocalSend6.app`.

### LocalSend (IPA Installer) 5.7.4340 — `local.codex.localsend-installer`

Declared: `firmware (>= 5.0), firmware (<< 8.0), ai.akemi.appinst (>= 2.0),
ai.akemi.appsyncunified`.

| Check | iOS 6.1.3 | iOS 7.1.2 |
|---|---|---|
| Package/script/IPA validation | Passed | Passed |
| 32-bit iOS 7 runtime/API probe | n/a | Passed |
| Install through appinst | Not run | **Not run: dependencies absent** |
| Launch, photo selection, HEIC decode, transfer | Verified on the 4340 app on iOS 6 | **Untested** |

This package contains the retained LocalSend 5.7.4340 IPA, not app data. It uses
the official `appinst` and requires Karen's repository <https://cydia.akemi.ai/>.
The mini 2 had neither `ai.akemi.appinst` nor `ai.akemi.appsyncunified`, and the
repository timed out from the Mac, so no IPA install was attempted. The
maintainer scripts reject a pre-existing `/Applications/LocalSend6.app` or
`/Applications/LocalSend.app` rather than relocating data.

### Troubadour (IPA Installer) 1.6.447 — `local.codex.troubadour-installer`

Declared: `firmware (>= 5.0), firmware (<< 8.0), ai.akemi.appinst (>= 2.0),
ai.akemi.appsyncunified`.

| Check | iOS 6.1.3 | iOS 7.1.2 |
|---|---|---|
| Package/script/IPA validation | Passed | Passed |
| 32-bit iOS 7 runtime/API probe | n/a | Passed |
| Install through appinst | Not run | **Not run: dependencies absent** |
| Launch and playback | Verified on 1.6.446 on iOS 6 | **Untested** |

Same dependency and availability limit as LocalSend. 1.6.447 contains the
SABR audio-membership repair verified on iOS 4; the installed iOS 6 copy remains
1.6.446 and was not upgraded during this work.

### Blastron Revival 0.1.15 — `local.codex.blastron-revival`

Declared: `firmware (>= 6.0), firmware (<< 7.0), mobilesubstrate`.

Tested only on iPad2,2 / iOS 6.1.3 against the exact Blastron build recorded in
the project. The package is deliberately capped below iOS 7. It contains no
original game assets or game executables; the dylib applies hooks to an
already-installed copy of the game.

### Legacy Timezone Update 2026e-1 — `local.codex.legacy-timezone`

Declared: `firmware (>= 4.3), firmware (<< 7.0), gsc.armv7`.

System installation/removal tested on iPad2,2 / iOS 6.1.3; physical iOS 4.3.3/5 tests were not performed. The
installer verifies the iOS 4–6 ICU layout, keeps a backup and refuses iOS 7
pending a complete iOS7 system-install/reboot/rollback test. The separate preview actually parses ICU51 and passes staged validation; the older cap is not evidence that ICU51 is inherently incompatible. The
package contains IANA timezone data and generated ICU resources, not Apple SDK
files.

A 2026e-2 adapter for the iOS 7 ICU 51 layout was built and staged on the mini 2
/ 7.1.2: 600 files validated, the system ICU SHA256 stayed unchanged and no
system files were modified. It is **not in the stable APT index** until a real install, reboot and removal round-trip pass. The separate manual preview is downloadable from docs/previews; it is not an automatic upgrade.

### Legacy Device Access 1.1.0 — `local.codex.device-access`

Declared: `firmware (>= 4.3), firmware (<< 8.0), mobilesubstrate`.

| Check | iOS 4.3.3 / 6.1.3 | iOS 7.1.2 |
|---|---|---|
| Install | Verified (1.0.1; 1.1.0 not installed) | Verified (1.1.0) |
| `status` / `lock` / `unlock` round-trip | Verified (1.0.1) | Verified (1.1.0 adapter) |
| Passcode refusal policy | Source/negative checks | Native simulated-passcode refusal verified; no passcode was configured/removed for this test |
| Daemon, listener or boot hook | None | None |

The CLI is a one-shot, root-operated diagnostic helper. The 1.1.0 adapter adds
iOS 7.x while keeping the exact-version checks for 4.3.3 and 6.1.3. It never
unlocks a device with a configured passcode.

## Known test limitations

- The home LAN could not reach the configured VPS endpoint directly (TCP and UDP
  timed out). A local UDP relay carried a full 1.2.1 engine handshake
  and 9/7 IP packets, proving the iOS 7 tunnel code path; the direct network path
  remains unlocalised and needs server-side capture.
- On iOS 7.1.2 the entitlement-signed launch helper now starts Apple-signed apps
  (`com.apple.mobilesafari` returned 0; Preferences returned 3 while already
  running). Later Cydia/Amnezia launch observations conflict across the icon-repair attempts; full GUI operation remains unverified. Absence of appinst does not establish why an already-present system app failed to launch. The two IPA installers really do require appinst/AppSync. `uicache` must run
  as mobile; the root run reports `cannot open cache file. incorrect user?`, so a
  small privilege-drop helper was used for the refresh.
- `https://cydia.akemi.ai/Packages.gz` timed out from the Mac (20 s, zero bytes),
  so the official AppSync/appinst dependencies could not be installed from here.
  This is a dependency-fetch limitation, not proof that the packages are
  incompatible with iOS 7.
- No supported game is installed on the mini 2, Veteris 4 is absent, and the
  LocalSend/Troubadour IPA installers were not executed. Their app workflows are
  therefore untested even though the packages and iOS 7 APIs were audited.
- The attempted screenshotr capture path lacked its Developer Disk Image/service. No visual capture was obtained; this does not prove every possible iOS7 screenshot method is unavailable. Process/log observations are not pixel verification.
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
