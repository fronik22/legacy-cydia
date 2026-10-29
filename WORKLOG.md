# Actions / findings

2026-10-28: user requests addable GitHub-hosted Cydia repo containing our work, with iOS7-specific support. Existing account fronik22 authenticated. Current iOS6 inventory and old released sources reused. Senko is excluded permanently. Scope includes apps/tweaks, not republishing third-party dependency packages or original games.

2026-10-28 repo build: created flat APT generator (`repo/build_repo.py`), manifest
(`repo/packages.json`), validator (`repo/validate_repo.py`) and nine package
entries. Rebuilt Amnezia6 1.2.0 (armv7 app/daemon/CLI + universal arm64 status
hook), Performance Overlay 0.1.9, Power Logger 1.1.0, Game FPS 0.2.1 and Veteris
1.2.0. Imported Device Access source under `projects/device-access`; Blastron and
Legacy Timezone stay binary-only because their build inputs contain game-derived
addresses and Apple ICU data. `docs/` now has Packages, Packages.gz, Release,
checksums, depictions, icons and nine debs.

Device checks: Amnezia6 1.2.0 installed on iPad4,5/7.1.2; daemon started, utun0
and route installed, status/stop work. Handshake stayed `connecting`; both iPads
cannot reach the configured VPS endpoint from the test LAN, while the same
profile handshakes from the Mac. Performance Overlay 0.1.9 universal hook loaded and SpringBoard
survived respawn. Power Logger 1.1.0 arm64 daemon started under launchd and wrote
status.json. iOS 7 app launch and screenshots remain blocked (SBSLaunch returns 9
for every app; no iOS 7 Developer Disk Image). Game FPS, Veteris and LocalSend
remain unverified on iOS 7 despite their declared ranges.

Local validation: `python3 repo/validate_repo.py` passes; Packages.gz matches
Packages byte-for-byte; Release MD5/SHA256 entries match all nine debs; local HTTP
fetch of Packages, Release, a deb and a depiction succeeds. Scrubbed the real VPS
endpoint and a device UDID from public test/worklog text; live profiles and
private runtime dumps stay under ignored `private/`.

2026-10-28 iOS 7 continuation (the Codex chat stopped at 15:44 MSK on a usage
limit while the parent agent was testing packages):

- Installed on iPad4,5 / 7.1.2 with `dpkg -i`, all exit 0: Amnezia6 1.2.1 over
  1.2.0, Performance Overlay 0.1.10 over 0.1.9, Power Logger 1.1.1 over 1.1.0,
  Legacy Game FPS 0.2.2. Device Access 1.1.0 was already installed; rechecked.
- Runtime: Amnezia6 daemon 9179 idle, `/var/tmp/amnezia6d.sock` is `srw-rw----
  root:mobile` (0660), profile stays 941 bytes with its 14:49 mtime; Power daemon
  9101 writes status.json version 1.1.1 with `enabled:false`; HUD preference stays
  `Enabled:false`; SpringBoard respawned to 9229 and no SpringBoard/Amnezia crash
  report appeared. Game FPS 0.2.2 and all three arm64 Settings bundles are in
  place. Device Access 1.1.0 returns `locked=true`, `passcodeProtected=false`.
- App-launch path: the entitlement-signed Launch helper starts Apple apps
  (Safari exit 0; Preferences exit 3 while already running). Amnezia6 returns 3
  and no `UIKitApplication` appears. A privilege-drop helper ran `uicache` as
  mobile (exit 0) after root reported `cannot open cache file. incorrect user?`,
  but the fake-signed app still does not start. AppSync Unified/appinst are not
  installed and `https://cydia.akemi.ai/Packages.gz` timed out from the Mac
  (20 s, zero bytes), so the dependency could not be installed. This blocks app
  UI/workflow tests; it is not an app or package crash.
- Repo: manifest now has 11 packages with 1.2.1/0.1.10/1.1.1/0.2.2/1.1.0 builds
  and the two IPA installers. `python3 repo/build_repo.py` and
  `python3 repo/validate_repo.py` pass (11 debs, checksums and depictions match).
  The installers are explicitly `install not run`; the iOS 7 timezone 2026e-2
  adapter remains unpublished; LocalSend 6 is marked iOS 7-untested. No commit
  or push was made, so the live Pages index still shows the earlier nine.
