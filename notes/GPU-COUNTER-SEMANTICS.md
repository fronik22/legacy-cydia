# GPU counter semantics — iPad mini2 / iOS7.1.2

2026-10-29. Read-only review of saved measurements and primary Apple documentation. No device/UI/code changes. This note does not endorse the rejected idle-refresh cap as a rendering fix.

## Update: live calibration supersedes the old percentage averages

Root's subsequent paired reads prove that the published iOS7 PerformanceStatistics values are destructive/shared samples: all53positive first reads immediately becamezero on the second read; rendercount270→0. Root evidence: private/hud-causal-20261029/pair-summary.json. Polling at10Hz gives a much smaller arithmetic mean without changing the1HzHUD. Therefore the earlier29.8→6.3mean snapshot comparison cannot be claimed as a calibrated reduction of sustained GPUbusytime, nor can arbitrary poll-rate averaging repair this dictionary. It is valid evidence of changed snapshot/read/presentation behavior only.

## What is established

The shipped overlay already has an arm64 slice, loaded into the A7 SpringBoard. Rewriting it merely to become64bit would not change that architecture. Apple introduced Metal in the iOS8 SDK; it is unavailable on the target7.1.2. A Metal rewrite therefore cannot be the iOS7 solution. [Apple iOS8 SDK announcement](https://www.apple.com/newsroom/2014/06/02Apple-Releases-iOS-8-SDK-With-Over-4-000-New-APIs/).

Apple's OpenGL ES tools describe Tiler as geometry processing, Renderer as pixel/fragment processing, and Device as combined GPU use. The tools separately expose GPU frame time. These definitions do not disclose the exact averaging window, timer denominator, clock/DVFS treatment or property-refresh/reset behavior of this iOS7 AGX IORegistry dictionary. A field named Device Utilization percent alone cannot establish milliseconds of wall-time GPU busy or percent of maximum GPU performance. [Apple OpenGL ES Tools Overview](https://developer.apple.com/library/archive/documentation/3DDrawing/Conceptual/OpenGLES_ProgrammingGuide/ToolsOverview/ToolsOverview.html).

No public primary AGX implementation or device-specific counter-window contract was found in this bounded search. Modern M-series third-party IOReport implementations are not evidence that the same channels/API exist on A7/iOS7. Do not import those denominators or GPU-frequency assumptions.

## Saved evidence, not new device tests

Host analysis of private/hud-render-20261029 and ../work/cydia-ios7-tweaks-20261028. Main retained windows discard their first3records; ~1.007s observer spacing.

| Window | Compositor frames/s | Mean driverDevice% | Driver renders/sample | Mean gartMapIn/sample |
| --- | ---: | ---: | --- | ---: |
| Original Settings HUDON |0.993 |29.82 |5 |13.34MB |
| Tight-window Settings HUDON |0.993 |30.12 |5 |13.02MB |
| ActiveHome HUDON |10.055 |19.76 |7–9 |0.179MB |
| Rejected adaptive Settings |0.192 |6.28 |0–20 |2.506MB |
| Adaptive, FPS row hidden |0.166 |6.08 |0–20 |2.328MB |

Five driver-counted renders per presented HUD frame are a useful lead for extra compositor passes, not a demonstrated mapping from each count to a particular offscreen pass. The approximately13MB mapping activity resembles one full2048x1536x4 framebuffer (12.58MB), despite the tiny HUD window. GART mappings are not proven physical copies, texture upload bandwidth or GPU-duration measurements. Home's tenfold higher presentation rate with lowerGPU% and far lower mapping count also shows why frame count alone is insufficient to assign a rendering cost.

Some OFF-window records contain later activity, so not every OFF file is a pristine zero baseline for its entire duration. In new-settings-off, the first stopped-frame interval isGPU0 and renders0, but later6presentation increments occur in the retained window; the saved file cannot identify who produced those later frames. Do not silently discard them or brand that whole file idle. The older dedicated settings-off-2 comparison remains the documented settled zero baseline.

Raw textureCount is negative and decreases across some OFF samples. It cannot be treated as a valid absolute number of live textures. Available fields do not include a directly validated accumulated GPU nanoseconds counter.

## Highest-value next tests at unchanged refresh

1. Keep HUD content/update rate fixed at the user's selected interval. Phase-jitter a GPU-only observer, recording mach timestamps, read duration, raw Device/Renderer/Tiler fields, driver render/mapping fields and the independent compositor counter. Compare1Hz versus5/20Hz observer polling in repeated matched windows. The existing HUD also reads the same dictionary: whether reads refresh/reset shared per-sample statistics must be tested, not assumed. Avoid the full process/RAM walk at every high-frequency sample.
2. Hold cadence fixed while substituting one component at a time: static text, changing text, plain opaque rectangle, alpha background, border/corners, existing separate UIWindow versus an existing compositor layer. Measure submission/pass/mapping deltas and CPU alongside the unmodified driver fields. A tiny window has already failed to reduce this cost; repeating that geometry experiment without a new variable is low value.
3. Obtain independent GPU-duration evidence through an available compatible OpenGL ES/Core Animation Instruments timeline, or a validated cumulative busy/residency channel if this exact driver exposes one. Validate any channel's units and monotonically accumulating behavior on known idle and known rendering intervals before deriving a wall-time percentage. Do not infer time from GPU%×seconds without the missing window contract.
4. If a specific blend/offscreen/format-conversion path is identified, change that path and repeat at exactly the original refresh. A lower query/display rate is not acceptance evidence for the requested fix.

Apple's Core Animation guidance recommends measuring a baseline and using opaque backing where it truly removes blending. Marking a layer opaque does not remove alpha from an image assigned directly to its contents. [Apple Core Animation performance guide](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CoreAnimation_guide/ImprovingAnimationPerformance/ImprovingAnimationPerformance.html).

Apple's2014 render-pipeline material distinguishes view/string drawing from render-server/GPU work, and identifies extra passes from masks, rasterization updates and group opacity. These are test candidates, not proof that the HUD currently uses blur or any particular expensive effect. The existing source uses a UILabel and translucent panel; UIVisualEffectView blur is not established here. [Apple WWDC2014 Session419 slides](https://devstreaming-cdn.apple.com/videos/wwdc/2014/419xxli6f60a6bs/419/419_advanced_graphics_and_animation_performance.pdf?dl=1).

## Verification limits

No live measurements, driver disassembly, power/DVFS calibration, Instruments capture or rewrite occurred in this subtask. Exact AGX denominator/reset/window semantics remain unresolved. The strongest current actionable evidence is extra driver renders and large mapping activity in the compositor path at a fixed1HzHUD presentation rate, with no improvement from shrinking the window.

## Native independent IOReport discovery and reader

The parent authorized bounded read-only discovery/subscription tests on the exact mini2; no UI/settings changes by this agent. The first discovery scanned746 IOServiceentries, below4096cap, reading only legends/known namedproperties. AGXAcceleratorG3_B0 publishes IOReport GPU Energy,7 GPU Performance States,11 DVD Request States,54bucket Active Time Histogram,54bucket Idle Time Histogram and a debugBEcount. IOReportHub is present with IOUserClientClass IOReportUserClient.

One fullAGXpropertiesread was performed only in a parent-approved gap between measurements. It also exposed InternalStatisticsAccm and PerformanceStatisticsAccum, but their current dictionaries do not expose an explicit validated cumulative GPUbusy nanoseconds field. No further full/PerformanceStatistics reads were made.

Standalone /usr/lib/libIOReport.dylib and privateIOReport.framework both fail actual dlopen; not merely filesystem checks. A bounded primary-format dyld-cache metadata scan found700 arm64images and701 armv7simages, with no standaloneIOReport image. [Apple dyld239.4 cache format](https://raw.githubusercontent.com/apple-oss-distributions/dyld/dyld-239.4/launch-cache/dyld_cache_format.h) was used for validated header/image-path offsets; no instructions were disassembled or full cache copied. Actualcached PowerlogCoreLoggers.framework and PowerlogMain.framework load and expose/reexport IOReportCopyAllChannels/CreateSubscription/CreateSamples/CreateSamplesDelta/StateGetResidency and related helpers. NoPowerLog agent or recording session was instantiated.

A bounded original C/Objective-C reader dynamically calls the real helpers through PowerlogCoreLoggers. Core subscription/sample/iterate/refcleanup ABI follows [Apple PowerManagement494.30.1 pmset.c](https://raw.githubusercontent.com/apple-oss-distributions/PowerManagement/PowerManagement-494.30.1/pmset/pmset.c); histogram getter return/count types are also confirmed in [Apple currentpmset.m](https://raw.githubusercontent.com/apple-oss-distributions/PowerManagement/main/pmset/pmset.m). There are no guessed IOConnect selectors. Only four known AGXchannels are selected. @finally CFReleases subscription,subscribedchannels,desiredchannels,matchingdictionary; boundedcount/duration,signalstop and processMach-port teardown prevent a persistent subscription.

The native root3sample and UID5013sample tests both succeed. Mobile test uses the existing RunasMobile helper, not a rootdaemon or entitlement escalation. The states are OFF,VLOW,VNOM,VMAX,VLOWINT,VNOMINT,VMAXINT. In the idlemobile run, OFF advances48,218,921ticks versus48,222,802Mach ticks over2.0093seconds (ratio0.99992); all otherstates remainconstant. Rootrun ratio0.99994. This directly validates state-residency partition timing against the actual125/3nsMach timebase. Powered/non-OFF residency remains distinct from actual shaderbusytime.

Both histograms return54buckets with hits/min/max/sum. Idlecounters in the fully idle3sample run remainconstant despite OFFresidency advancing: an ongoing idleperiod has not yet completed, so histogram deltas require controlled transitions and boundary analysis. GPUenergy modelcounter18947 remainsconstant. No Joule/watt conversion is established. IOReportChannelGetUnit returnsUINT64_MAX, explicitlyinvalid, in these sampleobjects; do not label it as a valid unit. The registrylegend itself carries unit72058115876454424 for GPUstate/active/idle, identical across thosechannels, and216173314689728512 for energy. Counterconversion beyond the validated state/Mach identity remains pending the parent's controlledON/OFF samples.

Matching [Apple XNU2422 IOReportTypes](https://raw.githubusercontent.com/apple-oss-distributions/xnu/xnu-2422.1.72/iokit/IOKit/IOReportTypes.h) defines local-timebase stateupticks and histogramhits/min/max/sum fields. Decoding the legendchannel type by that packed layout matches state7elements and histogram54elements; this is metadata validation, not proof that a particular activehistogram equals all physical GPUwork.

Private evidence/source/build: private/gpu-counter-semantics/{registry*.plist,cache-library-hub.plist,metadata-probe.m,ioreport-reader.m,idle-root.jsonl,idle-mobile.jsonl}. Root andmobile reader runs have no stderr and return0. Temporary registry/metadataexecutables were removed; the bounded /var/tmp/codex-gpu-ioreport-reader is temporarily left by explicitcoordination for the parent's controlledtests, and should be removed afterward. Initial metadata link lacked SDKstub memchr; equivalent boundedstrnlen test fixes the diagnostic. Reader block-array capture was moved to static storage; the tested existing narrow _Unwind_Resume libSystem declaration resolves the SDK's incomplete export stub. No unrestricteddynamiclookup or device configuration change.
