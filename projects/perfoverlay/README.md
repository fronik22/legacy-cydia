# PerfOverlay

A small, non-interactive performance HUD for jailbroken iOS 4–9 devices.
It is a Cydia Substrate dylib injected into SpringBoard and drawn in a
transparent `UIWindow` above the status bar. On iOS 5/6 the package also
installs a NCSettings toggle named **HUD**.

```
FPS  40
CPU  24%
RAM  148/502M
GPU3D  9%
```

## Metrics

| Row | Source | Meaning |
| --- | --- | --- |
| `FPS` | `CARenderServerGetFrameCounter` in QuartzCore | Frames actually composited by the render server. `FPS idle` means fewer than 1 frame/s. |
| `CPU` | `host_processor_info(PROCESSOR_CPU_LOAD_INFO)` | Total non-idle CPU time across all cores. |
| `RAM` | `host_statistics(HOST_VM_INFO)` + `hw.memsize` | Active + inactive + wired pages, divided by physical memory. |
| `GPU3D` | IOKit PowerVR `PerformanceStatistics` | 3D-core utilization (`Device Utilization %`, with renderer/tiler fallbacks). This is **not** the video decoder. |

The FPS counter is a global render-server counter, not a `CADisplayLink`
tick. A display link can only tell you that the display refresh callback
ran; it cannot tell you whether the compositor produced a new frame. The
display-link path exists only as a fallback when the global counter cannot
be opened. A transient zero from the global counter never switches modes.

## Verified configurations

| Device | OS | Package | Result |
| --- | --- | --- | --- |
| iPad 2,1 (`iPad2,1`) | iOS 4.3.3 (`8J2`) | 0.1.5 | armv7 overlay; left on the original installation |
| iPad 2,2 (`iPad2,2`) | iOS 6.1.3 (`10B329`) | 0.1.6 | `src=global`, live CPU/RAM/`GPU3D`, NCSettings HUD |

Both devices have 512 MB RAM and a 2 × 1 GHz A5. The arm64 slice is
build-verified only; no iOS 9 hardware was available.

## Requirements

- Jailbroken device with Cydia Substrate (MobileSubstrate)
- iOS 4.3 or newer for the armv7 slice; iOS 7.0 or newer for arm64
- `dpkg` for installation
- Optional: NCSettings on iOS 5/6 for the HUD toggle

## NCSettings toggle

The package installs the toggle at:

```
/var/mobile/Library/NCSettings/Toggles/PerfOverlay/Toggle.dylib
```

On first load, the SpringBoard tweak adds `PerfOverlay` once to the front of
NCSettings' `Visible` list and writes `NCSettingsRegistered=true` to
`com.local.perfoverlay`. If the user later removes HUD from NCSettings, it
is not added back on the next respring or upgrade. If NCSettings is not
installed, the tweak does nothing; if NCSettings exists but its `Visible`
list has not been created yet, registration is retried on the next launch.

Tapping the HUD toggle writes `Enabled` in `com.local.perfoverlay` and posts
`com.local.perfoverlay.toggle.on` / `.off`. SpringBoard updates the overlay
immediately, and the state survives a respring. The toggle starts enabled
when the preference is absent.

Theme icons are installed under both `PerfOverlay/` and `HUD/` for the
Default and Blue NCSettings themes:

- Default: opaque white when on, white at about 30% alpha when off.
- Blue: light-blue gradient when on, neutral grey when off.

`python3 ncsettings/make_icons.py` regenerates the theme PNGs from the
Default glyph mask.

NCSettings exists only on iOS 5/6. On iOS 4 and iOS 9 there is no equivalent
NCSettings control; the overlay preference can still be changed manually.
On a system without `defaults`, edit
`/var/mobile/Library/Preferences/com.local.perfoverlay.plist` and respring.

## Build

The build uses an iOS 9.3 SDK with an armv7 compatibility sysroot, plus a
local arm64 SDK overlay that supplies the missing `liblaunch.tbd` stub.

```sh
cd perfoverlay
python3 build.py
python3 package.py
```

Environment overrides:

- `IOS4_SDK` — path to the iOS SDK (default `~/Documents/work/iPhoneOS9.3.sdk`)
- `IOS4_STUB` — armv7 import-stub sysroot
- `IOS4_LDID` — path to `ldid`

The resulting packages are written to `build/local.perfoverlay_<version>_iphoneos-arm.deb`.

