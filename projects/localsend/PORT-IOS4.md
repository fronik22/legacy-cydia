# LocalSend iOS 4.3.3 port work log

## Current verified outcome — 2026-10-15

Clean universal iPad build 5.7.4335 is installed and launches on iPad2,1 / 4.3.3. Actual UI, real LAN discovery, sending/receiving, PNG/H.264 Photos saves and the clean executable receipt check passed. Native protocol/negative checks also passed. See TEST-RESULTS.txt. HEIC conversion now passes on 4.3.3; iOS 5/6 hardware remains unverified. The historical pending/failed checks below are superseded by the final verification section.

Upstream: https://github.com/theanazerka/unlocalsend, commit 90e860ad2c535f86eb1b78b3f6acdba295b73bca (0.5.7). Upstream declares iOS 6.0+. Separate checkout: work/unlocalsend-ios4.

Target: iPad 2 / iOS 4.3.3 / 8J2 / armv7. No firmware or network changes authorized by this port. Preserve app data on upgrades.

Scope: build/package metadata, ARC and weak runtime, JSON, UUID, HTTP responses, modal presentation, text input and root layout; TLS and transfer protocol remain the upstream bundled Mbed TLS implementation. Keep existing iOS 6 workflows. HEIC converter depends on libc++ (absent on iOS 4); isolate it in an optional module so older OS can still transfer originals, while iOS 6 keeps conversion. Record this limit until native support exists.

Build and device transfer verification pending. Do not claim installation/launch as transfer proof.

## Work chronology

- Separate clone completed. Latest screenshot IMG_0004.PNG copied to Downloads and byte-verified after USB reconnection; source image preserved.
- Reused historical ARClite and PLWeakCompatibility plus JSONKit (licenses retained) rather than changing device libraries. UUID uses CFUUID. HTTP response construction uses a scoped fallback on iOS 4. Native modal APIs remain on iOS 5+, legacy APIs are used on 4; a text-alert subclass and root-view layout bridge cover missing UIKit entry points.
- Main binary built with iOS 4.3 minimum; original HEIC C++ archives isolated in a module with iOS 6 minimum. Fixed module linking by explicitly linking libc++abi and ARM compiler support.
- Initial IPA installation succeeded. Native checks exposed URL authentication constants incorrectly imported from CFNetwork; moved these import stubs to Foundation, their iOS 4 owner. No system framework was modified.
- Weak lifetime, JSON Unicode/roundtrip/malformed/mutable, UUID and HTTP response tests reached their assertions successfully. A CLI-only UIKit alert check trapped in GraphicsServices before UIKit initialization; this is a test harness boundary, not yet evidence of an app UI defect. Harness initialization and normal app launch are being checked.

- Native core self-tests now PASS on the target after removing UIKit checks from the non-UIApplication CLI harness. UIKit checks must run inside the actual app.
- Native HTTPS receiver tests PASS: TLS 1.2, advertised certificate fingerprint, 215 KiB content-length/chunked bytes, collision-safe destinations, decline, wrong tokens, busy state, checksum mismatch cleanup, cancellation including stalled uploads, multiple and empty files, malformed JSON and hidden names.
- Native HTTPS sender tests PASS twice with exact 215 KiB bytes received on the Mac; wrong SHA-256 pin rejected before HTTP. Identity certificate remains unchanged across requests. Initial test-fixture mutual-TLS authentication failed with an OpenSSL peer fatal alert; ordinary TLS/pin tests passed with no client-certificate request. Do NOT claim mutual-TLS interoperability verified by this fixture.
- Found and guarded UILabel.minimumScaleFactor (iOS 6+) and UIProgressView tint properties (iOS 5+) in all callers. iOS 4 uses minimumFontSize / native progress appearance.
- App launch helper needs the SpringBoard launch entitlement; without it the API misleadingly returned “SpringBoard is not running”. With it, the actual failure is “device locked”. Screen lock is enabled, passcode absent; automatic unlock options did not open it. User was asked once to unlock. No passcode was attempted. App UI checks remain pending while locked.

## Earlier checkpoint before automatic unlock

Clean build 5.7.4332 upgraded successfully; app data retained and installed executable hash verified against the exact IPA. Latest launch returns device locked. No diagnostic UI build was installed and no command reader is active. Native test server stopped and temporary synthetic transfer files/helpers removed. Temporary sender-test reverse SSH route was stopped in its finally block. Existing SSH forward, Wi-Fi logger, proxy, Senko and Troubadour services were preserved.

