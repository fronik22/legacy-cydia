Amnezia6 is distributed under GNU GPL version 2; see LICENSE.

The native status badge hook follows Senko status/senko_status.m (GPL v2).
The UTUN and PF_ROUTE implementation is adapted from Senko by sqmrak:
https://github.com/sqmrak/senko (GNU GPL v2).

Cryptographic primitives include Monocypher; its license and notices are in
third_party/monocypher/LICENCE.md and the unmodified source headers.

Profile bundle extraction and padding semantics adapted from Senko4.1.1 (GPLv2), pinned a3d26f04bdfdb34f87578dc61d22637f2a33ec74. Sources/notices: third_party/senko. cJSON retains its MIT license there. QR decoding uses quirc (ISC), sources/license in third_party/quirc. Cookie generator semantics adapted from WireGuard/AmneziaWG cookie.go (MIT), Copyright(C)2017-2025 WireGuard LLC. Full upstream MIT notice is supplied as third_party/WireGuard-MIT.txt.

Animated QR framing follows the documented wire behavior of official AmneziaVPN
qrCodeUtils/importController, inspected at upstream b39f583097b7eeb1888702b4fa2f37b4aee66a33
and dev94ea5b00aaddc70affbbf20b78ae309fb94787ac on 2026-10-29. No upstream GPLv3 implementation is copied.
quirc region capacity is increased from 254 to 1024 for dense 850-byte QR parts.
Test fixture generation uses the upstream Nayuki C++ QR encoder (MIT); complete
sources and license text are retained in third_party/qrcodegen. It is not linked
into the app.
