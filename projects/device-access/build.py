#!/usr/bin/env python3
"""Build the Device Access CLI and its one-shot payload for armv7/iOS 4.3."""
from pathlib import Path
import os
import subprocess

ROOT = Path(__file__).resolve().parent
BUILD = ROOT / "build"
BUILD.mkdir(parents=True, exist_ok=True)

SDK = Path(os.environ["IOS4_SDK"])
STUB = Path(os.environ["IOS4_STUB"])
LDID = os.environ["IOS4_LDID"]

for name in ("DeviceAccess", "AccessOnce"):
    output = BUILD / (name + (".dylib" if name == "AccessOnce" else ""))
    obj = BUILD / (name + ".o")
    commands = [
        ["xcrun", "clang", "-target", "armv7-apple-ios4.3", "-isysroot", str(SDK),
         "-fno-objc-arc", "-fblocks", "-Os", "-c", str(ROOT / "src" / (name + ".m")), "-o", str(obj)],
    ]
    link = ["xcrun", "ld-classic", "-arch", "armv7", "-iphoneos_version_min", "4.3",
            "-syslibroot", str(STUB), "-L" + str(STUB / "usr/lib"), "-o", str(output)]
    if name == "AccessOnce":
        link.append("-bundle")
    else:
        link += ["-no_pie", str(SDK / "usr/lib/crt1.3.1.o")]
    link += [str(obj), "-framework", "Foundation", "-framework", "CoreFoundation",
             "-lobjc", "-lgcc_s.1", "-lSystem"]
    commands.append(link)
    commands.append([LDID, "-Cadhoc", "-Hsha1", "-S", str(output)])

    for index, command in enumerate(commands):
        result = subprocess.run(list(map(str, command)), capture_output=True, text=True)
        (BUILD / (name + "-" + str(index) + ".log")).write_text(result.stdout + result.stderr)
        if result.returncode:
            raise SystemExit(result.stderr[-5000:])

print("Built root CLI and one-shot access payload")
