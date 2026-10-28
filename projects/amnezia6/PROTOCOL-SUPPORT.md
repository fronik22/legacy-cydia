# Protocol support — inspected 2026-10-25

Amnezia6 is a small native implementation, not the official Go client. App version 1.0.6 is independent of AWG protocol versions. CLI `protocol/1` denotes this app’s local control socket format, not AmneziaWG 1.0.

Implemented configuration/wire features: normal WireGuard Noise/ChaChaPoly transport; legacy Jc/Jmin/Jmax and H1–H4/S1–S2; AWG 1.5/2.x signature chain I1–I5, ranged H1–H4 and S1–S4 prefixes; AWG 3.1 header protection via HeaderProtectionKey, additional content padding (single integer), RandomTrailers and timing ranges (RekeyAfterTime/RekeyTimeout/RejectAfterTime/KeepaliveTimeout/MaxHandshakeAttempts). Support depends on the profile parameters; there is no separate protocol-version selector or negotiation.

Known incomplete areas: ContentPaddingAddition range syntax is not accepted (only a single integer). Incoming cookie challenges are not consumed/replied to; DisableCookies is accepted but the initiator has no cookie-response transmission path. Local session implementation is not a full upstream conformance certification. Never imply all 3.1 server configurations were tested. IPv4 only; one active profile.

Current device profile has HeaderProtectionKey, S1–S4, H1–H4, I1, RandomTrailers and rekey range119–134seconds, with ContentPaddingAddition=0. No keys copied into this report. A successful real connection with this profile checks that specific combination, not all combinations.

Primary current protocol reference: https://docs.amnezia.org/documentation/amnezia-wg/ (checked2026-10-25). Implementation evidence: src/config.c, src/protocol.c, src/tunnel.c.


## Superseded in1.1.0 (2026-10-26)
The two limitations above are now implemented: ContentPaddingAddition ranges and incoming authenticated cookie challenges/MAC2 retries. Existing other limits (IPv4, datagram/junk bounds, upstream conformance not exhaustive) still apply. See PROFILES-RESULTS-20261026.md for tests.
