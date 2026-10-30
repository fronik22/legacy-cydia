# Legacy Cydia repository

Public APT repository for jailbroken 32-bit and early 64-bit iOS devices. It
contains only packages built in this project; third-party dependencies, original
games, SDKs, signing keys, device dumps and account configuration are not
published here.

**Cydia source URL**

```
https://fronik22.github.io/legacy-cydia/
```

Add it in Cydia under **Sources → Edit → Add**, then refresh. The same files are
also served from the `docs/` directory of this repository.

## Packages

| Package | Version | Declared firmware | iOS 7 status |
|---|---|---|---|
| `com.mak.amnezia6` — Amnezia6 | 1.3.3 | 4.3 – 7.x | Animated QR import confirmed on iOS7; DNS templates and AWG3.1 keepalive ranges fixed |
| `local.perfoverlay` — Performance Overlay | 0.1.12 | 4.3 – 9.x | Selectedrefresh restored; iOS7A7 cumulative GPU on~0.5% at1Hz, qualifieddriverfallback elsewhere |
| `local.legacypower` — Power Logger | 1.1.1 | 6.0 – 7.x | Installed, launchd daemon and native arm64 sampling; recording off |
| `local.legacy-game-fps` — Legacy Game FPS | 0.2.2 | 6.0 – 7.x | Installed and Settings bundle loads; **no iOS 7 game session** |
| `local.codex.veteris-ipad` — Veteris Native iPad | 1.2.0 | 5.0 – 7.x | **Untested on iOS 7**; Veteris 4 is not installed on the test device |
| `local.codex.localsend-installer` — LocalSend (IPA Installer) | 5.7.4340 | 5.0 – 7.x | **Install not run on iOS 7**; needs official appinst + AppSync |
| `local.codex.troubadour-installer` — Troubadour (IPA Installer) | 1.6.447 | 5.0 – 7.x | **Install not run on iOS 7**; needs official appinst + AppSync |
| `local.codex.blastron-revival` — Blastron Revival | 0.1.15 | 6.0 – 6.x | Legacy-only; intentionally capped below 7.0 |
| `local.codex.legacy-timezone` — Legacy Timezone Update | 2026e-2 | 4.3 – 7.x | Install/removal/reinstall/reboot and native32/64 date conversions verified on7.1.2 |
| `local.codex.device-access` — Legacy Device Access | 1.1.0 | 4.3 – 7.x | Verified on 7.1.2 for status, lock and unlock; passcode refused |
| Legacy C++ Runtime | 1.0.0 | 4.3.x only | iOS7 has its own runtime; do not replace it |
| Legacy 1080p60 Timing Fix | 1.0.0 | iPad2 / 4.3.3 only | Decoder-specific workaround; not applicable to7 without a reproduced regression |
| LocalSend Photos Without Location | 1.0.0 | 4.3.3 only | iOS6/7 use native photo permission handling |

The exact `Depends` line in each package is authoritative. An incompatible firmware dependency prevents installation; it does not guarantee that Cydia hides the package. The two IPA installer packages
also depend on `ai.akemi.appinst` and `ai.akemi.appsyncunified`; add Karen's
official source <https://cydia.akemi.ai/> before installing them. The test iPad
mini 2 did not have those dependencies, so their app workflows remain untested.

### Support levels

- **Verified** — installed from this repository and exercised on a real device
  of that OS version. The evidence and remaining limits are listed in
  [SUPPORT.md](SUPPORT.md).
- **Installed / loaded** — the package installs, its binaries run and the hook
  or daemon survives; the full user-visible feature has not been exercised.
- **Untested** — the package compiles and declares the range, but no runtime
  evidence exists for that OS version. Do not treat it as supported.
- **Legacy-only** — the package deliberately refuses newer firmware because its
  installer or hooks depend on an exact OS layout.

No package is claimed to support iOS 7 merely because it compiles. Runtime
evidence is recorded per package in [SUPPORT.md](SUPPORT.md) and in each
package's depiction page.

## Tested devices

| Device | Model | Firmware | Role |
|---|---|---|---|
| iPad 2 (GSM) | `iPad2,2` | 6.1.3 (10B329) | Primary legacy device; all iOS 6 claims |
| iPad mini 2 | `iPad4,5` | 7.1.2 (11D257) | iOS 7 / arm64 checks |

Package upgrades preserve existing app data/profiles and disabled monitor preferences. The separate mini2 icon repair changed its backed-up layout; no icon repair is part of these packages. The repository does not change firmware or install Senko/the retired Wi-Fi monitor.

## iOS 7 architecture notes

- `iPad4,5` runs a 64-bit SpringBoard. Any SpringBoard hook therefore needs an
  `arm64` slice. Amnezia6's status hook and Performance Overlay ship universal
  `armv7 + arm64` dylibs.
