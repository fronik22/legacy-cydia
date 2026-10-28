# Troubadour 1.6 for iPad 2 / iOS 4.3.3

Experimental armv7 port of upstream commit
`db2b0da2ec0277ea77181c68a80a7629b5cc1627`.
Bundle identifier is unchanged; build number is `1.6.447`.

## Installation

Requires a jailbroken device, AppSync for iOS 4, MobileSubstrate,
TLSFix 1.1, and current trusted root certificates. TLSFix source and repository:
https://github.com/nfzerox/TLSFix / https://nfzerox.github.io/cydia/ .
TLSFix is installed separately and is not bundled in this IPA.

Install the IPA with your IPA installer. Use an upgrade operation to preserve
existing app data; do not uninstall first. No firmware update is needed.
If using legacy dpkg, Debian archives must use `./` prefixes for payload paths;
otherwise files can be placed incorrectly despite a successful unpack.

## Changes

- Build 1.6.447 rejects undeclared SABR tracks before changing audio state.
  Previously a server-supplied 720p60 video track excluded from the requested
  video catalog could replace AAC initialization and segment acknowledgements.
  The device regression reproduces the corruption on 446 and passes on 447.
  This does not change the VPN or promise uninterrupted network delivery.

- Both runtimes defer startup seek/play until readiness, including a seek
  requested before readiness. Lost manual SABR playback can fetch fresh direct
  URLs when the TV reply omitted them, retaining quality and position.
- ReadyToPlay no longer cancels an outstanding seek completion, which could
  leave iOS 6 paused during a startup SponsorBlock skip.
- Rejected stray SABR packets do not force a restart after the selected track
  has already been accepted. The menu reports accepted media rather than a
  rejected server announcement.
- Player quality choices are synchronized immediately and retained across videos
  and app restarts. Explicit Auto is saved too; internal reloads do not overwrite
  the preference.
- A manual resolution prefers its 30-fps track when present, but can use its
  60-fps-only track. SABR advertises a matching frame-rate ceiling and pins that
  track. If the video lacks the requested resolution, a fixed available track
  plays while the global preference remains saved. This does not fix iOS 4's
  60-fps stuttering.

- iOS 4 resumes after a two-second unintended zero-rate stall when at least
  one second of playable media is buffered. Explicit pause, pending seek,
  startup and completed playback remain paused. This does not change streams.
- iOS 4 defaults to 30-fps tracks; the existing 60-fps switch remains available.
  The maximum resolution stays 1080p when a compatible track exists. A video
  with only 1080p60 cannot supply 1080p30 without transcoding.

- Quality changes/fallback preserve an unfinished saved-position seek instead
  of reading the replacement player's zero clock. Starting at zero clears the
  pending-seek flag, so the timer and progress reports advance normally.
- Explicit quality choices reject mismatched SABR init/media before decoding.
  A single fallback uses direct tracks at the same selected quality. Older
  asynchronous selections and stale SABR notifications cannot replace a newer one.
- Direct playback honors the selected audio track or configured language;
  the default prefers the original audio. A missing explicit track is an error
  instead of silently switching language.
- HLS downloads and caches are bound to their playback session. Old requests
  cannot fill the replacement session's cache. UMP payloads own their bytes,
  and oversized network lengths are rejected without 32-bit overflow.
- Each viewing session gets a fresh nonce, including reopening the same video;
  decoder/quality changes keep that session.
- Progress requests use a serial queue and keep the video nonce captured at
  enqueue time. Opening a resumed video reports its saved position; failed exit
  reports remain available for retry. Recovery queues before new viewing sessions.
  Home refreshes fetch current server data rather than a two-minute feed cache.
- Progress reporting survives decoder restarts and quality changes; closing the
  screen or switching videos sends the final position before the old player
  and its metadata are released.

- iOS 4-compatible ARC/weak runtime linking and JSONKit serialization.
- Controller layout callbacks so the interface renders on iOS 4.
- Legacy HTTP response construction for the built-in tunnel transport.
- Skip unsupported lock-screen metadata on iOS 4: loading iOS 5's missing
  `MPNowPlayingInfoProperty*` globals crashed immediately after video data arrived.
