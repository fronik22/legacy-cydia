# Veteris iPad work log — 2026-10-20

1. Inspected installed Veteris 4 metadata and the original repository DEB. No UIDeviceFamily key; nonexistent NSMainNibFile~ipad=MainStoryboard-iPad. Actual resource is en.lproj/MainStoryboard.storyboardc.
2. Read upstream source at commit 7e6edbd11d8c509f9a39536dc380824bd2af1db7. SearchTableViewCell uses fixed 320-point layout; HomeViewController fixes logo x to 60. Main app detail view already calculates much of its layout from available width.
3. Captured baseline on iPad2,2/iOS6.1.3: window/screen 320x480, userInterfaceIdiom=phone, scale1.
4. Created separate metadata setup executable and app-scoped layout dylib. No app executable replacement, network changes, daemon, or global SpringBoard hooks. Package pins Veteris version4.
5. Device self-tests passed for family/storyboard changes, idempotency and missing/existing-key restoration. Applied twice and removed; original Info.plist dictionary restored exactly.
6. First package configure failed because su was incorrectly addressed as /usr/bin/su. Changed scripts to resolve su via PATH (/bin/su on device), rebuilt and successfully configured the package. Failed log retained as validation/install-attempt1.log.
7. Native metadata plus mobile uicache/respring yielded 768x1024, idiomPad. Initial dylib loaded but did not hook because MSHookMessageEx was not globally exported in this Substrate setup; the 768/1024-point cell checks correctly failed. Fixed loading by explicitly opening installed libsubstrate.dylib. Removed an unnecessary pre-UIApplicationMain idiom check; target bundle/version and width still scope changes.
8. Reinstalled rebuilt package with app stopped before replacing its mapped dylib. Continuing final UI and uninstall/reinstall checks.

Evidence is under validation/. Device/cache dumps remain private and are excluded from release artifacts. Existing Veteris crash reports at07:38–07:41 report suspension while an OpenGL shader cache file is locked (0xdead10cc); this is separate from the layout checks and no claim is made to fix it.

9. Visually verified real list cells; they use AppListTableViewCell, separate from SearchTableViewCell. Added width-based label resizing there and download-row geometry. Fixed home gradient-layer bounds as well.
10. A temporary inspection-only delayed block initially referenced a dictionary after draining its pool; symbolicated crash context pointed to the inspection bundle. Moved draining until after block copying. Subsequent list/home/detail/settings snapshots and 768/1024-point checks passed.
11. Real DEB removal/restoration and reinstall passed. Captured native home/list/detail/settings; 2x offscreen rendering1536x2048 passed. Inspected the final DEB with direct ar/tar parsing due BSD ar selection mismatch. Installed final artifact, compared runtime/setup bytes to archive, verified unchanged original app executable and install-ok status; self-test and clean launch passed.
12. Final process was restarted without inspection bundles. Temporary device probes and copied DEBs were removed. Public source/release excludes SDKs, credentials, device/cache/crash dumps and the upstream app binary.


## Background fix / version1.1.0

13. Reproduced the user's exit failure: app PID2114 vanished immediately after switching to Settings; new crash0xdead10cc named `/private/var/mobile/Library/Caches/com.victorlobe.veteris/com.apple.opengl/shaders.maps` as locked during suspension. This was not evidence of a network failure.
14. Copied this device's dyld cache read-only and inspected IMGSGX543GLDriver / libCoreFSCache. `SGX_MAX_SHADER_CACHE_SIZE` is parsed near0x3025c748; zero bypasses fscache_open. Added the per-app environment value in the existing constructor. No disk cache deletion or global graphics changes.
15. Idle background/return checks at2/5/10seconds kept PID2354 and produced no new crash. App executable remained byte-identical. Package1.1.0 installed and self-tests passed. Initial verify launch returned3 because the screen was locked; harness now uses the existing no-passcode unlock helper, then passed.
16. A provisional custom background manager was tested then removed. Inspection of the actual released v4 binary (which differs from current public source) showed native YZBackgroundKeeper and helper support. The final tweak therefore adds only the cache setting alongside existing layout hooks. One provisional expiration test used manual pauseRep, which sets userPaused and cannot auto-resume; that approach was discarded, with no such code shipped.
17. Owned valid IPA test over an owned loopback SSH USB tunnel: normal background transfer completed with matching SHA256 and same process. Native expiration callback ended UIKit task; the app's existing helper kept the download running (helperKeepsAlive=1), and foreground reset expiration state. Full file checksum passed again. Initial test expected pause even with the native helper active; corrected the assertion to match the actual native branch. Only own fake queue record/files were removed.
18. No added SpringBoard hook, daemon, polling timer, unlimited background claim or user-data reset. Existing helper behavior is unchanged. Tradeoff: shader compilation may occur again at launch; battery/performance not benchmarked. Other OS/GPU hardware remains untested.