## Install

```sh
scp -P 22644 build/local.perfoverlay_0.1.8_iphoneos-arm.deb \
  root@127.0.0.1:/tmp/
ssh -p 22644 root@127.0.0.1 \
  'dpkg -i /tmp/local.perfoverlay_0.1.8_iphoneos-arm.deb'
```

Use the SSH port for the target device (for example, `22643` for the old
iPad and `22644` for the iOS 6 iPad). The package `postinst` restarts
SpringBoard. To remove:

```sh
ssh -p 22644 root@127.0.0.1 'dpkg -r local.perfoverlay'
```

## Diagnostics

The tweak appends one line per second to `/tmp/perfoverlay.log`:

```
loaded into com.apple.springboard pid=...
NCSettings registration check: bundle=1
NCSettings registration marker=1
global frame counter ready=1 sym=... kr=0 port=...
started pid=... screen=768x1024 windowLevel=...
tick fps=40.0 src=global cpu=24.0 ram=148/502 gpu=9
```

The NCSettings toggle logs to `/tmp/perf-toggle.log`. `src=global` is the
expected FPS mode. `src=displaylink` means the global counter could not be
opened; it will show the display refresh rate, not the composited frame
rate. NCSettings stores its toggle list and theme in
`/var/mobile/Library/Preferences/com.jamied360.ncsettings.plist`.

## Limitations

- SpringBoard only. The overlay does not inject into individual apps.
- The GPU row measures the PowerVR 3D core. H.264/HLS video playback can
  use the dedicated video decoder and display pipeline while `GPU3D` stays
  at 0%. This is expected and does not mean the GPU is unused.
- `GPU3D` is unavailable on hardware/drivers that do not expose
  `PerformanceStatistics`; the row then shows `n/a`.
- RAM is a system-wide allocation estimate, not an exact per-process figure.
  It includes reclaimable inactive pages.
- NCSettings is available only on iOS5/6. Settings > Performance HUD
  provides the master visibility switch on all supported systems. iOS 9 hardware was not available, so the arm64 slice and the
  iOS 9 GPU service path are build-verified only.
- The FPS display-link fallback measures refresh cadence, not game frames;
  use the global counter or the game's own Update samples for performance proof.

## Rotation (0.1.7)

The HUD follows the foreground interface in portrait, upside-down portrait,
and both landscape directions, keeping its existing10pt/30pt upper-left
margins and142×78pt size. Rotation uses SpringBoard's capability-checked
`activeInterfaceOrientation`, with `statusBarOrientation` as a fallback;
it does not enable the accelerometer or rotate portrait-only apps.

Status-bar and backboard orientation notifications update it immediately;
the existing one-second sampler also catches missed/older-system notifications.
Showing HUD after it was hidden refreshes orientation before display.

Build/geometry verified on macOS for armv7/iOS4.3 and arm64/iOS7.0;
physical rotation on iOS4/6/9 has not yet been checked for0.1.7.
Installing the package restarts SpringBoard, so finish any active game first.

Geometry self-check:

```sh
xcrun clang -Wall -Wextra -Werror probe/rotation-test.c -framework CoreGraphics -o build/rotation-test
build/rotation-test
```

## Configurable HUD (0.1.8)

Settings > Performance HUD (installed PreferenceLoader required): master visibility,
FPS, system average CPU, per-core CPU, RAM, GPU3D, four corners, font10–16,
background25/55/80%, sampling0.5/1/2s. Changes apply live and persist.
CPU1/CPU2 are physical-core load, each0–100%; aggregate CPU is weighted
across available core tick deltas, also0–100%. No app-specific CPU claim.
Hidden HUD stops sampling; disabled CPU/RAM/GPU rows skip those samplers.
The extra display link is paused when global FPS works or FPS is disabled.
Rotation remains enabled. HUD is non-interactive.

Blastron target Original/30/60 requires Blastron Revival0.1.10+. Only rendering
target changes. The original target is captured on first game Update and can
be restored. Simulation timing/physics are unchanged. This is not a universal
FPS unlock for other apps. A60 target does not guarantee sustained60.

Self-checks: probe/cpu-test.c (wrap/deltas/aggregate), probe/rotation-test.c
(24 original +192 corner/size cases). Both architecture slices and the
preference bundle build; native verification is recorded in WORKLOG.md.

