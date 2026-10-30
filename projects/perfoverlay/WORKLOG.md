# PerfOverlay change log

## 2026-10-21 — rotation0.1.7 (Codex)

- Requested in the Blastron Codex chat, referring to the OpenCode project. Located and edited this original project in place. Existing NCSettings/measurement changes preserved; no Git commit/reset performed. Pre-change copies of touched files: build/rotation-before/.
- Original UIWindow/panel used fixed portrait coordinates. New HUDLayout.h maps logical top-left to fixed portrait screen coordinates; PerfOverlay stores the panel and rotates/repositions it for all4 interface orientations, animating changes over0.2s.
- Source: capability-checked SpringBoard activeInterfaceOrientation; statusBarOrientation fallback. Notifications: UIApplicationDidChangeStatusBarOrientationNotification + com.apple.backboardd.orientation, with main-thread delivery; existing1Hz visible sampler recovers missed notifications. No new polling timer, accelerometer sampling, app orientation change or app injection.
- Preserved panel size/margins, non-interactive window, global FPS source, CPU/RAM/GPU measurements and NCSettings preference/visibility behavior. Hidden HUD still stops its sampling as before.
- Verification: native macOS CoreGraphics test runs the actual transform helper on24 screen/orientation combinations, checks margins/dimensions/onscreen bounds and inverse mapping. armv7 minimum4.3 and arm64 minimum7.0 builds/signatures succeeded, NCSettings bundle rebuilt, old-dpkg-compatible package produced.
- Physical-device rotation remains unverified. No package installation, SpringBoard restart, launch or other iPad UI actions performed in this change: user is testing Blastron; package postinst explicitly resprings.
- Reference checks: Apple status-bar orientation notification documentation https://developer.apple.com/documentation/uikit/uiapplication/didchangestatusbarorientationnotification ; legacy SpringBoard selector/notification reference https://github.com/mringwal/mouse-support/blob/master/Tweak.xm . Geometry implementation is original, no third-party code copied.

## Installation —2026-10-21

User explicitly requested installation. Installed0.1.7 over0.1.6 on iPad2,2/iOS6.1.3. dpkg completed successfully; SpringBoard15493→15712. Installed dylib SHA256 matches the reviewed build. Native startup log reports HUD orientation1, visible=1, global FPS/CPU/RAM/GPU updates. Physical landscape rotation has not yet been exercised. Evidence: outputs/perfoverlay/0.1.7/installation-results.json and installed-startup.log.

## 2026-10-21 — settings0.1.8 / per-core CPU

- Preserved original project and existing NCSettings toggle. Snapshot before settings change: build/settings-before/. No reset/commit. Added a PreferenceLoader Settings.app bundle; existing target has PreferenceLoader2.2.6, no new downloads.
- Configuration persists in com.local.perfoverlay: Enabled, ShowFPS/CPU/Cores/RAM/GPU, Corner, FontSize, Opacity, Interval, BlastronFPS. Darwin notification applies changes live on the main thread; Blastron reads the same render target.
- host_processor_info now publishes each core and weighted aggregate tick deltas. CPU wraps handled with unsigned32-bit subtraction,64-bit sums. Invalid samples show unavailable, not stale readings. Disabled samplers skip work; hidden HUD retains existing no-sampling behavior. Unused display-link paused. No per-app GPU claim.
- Dynamic panel sizing with original rotation and four corners. Actual helpers pass CPU delta/wrap/zero/weighted tests and216 geometry cases. All preference keys/defaults/selector schemas and package binary payload equality verified. armv7/iOS4.3, arm64/iOS7.0 builds/signatures succeeded.
- Build iteration: resetting all core values to-1 made clang emit memset_pattern16 absent in the legacy link stubs. Replaced with invalidating the baseline/core count; no fake implementation or SDK dependency added. Rebuild passed.
- Installed0.1.8 on the explicitly authorized iPad2,2/iOS6.1.3, together with Blastron0.1.10; dpkg passed, installed HUD/settings dylibs match build bytes. Respring expected. Live settings/FPS tests follow below.

