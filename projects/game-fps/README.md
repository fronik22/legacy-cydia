# Legacy Game FPS 0.2.0

Per-game Original/60 FPS controls for exact verified builds on armv7/iOS 6. Tested device: iPad2,2, iOS 6.1.3.

Settings → Legacy Game FPS:

| Game | Verified build | Control |
|---|---|---|
| WORMS 2: Armageddon | 1.25 | Original (~31 FPS) / 60 |
| WORMS 3 | 1.16 | Original / 60 |
| Minigore HD | 6.2 | Original / 60 |
| Minigore 2 | 1.4 | Original / 60 |
| Blastron | Existing Revival 0.1.10+ | Original / 30 / 60 |

Exact executable hashes: SUPPORTED-BUILDS.json. The installed Minigore is the HD edition; unverified iPhone editions/builds are not included. Blastron uses its existing preference/engine adapter; this package adds no second Unity hook.

Install the DEB and reopen supported games once. If Settings was already running, close only Settings through the app switcher and reopen it to refresh PreferenceLoader. Changes persist and apply live in supported games. Package defaults preserve original limits; requested profiles are explicitly enabled on the test device. No respring, VPN change or background daemon. Uninstall through Cydia and reopen supported games.

WORMS2 uses a native 32ms NSTimer on the test device. WORMS3 and both Minigores use CADisplayLink. The adapter changes only the verified game view's render pacing and restores its native request in Original mode. Minigore HD also derives its simulation step from a scene FPS value; its guarded native delta getter supplies1/60 when enabled and calls the original getter in Original mode, preventing a display-link-only2x speedup. Minigore2 also has a native scheduler gate: setting displayLink to60 alone only increases callbacks while actual frames remain30. Its exact-build, instruction-guarded target-FPS getter is overridden to60; the original scheduler still reads real time and supplies its native fixed-step delta. No executable/assets/saves are patched on disk.

Measurements count actual successful presentRenderbuffer calls, not just requested timer/display-link frequency or HUD refreshes. See TEST-RESULTS.json and WORKLOG.md for separate gameplay, menus/results, diagnostic and final-normal evidence. A results/tutorial screenshot is not evidence of combat performance.

60 is a target, not a guarantee in every scene. Higher CPU/GPU and battery use are expected. Minigore2's native fixed-step scheduler loses simulation time if it cannot sustain its requested rate; an effects/results window measured about52FPS and about0.87 seconds of simulation per wall second. This overload behavior is not repaired by the frame-cap adapter. Exhaustive trajectories, long sessions, multiplayer and other builds/devices are unverified. The display refreshes at60Hz; no uncapped mode is offered.

Logging stays inside each supported game's Library/Caches/LegacyGameFPS.jsonl, bounded to256KiB×2. It records policy/frame counts, not account tokens. Diagnostic-only native delta/stack hooks are excluded from the normal package. Normal native function hooks are limited to Minigore HD's verified delta getter and Minigore2's verified target-FPS getter. Original/private games, SDKs and device-access credentials are excluded from exports.

Build with an owned legacy-compatible SDK/linker/stubs and ldid:

```sh
python3 build.py GameFPS
python3 build.py Prefs
python3 package.py
python3 test_package.py
```

Do not set FPS_DIAGNOSTIC for a release build. Developer scripts reuse this workspace's guarded USB/SSH connector and are not portable access installers. Additional games require their own exact-build limiter, simulation-time and lifecycle validation; never apply systemwide timer/sleep hooks.