## iOS7 audit /0.1.10 (2026-10-28)

The shared hook and Settings bundle contain armv7/iOS4.3 and arm64/iOS7 slices. NCSettings integration is explicitly limited to iOS5/6; iOS7 uses Settings > Performance HUD. New A7 GPU class AGXAccelerator is supported; absent or invalid counters report unavailable.

A real iPad mini2/iOS7.1.2 test exposed a fourfold RAM overstatement: a64bit task advertises16KiB task pages but HOST_VM_INFO counts4KiB kernel pages. The adapter resolves vm_kernel_page_size dynamically on7+, falling back to host_page_size on old systems. It rejects impossible totals instead of displaying invented512MiB or clamping. Native same-source test changed2293MiB/975.96MiB to576.64MiB/975.96MiB. Pure regression includes both page sizes, impossible totals and overflow. iOS6 armv7 regression still reports173.71MiB/502.98MiB with4KiB fallback and SGXDriver543.

Read-only native64 tests also verified2CPUcores, AGX GPU counter availability and the global render-server counter; the idle screen produced no counter delta, so this is no active-game FPS measurement. The actual universal preference bundle loads against iOS7 PSListController and required methods exist. HUD stayed OFF throughout. Pixel layout/rotation and live toggles on7 still require a coordinated enabled-UI test. No supported-game performance claim from these probes.

Tests: probe/test_package.py, probe/metric-policy-test.c, probe/cpu-test.c, probe/rotation-test.c. Optional nonpersistent native metrics probe: python3 probe/build-metrics.py arm64 (armv7 for legacy), then run the resulting own CLI over authenticated SSH. It does not create/show the HUD or write preferences; diagnostics use only an own temporary log.

## iOS7 idle-load diagnosis (2026-10-29)

A native read-only A/B on iPad mini2/iOS7.1.2 confirmed the GPU percentage is
the AGX driver value, not a cumulative counter mistakenly formatted as a percent.
With HUD hidden, idle Settings settled at0% with no new render-server frames.
Showing HUD produced28–33% and approximately1 frame/s; hiding it again returned
to0% and stationary frames. The live HUD's own redraws therefore account for
the apparent Settings idle load. These driver percentages are not calibrated
power readings or percentages of maximum-frequency GPU performance.

Home itself continued compositing at10 frames/s with HUD hidden (14–17%);
showing HUD raised this to approximately11 frames/s (20–23% in the first run).
This establishes foreground Home/compositor work, without identifying a
specific Home animation or assigning private per-process GPU time.

After reboot the native RAM read was approximately531MiB:335MiB active,79MiB
inactive and117MiB wired;444MiB was free. No pageout or purge growth occurred
in these short windows. Earlier576MiB and the reported~600MiB include system
allocations and reclaimable inactive pages; they do not imply one app owns
600MiB or that memory pressure is high. Process RSS overlaps shared memory
and must not be summed as an exact decomposition. Detailed results and limits:
[HUD load diagnosis](../../notes/HUD-LOAD-DIAGNOSIS.md).

## Idle redraw optimization —0.1.11

A changed-text guard and global-frame-counter idle policy stop the HUD from sustaining a1Hz compositing loop on otherwise static screens. Global activity detection also runs when the FPS row is hidden. Sampling continues at the configured interval; only visible text redraws are capped toonce/5s while global frame activity is no greater than the HUD's own expected cadence. Active content and display-link fallback retain configured refresh. Unchanged text is never reassigned. Settings/toggle restart clears the draw timestamp. Geometry, metrics and preferences are unchanged. A live overlay necessarily causes occasional rendering; this is not a zero-GPU guarantee.

Native7.1.2 Settings comparison: global frames0.993→0.192/s and mean AGX driver snapshot29.82→6.28%, with brief peaks up to46%. ActiveHome remains at the measured normal cadence (see verification-idle-ios7.json). This is a short driver/frame measurement, not calibrated peak GPU capacity, battery watts or a game benchmark. HUD restored toas-foundOFF. A tight-window experiment did not reduceGPU and was discarded.

Self-check: `clang -Wall -Wextra -Werror probe/render-policy-test.c -o /tmp/hud-render-test && /tmp/hud-render-test`. Eleven assertions cover initial/idle/active/fallback/reset/interval behavior. Exact final package is checked with probe/test_package.py. iOS4–6/8–9 hardware execution of this change remains untested.
