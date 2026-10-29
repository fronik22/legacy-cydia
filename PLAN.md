# Cydia repository / iOS7 work

1. Inventory distributable own packages and source/licenses; verify Senko removal, do not reinstall it.
2. Port/audit Amnezia6 networking, daemon, status hook, lifecycle, signing and app UI for iOS7.
3. Audit remaining tweaks/apps per OS/private API/architecture. Preserve legacy-only guards for fixes already native/not applicable on7; build targeted adapters where needed.
4. Build tested .deb packages, include source/licenses, create flat APT index/Release/checksums/depictions. Keep unsafe/unverified packages out of the iOS7 supported channel.
5. Test packages/index/upgrade/uninstall trust boundaries, run read-only device identification and targeted non-destructive runtime tests.
6. Create public GitHub repository and Pages endpoint, verify Cydia metadata/packages fetch and record exact supported versus untested matrix.

No publication of keys/configs/accounts/private assets. No blanket OS7 claim from compilation. Deployment must preserve current app data, settings and disabled HUD/logger state.

Status 2026-10-28: the manifest now has 11 packages; the iOS 7 builds 1.2.1,
0.1.10, 1.1.1, 0.2.2 and 1.1.0 were installed and checked on iPad4,5/7.1.2.
The local index validates. Remaining: publish the updated index after review;
install/reboot the iOS 7 timezone adapter; and finish app workflow tests for
LocalSend/Troubadour (blocked by missing AppSync/appinst), Veteris (host app),
Game FPS gameplay, and visual HUD/Settings UI.
