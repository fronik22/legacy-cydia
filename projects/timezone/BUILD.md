# Building

The prebuilt `.deb` is sufficient for installation. Building is optional.

## Native tools
Requires macOS/Xcode with `clang` and `ld-classic`, an armv7 iOS SDK (development used SDK9.3), a matching legacy linker sysroot containing Foundation/CoreFoundation/objc/System/gcc_s.1 stubs and crt1.3.1.o in the SDK, `ldid`, and Python3. These Apple SDK files are not redistributed here.

```
export IOS_SDK=/absolute/path/to/iPhoneOS9.3.sdk
export IOS_LINK_SYSROOT=/absolute/path/to/legacy/linker/sysroot
export LDID=/absolute/path/to/ldid
python3 build.py TimezoneUpdate
python3 build.py TZProbe
python3 package.py
```

Output defaults to `dist/`; set `OUTPUT_DIR` to choose another output directory. Native binaries are armv7, minimum iOS4.3, ad-hoc SHA1 signed. `-Os` is required with the tested Apple clang17 because its -O0 ARM exception-table generator crashes on this installer.

## Data and licenses
`zoneinfo/` contains fat TZif files compiled by IANA zic2026e with `-b fat` from africa, antarctica, asia, australasia, europe, northamerica, southamerica, etcetera and backward. `package.py` adds `zone.tab` and `+VERSION`. `resources/` is the Unicode ICU44+ little-endian 2026e set. Check `PROVENANCE.json` for download URLs and SHA256 hashes. No Apple ICU package is included.

## Parser regression check (macOS)
Copy an original supported device ICU package to a private local path; do not redistribute it. On-device originals can be copied from `/usr/share/icu/icudt*l.dat` before installation or from the package's rollback directory after installation.

```
clang -fno-objc-arc -Wno-deprecated-declarations -framework Foundation TestICUPack.m -o test-icu-pack
./test-icu-pack /private/path/to/original.dat
```

This verifies resource preservation and malformed-input rejection. It writes `icudt49l-updated.private.dat` beside the sources for inspection; the filename is a test artifact, not an assumption in the installer. Physical runtime tests on each supported iOS version remain necessary. Host/device SSH orchestration scripts and credentials are deliberately excluded from this source kit.
