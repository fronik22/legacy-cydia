# LocalSend / Troubadour / Veteris: iOS 7 audit and packaging

Date:2026-10-28. Parent coordinates repo publication and device installation. This agent changed only the three owned projects and this note; no app, dependency, hook or preference was installed/changed on a device. Temporary /var/tmp/codex-apps7-probe files were removed after read-only checks. No respring/reboot/account operations.

## Correct sources and artifacts

- LocalSend5.7.4340: retained release outputs/unlocalsend-ios4/LocalSend-5.7.4340-iOS4.3.3-6.ipa, SHA256bbd259f7da4c4a316f9d315019e8b22d54cd31aae553712c0a22245bf5bede28. Sanitized source archive LocalSend-iOS4-source.zip matches working AppDelegate.m. This preserves batch photo/video/file selection, landscape/Retina assets, optional discovery and own TLS/HEIC compatibility code. Older published com.unlocalsend.ios6_0.5.7.deb is not this build.
- Troubadour1.6.447: retained release outputs/troubadour-ios4/Troubadour-1.6.447-ios4.3.3.ipa, SHA2569ed2fcd71ddc1e9b4c3cb55af0c7c20fb2a0fe776f2a74768360b5aca0c86d43. Matching sanitized447archive matches working player source.447is446plus the explicitly tested SABR audio-membership repair, not a rollback. Buffering record proves old-handler failure/new-handler success on iOS4; installed iOS6remained446and has not been upgraded/tested here.
- Veteris1.2.0: own source rebuilt for armv7/minimumiOS5; layout policy5–7, SGX cache workaround ONLY6. The previous verified6fix remains.32bit Veteris4 runs in A7compatibility runtime, so its app-only hook remains armv7; it does not inject into64bit SpringBoard.

Repository-ready DEBs:

- projects/localsend/dist/local.codex.localsend-installer_5.7.4340_iphoneos-arm.deb
- projects/troubadour/dist/local.codex.troubadour-installer_1.6.447_iphoneos-arm.deb
- projects/veteris-ipad/dist/veteris-ipad_1.2.0_iphoneos-arm.deb

## App-installer semantics and dependencies

LocalSend/Troubadour DEBs are explicitly IPA INSTALLER packages. They depend on official ai.akemi.appinst>=2.0 and ai.akemi.appsyncunified, obtained from Karen's https://cydia.akemi.ai/ repository; these third-party packages are not republished by this agent. The official appinst source selects MobileInstallationInstall on iOS5–7 and exits on platform installation failure: https://github.com/akemin-dayo/AppSync/blob/master/appinst/appinst.m . This uses platform IPA upgrade semantics and avoids duplicate /Applications bundles or bespoke container/data migration.

New installer IDs are local.codex.localsend-installer and local.codex.troubadour-installer; app bundle IDs stay com.unlocalsend.ios6 and ru.computershik.troubadour. Payload contains unchanged validated IPA bytes and GPL license, not app data. The actual postinst calls appinst once, propagates a failure and never launches an app/resprings. Existing /Applications/LocalSend6.app, LocalSend.app or Troubadour.app are refused before changes because their shared-home data cannot be safely assumed equivalent to a platform IPA container. No conflicting-package auto-removal or file relocation is attempted.

Removing the Cydia INSTALLER leaves the installed app and its data. Delete the application through the Home Screen when desired. This intentionally avoids silent data loss, and the package name/description/readme/scripts expose that behavior. Dependency unavailability makes installation fail safely rather than bypass signature handling. Installer firmware gate5.0<=version<8.0 is checked both by Depends and preinst. iOS4uses the existing standaloneIPA and its compatible AppSync4; the new official-appinst wrapper is not claimed on4.

## iOS 7-specific audit

LocalSend already branches modern status-bar spacing at7, exposes all iPad orientations with 1x/2x assets, uses capability-checked alert/presentation/font shims, and preserves native ALAssetsLibrary enumeration on6/7. The iOS4-only Photos/location gate bypass must NOT be installed on7. HEIC path chooses its native-libc++ iOS6+ decoder when CoreFoundation>=793; iOS7 provides libc++ (verified on device). The isolated old-runtime decoder remains for4/5. CoreFoundation/Foundation mappings and weak ObjC linkage remain compatible with the32bit7runtime; no64bit system-process injection. UIApplicationExitsOnSuspend stays true as in4340; continuous background reception is NOT advertised or newly enabled.