- Deferred initial seek/play until the player item is ready on iOS 4;
  seek completion checks against the expected HLS segment boundary where
  the iOS 5 callback API is absent. Startup remains marked as seeking so
  automatic ad skipping cannot overwrite the saved-position seek.
- TLSFix loading, legacy SecureTransport context management, and verified
  certificate chains/hostnames in the custom HTTPS transport.
- ES5 shims and reserved-property conversion for the old JavaScript engine,
  including dynamically evaluated video-attestation programs.
- Player conversion runs in the background and is cached. First preparation
  took about 35 seconds on the A5; the startup wait allows 60 seconds.

## Verified on hardware

Build 1.6.446 passed native selection/progress/report checks on iOS 4.3.3 and
6.1.3. Autonomous live checks verified immediate saved selection, pinned 720p
and 1080p playback, another video with 1080p60-only delivery, full app restart,
and explicitly saving Auto across restart. The iOS 6 live checks used a temporary
USB route to the existing proxy because its Wi-Fi could not reach it. See
`QUALITY-CHECKS.txt` and `QUALITY-PERSISTENCE-RECORD.md` for scope and history.

Earlier playback/compatibility evidence follows; its original build numbers
are retained.

Build 1.6.441 was tested on the attached iPad2,1 / iOS 4.3.3. A native
regression check covers original/explicit audio, rejected mismatched SABR
init/media, scoped fallback, overlapping quality selections, stale-session
cache pollution, malformed UMP lengths, a pending 203.1-second resume across
quality replacement, and clearing pending-seek state on a zero-position start. The packaged executable passed this
check and both existing progress/report checks on the device.

The diagnostic playback build reached ReadyToPlay and advanced at normal rate
at 1080p with Russian original audio after a single SABR-to-direct fallback.
Manual changes to 480p and 720p, then explicit English and Russian audio,
also reached ReadyToPlay and advanced. No new crash was recorded during these
checks. The diagnostics use the same playback sources as the release; their
remote controls and injected library are absent from the release IPA.
An identical 48-second 1080p60 / H.264 High 4.2 fixture was replayed locally
on iPad2,1 / iOS 4.3.3 and iPad2,2 / iOS 6.1.3, using the same diagnostic
binary and native AVPlayerLayer. iOS 4 counted 1,488 dropped video frames;
iOS 6 counted zero. Adding frequent PCR, decoder lead and continuous TS
counters did not eliminate the difference (1,450 drops at 47 seconds on iOS 4,
zero on iOS 6). Changing only the SPS level declaration also did not help.
A standard FFmpeg remux still dropped frames on iOS 4; the user also observed
stuttering during the local MP4 test. These results reproduce the failure in the OS-specific native playback path
independently of Internet delivery. Background app work and rendering geometry
were not controlled. The exact
AVFoundation/decoder mechanism remains unproven; this build does not patch it.
Manual 720p30 playback advanced normally without additional dropped frames.
The tested video offers 1080p only at 60 fps.
An induced buffered zero-rate stop recovered without replacing the player or
changing the stream. Native regression checks also verify that intentional
pause, an empty buffer and a pending seek do not trigger automatic playback.
The 1.6.441 diagnostic build reproduced a fallback while seeking to 210.8
seconds. The replacement retained that target, completed its seek in about
2.1 seconds, and advanced from 210.2 seconds at normal rate, with pending-seek
state cleared. A zero-start regression also clears that state. These checks
cover the start-from-zero/frozen-clock failure observed in 1.6.439.
The original iOS 6 executable was restored after that earlier comparison.
The later quality-persistence update targets both iOS 4 and 6; stall recovery
remains restricted to iOS 4.

iPad2,1, iOS 4.3.3 (8J2): installation and launch, rendered interface,
JSON Unicode roundtrip/malformed-input rejection, weak reference lifetime,
YouTube HTTPS access, player-signature decoder initialization, and execution
of the video-attestation program. Custom HTTPS transport accepted Google's
valid certificate and rejected a mismatched hostname. A native TLSFix probe
rejected a self-signed certificate.

