# Amnezia6 iOS7 audit /1.2.1

Date2026-10-28. Scope: our own source/packages; no Senko app/daemon restored.
The GPL-derived bundle parser and its mandatory attribution are part of
Amnezia6, not a Senko installation. Existing profile text/store and account
state are preserved; private evidence is excluded from Git.

## Platform work already in1.2.0

- armv7 app/daemon/CLI run on iOS7's compatibility runtime. A7 SpringBoard
requires the badge dylib's separate arm64 slice; claiming all installed
processes are arm64 would be incorrect.
- Actual iOS7.1.2 read-only runtime introspection found
SBStatusBarStateAggregator/sharedInstance/_updateVPNItem; the old
SBStatusBarDataManager is absent. SBTelephonyManager/isUsingVPNConnection remains.
The badge adapter selects the supported manager and signature-checks callbacks.
- Custom editor/log views disable extended-edge layout on supporting UIKit;
opaque navigation avoids iOS7 translucent-bar overlap while retaining4–6 paths.
- UTUN structs and routing header are fixed-width. Zero-length route sockaddr
padding is4bytes on arm64 too, not sizeof(long); regression fixture covers it.
- Firmware guard4.3≤version<8 executes before stopping mapped binaries.
No NetworkExtension dependency, firmware update or global TLS bypass added.

## Concrete1.2.1 fixes

1. Control socket had a0666 fallback when mobile group lookup/chown failed.
It now binds0600 under a temporary umask, requires root:mobile0660 before
listen, and aborts/unlinks on group/ownership/mode/listen failure.
2. Requested DNS installation failure previously continued with the physical
resolver. It now cleans the attempted routes/interfaces and retries with a
clear DNS error before a handshake can be sent.
3. Unsupported IPv6 Address/DNS/Endpoint and IPv4 split routes now reject with
clear errors. Existing common dual AllowedIPs defaults remain readable and are
not rewritten. IPv6 is still unprotected; the app's persistent footer says so
and states that no kill switch exists. This is not IPv6 leak prevention.

The older external Amnezia1.0.0/Senko comparison is historical. Cookies,
padding ranges, profile import/selection, backoff, MTU bounds and header-range
validation already exist in later sources; those were not reimplemented here.
Root-owned profile storage, a kill switch, IPv6 tunneling/blocking and split
routes remain separate work, not claimed as solved by these small fixes.

## Tests and actual iOS7 result

- Full `make test` passes. New socket tests exercise a real private Unix socket
plus injected group/chown/chmod/listen failures; no world-write fallback.
- DNS failure fixture proves no handshake is sent, routes are removed,
descriptors close, error/retry is visible, and a later successful retry works.
Existing DNS temporary-store partial-write cleanup tests remain green.
- Parser tests cover IPv6/multiple tunnel addresses, IPv6 DNS/endpoint,
unsupported split/IPv6-only routes, and retained single/dual full defaults.
- ASan/UBSan socket and protocol/parser tests pass.
- iPad4,5/iOS7.1.2 executes protocol/cookie/padding and profile/import/migration/
rollback tests successfully. Real root:mobile0660 socket creation and cleanup
pass. Probe binaries' SHA256 values match their final local builds.
- Shared1.2.1 engine was linked into an isolated root diagnostic, without
stopping/replacing the normal idle daemon or writing the profile store. A
private config copy used a temporary opaque Mac UDP relay to the same server.
Actual result: handshake established, HTTP301, configured DNS response,
9transmitted/7received IP packets (556/1034bytes). Relay counted10out/9in
opaque datagrams with no socket errors. Thus real iOS7 UTUN, crypto/transport,
route and DNS paths were exercised, not merely package installation.
- Cleanup confirmed idle state, temporary interface gone, physical default
gateway and global DNS snapshot restored. Original profile bytes remained
unchanged; profile store absence remained unchanged. No daemon, relay,
VPN-selection/config change or wake lock was left running.
- Direct endpoint comparison with the same engine/profile did not handshake
within12seconds. Endpoint route query selected the physical interface/gateway.
This does not establish an iOS7 driver or VPN code defect, nor prove an AP/ISP/
server fault. Matching server-side UDP capture is required to localize that
remaining direct-path failure.

## Rejected attempts / limits

First native profile run aborted because the harness pointed at a directory
without fixtures; copying the fixed public fixtures made the same test pass.
This was a diagnostic executable, not an app/SpringBoard crash. First relay
attempt received no device datagrams; a separate direct UDP echo then passed,
and the repeat relay test completed fully. That transient remains unexplained;
do not retroactively label it a proven network or package fault.

Read-only method dump temporarily loaded a constructor-only bundle, with no
selector mutation/timer/unlock/network change. Own temporary payload/output
were removed. iOS7 has no ps/pgrep/tail in its current bootstrap; use verified
launchctl inventory and bounded own probes instead of assuming tool presence.
All four native probe binary SHA256 values matched local bytes. A separately
reported Mac inetcat stdin truncation did not affect these verified SCP copies.

1.2.1 Debian archive path/script/content/license/profile-exclusion tests pass.
The final1.2.1 package has been built, but install/UI verification is coordinated
by the parent task; the standalone engine test is not represented as a final
packaged-app UI test. No long-session battery, 4/5 firmware, every server,
seamless roaming or physical IPv6 privacy claim.
