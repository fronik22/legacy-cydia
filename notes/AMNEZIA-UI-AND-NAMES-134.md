# Amnezia 1.3.4 — status bar and imported server names

2026-10-30. Write target is mini2/iPad4,5/iOS7.1.2 only. Existing profiles,
manual names, accounts and unrelated applications must be preserved.

## Status bar: measured cause

A one-shot read of the real 1.3.3 app found UIApplication statusBarStyle=2
(legacy BlackOpaque/white foreground), a default light navigation bar, and a
white status background. The actual UIKit render shows white status text on
white; only the green battery fill remains visible. Controller preferred style
was already0. The bundled Info.plist explicitly selected BlackOpaque and left
controller-based appearance unspecified in this legacy-linked application.

The fix selects UIStatusBarStyleDefault and explicitly enables
UIViewControllerBasedStatusBarAppearance. It uses UIKit's existing controller
style handling rather than a new overlay, global hook, redraw timer or app-wide
status-bar workaround. The added appearance key is ignored by older iOS.
Exact package tests check both values; actual final iOS7 appearance requires
its own post-install check.

Private evidence: private/amnezia-ui-20261030/before.{json,png}. The screenshot
and live connection/profile details are not distributed. Initial diagnostic
link omitted CoreGraphics; adding the explicit framework fixed the helper,
with no production code change. One-shot loaded code is pinned until normal
app termination; it creates no persistent job or sampling timer.

## Imported names

Official profile export stores the display name in root description, with
hostName fallback; native WireGuard configuration text has no such display-name
field. The previous importer retained only configuration text, discarding this
metadata. The animated scanner also forwarded normalized text after collection,
which erased the original bundle before the editor opened.

The shared importer now retains a bounded, validated description/hostName through
clipboard, file, URL, photo and live multipart QR paths. The editor is populated
before review/save. Metadata wins over a file's base name; absent metadata keeps
the existing filename/endpoint fallback. Existing manual names are not rewritten.
Already imported profiles cannot recover metadata that was discarded; reimporting
the original export is necessary to obtain its original display name.

Authoritative upstream locations, input validation and exact test results are
recorded by the focused importer audit/result note. The client does not query
reverse DNS or invent a name from the VPN endpoint.

## Final native integration

Installed1.3.4 on the exact mini2/7.1.2. Real before/after native app renders show
white-on-white2 -> readable dark/default0; explicit controller-based setting is
true. Packaged callbacks pass home/list/scanner/editor style checks and original
assembled two-part export -> imported editor -> actual visible server-name field.
Six standalone native executables pass clock, authenticated protocol/padding,
idle/rekey/staging/Stop, DNS-array rollback and profile/QR import regressions.
These are synthetic public fixtures; no real profile was saved or renamed.

A clean relaunch initially returned helper error3 because automatic screen lock
had occurred; exact no-passcode helper unlock/relaunch succeeded. An initial live
HTTP check ran before its helper had uploaded and returned127; cleanup restored
OFF. This was test orchestration, not a failed VPN handshake (real handshake and
authenticated traffic had already succeeded). The helper preflight and bounded
live test are rerun separately; raw evidence is retained privately.

Final live integration passed four direct-socket HTTP301 responses over135.47s,
bypassing any HTTP proxy. Two accepted key establishments occurred within the
controlled ON interval; session uptime remained continuous across renewal. The
prior OFF state was restored. All installed payload files match final DEB and
config/profile hashes remain unchanged. Original scan diagnostic restored byte-
exact; own temporary directories removed. Public receipts: project1.3.4 test/QR
JSONs; raw screenshots/logs/hashes stay in private/amnezia-ui-20261030. No battery
measurement or older-device execution is implied.
