# Legacy Cydia — 2026-10-29

Public source: https://fronik22.github.io/legacy-cydia/
GitHub: https://github.com/fronik22/legacy-cydia

## Published result

Artifact commit5b1f655 contains13active packages and13corresponding source archives. GitHub Pages build completed. Live Packages/Packages.gz/Release, every DEB and depiction, and the public source manifest were fetched over HTTPS and matched local bytes/hashes. Detailed local verification receipt is private/published-verification-20261029.json. Git working tree was clean after the artifact commit.

The obsolete direct LocalSend0.5.7 entry was withdrawn to prevent duplicate bundle IDs with the current5.7.4340IPA installer. Existing installed data is not automatically removed. Source archives include vendor/ThirdParty and license inputs; no Apple SDK, original game executable, private profile, account or device dump is published. Senko and the retired Wi-Fi recovery service are excluded.

## Reviewed Freebuff work

Read the exact chat “Jailbreak для iPad 2 в Codex”. Its records cover mini2 package updates and backed-up icon cleanup, including a device-specific DefaultIconState edit. It did not commit/push its11-package catalog. This pass completed publication and corrected inaccurate dependency/OS/license claims; no iPad was modified during this review. See notes/FREEBUFF-REVIEW.md and WORKLOG.md.

## Remaining before full iOS7 support can be claimed

- LocalSend/Troubadour IPA install, upgrade/data preservation and real app workflows. Official appinst/AppSync are dependencies; appinst DEB remains unavailable locally. An official AppSync116binary/source is cached privately, not silently republished.
- Veteris7UI/background and real sessions of the four FPS-supported games. HUD/Power native sampling and Settings loading were tested; visible HUD/rotation and unplugged PMU behavior remain unchecked.
- Amnezia1.2.1engine completed iOS7UTUN handshake/HTTP/DNS through a temporary opaque relay; direct endpoint timeout remains unlocalised. Do not infer its cause from that comparison or equate engine evidence with GUI launch. IPv6 leak protection/kill switch are absent.
- Timezone2026e-2ICU51 preview passed read-only/staged native checks and preserved2882unrelated resources, but system install/reboot/rollback on7remain untested. Stable APT stays2026e-1for4–6; preview is separately downloadable.
- The three iOS4-only helpers intentionally refuse7: libc++ is already native there, and the old decode/Photos hooks must not be forced onto a different OS path.

## Continue safely

English, brief results. iPad mini2/iOS7is the write target for future authorized tests; do not change iPad2/iOS6. Confirm exact connected identity before any device operation. Preserve existing iCloud/account hooks and settings from other work. Do not redo source recovery or icon cleanup. Read SUPPORT.md and notes/*-IOS7.md for evidence; historical audit notes retain their original package counts.

Regenerate: python3 repo/build_repo.py; validate: python3 repo/validate_repo.py. Source checks additionally live in repo/build_sources.py; historical archive-generation inputs are separate from rebuilding supplied corresponding source. No firmware update/restore, app-data deletion or install is required to validate the published repository.