- Remaining: iOS 7 install/reboot test for timezone 2026e-2; LocalSend and
  Troubadour IPA install/launch/transfer; Veteris 4 host app; Game FPS gameplay;
  visual HUD/Settings UI; direct Amnezia endpoint capture; publish the updated
  repo after review.

2026-10-28 device icon cleanup (user reported missing Cydia/Amnezia icons and
stale "Waiting" apps):

- Read-only inspection found 16 `IsPlaceholder` entries in
  `com.apple.mobile.installation.plist` (Bioshock, SilverBullet, IB2/IB3, Orc,
  Dead Space, Wild Blood, Dungeon Hunter 2, Gangstar, PoP, Shadowgun, Implosion,
  Godfire, Horn, Devil May Cry 4, Resident Evil 4); eight were still on page 2 of
  `IconState.plist`. `downloads.28.sqlitedb` had zero download/state/asset rows,
  so these were stale placeholders, not active transfers.
- Backed up `IconState.plist` and the installation cache to
  `*.bak-20261028-1935`. Removed the 16 placeholder IDs from both files, added
  `com.saurik.Cydia` and `com.mak.amnezia6` to page 1, kept the five real user
  apps (SixGuns, Asphalt 8, gladiator2, StarWarfare2, Pangu ipa1), and ran
  `sbreload` (SpringBoard 9229 -> 9991).
- Verified after respring: cache has 5 user apps and 0 placeholders; icon pages
  are 18/6; Cydia and Amnezia6 are present; no placeholder IDs remain. After
  unlocking (the earlier launch failures were only because the device was
  locked), `SBSLaunchApplicationWithIdentifier` returned 0 and both appeared as
  `UIKitApplication` processes (Cydia 10167, Amnezia6 10192) with no crash
  report; a second Cydia launch (10326) stayed alive for the 10 s check. The old
  `cydia://` web clip titled Cydia remains on page 2 as a fallback; it was not
  deleted.

2026-10-29 icon repair on iPad4,5 / 7.1.2 (user still saw the old layout and
reported that iPad2 must not be changed):

- The 2026-10-28 edit of `IconState.plist` was not sufficient. SpringBoard kept
  the old layout in memory and rewrote it on the next start. The old placeholder
  icons were also still backed by eight empty stub bundles in
  `/var/mobile/Applications` plus stale `ApplicationSync/ApplicationsSync.plist`,
  `ApplicationSync/iTunesStuff/SpringboardIconState.plist` and
  `ApplicationSync/AssetSortOrder.plist` records. The earlier `uicache` run had
  `HOME=/var/root`, so it reported success without updating the mobile cache.
- Backed up and moved the eight stub app directories to
  `/var/mobile/Applications.disabled-20261029-0540` (Ork, PoP, DungeonHunter2,
  ResidentEvil4, IB2, IB3, DevilMayCry4, Gangstar). Cleaned the three
  ApplicationSync plists (kept only the two INSTALLED entries in
  ApplicationsSync; removed placeholders and added Cydia/Amnezia to the other
  two). Moved the old `IconState`/installation backups and `IconsCache` under
  `/var/root/`, deleted the stale `IconState.plist`/`DesiredIconState.plist` and
  rebooted. After that the old icons were gone (layout 793, pages 16/6), but
  Cydia and Amnezia6 were still absent.
- Cydia and Amnezia6 are installed under `/Applications` and classified as
  System apps, so SpringBoard's default-plus-User-apps rebuild does not add
  them. Appended both bundle IDs to
  `/System/Library/CoreServices/SpringBoard.app/DefaultIconState~ipad.plist`
  and rebuilt the layout; final pages are 18/5 (795 bytes) with Cydia and
  Amnezia6 at the end of page 1. The stock default is backed up at
  `/var/root/DefaultIconState-ipad-original.plist`; restoring it removes the two
  icons again. Dock restored to Messages/Mail/Safari/Settings.
- Removed the old Cydia Safari web clip `B6ECDE5B-A9CE-427C-8B78-5BD87A3BA582`
  to `/var/root/webclip-cydia-20261029-0600/` (backup), so page 2 now has only
  the five real games.
