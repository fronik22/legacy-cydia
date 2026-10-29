# Legacy Cydia — 2026-10-29

Public source: https://fronik22.github.io/legacy-cydia/
GitHub: https://github.com/fronik22/legacy-cydia

## Published baseline

Artifact commit5b1f655 contains13active packages and13corresponding source archives. GitHub Pages build completed. Live Packages/Packages.gz/Release, every DEB and depiction, and the public source manifest were fetched over HTTPS and matched local bytes/hashes. Detailed local verification receipt is private/published-verification-20261029.json. Git working tree was clean after the artifact commit.

The obsolete direct LocalSend0.5.7 entry was withdrawn to prevent duplicate bundle IDs with the current5.7.4340IPA installer. Existing installed data is not automatically removed. Source archives include vendor/ThirdParty and license inputs; no Apple SDK, original game executable, private profile, account or device dump is published. Senko and the retired Wi-Fi recovery service are excluded.

## Reviewed Freebuff work

Read the exact chat “Jailbreak для iPad 2 в Codex”. Its records cover mini2 package updates and backed-up icon cleanup, including a device-specific DefaultIconState edit. It did not commit/push its11-package catalog. This pass completed publication and corrected inaccurate dependency/OS/license claims; no iPad was modified during this review. See notes/FREEBUFF-REVIEW.md and WORKLOG.md.

## Remaining before full iOS7 support can be claimed

- LocalSend/Troubadour IPA install, upgrade/data preservation and real app workflows. Official appinst/AppSync are dependencies; appinst DEB remains unavailable locally. An official AppSync116binary/source is cached privately, not silently republished.
- Veteris7UI/background and real sessions of the four FPS-supported games. HUD/Power native sampling and Settings loading were tested; visible HUD/rotation and unplugged PMU behavior remain unchecked.
- Amnezia1.2.1engine completed iOS7UTUN handshake/HTTP/DNS through a temporary opaque relay; direct endpoint timeout remains unlocalised. Do not infer its cause from that comparison or equate engine evidence with GUI launch. IPv6 leak protection/kill switch are absent.
- Timezone2026e-2 is installed on mini2/7.1.2: install/removal/reinstall/reboot,600managed-file checks and155 date/region cases in both armv7/arm64 consumers passed. Stable catalog is promoted to2; no timezone daemon.
- The three iOS4-only helpers intentionally refuse7: libc++ is already native there, and the old decode/Photos hooks must not be forced onto a different OS path.

## Continue safely

English, brief results. iPad mini2/iOS7is the write target for future authorized tests; do not change iPad2/iOS6. Confirm exact connected identity before any device operation. Preserve existing iCloud/account hooks and settings from other work. Do not redo source recovery or icon cleanup. Read SUPPORT.md and notes/*-IOS7.md for evidence; historical audit notes retain their original package counts.

Regenerate: python3 repo/build_repo.py; validate: python3 repo/validate_repo.py. Source checks additionally live in repo/build_sources.py; historical archive-generation inputs are separate from rebuilding supplied corresponding source. No firmware update/restore, app-data deletion or install is required to validate the published repository.

## Current fixes — 2026-10-29

Timezone completed as above. HUD0.1.10 controlled native A/B proves Settings28–33% GPU driver snapshot is caused by live HUD redraw (~1fps), OFF returns0%. Home OFF still~10fps/14–17%; exactHomeanimation unresolved. RAM531MiB including79inactive,444free; no pageout growth in shorttests. No metric formula/version change justified; see notes/HUD-LOAD-DIAGNOSIS.md. Amnezia1.3.0 is installed: native camera callbacks/lifecycle and four-part CMSampleBuffer replay through the actual packaged app reach review successfully. Optical animated sender screen remains untested. See notes/ANIMATED-QR.md. iPad2 untouched.

Current release artifacts: Amnezia1.3.0 SHA2561bca33f1f5946d963f8c25b5699769703a5ff1d683a9d534408db43119d43084; Timezone2026e-2 SHA2565afe90572e06eaa9e1603d1cb86dcd4c85fdf78c5d86e83f4e17aeed74f30270. Final root verification covers native camera navigation/lifecycle, real packaged callback replay to review, unchanged profile hashes, clean app relaunch and removed diagnostic helpers. A synchronous navigation test initially read before UIKit completed its transition; delayed assertion passes without a product change. Signed app bundle matches installed bytes. Allhosttests, package checks and clean extracted corresponding-source hosttests pass. Source kits/catalog refreshed and13-package validator passes. Live publication receipt will be private/published-verification-20261029-fixes.json.

## HUD/RAM follow-up —2026-10-29

HUD0.1.11 installed on mini2/7.1.2. Original geometry retained; tight-window experiment discarded after noGPU improvement. Changed text only, idle redraw caponce/5s while sampling continues at configured interval; active content retains normal refresh. Native Settings frames0.993→0.192/s, mean driverGPU29.82→6.28%, periodicpeak46%; Home active10.055fps.11-case policy self-check/package tests pass. Final installed dylib and Settings metadata match package; restored as-foundHUDOFF/Home and removed all ownprobes. Raw private/hud-render-20261029; verification-idle-ios7.json. GPU percentages are driver snapshots, no calibrated watts/peak capacity. New behavior on otherOS hardware/game sessions remains untested.

RAM native VM64 identity reconciles548.41MiB as177.56anonymous+256.35occupiedfile-backed+114.50wired,427.12free. LargestRSS SpringBoard80/kernel80/Settings18MiB; no500MiB process. VPNdaemon0.31MiB, PowerLogger1.61MiB. Cached iOS6 same-formula174MiB on a different512MiB iPad2 is not a controlled OS comparison. See notes/RAM-IOS7-ATTRIBUTION.md. No service disabled or memory purged; no iOS6 device operation.
