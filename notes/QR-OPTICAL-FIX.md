# Amnezia6 optical QR diagnosis (2026-10-29)

Scope: `projects/amnezia6` and this note; parent owns publication/worklog/handoff.
Device writes and UI blocked pending parent release of HUD counter tests.

Read ios4-backport and ponytail skills, AGENTS.md, ANIMATED-QR.md,
TEST-RESULTS-1.3.0.json, full scanner/shared decoder/collector/test sources.
Installed 1.3.0 has proven synthetic BGRA callback decoding and live camera
callbacks/lifecycle, but no optical display result. User reports live scanning
produces no result, so callback replay cannot validate this failure.

Current scanner selects 1280x720 (else High), BGRA frames, shared quirc decoder
bounded1280px, 0.15s throttle. No explicit autofocus/exposure configuration.
Native iOS7 QR metadata output is unused. Exact multipart framing/assembly has
independent fixture coverage and must stay shared. No camera frame, profile,
QR payload or credentials may enter Git or public test artifacts.

Potential reach: scanner/header, isolated device diagnostic and lifecycle
regression; version/control/daemon/Makefile/package test if changed. Static image
QR import and native iOS4–6 quirc fallback must remain usable. Newer class,
metadata constants and selectors require runtime guards and import inspection.
No product edit made yet: need optical evidence before claiming root cause.

One read-only rg used an unmatched notes/DEVICE* zsh glob; command stopped before
those note reads, repeated targeted known paths successfully. Apple official
focus documentation and SDK headers confirm continuous autofocus support must
be checked and configuration lock acquired; QR metadata type is iOS7+.

Candidate1.3.1 enables native QR metadata capture on iOS7 when the runtime class,
weak QR type and availableMetadataObjectTypes all support it. Native callback
uses the same receiveText/collector; multiple simultaneous QR objects are rejected.
Quirc video decoding remains only the older/unsupported fallback, avoiding duplicate
native+quirc decoding. Explicit continuous autofocus/exposure set only after
configuration lock and respective support checks. No stored profile change.

`make test deb` passes. armv7/iOS4.3 app links; nm shows only weak QR type import,
no direct AVCaptureMetadataOutput class reference. Existing QRRegression extended
with configuration, primary delegate mode, focus mode and multiple QR guard checks;
alternating native-object callbacks and BGRA sample replay verifies shared assembler.
Synthetic metadata objects test delegate handling, not the system optical decoder.
Device install/runtime validation is next after parent UI release.

Read-only exact-device probe confirms iPad4,5 installed1.3.0, daemonidle/tx0/rx0.
Pre-install config/profile hashes equal earlier verified release evidence.
Device lacks shasum and head; repeated with openssl dgst -sha256 and no pipeline.
No sensitive bytes read. Parent provides existing mobile-context launch helpers,
so no new privileged helper is required. Evidence staged under ignored
projects/amnezia6/build/optical-evidence (0700; files0600).

User clarification via parent: scanner shows Received1/2 then glitches repeatedly.
This confirms some optical decoding. Primary upstream94ea5b00 and cachedb39f583
both explicitly use Base64UrlEncoding|OmitTrailingEquals, so padding cannot yet
be claimed as this sender's actual cause. Nevertheless strict parser rejected
otherwise canonical padded tails; added exact padded OR unpadded comparison,
retaining rejection of whitespace, excess padding and noncanonical trailing bits.
New compressed two-part tests cover both one- and two-'=' tails, reverse order,
duplicates and byte-identical valid import. First test incorrectly treated a
single '=' appended to a legitimate unpadded one-'=' tail as malformed; corrected
negative cases to append beyond the fully padded canonical form. New test passes.

Concrete repeated-loop bug: complete assembly followed by A6ImportConfig failure
reset collection, and next camera frame overwrote its error with1/2. Now complete
transport/profile failures stop camera and keep the error visible; Back retries.
Added bounded privacy-safe last scan plist (Foundation-compatible with iOS4):
string length, header count/index/part length, received count, fixed event/status
codes and capped counters only; no raw text/config/keys/endpoints/errors logged.
Atomic overwrite at most1Hz/120 periodic writes per scanner plus final result,
0600 inside existing private0700 preferences directory. The plist is not packaged.

Final runtime verification on iPad4,5/iOS7.1.2/11D257: native system QR metadata
available/configured, production quirc video delegate disabled in native mode,
rear1280x720, continuous autofocus mode2. Diagnostic-only video observer counted27
real frames. Mixed synthetic native objects/BGRA callback replay progressed
1/4,2/4,duplicate2/4,3/4 then review editor. All navigation/resign/restart checks
pass; zero callbacks after stop. Actual rejected-profile callback then further
single/multiple callbacks confirms sticky error, camera stopped, no review; last
scan diagnostic is fixed-code-only,0600 and<8KiB. Native standalone regression
also passes real compressed2part padded/unpadded tails (=,==) and all negatives.

