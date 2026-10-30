# Amnezia6 keepalive/timer correctness — 2026-10-30

Scope: initiator-side timers, key validity and idle behavior. This is not full
AWG protocol conformance or a battery measurement. No private profile, endpoint,
device or networking state was inspected/changed by this audit.

## Primary source

Current upstream master was checked through GitHub API and fetched at
b5928efb6ca19f0153958460c3d141f04abc5c2e; the earlier saved snapshot is still current.

- [Timer actions and interval selection](https://github.com/amnezia-vpn/amneziawg-go/blob/b5928efb6ca19f0153958460c3d141f04abc5c2e/device/timers.go)
- [Authenticated sends and renewal](https://github.com/amnezia-vpn/amneziawg-go/blob/b5928efb6ca19f0153958460c3d141f04abc5c2e/device/send.go)
- [Response confirmation and authenticated receive](https://github.com/amnezia-vpn/amneziawg-go/blob/b5928efb6ca19f0153958460c3d141f04abc5c2e/device/receive.go)
- [Peer starts with zero interval](https://github.com/amnezia-vpn/amneziawg-go/blob/b5928efb6ca19f0153958460c3d141f04abc5c2e/device/peer.go)

A keepalive range selects the next idle interval after authenticated traffic;
normal traffic postpones that timer. It is not a heartbeat sent on top of every
active transfer. Off/omitted disables persistent heartbeats, while confirmation
and response keepalives still have protocol roles. A valid handshake response
requires immediate key confirmation. Renewal follows traffic/key age, not an
unconditional idle cron. Retry/silence timers add 0–333ms jitter; the upstream
attempt limit permits N+2 initiation transmissions. Expiry checks use the upper
RejectAfterTime bound; receive-side freshness uses its selected value and the
lower keepalive/retry bounds. These distinctions come from the linked code.

## Confirmed local defects corrected

1. Omitted PersistentKeepalive previously invented25; it now stays0/off. Explicit
   scalar/range values remain intact. Real Amnezia exports explicitly carry their
   intended value, including25–35.
2. Successful responses previously marked CONNECTED without sending a transport
   confirmation. They now send staged data immediately, or one authenticated
   empty packet when there is no staged data. This also confirms renewed keys.
3. Whole-idle connections previously renewed at120s and tore down/reconnected at
   sampled key expiry. They now retain interface/routes/DNS; expired transport
   keys are wiped, old transport packets rejected, and actual outgoing or late
   authenticated incoming traffic requests renewal. No packet is sent with an
   expired key.
4. One bounded first outbound IPv4 datagram can wait for a new key. Version,
   IHL, exact IP length and MTU are validated before storing it. More packets
   are dropped while that single slot is full. Rejected responses cannot flush
   it; a successful response does. Stop/retry wipes it. This bounded queue is an
   application policy, not a claim to reproduce upstream's full staged queues.
5. Retry/silence jitter, sampled-zero timer cancellation and attempt counts now
   match the reviewed paths. Normal activity cancels redundant reply timers.
6. Protocol duration/uptime/cookie-age scheduling used wall time. a6_now_ms now
   uses legacy-compatible mach_absolute_time with thread-safe timebase init.
   Wire TAI64N generation still uses wall time independently.
7. ON polling follows actual deadlines, retaining a3s source-address check.
   OFF/ERROR waits indefinitely on the control socket/signals instead of waking
   every500ms; controls and stop signals still wake the daemon immediately.

The existing1/2/4/8/16/30s network/setup retry backoff and30s exhausted connected
renewal-round delay remain explicit app reconnection policies. They are not
presented as identical upstream queue/lifecycle behavior. Full keyring retention,
responder operation, message-counter exhaustion, IPv6 and full server conformance
are outside this targeted repair.

## Verification

- tests/test_protocol.c: absent interval0, scalar/range/off/bounds; existing real
  crypto, authenticated padding, challenge and replay checks retained.
- tests/test_tunnel_retry.c: deterministic clock/network wrappers plus real AEAD
  for confirmation/data receive. Covers immediate confirmation; wholly idle
  PK-off; key-only expiry; expired RX rejection; bounded/validated first packet;
  rejected-response no-flush; TX/lateRX renewal; zero-range draw; jitter/attempt
  bounds; adaptive idle polling; and Stop/retry plaintext wiping.
- tests/test_clock.c: mocked monotonic ticks/timebase and forward/backward wall
  jumps; timer milliseconds stay monotonic, TAI64N still reads wall time.
- Full host, native compilation and sanitizer outcomes are appended below after
  execution. Private logs/primary snapshots live in projects/amnezia6/build/keepalive-audit/.

Initial old tests expected unconditional expiry reconnection and omitted the new
legitimate outbound data in their counter expectation. Those assertions failed
as expected after the behavior change; they were updated to test preserved
interface state and correct data accounting. Failures remain in ignored logs.

Final checks passed: full `make test`; armv7 legacy native compilation/link of
`build/test_tunnel_retry-device` and `build/test_protocol-device` (including
pthread_once/mach_absolute_time); separate ASAN+UBSan timer/protocol/clock suites.
No native executables were run and no device/VPN route/DNS state was changed.
