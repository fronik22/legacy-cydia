# Cydia repository / iOS7 work

1. Inventory distributable own packages and source/licenses; verify Senko removal, do not reinstall it.
2. Port/audit Amnezia6 networking, daemon, status hook, lifecycle, signing and app UI for iOS7.
3. Audit remaining tweaks/apps per OS/private API/architecture. Preserve legacy-only guards for fixes already native/not applicable on7; build targeted adapters where needed.
4. Build tested .deb packages, include source/licenses, create flat APT index/Release/checksums/depictions. Keep unsafe/unverified packages out of the iOS7 supported channel.
5. Test packages/index/upgrade/uninstall trust boundaries, run read-only device identification and targeted non-destructive runtime tests.
6. Create public GitHub repository and Pages endpoint, verify Cydia metadata/packages fetch and record exact supported versus untested matrix.

No publication of keys/configs/accounts/private assets. No blanket OS7 claim from compilation. Deployment must preserve current app data, settings and disabled HUD/logger state.

Status 2026-10-28: repo generator, manifest and validator are in place; nine
packages are staged under `repo/incoming/` and rendered into `docs/`. Remaining:
publish GitHub Pages, verify the source from the iPads, and finish iOS 7 runtime
audits for Game FPS, Veteris and LocalSend.