Troubadour already gates its TLSFix/ES3/legacy playback recovery paths to<5; iOS7 uses native networking/JavaScript/media paths. UIViewControllerBasedStatusBarAppearance=false preserves the app's themed status-bar policy on7; its YTNavigationController capability-checks/disables the new interactive-pop gesture because the app draws its own hidden-navbar back controls. It forwards6+orientation decisions. Playback is custom AVPlayer/MediaPlayer, not AVPlayerViewController. The binary weak-links AVKit, which is absent on7; there are NO AVKit class references in source, and weak absence must remain safe. No insecure trust bypass or global certificate change was added.

Veteris retains the version4bundle guard/declared dependency and metadata backup/restore. Only validated own layout hooks run on5–7. iOS6-specific SGX_MAX_SHADER_CACHE_SIZE=0 is no longer applied indiscriminately to7's different PowerVRdriver. Do not claim a7suspension bug fixed merely because the6workaround is withheld; full7app UI/background validation is still needed. Native setup transformation remains idempotent and refuses externally modified metadata on removal.

## Checks actually performed

- Seven tests pass: three malformed-IPA input checks plus four maintainer-script fixture tests running the ACTUAL scripts: firmware4/5/6/7/8/invalid gate, refusal of old /Applications app without touching sentineldata, appinst exactlyonce/failure code propagation, and nonconfigure/remove not installing/removing user data.
- IPA input validation checks one top-level bundle, exact bundleID/build, executable permission, CRC, no traversal/symlink/mobileprovision/private/Documents files, bounded entrycount/size. Generated DEBs use old-dpkg-compatible gzip tar/ar with ./relative paths.
- LocalSend actual4340IPA iPad metadata/1x2x launch/icon/orientation checker passes. Troubadour reserved-property/ES3solver regression passes. Latest appIPAs remain byte-for-byte their previously released builds; no unsupported claim of newly rebuilt app binaries.
- Real mini2/iOS7.1.2 armv7 read-only runtime probe: pointerBytes4, Foundation/NSJSONSerialization/UIKit/AssetsLibrary/AVFoundation/MediaPlayer/MobileInstallation/libgcc_s.1/libstdc++6/libc++1 load; ALAssetsLibrary/AVPlayer/MPMoviePlayerController/UIWebView/UIFont/UIViewController present; iOS7edgesForExtendedLayout and interactivePop selectors available; MobileInstallationInstall symbol exists. AVKit load returns image-not-found, as expected before8. Probe exits normally, showing actual32bit execution on A7. Raw sanitized result under projects/localsend/build/cydia/runtime-ios7.json (buildignored).
- Veteris C version-policy test covers major3..10and verifiescacheworkaround6only. Native metadata self-test passes both macOS and actual7.1.2Foundation (family/storyboard/idempotency/absent+existing key restore). This does not load the app hook or mutate installed Veteris metadata.
- armv7 release Mach-O slices/dependencies audited; compile/link/sign/package Veteris1.2.0successful. Existingstub toolchain emits legacy target/simulator-tagged-stub linker warnings; binaries actually execute in7's32bit runtime for setup/probe. No SDK/import-stub files belong in published source.

## Unverified / publication requirements

The mini2 currently lacks official AppSync/appinst, and its generic app-launch path is independently failing. No LocalSend/Troubadour installer execution, real IPA upgrade UUID preservation, app launch, transfer/photo selection/HEIC decode or video playback was claimed on7. No Veteris7UI/background test. Parent must classify these as API/build/runtime-dependency audited, awaiting app workflow tests; no blanket completeiOS7claim.

All three projects' license files are GPLv3 (the prior repo matrix's GPL2forVeteris is incorrect). Corresponding source must include LocalSend vendor source and Troubadour ThirdParty/Resources, not only the tracked files excluded by .gitignore. Parent is preparing complete source archives/release links. Publish no Apple SDK/import stubs, game binaries, account credentials/device dumps. Existing sanitized source/test references can include local paths; remove/private-scrub device/account endpoints before publishing summaries. The docs note sources available in the repository/releases; never claim binary-only satisfies GPL.

### Final packager checks / failed attempts

Initial macOS BSD ar verification addressed members without their trailing slash and failed to find data.tar.gz (the earlier existing packager convention retained the slash). The new installer writer now uses portable space-terminated ar member names; extraction through platform ar and tar succeeds, and embedded IPA hashes match the exact retained releases. Gzip timestamp is fixed0; full rebuilds of both installer DEBs are byte-identical. Control md5sums cover every payload file. Existing Veteris packager format is unchanged because its prior installation path is separately verified. No package was installed during this archive check.

Canonical dependency availability was probed with HTTPS HEAD https://cydia.akemi.ai/Packages.gz; it timed out after15seconds/0bytes. This is recorded as unresolved dependency-fetch availability, not proof of appinst/AppSync incompatibility. The wrapper cannot be claimed installable from our Cydia repo alone unless official dependency sources are configured/reachable.
