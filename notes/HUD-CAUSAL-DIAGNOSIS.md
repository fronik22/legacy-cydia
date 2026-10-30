# HUD causal diagnosis —2026-10-29

User rejected the5s idle redraw workaround.0.1.12 is installed on iPad4,5/7.1.2 and restores the selected visible cadence; retains only unchanged-text avoidance. No firmware/profile/account change. CurrentGPU telemetry is not yet repaired.

## Equal-cadence controls

Private native SpringBoard harness tested11phases of12s, restored all UI state automatically, and reset the idle timer only for the bounded test. A separate10HzGPU-only observer recordedtimestamps/globalframes/rawstats; first3s and last0.5s ofeachphase excluded. Sampler-with-hidden-window and static-visible-HUD each produced0newframes/0AGX values. Full-rateHUD produced0.95fps; plain labels, tinytransparentwindow and pre-renderedbitmaps produced similar1fps statistics. Opaque/square controls changedrawnumbers modestly. A statusbar-context control was explicitlyskipped because no visible statusbarwindow was exposed inSpringBoard. Offfirstphase had1.79fps transientactivity and is not accepted as a clean idle baseline. Existing-app-label control laterproduced1.95fps ratherthan1, so it is not a matched-rate renderercomparison. No rendererrewrite benefit proved.

## Destructive counter reads — decisive result

Actualnativeback-to-back IORegistryEntryCreateCFProperty(PerformanceStatistics) calls:270retainedpairedsamples,53positivefirstvalues, all53 immediatelyzero onsecondread. FirstqueryCommandBufferRenderCountsum270, secondquerysum0. ExampleGPU30%,5renders→0%,0renders within~1ms. Occasionalworkarrivedbetweenreads. Thus thepropertyisconsumptive; point-read percentages and their arithmeticmeans depend on read cadence and competingobservers. Raw1Hz~30% versus10Hz~3–4% do not establish sustainedwall-time GPUusage or a10x physicalimprovement. Theprevious0.1.11 percentcomparison was not a calibratedGPU/battery saving. No new divisor or smoothing heuristic is accepted as a repair.

## Independent timing path

AGX exposes actual IOReport GPU Performance States, Active/Idle Time Histograms andEnergy. The standaloneIOReportlibrary is absent, but helperfunctions are exported through dyldcachedPowerlogCoreLoggers/PowerlogMain. ReaderABI, cleanup, actualunits, mobilepermission and busy-versus-powered semantics are beingvalidated before integration. Do not guess IOConnectselectors. MetalbeginswithiOS8 and currentSpringBoardHUDalreadyrunsarm64; no unsupportedMetal/64bitrewrite explanation. See notes/GPU-COUNTER-SEMANTICS.md.

## Evidence/limits

private/hud-causal-20261029 contains signedprobe/harnesssources, buildlogs,11phaseevents, raw10Hzstats andpairedreadings/summary. Initialdiagnosticlink omittedCoreGraphics forCGPointZero; addingthecorrectframeworkfixedit. Allproductcodewasrebuilt/signedforarmv7+arm64, exact0.1.12packagecheckpassed. Instrumentation is testonly, not packaged. PhysicalGPUbusytime/cumulativecountervalidation remains inprogress.