Initial harness runs got UIApplicationStateInactive1/sessionoutputs0; later clean
run succeeded without a product change. A subsequent launch=3 was confirmed
screen-locked/passcodefalse and resolved using existing codex-device-access
unlock, then same mobile launch returned0. Exact UDID screenshot attempt failed
Invalid service (developer image absent); no mount or other device was touched.
These runner issues are separate from optical QR evidence.

Final DEB SHA256:40b838bf0a2ed4a48a2ff3148c4e4080db86844f965c1c2ed51ff37119b2255d.
Installed app SHA256:5c6ef094076a90de06509325fe6c6986568416f568f3fcd19d52b4a627e454c7,
matching signed package payload. Profile/config hashes unchanged; daemonidle,
tx0/rx0. Clean app relaunch unloads all injected diagnostics. Removed only own
explicit files under/tmp/a6-qr13 and directory plus synthetic qr-last-scan.plist;
existing parent helpers left alone. App main left foreground, HUD unchanged.
Public runtime evidence: projects/amnezia6/TEST-QR-RUNTIME-1.3.1.json and
TEST-RESULTS-1.3.1.json. Private ignored verification: build/optical-evidence.
Future real scan diagnostic path:
/var/mobile/Library/Preferences/Amnezia6/qr-last-scan.plist.
No actual sender optical animation pass is claimed; iOS4–6 hardware untested.

## 1.3.2 — actual remaining failure: DNS template import

Fresh user optical run on1.3.1 reached complete2/2 and displayed
`DNS is not an IPv4 address`. Parent preserved bounded real scan evidence:
decoded_frames23,duplicate21,last_frame count2/eventcomplete/index0/part_length850/
received2/string_length1144,statusprofile_rejected. Thus real sender camera and
multipart assembly succeeded; the remaining observed error is profile DNS validation.
No private QR/config/key/endpoint was read or logged.

Root cause in supported official format: native WG/AWG `last_config` retains
`DNS = $PRIMARY_DNS, $SECONDARY_DNS`; root `dns1`/`dns2` are substituted by official
ConfiguratorBase::applyDnsToNativeConfig. Our importer previously emitted the
literal template unchanged. Primary source verified currentdev:
https://raw.githubusercontent.com/amnezia-vpn/amnezia-client/dev/client/core/configurators/configuratorBase.cpp
Cachedb39f583 also has server_scripts/{awg,awg_legacy,wireguard}/template.conf,
SelfHostedUserServerConfig::getDnsPair and exportController writing dns1/dns2.
Upstream replaces empty/invalid DNS metadata using app defaults; it does not
establish an explicit empty-secondary omission contract. This client invents no
resolver: missing/empty referenced metadata returns a clear error. Only matching
referenced fields are required. Existing explicit DNS remains unchanged.

1.3.2 expands the two exact official tokens from strict IPv4 string fields;
invalid/missing/IPv6/newline-injection metadata is rejected. Config parser now
preserves comma/whitespace-separated and repeated-line IPv4 DNS values, normalizes
them to the existing63-character field, and rejects empty elements, hostnames,
CIDR, unresolved placeholders, overflow and IPv6. Previously comma lists silently
dropped all but first; DNS service now installs full ordered ServerAddresses CFArray.
Only other cfg.dns consumer, diagnostic tunnel probe, explicitly queries first
installed resolver while engine keeps the full list. No struct/control ABI change.

Host regressions pass. New fixture profile-dns-template.json contains only public
synthetic keys/RFC5737 endpoints/resolvers. Existing upstream Nayuki generator
builds a real compressed two-part animation under ignored build/dns-fixtures.
Actual QR images -> rotated/padded BGRA -> shared quirc -> collector -> import ->
parsed config preserves both DNS values. Tail-padding two-part regressions also
now use template metadata. String/object last_config, explicit DNS preservation,
missing/empty/wrong-type/hostname/IPv6/injection metadata and unresolved token
negatives pass. Mock dynamic-store CFArray installation, removal and partial-write
rollback pass without changing host networking.

Device standalone tests also pass: actual two-part QR/template chain and all
negative cases, profile import/persistence tests restricted to own temporary test
directory/FakeDaemon, and native CoreFoundation mock DNS array/cleanup rollback.
No real VPN was activated. Added fixed app_version to privacy-safe last scan
record; helper verifies exact top-level/frame-key allowlists and version1.3.2.

Final1.3.2 packaged callback test passes real generated two-part DNS-template
images: order1,duplicate1,0 through native metadata objects/BGRA callback, opens
review with both expanded resolvers;26 real diagnostic camera callbacks and full
lifecycle/sticky-error/privacy/version checks pass. First diagnostic attempt hit
an asynchronous UIKit transaction exception. Private focused crash has no product
frame beyond main; serializing test-only poproot→500ms→profiles→500ms→scanner
resolved it without a product change. Test-only handler records exception class
and fixed reason markers only, never arbitrary text; restored on completion.

