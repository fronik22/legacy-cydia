#!/usr/bin/env python3
"""Package the root CLI and one-shot SpringBoard payload."""
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
from package_deb import build_deb

BUILD = ROOT / "build"
STAGE = BUILD / "stage"
CONTROL = BUILD / "control"
for directory in (STAGE, CONTROL):
    shutil.rmtree(directory, ignore_errors=True)
    directory.mkdir(parents=True)

bin_dir = STAGE / "usr/bin"
bin_dir.mkdir(parents=True)
shutil.copy2(BUILD / "DeviceAccess", bin_dir / "codex-device-access")
(bin_dir / "codex-device-access").chmod(0o755)

lib_dir = STAGE / "usr/lib/codex-device-access"
lib_dir.mkdir(parents=True)
shutil.copy2(BUILD / "AccessOnce.dylib", lib_dir / "AccessOnce.dylib")

(CONTROL / "control").write_text("""Package: local.codex.device-access
Name: Legacy Device Access
Version: 1.1.0
Architecture: iphoneos-arm
Description: Explicit root-operated no-passcode screen access for device tests.
 Version-specific adapters for iOS 4.3.3, 6.1.3 and 7.x. No daemon or boot auto-unlock.
Maintainer: Legacy iPad Tools
Section: Development
Depends: mobilesubstrate, firmware (>= 4.3), firmware (<< 8.0)
""")

doc = STAGE / "usr/share/doc/local.codex.device-access"
doc.mkdir(parents=True)
(doc / "README").write_text(
    "Run over authenticated root SSH: codex-device-access status; "
    "codex-device-access unlock. Explicit lock test: codex-device-access lock. "
    "Configured passcodes are refused. No SUID mode, daemon, listener or startup hook. "
    "Supported OS versions: 4.3.3, 6.1.3 and signature-checked iOS7. "
    "Uninstall: dpkg -r local.codex.device-access.\n"
)
shutil.copy2(ROOT / "COPYING", doc / "COPYING")

build_deb(STAGE, CONTROL, ROOT / "dist/device-access_1.1.0_iphoneos-arm.deb")
print("wrote dist/device-access_1.1.0_iphoneos-arm.deb")
