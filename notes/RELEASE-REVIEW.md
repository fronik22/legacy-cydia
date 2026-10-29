# Release review — 2026-10-29

Read-only host/package audit. No device install, removal, respring, feature enable,
profile change or iPad 2 operation. Only this note was authored by this reviewer.

## Required corrections before publication

1. `SUPPORT.md`, Veteris paragraph reverses the guard: it says
   `SGX_MAX_SHADER_CACHE_SIZE=0` is set only on iOS 7. Actual
   `src/VersionPolicy.h` / `VeterisIPad.m` apply this workaround only on iOS 6;
   iOS 7 receives layout hooks and skips the SGX workaround.
2. `README.md` and generated landing-page template in `repo/build_repo.py`
   promise incompatible packages are hidden by firmware Depends. Depends is an
   installation constraint; describe refusal of unsupported installs without
   promising Cydia visibility behavior.
3. README/SUPPORT attribute all fake-signed launch failures to absence of
   AppSync **and appinst**. appinst is the IPA installation command and a real
   dependency of the two IPA wrappers; it is not a demonstrated prerequisite
   for launching an already-present `/Applications` app. Preserve the observed
   helper failure, mark its cause unproven, and keep UI launch/transfer/playback
   untested. Engine traffic proves the isolated engine path, not app UI launch.
4. Both LocalSend delivery paths share `com.unlocalsend.ios6`. Wrapper preinst
   rejects an existing direct `/Applications/LocalSend6.app`; the direct 0.5.7
   DEB has no scripts or Conflicts and permits the reverse order after IPA
   installation. Prevent that order or withdraw the old direct package from
   the active catalog; document manual migration while both remain offered.

## Current archive inventory

All DEBs declare `Architecture: iphoneos-arm`. `arm64` below describes payload
slices, not the Debian architecture. Every manifest ID matches archive control;
all 11 incoming DEBs are byte-identical to their generated public copies.

| Package | Version / firmware | Architecture and installer findings |
|---|---|---|
| Amnezia6 | 1.2.1 / >=4.3,<8 | App/daemon/CLI armv7; status hook armv7+arm64. preinst checks firmware before stopping old processes; existing profile retained, daemon idles until start. |
| Performance Overlay | 0.1.10 / >=4.3,<10 | Hook+Settings armv7+arm64; legacy NCSettings toggle armv7 and guarded to iOS5/6. Install/remove resprings; no enabled user preferences shipped. |
| Power Logger | 1.1.1 / >=6,<8 | Daemon+Settings armv7+arm64. Scoped daemon lifecycle; recordings/preferences retained. Default-OFF payload check passes. |
| Legacy Game FPS | 0.2.2 / >=6,<8 | Game hook armv7, Settings universal; runtime OS6/7 plus exact bundle/version/hash guards. No maintainer scripts/respring. |
| Veteris Native iPad | 1.2.0 / >=5,<8 | armv7 hook+setup; pins Veteris4 and checks bundle/version before metadata changes. Setup/removal preserves metadata; user must respring. iOS7 layout untested. |
| LocalSend direct | 0.5.7 / >=6, no cap | armv7 `/Applications` app; no scripts, no automatic uicache, no reverse-order duplicate prevention. data.tar.lzma; legacy device install evidence exists, not a new format failure. |
| LocalSend IPA installer | 5.7.4340 / >=5,<8 | armv7 IPA MinimumOSVersion4.3; wrapper deliberately narrower. Depends official appinst>=2.0+AppSync; OS/path preflight, appinst once, errors propagate, removal retains app/data. |
| Troubadour IPA installer | 1.6.447 / >=5,<8 | Same wrapper behavior; armv7 IPA MinimumOSVersion4.3. appinst/install/launch/playback not newly tested. |
| Blastron Revival | 0.1.15 / >=6,<7 | armv7 hook+setup; legacy cap retained. Reversible apply/remove helper; no original game payload found in package checks. |
| Legacy Timezone | 2026e-1 / >=4.3,<7, gsc.armv7 | armv7 apply/check, backed-up restore on removal; requests reboot through Cydia protocol. Catalog remains 2026e-1; staged 2026e-2 is not an installed/public release. |
| Device Access | 1.1.0 / >=4.3,<8 | armv7 CLI+universal one-shot dylib; no maintainer scripts/daemon. Runtime accepts exact4.3.3/6.1.3 or7; iOS7 method signatures and passcode state checked, unknown signatures refused. Existing status/lock/unlock evidence is not repeated here. |