Source, IPA, notices, native test outputs, build instructions and checksums are delivered separately under outputs/unlocalsend-ios4. Screenshots already copied into Downloads remain unchanged. Native tests do not claim normal app UI success, real LAN discovery, media export or iOS 6 hardware verification.

## Automatic unlock and final device verification

- The user requested autonomous unlocking rather than asking for a physical screen unlock. A temporary root-injected SpringBoard probe confirmed the real controller/method signatures. Automatic MobileSubstrate loading did not load that probe; explicit `cynject` succeeded. No launch-daemon, firmware, passcode or Wi-Fi configuration change was made.
- Verified `SBAwayController.sharedAwayController`, BOOL `isPasswordProtected`/`isLocked`, and `unlockWithSound:isAutoUnlock:`. A simulated passcode refused, the already-unlocked case was handled, and an actual no-passcode locked→unlocked regression passed.
- Replaced the polling probe with a reusable one-shot helper: verifies OS/SSH key/method signatures, refuses a configured passcode, injects once, returns the state and cleans uploaded files. It has no listener/timer/auto-load file. Saved in outputs/ipad-unlock-helper and the ios4-backport deployment reference/scripts. Skill validator passed.
- USB disappeared during testing. Switched to LAN SSH only after its host key matched the known USB target; verified 4.3.3 / 8J2 again.
- UI tests passed: nonzero layout and ready listener; settings; custom old-OS text alert with correct UTF-8 saved bytes; file browser presentation/dismissal; media picker presentation/dismissal. Captured/inspected UI screenshots in work/unlocalsend-ios4.
- Actual application tests over Wi-Fi passed: multicast announcement/unicast reply with matching fingerprint; encrypted HTTPS receiver; offer UI Accept and Decline; three exact files; PNG and synthetic Baseline H.264 MP4 saved to Photos; sender sent selected UTF-8 text to the Mac over pinned HTTPS and persisted completion history.
- Restored the clean packaged executable and checked its hash. A final actual Wi-Fi incoming transfer then passed on that exact executable, using a one-shot injected approval payload. That payload was removed and the app stopped/relaunched cleanly afterward. No modified release binary or diagnostic command reader remains.
- Removed probing tweak/filter/requests; its ten-minute bounded reader had expired. Removed synthetic app documents, temporary payload libraries and test history. Two small synthetic items remain in Photos to demonstrate successful image/video saves. Existing media/settings preserved.
- Evidence: ui-functional-ios4.log, ui-transfer-ios4.log, discovery-ios4.log, clean-proof-ios4.log, final-verification-ios4.json; full chronological UI journal ui-ios4-actions.json (private working directory). Public concise results copied into TEST-RESULTS.txt.

## Native iPad revision — 2026-10-15

Requested native iPad 2 and iPad 3/4 Retina support, plus durable unlock helper preservation. Scope: universal device-family metadata, 1x/2x iPad launch images/icons, iPad photo-library popover and width-correct transfer rows. Existing UIKit point layout and screen-scale vector rendering are reused. Portrait orientation retained. Verify upgrade preserves app data and actual iPad idiom/native bounds. Retina hardware is not currently connected; distinguish offscreen 2x rendering from real hardware checks.