Targeted ASAN+UBSan builds in build/sanitize pass template/import/config/DNS-array/
QR regressions. ASAN leak detection disabled for Foundation process globals;
no address/undefined-behavior failure observed. No actual network DNS was changed
by tests (CoreFoundation store APIs are mocked).

Final DEB SHA256:5e06bb44c620aeae854cd9cd6494b9bd502ea1d2bd797e7016aa42c7f8c4853a.
Installed signed app SHA256:55115068e9d13e3c0838a0cb9443de37a08d4ce509a45a9070f40f50ce97c769,
matching packaged payload. Config/profile hashes unchanged; daemonidle/tx0/rx0.
Ten-second physical-only probe with no injected data saw no new decoded QR and
no review. This does not validate actual sender import after DNS fix. Camera
stopped/back returned main; clean app relaunch unloaded diagnostic code. Restored
pretest actual1.3.1 scan diagnostic (user evidence), identifiable by absent new
app_version field. New scans include app_version1.3.2. Only inventoried own
/tmp/a6-qr13 files/directories were removed; user diagnostic and parent helpers
left untouched. App main foreground and HUD unchanged at UI release.

Public summaries: TEST-RESULTS-1.3.2.json, TEST-QR-RUNTIME-1.3.2.json. Historical
1.3.1 summary now records user's confirmed optical2/2 and remaining DNS error.
Private ignored evidence: projects/amnezia6/build/dns-evidence, including native
regressions, callback/physical JSON, sanitizer log, hash snapshots and crash.
No iOS4–6 hardware, real VPN activation or connectivity test claimed.

## 1.3.3 — current-template and timer audit (2026-10-30)

User actual1.3.2 import passed DNS and next failed PersistentKeepalive. Current
primary AWG3.1 template/defaults use25-35 (July cache had fixed25). Full audit,
primary pinned references and every native-field consumer are recorded in
projects/amnezia6/TEMPLATE-AUDIT-1.3.3.md. Read-only child also found ignored
MaxHandshakeAttempts minimum, padded keepalive rejection, and I1–I5 validation
only at send; all repaired. DisableCookies is responder-only upstream and has no
corresponding initiator behavior; remote cookie challenge processing stays enabled.

PersistentKeepalive now supports off/0/scalar/range≤65535. All authenticated TX/RX
reset randomized persistent deadlines; bad tags/replays do not. libc cached
arc4random supplies jitter, equal bounds need no RNG, deadline addition saturates.
Nonempty RX schedules delayed KeepaliveTimeout reply; authenticated TX cancels it;
padded empty RX does not cause reply ping-pong. KeepaliveTimeout also participates
in unanswered-data retry (upper bound + sampled RekeyTimeout, verified primary).
Max attempts sample once per shared handshake round and stay fixed across retries.
Padded authenticated empty payloads accepted after AEAD/replay checks. Invalid
signature syntax/expanded size rejected at configuration boundary. Unresolved
value placeholders preflight before field parsing; `$` comments remain allowed.
Initial old test expected DNS-specific wording for a placeholder; updated to
accept deliberate upfront generic placeholder error. No product issue in that test.

Full host/package, actual iOS7 standalone full-native-template/image/protocol/timer
regressions and ASAN+UBSan pass. Separate sanitizer build keeps normal artifacts
unchanged; leak detection disabled for Foundation process globals. Native timer
suite uses actual AEAD/replay and mocked network/interface/DNS calls, not real VPN.
Packaged fullAWG3.1 two-part callback replay opens editor with25-35/all fields/both
DNS;26 diagnostic camera callbacks, lifecycle/privacy/version/sticky-error pass.

Final DEB:8e40ec9f34c048187669570e5ad811a51a91756e0d77a383a5ae7f51abc8310e.
Installed signed app:456865bbe45a8cd98aa965dd6662591a6c3d419c3705b58ea95dcc281e5390d5,
matching package payload. Clean app relaunch unloads injected diagnostic code;
pretest real1.3.2 error diagnostic restored before fresh user retest.

IMPORTANT concurrent user state: before/after config/profile hashes changed
while the user imported/saved; no harness save/start was called. Last captured
agent status wasidle/tx0/rx0, then parent observed real/non-RFC5737 connected
traffic after UI release. User explicitly confirmed same animated QR opens editor
on1.3.3. Actual optical import PASS is user-confirmed, distinct from synthetic
callback/runtime tests. Preserve new profile/connection; do not restore old hashes.
Parent owns HUD doc-only install/publication; no more Amnezia UI operations.
Public evidence: TEST-RESULTS-1.3.3.json and TEST-QR-RUNTIME-1.3.3.json.
Private ignored evidence: build/133-evidence. iOS4–6 hardware and full server
conformance remain untested; metadata-only custom MTU limit documented in audit.