A native progress-lifecycle regression check verifies advancement from 10 to
115 seconds across decoder replacement and closes the session on exit. This
uses a controlled clock and does not send history requests. A second native check
verifies renewed session nonces, ordered reports, stable captured nonces, fresh
home requests, retry of a
failed final report, and resumed opening timestamps, using a fake transport.
Real viewing on iOS 4 advanced the server position from 144 to 182 seconds;
the original iOS 6 app independently fetched that same 182-second position,
started at its HLS segment at 179.2 seconds, and advanced normally. The reverse
handoff returned a 211-second server position from iOS 6 to iOS 4.
Two consecutive reopenings of that same video with renewed session IDs saved
211 -> 246 -> 279 seconds, independently fetched by the original iOS 6 app.
The release IPA passed the native progress checks and excludes test controls.

Saved-position automatic startup, decoder restart at a different position,
automatic startup without a saved position, and pausing during opening passed
on-device checks. Initial seeking completed in about 2.4 seconds, and the tested
restart took about 1.2 seconds, after stream preparation. iOS 4 rounded the
66-second seek to the segment beginning at 61.44 seconds; exact second-level
resume is not guaranteed. The diagnostic jumps are absent from the release IPA.
Long uninterrupted playback remains unverified.

TV/SABR video playback is verified: the native player reached ReadyToPlay and
playback time advanced at normal rate without a crash. The existing Wi-Fi HTTP
proxy initially misrouted the loopback HLS playlist to the Mac (HTTP 503). Adding
`localhost`, `127.0.0.1` and `::1` to the active network service's proxy ExceptionsList
fixed this while preserving its internet proxy settings. This network setting is
separate from the IPA; another Wi-Fi profile using a proxy may need the same fix.

Google did not issue an integrity token during attestation tests; the tested TV
playback path did not request that token. Full WARP/VPN behavior, downloads,
background playback, and other OS/device versions are untested. This build uses the private JavaScriptCore C API
available on this iOS release; future YouTube script changes can break it.

## Build

On macOS, provide an iPhoneOS 9.3 SDK, a compatible historical
`libarclite_iphoneos.a`, Xcode command-line tools with `ld-classic`, Python 3.9+
and `ldid`. These Apple toolchain files are not redistributed here.

```sh
export TROUBADOUR_IOS_SDK=/path/to/iPhoneOS9.3.sdk
export TROUBADOUR_ARCLITE=/path/to/libarclite_iphoneos.a
export TROUBADOUR_LDID=/path/to/ldid
python3 tools/build-ios4.py
python3 tools/package-ios4.py /path/to/ru.computershik.troubadour_1.6.ipa /path/to/Troubadour-ios4.ipa
```

The original release IPA supplies release-only artwork and configuration.
Source resources overlay it; the binary is rebuilt and ad-hoc signed.
The SDK import stubs are adjusted during the build to match iOS 4 symbol
ownership. Delete `build-ios4/` before rebuilding after changing dependencies
or headers other than `src/compat/YTLegacy.h`.

Checks:

```sh
node tools/test-ios4-solver.js
# Optional device regression binary; see the script docstring for deployment.
python3 tools/test-ios4-playback.py
# On the device, using the installed app's executable:
./Troubadour --compat-self-test
./Troubadour --compat-progress-test
./Troubadour --compat-report-test
./Troubadour --compat-player-test /path/to/player.js
```

The two `--compat-ssl-test` flags are developer checks requiring a TCP forward
from device localhost:18443 to www.google.com:443. They are not VPN tests.
Use `--compat-ssl-test` and `--compat-ssl-test-badhost`; both must exit zero.

## Licensing

Troubadour is GPL-3.0; see LICENSE. The accompanying source archive contains
the modified source and build/package scripts. Vendored JSONKit is used under
its BSD license; PLWeakCompatibility, Acorn 1.2.2, es5-shim/es5-sham 4.6.7,
and the typed-array polyfill retain their license notices in ThirdParty or
Resources. The typed-array shim includes an offset correction.

## Final delivery state (446)

Both devices run the clean packaged binary, with temporary tracing and controls
removed and installed hashes verified. iOS 4 retains 1080; iOS 6 retains its
original Auto. The temporary USB network route used for iOS 6 live acceptance
was removed and its original proxy restored. Normal iOS 6 network probes still
failed afterward; the app tests do not establish that its Wi-Fi/proxy works.
See `QUALITY-PERSISTENCE-RECORD.md` for the complete results and limitations.
