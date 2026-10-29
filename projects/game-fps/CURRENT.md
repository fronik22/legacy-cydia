# Current audit —0.2.2

Hook remains exact-build armv7, Settings is universal and loads natively on iOS7.1.2. Four-game iOS7 timing is unverified; earlier iOS6 gameplay results below remain separate. New package includes GPLv3COPYING and no preferences reset. See README.md final audit and package tests.

# Current state — 2026-10-22

Legacy Game FPS **0.2.0** is installed on iPad2,2 / iOS6.1.3. WORMS3, Minigore HD and Minigore2 profiles are explicitly enabled at60FPS. Existing WORMS2/Blastron preferences are retained. Package defaults preserve Original for new installations. Firmware support remains armv7/iOS6.

Implemented and verified:

- WORMS3 build1.16: native CADisplayLink interval2→1. Same-PID active match and menu Original/60/Original/60 measurements: roughly30→60→30→60 actual successful presents/s.
- Minigore HD build6.2: display-link pacing plus native delta getter0x222ad. Original scene step derives from its FPS; return1/60 only while enabled so render changes do not create a2x simulation speedup. Matched diagnostic in-level movement:30.00FPS /999.8ms simulation per wallsecond →60.17FPS /1002.8ms. Menu Original can already be60FPS. Diagnostic observers are excluded from final normal build.
- Minigore2 build1.4: display-link pacing alone was insufficient (callbacks60, actual frames30). Native scheduler0x125481 uses engine target getter0x785a1; guarded override returns60, Original calls the real getter. Final normal combat capture shows live enemies/fire/hearts and59.98/59.45 actual presents/s. Native fixed-step simulation can lose time when overloaded; effects/results windows measured~52FPS/~0.87 simulation seconds per wallsecond. This limitation remains.
- Both native adapters require matching bundle/version/executable SHA256 and expected initial instruction bytes. Exact supported hashes: SUPPORTED-BUILDS.json. No original game executable/assets are changed on disk.
- Settings bundle model:5values /6groups /5rows; round-trips passed. Settings-only restart is required after installing while Settings was already running. Final actual pane is visually verified: all5 game controls, all showing60FPS. See observations/extension-settings-opened.png.

Final normal dylib SHA256:70f8d8485f0af2f7df31c1e2a352e022bc73e6f762489f9962ed9b145d2e6be2.
DEB SHA256:0ab3cab5c1a04dd210951188392b1bc81fa5ad4925f68cf76452110093afbbb5.
Installed bytes match the build; no diagnostic stack/native-delta observation hooks remain. The normal native limiter/delta adapters are intentional.

Evidence index:

- TEST-RESULTS.json: scene-labelled measurements and final installation identity.
- WORKLOG.md: actions, failed hypotheses and outcomes, including incorrectly labelled early AFK/menu probes.
- observations/minigore-combat-timing-phases.json: actual supplied simulation delta at Original/60.
- observations/minigore2-normal-combat-events.jsonl + minigore2-long-retry-combat.png: normal combat proof.
- observations/extension-install.json: installed hashes, enabled profiles and process audit.
- original.private/: owned binaries, cached metadata/disassembly and targeted scheduler/clock analysis; excluded from distributions.

Preservation audit: SpringBoard146 and Amnezia app3939/daemon3806 unchanged. Senko daemon changed from4859 to5209 during the task for an unestablished reason; no task command restarted it, and the current daemon was left running. No respring was performed.

Input lessons: Minigore Play needs a short tap; Minigore2 Retry worked reliably with stationary long touch. Foregrounding can present a delayed pause menu. Do not label tutorial/difficulty/results frames as combat. Device policy timestamps, not host time, delimit measurement windows. Use actual Mach-O __TEXT vmaddr when reading ASLR-adjusted memory; the two Minigore binaries differ.

Remaining limits: no exhaustive trajectories, long-session, multiplayer or other-build/device guarantees. Higher frame rates increase power use. No uncapped rendering mode; this iPad display is60Hz. Previous WORMS2 validation is retained in observations/previous-release-validation.json and the0.1.0 export. Future profiles require their own limiter, timing and lifecycle evidence.

Final Settings automation must reproduce UIKit’s willSelectRow→selectRow→didSelectRow pipeline; didSelect alone selected the root row without changing the detail pane. Unlock immediately before UI work. The native helper is developer-only, one-shot and removed from the device; no new service remains. Final temporary-path cleanup passed.