### Native corrections / verification

- Initial pane WAS BLANK, reported by user and screenshot001-settings.png. Specifier getter returned15 objects but did not populate inherited PSListController table model. Fixed via [super setSpecifiers:], confirmed native4 groups/11 table rows and visible pane005-settings-pane.png. Standalone read-only settings-check asserts table rows as well as values; previous count-only check missed this real issue. No unrelated Settings UI changes.
- Actual UI toggling ShowCores off removed CPU1/CPU2; mobile preference persisted false, HUD received notification; restoring on restored both rows. Bottom-right corner applied visually (008-bottom-right.png); restored original top-left. Settings changes needed no respring.
- First game FPS preference test failed: native app read60 while global mobile plist contained30. Sandboxed game CFPreferences resolved its container domain. Blastron reader changed to the explicit shared mobile preference file and re-reads on activation. After game-only restart PID16245, native before-1/requested30/after30 passed. Shared settings are not claimed working solely from plist contents.

- Final game preference test: Settings FPS30 selected visibly, new process read-1→30; selecting60 and reactivating read30→60 in the same game PID. Restored ShowCores=true, Corner=0, BlastronFPS=60. Final installed binaries equal build.
- Physical landscape HUD and corner placement verified in native screenshots; iOS4/iOS9 hardware still not tested for this settings release. Font/opacity/interval controls build/schema tested, not every UI combination.

## iOS7 audit /0.1.10 (2026-10-28)

The shared hook and Settings bundle contain armv7/iOS4.3 and arm64/iOS7 slices. NCSettings integration is explicitly limited to iOS5/6; iOS7 uses Settings > Performance HUD. New A7 GPU class AGXAccelerator is supported; absent or invalid counters report unavailable.

A real iPad mini2/iOS7.1.2 test exposed a fourfold RAM overstatement: a64bit task advertises16KiB task pages but HOST_VM_INFO counts4KiB kernel pages. The adapter resolves vm_kernel_page_size dynamically on7+, falling back to host_page_size on old systems. It rejects impossible totals instead of displaying invented512MiB or clamping. Native same-source test changed2293MiB/975.96MiB to576.64MiB/975.96MiB. Pure regression includes both page sizes, impossible totals and overflow. iOS6 armv7 regression still reports173.71MiB/502.98MiB with4KiB fallback and SGXDriver543.

Read-only native64 tests also verified2CPUcores, AGX GPU counter availability and the global render-server counter; the idle screen produced no counter delta, so this is no active-game FPS measurement. The actual universal preference bundle loads against iOS7 PSListController and required methods exist. HUD stayed OFF throughout. Pixel layout/rotation and live toggles on7 still require a coordinated enabled-UI test. No supported-game performance claim from these probes.

Tests: probe/test_package.py, probe/metric-policy-test.c, probe/cpu-test.c, probe/rotation-test.c. Optional nonpersistent native metrics probe: python3 probe/build-metrics.py arm64 (armv7 for legacy), then run the resulting own CLI over authenticated SSH. It does not create/show the HUD or write preferences; diagnostics use only an own temporary log.

## 2026-10-29 — iOS7 reported idle GPU/RAM investigation

Native exclusive-window A/B after coordinated reboot: Settings HUD ON28–33%
AGX/~1composited frame/s; repeat OFF0%/stationary frame counter. Home OFF
14–17%/~10fps, first ON20–23%/~11fps. Live HUD redraw produces the apparent
Settings idle GPU load; Home/compositor has additional foreground work.
No process GPU-time or power attribution claimed. Driver counters clear to0
when rendering stops; no percent arithmetic/display fix justified.

