#!/usr/bin/env python3
"""Copy an iPhoneOS SDK and add the stubs needed for an arm64 iOS 7 link.

The iOS 9.3 SDK re-exports /usr/lib/system/liblaunch.dylib but does not ship
that stub. ld-classic also needs an arm64 entry for libgcc_s.1. Neither
library is used at runtime by the badge hook; the stubs only satisfy the link.
"""
import shutil
import sys
from pathlib import Path

LAUNCH_STUB = """--- !tapi-tbd-v2
archs:                   [ arm64 ]
platform:                ios
install-name:            '/usr/lib/system/liblaunch.dylib'
current-version:         1
compatibility-version:   1
exports:
  - archs:               [ arm64 ]
    symbols:             [ ]
...
"""

GCC_STUB = """--- !tapi-tbd-v2
archs:                   [ arm64 ]
platform:                ios
install-name:            '/usr/lib/libgcc_s.1.dylib'
current-version:         1
compatibility-version:   1
exports:
  - archs:               [ arm64 ]
    symbols:             [ ]
...
"""


def main():
    if len(sys.argv) != 3:
        raise SystemExit("usage: prepare_arm64_sdk.py <iPhoneOS.sdk> <destination>")
    source, destination = Path(sys.argv[1]), Path(sys.argv[2])
    if not (source / "SDKSettings.plist").exists():
        raise SystemExit("not an SDK: %s" % source)
    if not destination.exists():
        print("+ copying %s -> %s" % (source, destination))
        shutil.copytree(source, destination, symlinks=True)
    (destination / "usr/lib/system").mkdir(parents=True, exist_ok=True)
    (destination / "usr/lib/system/liblaunch.tbd").write_text(LAUNCH_STUB)
    (destination / "usr/lib/libgcc_s.1.tbd").write_text(GCC_STUB)
    print("prepared %s" % destination)


if __name__ == "__main__":
    main()
