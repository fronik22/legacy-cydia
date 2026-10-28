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
| `com.mak.amnezia6` — Amnezia6 | 1.2.0 | 4.3 – 7.x | Installed and runtime-checked on 7.1.2; tunnel handshake not retested |
| `local.perfoverlay` — Performance Overlay | 0.1.9 | 4.3 – 9.x | Universal hook loaded on 7.1.2; SpringBoard stable |
| `local.legacypower` — Power Logger | 1.1.0 | 6.0 – 7.x | Universal daemon started by launchd on 7.1.2; logging stays off by default |
| `local.legacy-game-fps` — Legacy Game FPS | 0.2.1 | 6.0 – 7.x | **Untested on iOS 7**; verified on 6.1.3 only |
| `local.codex.veteris-ipad` — Veteris Native iPad | 1.2.0 | 5.0 – 7.x | **Untested on iOS 7**; 1.2.0 adds an iOS 7 shader-cache guard |
| `com.unlocalsend.ios6` — LocalSend 6 | 0.5.7 | 6.0+ | **Untested on iOS 7**; verified on 6.1.3 only |
| `local.codex.blastron-revival` — Blastron Revival | 0.1.15 | 6.0 – 6.x | Legacy-only; intentionally capped below 7.0 |
| `local.codex.legacy-timezone` — Legacy Timezone Update | 2026e-1 | 4.3 – 6.x | Legacy-only; the installer validates the iOS 6 ICU layout and refuses iOS 7 |
| `local.codex.device-access` — Legacy Device Access | 1.0.1 | 4.3 – 6.x | Legacy-only; runtime accepts exactly 4.3.3 and 6.1.3 |

The exact `Depends` line in each package is authoritative. Cydia hides a package
when the installed firmware does not satisfy it.

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

Both devices keep their existing apps, profiles, saves and settings. The
repository does not change firmware and does not install Senko or the Wi-Fi
monitoring service.

## iOS 7 architecture notes

- `iPad4,5` runs a 64-bit SpringBoard. Any SpringBoard hook therefore needs an
  `arm64` slice. Amnezia6's status hook and Performance Overlay ship universal
  `armv7 + arm64` dylibs.
- Amnezia6's app, daemon and CLI stay `armv7` and run under the 32-bit runtime
  on iOS 7. This is intentional: the networking code and the UTUN/route/DNS
  paths were validated on the 32-bit runtime.
- Power Logger ships a universal daemon and preference bundle.
- Preferences, daemons and launchd plists keep the same paths on both systems,
  so an upgrade from the iOS 6 packages preserves configuration.
- Legacy-only packages keep their existing `< 7.0` caps. Widening a cap without
  an adapter and a device test would be a false support claim.

## Install without Cydia

```sh
scp com.mak.amnezia6_1.2.0_iphoneos-arm.deb root@device:/var/tmp/
ssh root@device 'dpkg -i /var/tmp/com.mak.amnezia6_1.2.0_iphoneos-arm.deb'
```

Use `dpkg -r <package>` to remove. Amnezia6 keeps its profile at
`/var/mobile/Library/Preferences/Amnezia6/amnezia6.conf`; the package scripts do
not overwrite an existing profile. Power Logger and Performance Overlay default
to **off**.

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

- No credentials, VPN profiles, private keys, account configuration, device
  dumps, Apple SDKs or original game assets are committed.
- Blastron Revival and Legacy Timezone Update are distributed as binary-only
  legacy packages because their build inputs contain game-derived addresses and
  Apple ICU data that cannot be published. Their depiction pages say so.
- Source licenses are kept next to each project. Amnezia6 is GPL-2.0 and
  includes the upstream Monocypher and Senko notices; Senko itself is not
  installed or reintroduced as a service.
- This repository is not affiliated with Apple, SaurikIT, Cydia or any game
  publisher.

## Links

- Support matrix and evidence: [SUPPORT.md](SUPPORT.md)
- Issue tracker: <https://github.com/fronik22/legacy-cydia/issues>