- Verified after a normal respring: `IconState.plist` is 795 bytes, Cydia and
  Amnezia6 each appear once, all eight placeholder IDs and the web clip are
  absent, and the layout survives the respring. `uiopen cydia://` returned 0;
  the entitlement Launch helper returned 3 for both apps (ambiguous: already
  running or launch refused), and no visual screenshot is available on iOS 7.
- iPad2 was read-only in this pass. Its `IconState.plist` md5 did not change
  before/after (16/20/5 pages, Cydia and Amnezia6 on page 2), its packages are
  still the iOS 6 set (Amnezia6 1.1.0, Cydia 1.1.30, Blastron revival, Veteris,
  Device Access, timezone 2026e-1, PerfOverlay 0.1.8, Power Logger 1.0.0, Game
  FPS 0.2.0), and its file mtime predates this repair. No iPad2 package,
  layout or app was installed, removed or edited in this pass.

2026-10-29 Freebuff handoff review: read the exact “Jailbreak для iPad 2 в Codex” thread from its local read-only conversation database. Freebuff installed the newer iOS7 packages and recorded reversible mini2 icon cleanup; it did not commit/push the11-package update. Confirmed public main still382e136 and local index/deb checks pass. No device changes in this review; iPad2 remains outside the write scope. Corrected unsupported blanket AppSync launch diagnosis, reversed Veteris SGX OS statement and Cydia hide-vs-install claim. Retired obsolete direct LocalSend0.5.7 from the active index because its installation can duplicate the current IPA bundle, and its exact matching source is unestablished. Added the three original strictly guarded iOS4 packages and a separate non-indexed timezone7 preview. Source/licenses are being completed before publication.

2026-10-29 publication preparation: active index now13packages after withdrawing obsolete directLocalSend and adding the three strictly iOS4-only helpers. Added13complete source ZIPs with SHA256 manifests and vendor/license inputs, including matchingBlastron0.1.15 and stable/preview timezone sources. Updated source links and license identities (Timezone0BSD; DeviceAccess/BlastronGPL3). Current index/deb/source-hash validation passes. One upstream trailing space in the verbatim Roboto OFL notice is preserved; code whitespace checks otherwise pass. Source builder regression/audit passed. No device state was changed by this review/publication pass; uncheckediOS7workflow limits remain explicit.

2026-10-29 published artifact commit5b1f655 tofronik22/legacy-cydia main. Pages build succeeded; live HTTPS checks matched Packages, gzip, Release, all13DEBs/depictions and13-source manifest. Verification receipt private/published-verification-20261029.json; support limits retained, no device changes in this publication pass.

2026-10-29 current requested fixes: scoped writes to USB iPad4,5/7.1.2 only. Backed up stock timezone ICU and original transaction receipt privately, installed2026e-2, verified155 date/region cases/three consumers, removed with verified stock ICU hash and restored zone link, reinstalled/idempotency pass; reboot requested for final cache reload. QR and HUD investigations proceed independently; no iPad2 writes.

2026-10-29 timezone final reboot:600installed file hashes verified; fresh native arm64 155cases exactly match armv7/IANA2026e. First postinstall shell probe lacked /usr/local/bin inPATH; corrected to absolute helper paths (not an installer failure). HUD native A/B identifies redraw observer effect and plausible global RAM occupancy, no metric code change. QR real-app test caught stale quirc objects due omitted generated dependency files; fixed APP_OBJ .d inclusion and rebuilt/reinstalled the corrected1.3.0. Real camera capture/lifecycle plus four-part callback replay reaches review, without saving/connecting. Detailed agent notes retain failed attempts and untested optical/olderOS limits.

2026-10-29 resumed after agent quota stop: recovered final diagnostic result; retested navigation after UIKit transaction settling (all lifecycle checks pass), confirmed installed signed app payload hash and unchanged profile hashes. Cleanly relaunched app to drop injected diagnostics, returnedHome and removed /tmp/a6-qr13. Refreshed source kits, catalog and checksums. Host suite, final DEB verification, clean extracted-source host suite and13-package repo validator pass. Native camera and synthetic callback replay are verified separately; optical sender and older-device camera tests remain outstanding. No iPad2 operations.
