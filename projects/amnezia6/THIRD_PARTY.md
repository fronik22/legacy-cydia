Amnezia6 is distributed under GNU GPL version 2; see LICENSE.

The native status badge hook follows Senko status/senko_status.m (GPL v2).
The UTUN and PF_ROUTE implementation is adapted from Senko by sqmrak:
https://github.com/sqmrak/senko (GNU GPL v2).

Cryptographic primitives include Monocypher; its license and notices are in
third_party/monocypher/LICENCE.md and the unmodified source headers.

Profile bundle extraction and padding semantics adapted from Senko4.1.1 (GPLv2), pinned a3d26f04bdfdb34f87578dc61d22637f2a33ec74. Sources/notices: third_party/senko. cJSON retains its MIT license there. QR decoding uses quirc (ISC), sources/license in third_party/quirc. Cookie generator semantics adapted from WireGuard/AmneziaWG cookie.go (MIT), Copyright(C)2017-2025 WireGuard LLC. Full upstream MIT notice is supplied as third_party/WireGuard-MIT.txt.