- Amnezia6's app, daemon and CLI stay `armv7` and run under the 32-bit runtime
  on iOS 7. This is intentional: the networking code and the UTUN/route/DNS
  paths were validated on the 32-bit runtime.
- The LocalSend/Troubadour **IPA installer packages** require appinst and AppSync. This dependency does not establish the cause of an Amnezia6 launch failure: its direct system-app package follows a different path. The1.3.0 app launched as mobile and passed native scanner/review workflow tests on7.1.2; optical sender scanning and full tunnel GUI workflows remain unverified.
- Power Logger ships a universal daemon and preference bundle.
- Preferences, daemons and launchd plists keep the same paths on both systems,
  so an upgrade from the iOS 6 packages preserves configuration.
- Legacy-only packages keep their existing `< 7.0` caps. Widening a cap without
  an adapter and a device test would be a false support claim.

## Install without Cydia

```sh
scp com.mak.amnezia6_1.2.1_iphoneos-arm.deb root@device:/var/tmp/
ssh root@device 'dpkg -i /var/tmp/com.mak.amnezia6_1.2.1_iphoneos-arm.deb'
```

Use `dpkg -r <package>` to remove. Amnezia6 keeps its profile at
`/var/mobile/Library/Preferences/Amnezia6/amnezia6.conf`; the package scripts do
not overwrite an existing profile. Existing disabled HUD/logger preferences are preserved; Power Logger recording defaults to **off**. Check the HUD master switch before use.

## Build from source

Each project has its own build instructions. The common requirements are macOS,
Xcode command-line tools, an external legacy iPhoneOS SDK/import sysroot, and
`ldid`. Apple SDKs, generated stubs and device data are not redistributed.

| Project | Build entry point |
|---|---|
| `projects/amnezia6` | `make device app deb` (see its `README.md`) |
| `projects/perfoverlay` | `python3 build.py && python3 package.py` |
| `projects/power-logger` | `python3 build.py && python3 package.py` |
| `projects/game-fps` | `python3 package.py` after building `build/GameFPS.dylib` |
| `projects/veteris-ipad` | `python3 build.py VeterisIPad && python3 package.py` |
| `projects/localsend` | see `projects/localsend/README.md` |
| `projects/troubadour` | see `projects/troubadour/CYDIA-INSTALLER.md` |
| `projects/device-access` | `python3 build.py && python3 package.py` |

Rebuild the repository index after replacing any `.deb` in `repo/incoming/`:

```sh
python3 repo/build_repo.py
```

The generator reads `repo/packages.json`, copies the packages to `docs/debs/`,
writes `Packages`, `Packages.gz`, `Release` with MD5/SHA256 checksums, and
generates the landing page and depictions. It does not need `dpkg-deb` or
`apt-ftparchive`.

## Repository layout

```
docs/                 GitHub Pages root (generated)
repo/build_repo.py    flat APT index generator
repo/packages.json    package manifest and support notes
repo/incoming/        source .deb files copied into docs/debs/
projects/             source trees for packages that can be published
private/              local-only secrets and runtime dumps (gitignored)
```

## Privacy and licensing

Repository tooling uses GNU GPLv3 (LICENSE); project and data licenses remain independent as listed below.

- No credentials, VPN profiles, private keys, account configuration, device
  dumps, Apple SDKs or original game assets are committed.
- Corresponding source archives include required vendor/ThirdParty sources and licenses; see [source archives](source-archives/README.md). Original game binaries, Apple SDKs and the device's complete ICU file are excluded. Blastron's own hook source is distributable; its address table does not justify withholding GPL source.
- Amnezia6 is GPL-2.0; Device Access, Blastron, HUD, Power Logger, Game FPS, Veteris and the app ports use GPL-3.0. Timezone tooling is 0BSD, with IANA/Unicode data licenses; the C++ runtime retains LLVM notices.
- The obsolete direct LocalSend 0.5.7 package has been withdrawn from the active index to prevent duplicate app bundle IDs with the current IPA installer. Existing installed apps/data are not removed automatically. Export data before manually migrating a direct system-app installation.
- iOS 4-only runtime, video timing and photo gate packages remain available with their strict original firmware guards; their hooks must not be forced onto iOS 7.
- Timezone2026e-2 is now stable: native7.1.2 install/removal/reinstall/reboot checks and155 date/region cases in both32/64-bit consumers pass.
- This repository is not affiliated with Apple, SaurikIT, Cydia or any game
  publisher.

## Links

- Support matrix and evidence: [SUPPORT.md](SUPPORT.md)
- Issue tracker: <https://github.com/fronik22/legacy-cydia/issues>