All own-package maintainer scripts pass `/bin/sh -n`. All archive member paths
inspected are relative without `..` components. These checks do not execute
installation scripts or establish runtime compatibility.

## Verification run

- `python3 repo/validate_repo.py`: PASS, 11 packages / 11 DEBs; Packages.gz,
  index sizes/hashes, Release checksums, local depiction/icon targets agree.
- Amnezia `make test` and `tests/test_package.py` on exact1.2.1 DEB: PASS.
  Includes private socket ownership/failure cleanup, profile migration/rollback,
  protocol bounds, retries, DNS failure, route rollback and atomic saves.
- HUD `probe/test_package.py`: PASS; exact universal payload and min OS slices.
- Power `test_package.py`, `test_analyze.py`: PASS; exact payload, defaultOFF,
  signed-current/charging, CPU integration and sampling-gap handling.
- FPS `test_package.py`: PASS,2 tests; source/settings profiles, hash scope,
  exact binary identity, hook armv7 and Settings universal.
- IPA `packaging/test_installer.py`: PASS,7 tests; OS gate, existing-app refusal,
  one invocation/failure propagation, retention and malformed IPA rejection.
- Fresh host clang/assert checks: PASS for Power platform/math/store, HUD metric
  policy, FPS OS policy and Veteris version policy.

## Official dependencies retained privately

Present in `private/official-dependencies/`, excluded from public distribution:

- AppSync116.0 rootful DEB,51,658bytes; SHA256
  `0036f28fcbdb165d4f58968a237ca9fe7b6ed33fea25b9a5eb1fc141f6bf5a09`.
  Filename records upstream commit235aca6cddfbdc9fa87fcb5b2aec2df37ed6d65a.
  Control supports firmware>=5.0,<=18.2 and substrate>=0.9.5100. Own dylibs
  and binary maintainer actions contain armv7/arm64 slices. Not installed.
- AppSync GPLv3 source archive,46,612bytes; SHA256
  `c11056f408540caaf9b8d64ac8e922d91bc74b01ce11ceffa9f05b67a0537ccb`.
  Extracted source contains appinst2.1.1, its control/Makefile and GPL notice.
- No official **appinst DEB** exists in that directory. Source alone does not
  satisfy installed IPA wrapper dependencies. Its Makefile also needs external
  Theos/libzip.a; no unverified private dependency build was attempted here.

These are checks of retained local artifacts, not a fresh upstream signature,
origin or availability verification. Do not publish private archives or keys.

## Failed attempts and limits

- Initial generic archive inspector assumed `data.tar.gz` and stopped at old
  LocalSend's `data.tar.lzma`; rerun selected actual tar member and completed.
- Initial AppSync inspector assumed textual maintainer scripts; its actions are
  fat Mach-O binaries, so decoding stopped. Rerun classified slices safely.
- One host-policy command with shell `rm -rf` cleanup was rejected by automatic
  command review. Python TemporaryDirectory replacement completed all checks.
- No device UI, real IPA upgrade/container persistence, game session, enabled
  HUD, logger battery run, timezone install/reboot/restore, dependency install,
  or publication tested by this reviewer. Reuse existing per-device evidence;
  do not turn host passes into feature verification claims.

## Parent integration after this review

The four publication corrections above have been applied. The obsolete direct LocalSend package was withdrawn, matching source archives were added, and the three original iOS4-only helpers brought the active catalog to13packages. This note retains the original11-package audit snapshot; the final validator checks the current catalog and source hashes. No new device test is implied by the catalog update.
