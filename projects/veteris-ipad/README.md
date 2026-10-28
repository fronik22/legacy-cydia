# Veteris Native iPad 1.1.0

Separate, removable jailbreak package for **Veteris version 4**. Enables a native iPad window and fixes the home screen, application lists, search/favorites rows, and download-row geometry. The existing detail screen and Settings then use their native UIKit sizing. Portrait orientation follows Veteris's original policy. Version1.1 also fixes the immediate suspension crash and restores the app's existing background-download behavior.

The original app omitted `UIDeviceFamily` and referenced a nonexistent iPad nib. It therefore ran in 320×480 iPhone compatibility mode. The package sets the family to `[1,2]`, selects the actual MainStoryboard, and uses an app-only Substrate library for remaining fixed-width layouts.

## Install/remove

Requires jailbroken iPad, Cydia Substrate, and `com.victorlobe.veteris` **version 4**. Package dependency range is iOS5–6; actual hardware testing was **iPad2,2, iOS6.1.3 (10B329)** only.

Install the DEB using a package manager, or `dpkg -i veteris-ipad_1.1.0_iphoneos-arm.deb`, then respring. Remove with Cydia or `dpkg -r local.codex.veteris-ipad`, then respring. Original metadata keys are saved under `/var/lib/veteris-ipad/` and restored on removal. If somebody changes those keys externally, removal refuses to overwrite their changes.

**Remove this package before upgrading Veteris beyond version 4.** Version pinning and the runtime version check deliberately avoid applying untested hooks to a different release. No app binary replacement, user-data deletion, Wi-Fi/proxy changes, daemon, polling timer or SpringBoard hooks.

Retina uses native UIKit point/pixel scaling. A 1536×2048 offscreen render and 768/1024-point row geometry passed on iPad2; this is not a physical iPad3/4 Retina test. iOS5, other iPad models, landscape, extended battery/stability tests, installation of third-party packages and every optional screen remain unverified. An owned test IPA completed in background with a matching SHA256; the native background-task expiration/foreground lifecycle also passed.

## Suspension crash and background behavior

On the tested iOS6.1.3 device, iOS terminated the original app with **0xdead10cc** on leaving it because the SGX OpenGL shader disk cache kept `com.apple.opengl/shaders.maps` locked. The tweak sets `SGX_MAX_SHADER_CACHE_SIZE=0` inside Veteris before graphics initialization. Inspection of this device's IMGSGX543GLDriver confirmed that zero follows the driver's own no-disk-cache branch. It does not disable GPU rendering or change system graphics settings.

Veteris4 already includes `YZBackgroundKeeper`, queue interruption/resume, and its own helper. This package reuses them; it adds no background service or timer. Active downloads can continue with the existing helper. Idle Veteris can suspend normally and keep its screen state. iOS may still terminate suspended apps under memory pressure; this is normal. No claim of unlimited background execution or reduced battery use is made. Disabling the disk shader cache may increase shader compilation at launch; performance/battery cost has not been benchmarked. Other GPUs/OS versions need validation.

## Build

macOS with Xcode's clang/ld-classic, an external compatible armv7 iOS SDK/import sysroot and ldid. Apple SDKs, generated Apple import stubs and private device data are not distributed here. Set `IOS_SDK`, `IOS_STUB` (compatible legacy import sysroot, or a suitable legacy SDK) and `IOS_LDID` to your local toolchain paths.

```sh
python3 build.py Setup
python3 build.py VeterisIPad
python3 package.py
```

`package_deb.py` is reused from our existing Legacy iPad Tools packager and preserves `./` archive paths for old dpkg compatibility. The installed setup executable has a non-mutating `--self-test`. Additional native inspection sources are provided in `tools/`; the workspace-specific USB harness and device credentials are excluded.

Own implementation/build sources are provided under COPYING. No Veteris application binaries or SDKs are included. Inspected upstream source: https://github.com/victorlobe/Veteris , commit `7e6edbd11d8c509f9a39536dc380824bd2af1db7`.
