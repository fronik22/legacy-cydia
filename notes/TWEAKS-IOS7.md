# iOS7 tweak audit — 2026-10-28

Owned projects only; no device firmware, account guard, GSAPort, saves, VPN profiles or user settings changed by this audit. Raw measurements remain outside the public source at work/cydia-ios7-tweaks-20261028.

| Package | Final artifact | Architecture / gate | Actual verification |
| --- | --- | --- | --- |
| Performance HUD0.1.10 | projects/perfoverlay/build/local.perfoverlay_0.1.10_iphoneos-arm.deb | Universal armv7/iOS4.3 +arm64/iOS7; firmware<10 | Same-source native iOS6/7 metrics, A7RAM bug fixed, arm64Settings loader; HUD remainedOFF |
| Power Logger1.1.1 | projects/power-logger/dist/local.legacypower_1.1.1_iphoneos-arm.deb | Universal daemon/Settings; iOS6–7 | Native32/64 own CPU calibration,96Btaskinfo/deltas, PMU/GPU readings, Settings loader; no recording enabled |
| Legacy Game FPS0.2.2 | projects/game-fps/dist/legacy-game-fps_0.2.2_iphoneos-arm.deb | Thinarmv7 exact-build game hook; universalSettings; iOS6–7 | Package/architecture/guard checks and real arm64Settings loader; four-game iOS7 gameplay remains unverified |

## Concrete iOS7 fixes and evidence

A7 has16KiB pages in arm64 tasks, but the kernel VM page counters on7.1.2 use4KiB. The formerHUD multiplied host_page_size by HOST_VM_INFO and displayed2293MiB used on a975.96MiB machine. The new dynamic vm_kernel_page_size adapter corrects the same native read to~576MiB and rejects impossible totals/overflow; iOS6 retains the4KiB fallback. No fixed512MiB fallback remains. Regression test covers the exact mismatched sizes.

Both samplers recognize AGXAccelerator and validate percentage bounds; idle native reading was0, not an unavailable fakezero. Global CARenderServer counter exists and is callable in nativearm64; idle count remained93107, so active FPS accuracy/rotation/visible HUD pixels are not claimed. NCSettings integration is restricted to5/6;7uses the universal Preferences pane.

Powerd validates its96byte PROC_PIDTASKINFO layout and return length; native32/64 task readings and own CPU busy tests give100.08%/99.95%, confirming Mach tick conversion. Native64 two-sample test returned85valid taskinfo records and84nonnull CPUdeltas, with kernel_task CPU intentionally unavailable. New --sample-pair is nonpersistent, leaves disabled recording and daemon untouched. A narrow libSystem memcpy/strcmp import declaration fixes the incomplete SDK; unrestricted dynamic_lookup was removed.

All three arm64 Settings bundles dlopen successfully against the actual iOS7 Preferences framework; PSListController loadSpecifiersFromPlistName:target: and setSpecifiers: exist, expected subclasses/specifiers methods exist. Probe does not instantiate controllers or change preferences; this is loader/ABI verification, not interactive pane verification.

## Tests / failed attempts

Default host/package tests and ASan/UBSan policy/math/store tests pass. Perfoverlay CPU and216rotation/placement cases pass; exact final payloads, architecture minima and GPLv3license files are checked. GameFPS guards keep native ARM instructions out of64bit processes. Existing6.1.3 GPU/CPU/RAM sampling regression passes.

Initial strict arm64Power link failed because the ownedSDK lacks memcpy/strcmp export declarations; dynamic_lookup temporarily used by the prior build was replaced with only those explicit standardABI declarations. A first local package assertion wrongly expected leading spaces in the GPLheading; corrected to exactCOPYING-byte identity, with no package-content change for that fixture failure.

Remaining: enabledHUD/rotation/Settings-toggle UI on7, actual four-game iOS7 presentation/simulation timing, unplugged PMU battery calibration and long-run battery/daemon lifecycle. Source compatibility and successful native samplers must not be described as all these tests passing.

Final package identities (parent integrates/publishes; this agent did not push or change installed packages):

- HUD0.1.10 SHA25624a2b7ee86bcad6da0962711c685a9bc25ec6c73463f140e4147540ad82103d5.
- Power1.1.1 SHA2560e7e5f0ab0d8a0c29d145b90937f3892835ff4836c18cc81a969db90c8d65c80.
- GameFPS0.2.2 SHA256c353dc8613a66f8edac75edaea88ae96c048e43ae0763f934cd26171c8d5ecc6.

Each project's verification-ios7.json records source/package hashes and sanitized native results. Temporary own probe executables/panes/logs were removed from both devices. iOS7Powerdaemon7862 and SpringBoard7805 remained unchanged during tests; HUD/Recording both remainedOFF. Settings loader checks did not instantiate/show controllers.