RAM~531MiB =335active+79inactive+117wired;444MiBfree, no pageout/purge growth.
0.1.10 page-size correction remains valid. Largest Settings RSS kernel82MiB,
SpringBoard79MiB, Preferences18MiB; shared RSS cannot exactly decompose global
VM queues. Short native windows do not establish battery draw/leak behavior.

README calls RAM an allocation estimate and documents observer overhead. No
product/package change or respring. Enabled=true restored, Home left unlocked
for coordinated QR test; own temporary binaries/log removed. Full sanitized
evidence/limits: notes/HUD-LOAD-DIAGNOSIS.md. Private raw and probe source kept
outside public repository at work/cydia-ios7-tweaks-20261028.

## Idle-render overhead follow-up — 2026-10-29

User requested lowering HUD observer cost and attributing RAM. Scoped0.1.11 candidate replaces full-screen transparent UIWindow with the exact rotated panel bounds, retains screen-coordinate placement and rotation, skips equal text/frame assignments. Metric formulas and user preferences unchanged. Pure rotation/corner tests now assert tight window equals prior physical panel rectangle. Native before/after measurement pending. Separate read-only VM64/process probe attributes anonymous/file-backed/wired queues; no memory purge or system-service disabling.

Tight-window candidate: native16geometry/touch cases passed after fixing test-directory write permissions and using actual UIKit orientation constants instead of guessed numeric values. Its SettingsGPUmean30.12% versus29.82% baseline at~1fps showed no reduction; discarded the geometry change. BackboarddCPU changed7.13→5.92% in short windows, insufficient evidence of a GPU fix. Final candidate retains original geometry and caps changed-text redraws toonce/5s only when the global counter indicates at mostHUD-own frame activity; active content/fallback retain configured cadence. Sampling remainsunchanged. Public11-case render policy self-check covers idle/active/first/reset/fallback/interval logic.

Final adaptive redraw native7.1.2 result: Settings globalframecadence0.993→0.192fps; mean driverGPU29.82→6.28%, periodicpeak46%. ActiveHome comparison completed; final HUDOFF/Home restored asfound. CPU/process/memory queues were observed without changing metric formulas or disabling services. Battery watts and realgameperformance not measured. Raw private/hud-render-20261029; public verification-idle-ios7.json and RAM note.

Final caller review found idle detection was tied to ShowFPS. Made global activity sampling independent of row visibility; native hidden-FPS check confirms valid global counter, absentFPSrow and idle cadence0.166fps. Only the in-memory row flag was changed for testing and restored; preferences remainasfound. Rebuilt/reinstalled final artifact, exact installed dylib/footer hashes match; owntemporaryfiles removed. One-shot diagnostic code was pinned for callback safety and becomes quiescent after completion until normal SpringBoardexit; no persistent hook/job/timer.

## Rejected throttling / causal investigation —2026-10-29

User explicitly rejected idle refresh reduction.0.1.12 removes the idle cap and restores the selected visible refresh interval everywhere, retaining only the harmless unchanged-text guard.0.1.11 was a workaround and is not accepted as a render-cost repair. Investigate sampler-only/static/redraw and existing-context/simple-overlay controls at equal cadence; do not claim a64bit/Metal rewrite solves unmeasured costs.

Finalindependentnative120sampletrace: same1HzHUDnon-OFFresidency.4973%wall; completedactivehist.6700%withboundarybias, allstatepartition/Machticksratios.99967–1.00036. NewGPUTime.h adapter usesonlyknownA7statechannel, validatedUID50164bit; actualSpringBoardtrace10samples retainsselected1s andnewsource,lastsettled.504%. Thiscorrectsmeasurement, doesnotclaimshaderbusy oroptimization. Initialnativearmv7probe returnedavailablefalse; newbackendthereforeexplicitlynotenabledin32bit/otherOS. A narrowownedlibSystemUnwind declaration fixesSDKexportgap, no dynamic_lookup. Sourcebuilderallowlist includesonlythreeownedminimal ABI declarations (notSDKfiles), makingcorrespondingsource complete.0.1.11throttledeleted.
