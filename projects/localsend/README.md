# LocalSend — iOS 4.3.3–6.x port

## Automatic discovery — build5.7.4340 (2026-10-20)

Settings → General → **Auto discovery** is **OFF by default**, including upgrades from4339. The switch is saved across launches. OFF disables the repeated10-second search and automatic scan when returning to the foreground. Startup still performs one scan; the refresh button performs one scan; passive discovery/receiving remain available. ON scans immediately and repeats every10seconds while the app is active. Leaving the app stops its timer. No separate service is installed.

Verified on iPad2,2/iOS6.1.3: default OFF/no repeats, manual refresh, ON repeats, ON/OFF persistence across full relaunches, timer lifecycle callbacks, RU/EN/UK layout at320/768/1024 widths and preservation of all pre-existing preferences. Test observers were removed and the clean packaged app relaunched with the option OFF. Physical iOS4.3.3/5, two-device transfers on this new build and battery consumption were not retested. Prior media/protocol reports below apply to their stated builds.

See **AUTOMATIC-DISCOVERY-RECORD.md** and **AUTOMATIC-DISCOVERY-VERIFICATION.json** for actions/results.


Separate source tree and experimental armv7 build of [unlocalsend](https://github.com/theanazerka/unlocalsend), upstream commit `90e860ad2c535f86eb1b78b3f6acdba295b73bca` (0.5.7). Upstream targets **iOS 6.0 and later**. This port lowers the minimum to 4.3 and adapts the APIs used by the app. Hardware checks cover **iPad2,1/iOS4.3.3(8J2)** and **iPad2,2/iOS6.1.3(10B329)**. iOS5, other iOS6 releases and Retina hardware remain untested.

## Multiple files, photos/videos and landscape — build5.7.4340

In **File**, check multiple files across directories, then **Add (N)**. In **Photos and videos**, open an album, check thumbnails or use **Select all**, then **Add (N)**. Selection survives album navigation and rotation; Cancel leaves the existing send queue unchanged. Photos and videos are copied in original format without re-encoding. iOS4 uses generated filenames because the native filename API starts with iOS5.

Tap a recipient once to offer the whole queue in one session, uploading each accepted file individually. Partial acceptance and failed uploads preserve correct completion/history. Main screens, both pickers and the media grid support landscape; universal iPad resources include1x/2x portrait/landscape.

On jailbroken **iOS4.3.3 (8J2)** with Location Services off, install the accompanying **LocalSend Photos Without Location1.0.0** tweak. It grants Photos access only to this app through the native Photos gate; it does not enable GPS or change global privacy settings. This intentionally includes embedded location metadata in originals. Other apps/OS versions are excluded. Installation briefly reloads SpringBoard; uninstall with `dpkg -r local.codex.localsend-photos`. On iOS6.1.3, the same IPA passed native multi-photo/video selection, sending/receiving and rotation after ordinary Photos approval, with no bypass tweak installed. iOS5 remains untested.

See MEDIA-BATCH-RECORD.md and the tweak WORK-LOG.md / TEST-RESULTS.md for verification, rejected approaches and exact limits. Test transfers use authenticated USB forwarding to a local TLS fixture; they establish byte integrity, not new Wi-Fi/VPN throughput measurements.

## Installation

Use `LocalSend-iOS4.3.3-6.ipa` with an IPA installer on a jailbroken device with the matching AppSync already installed. Build4340 is installed and tested on the connected iOS6.1.3 iPad; current iOS4 hardware verification is pending. Bundle ID remains `com.unlocalsend.ios6`; build is `5.7.4340`. Upgrade instead of uninstalling to retain files, preferences and identity. No firmware change, TLSFix reinstall or global proxy change is required by this port. TLS 1.2/1.3 uses the upstream bundled Mbed TLS implementation.

Open LocalSend and keep it in the foreground. Both peers normally need the same LAN; multicast discovery uses UDP 53317 and receiving uses HTTPS/TCP 53317. Files are in the app's Documents directory, exposed through iTunes File Sharing. Initial native tests used USB forwards and synthetic data; later actual-app tests also passed over real Wi-Fi, including multicast discovery.

## Verified and pending

Native iOS 4 tests passed: weak lifetime; JSON Unicode/roundtrip/malformed input/mutable containers; UUID uniqueness; HTTP response metadata; TLS 1.2 receiving, certificate fingerprint, streamed/chunked 215 KiB uploads, token checks, busy session rejection, collision-safe filenames, decline, checksum mismatch, cancellation/partial-file cleanup, multiple files, empty files and malformed requests. Sending 215 KiB twice passed with exact bytes received; a wrong certificate pin failed before HTTP upload. The local TLS identity was reused. A strict mutual-TLS fixture failed; client-certificate authentication is **not** claimed verified.

The final clean IPA is installed and its executable hash is checked. Native iPad revision 5.7.4334 additionally passed actual iPad idiom/native bounds, all three tabs, filesystem picker, photo popover cancel and simulated selection delegates, Unicode input and real Wi-Fi HTTPS receipt. A 1536×2048 offscreen render passed; this does not establish Retina hardware behavior. **Actual app UI and real Wi-Fi checks passed on iOS 4.3.3:** root/tabs layout, old-OS text input with correct UTF-8 content, file browser and photo/video picker presentation/dismissal, multicast discovery and unicast reply, incoming Accept/Decline, multi-file receipt, outgoing pinned HTTPS with exact bytes and saved completion history. Received PNG and H.264 MP4 were saved to Photos without errors. A further real Wi-Fi receipt passed on the exact clean packaged executable, approved by a one-shot test payload; that payload was removed and the clean app relaunched. No diagnostic command reader is enabled in the delivered IPA. HEIC conversion and app Photos save additionally passed in build 5.7.4334. Other formats, iOS5 and other iOS6 releases remain unverified.

## Compatibility limits

- HEIC→JPEG conversion now works locally on iOS 4.3.3 through an app-private decoder with a statically bundled C++ runtime. No system library install is required. Apple/reference images and a 4032×3024 (12MP) HEIC passed; received HEIC was converted and saved to Photos by the real app. Originals remain in Documents. The existing 24MP limit rejects larger images. Conversion uses the CPU and can be slow on old devices (about 7.6s for the synthetic 12MP fixture). The original iOS 6 decoder module remains unchanged and hardware-untested here.
- Unsupported video codecs (including HEVC) stay in the app; compatible native formats retain the upstream Photos/export paths, pending verification on 4.3.3.
- Media exports use256KiB chunks. Sending requests mapped-if-safe file data and writes TLS headers/bodies separately, avoiding an extra full-body concatenation. Mapping is a platform hint; arbitrary large videos have not been stress-tested. Prefer files that fit available storage/memory.
- Native universal iPhone/iPad registration: iPad 2 uses 768×1024 pixels; iPad 3/4 Retina uses the same point layout at 2x (1536×2048 pixels). Portrait and both landscape orientations are supported; iPad also supports upside-down portrait. iPad library selection uses a native multi-select album/grid controller; icons and launch images include 1x/2x iPad resources. The iPad 2 mode is hardware-verified; Retina resources and 2x offscreen rendering passed, but iPad 3/4 hardware is untested.
- Incoming encrypted transport and discovered-peer SHA-256 pinning are retained. Manual IP entry without an announcement retains upstream's unpinned behavior.
- No claim of compatibility with 64-bit-only iOS releases: the supplied binary is armv7.

## Build

External inputs: macOS with clang and `ld-classic`; iPhoneOS 9.3 SDK; historical `libarclite_iphoneos.a`; `ldid`; Python 3.9+. Apple SDK/support archives are not redistributed. Vendored upstream Mbed TLS and HEIC sources/archives are retained. iOS 4 HEIC additionally builds a private LLVM libc++ release_35 + libc++abi 3.5.2 runtime from full vendored sources; their licenses are included. See vendor/HEIC-NOTES.md. The iOS 4 decoder archives are rebuilt with scripts/build_heic_ios4.py when absent; that rebuild also needs CMake and Ninja. JSONKit and PLWeakCompatibility are included with their licenses.

```sh
export IOS4_SDK=/path/to/iPhoneOS9.3.sdk
export IOS4_ARCLITE=/path/to/libarclite_iphoneos.a
export IOS4_LDID=/path/to/ldid
python3 scripts/build_ios4.py --checks
```

`python3 scripts/build_ipad_resources.py` regenerates iPad launch backgrounds and icons (macOS sips required). `python3 scripts/check_ipad_package.py` verifies packaged iPad metadata and asset dimensions. The script produces `LocalSend-iOS4.3.3-6.ipa` and the optional native test executable `build-ios4/legacy-checks`. On the target runtime: `legacy-checks selftest`. Receiver helper mode is `legacy-checks receiver /path/to/test-directory 53617`; it auto-accepts test offers and must only be run for an explicit isolated test, then stopped. Native sender helper mode is `legacy-checks send https://HOST:PORT/api/localsend/v2 SHA256PIN /path/to/payload`. A diagnostic UI build uses `--diagnostics` and produces a differently named IPA; it is not the delivered app. Delete `build-ios4` before rebuilding after changing toolchain, dependency headers or compiler flags.

The normal Theos Makefile and original macOS test scripts are upstream iOS 6 tooling. Use this custom build and the target-device checks for this port. See `PORT-IOS4.md` for attempts/results and `TEST-RESULTS.txt` in the distribution folder for concise evidence. The original upstream README is preserved as `README-UPSTREAM.md`.

## License

GPL-3.0; see LICENSE. Matching modified source, build/test scripts and dependency notices accompany the IPA. SDKs, private keys, device dumps and credentials are excluded from the source archive.

## Unattended device tests

Automatic no-passcode unlocking was verified through a one-shot root-injected SpringBoard helper. Both a simulated configured-passcode refusal and a real locked→unlocked transition passed. The reusable helper/procedure is saved separately in `outputs/ipad-unlock-helper` and the `ios4-backport` skill. No permanent unlock tweak or lock-screen setting change is needed. A portable helper archive is also preserved in Downloads as `iPad-unlock-helper-iOS4.3.3.zip`; this helper is verified only on 4.3.3 and refuses other OS versions until adapted/tested.

Test app documents/history and temporary controls were cleaned. Three synthetic test media items (a 32×32 PNG, a one-second H.264 video and a 114×114 HEIC-derived JPEG) remain in Photos as evidence of the successful save path. Existing photos and settings were preserved. A PNG is not necessarily a screenshot; use dimensions/metadata when copying later screenshots.

Legacy image naming/scaling follows [Apple’s high-resolution resource guide](https://developer.apple.com/library/archive/documentation/2DDrawing/Conceptual/DrawingPrintingiOS/SupportingHiResScreensInViews/SupportingHiResScreensInViews.html). UIKit uses points and renders vectors/text at the screen scale.

For HEIC device regression checks, `scripts/heic_device_check.c` loads the exact module, converts a local input to JPEG and reports dimensions/errors. `scripts/heic_runtime_check.cpp` checks the private runtime’s ownership, exceptions and thread/mutex behavior. Native results are recorded in TEST-RESULTS.txt.

## iOS6.1.3 verification

Same4338 IPA installed on iPad2,2. Native Photos approval, two photos plus one video, select-all/deselect/back/re-entry, portrait/landscape, original-byte exports, one pinned HTTPS batch and exact256KiB receiving passed. Temporary fixtures were removed; ordinary Photos approval stays granted. No Photos bypass tweak is installed on6. See IOS6-TEST-RESULTS.md and IOS6-VERIFICATION.json.


Build5.7.4339: automatic foreground discovery and explicit Wi-Fi multicast rejoining. Both iPads rediscover each other without manual scanning; real-LAN128KiB transfers passed in both directions. Details: NETWORK-DISCOVERY-RECORD.md.