- Added UIDeviceFamily=[1,2] to both source metadata copies and build 5.7.4333. Retained existing point-based geometry and screen-scale vector rendering; added 768×1004/1536×2008 portrait launch backgrounds and 72/144px iPad icons. Sources/checks are build_ipad_resources.py and check_ipad_package.py. UIKit status bar completes the 768×1024/1536×2048 surface.
- Native iPad library picker now uses retained UIPopoverController anchored to the Media card. Shared dismissal covers chosen image, chosen movie and cancellation; outside-tap delegate clears ownership. Transfer list text/status width now follows the native row width.
- USB upgrade succeeded with app identity/preferences preserved. Diagnostics measured idiom=Pad, screen scale=1, window=768×1024 and root content=768×1004 on actual iPad2,1 / 4.3.3. All three tabs, filesystem picker, native photo popover, cancellation, simulated selected-image callback/JPEG write and Unicode text alert passed. Real Wi-Fi encrypted offer/accept/upload/completion returned exact bytes. See ipad-native-ios4.log and ui-ipad-*.png.
- Forced 2x offscreen rendering returned 1536×2048. Packaged 1x/2x resources and universal metadata checks passed. This is NOT a hardware test of iPad 3/4 or iOS 6. Portrait-only behavior is retained.
- Installed exact clean release IPA; executable SHA-256 matches package, no diagnostic command-reader marker. One-shot in-app native snapshot confirmed clean build 5.7.4333 still uses iPad idiom and native bounds. Target has no ps executable (exit 127); process lookup used launchctl instead. Snapshot payload/files/launcher removed; app relaunched to drop the injected library. Original preferences restored/compared, synthetic app documents removed; Documents is empty as before. Existing services/media unchanged.
- Preserved reusable unlock kit at outputs/ipad-unlock-helper and /Users/mak/Downloads/iPad-unlock-helper-iOS4.3.3.zip. Skill script/source byte-match the kit. Reused helper successfully (already-unlocked); prior locked→unlocked and passcode-refusal tests retained. No daemon/automatic unlock installed. Helper remains verified only for iOS 4.3.3 and refuses other versions.

## HEIC iOS 4 feasibility / backport — 2026-10-15

Current limitation is the decoder build/runtime, not an intrinsic HEIC requirement for iOS 6. Main app gates LSHEIC.dylib to iOS 6 because bundled libheif/libde265 were built against system libc++ (not supplied by iOS 4). Apple documents libc++ availability from iOS 5; this particular module targets 6. No decoder backport was attempted during the initial compatibility work.

Investigated reuse of existing local FFmpeg 7.1.2 C sources: native remux build has MOV/HEIF demuxing but no HEVC decoder; grid images need composition/transform handling. Prefer preserving existing libheif semantics with a private app-local C++ runtime, pending actual target verification. No system libraries will be replaced.

- Built LLVM libc++ release_35 + libc++abi 3.5.2 privately from source. The first module load failed with Unwind_DeleteException assigned to modern libSystem. Assigned all used unwind imports to the target's libgcc_s.1; no runtime shim/system replacement was needed. Exact compile/link tests and failure/success output are retained in heic-native-ios4.log.
- Private runtime regression passed on 4.3.3: strings/vector/shared ownership, throw/catch, mutex and a joined native thread. Rebuilt libheif 1.18.2 and libde265 1.0.16 archives at minimum iOS 4.3, preserving their existing decode/transform code. LSHEIC4.dylib statically links the runtime and exports only LSDecodeHEIC. Actual imports contain no system libc++. The original iOS 6 LSHEIC.dylib is byte-identical to build 5.7.4333.
- Native iPad2,1 tests passed: Apple HEIC 114×114, reference HEIC 1280×854, Apple HEIC 4032×3024→JPEG. Last 12MP fixture took 7.55s including remote execution. Invalid bytes and Apple 5000×5000 HEIC returned errors; the existing 24MP bound prevented oversized decode. Fixtures are generated from supplied app artwork, not user photos. Native CLI files/folders were removed.
- Actual diagnostic app over real Wi-Fi received Apple HEIC with exact original bytes, converted through the new module and saved JPEG to Photos without error. One synthetic 114×114 JPEG now remains in Photos in addition to the two earlier PNG/video fixtures; no user media was changed. The original received test file was removed. See heic-app-ios4.log and ui-heic-photos-ios4.png.
- Clean build 5.7.4334 upgraded and launched. Executable and LSHEIC4 module are byte-identical to the IPA; no diagnostic command reader. Native clean-app snapshot still shows iPad idiom and 768×1024 window. Snapshot library/files/launcher removed and app relaunched. Only test history was restored to the pre-test list; other current preferences preserved. Documents is empty as before. Final hashes/state in final-verification-ios4.json.
- No iOS 6 hardware/Retina hardware test was added; original iOS 6 module retained exactly. Decoder coverage is the stated fixtures, not every possible HEIF variant. Existing 24MP limit and CPU conversion cost remain.

## Multi-file / landscape revision — 2026-10-16

Build5.7.4335 implements queued multi-file selection and one-offer batch sending plus native landscape; full changes, actual tests and limits are in BATCH-LANDSCAPE-RECORD.md. Prior historical portrait-only/4334 notes above describe those older releases. New source/IPA/verification are packaged together.
