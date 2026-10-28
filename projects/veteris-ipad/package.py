from pathlib import Path
import shutil, plistlib

ROOT = Path(__file__).resolve().parent
from package_deb import build_deb
VERSION = (ROOT / 'VERSION').read_text().strip()

B = ROOT / 'build'
stage, control = B / 'stage', B / 'control'
for p in (stage, control):
    shutil.rmtree(p, ignore_errors=True)
    p.mkdir(parents=True)
lib = stage / 'Library/MobileSubstrate/DynamicLibraries'
lib.mkdir(parents=True)
shutil.copy2(B / 'VeterisIPad.dylib', lib / 'VeterisIPad.dylib')
(lib / 'VeterisIPad.plist').write_bytes(plistlib.dumps({'Filter': {'Bundles': ['com.victorlobe.veteris']}}))
setup = stage / 'usr/libexec/veteris-ipad-setup'
setup.parent.mkdir(parents=True)
shutil.copy2(B / 'Setup', setup)
setup.chmod(0o755)
(control / 'control').write_text(f'''Package: local.codex.veteris-ipad
Name: Veteris Native iPad
Version: {VERSION}
Architecture: iphoneos-arm
Maintainer: Legacy iPad Tools
Author: Legacy iPad Tools
Section: Tweaks
Depends: firmware (>= 5.0), firmware (<< 8.0), mobilesubstrate (>= 0.9.5000), com.victorlobe.veteris (= 4)
Description: Native iPad layout and suspension crash fix for Veteris 4.
 Removes iPhone compatibility sizing, fixes storyboard selection, and adapts
 home and application-list layouts. Fixes SGX shader-cache suspension kills
 so Veteris's existing background download support can work normally.
''')
(control / 'postinst').write_text('''#!/bin/sh
set -e
/usr/libexec/veteris-ipad-setup apply
/usr/bin/killall Veteris >/dev/null 2>&1 || true
su mobile -c /usr/bin/uicache
echo "Respring to reload the iPad application metadata."
''')
(control / 'prerm').write_text('''#!/bin/sh
set -e
case "$1" in
    remove|deconfigure)
        /usr/libexec/veteris-ipad-setup remove
        /usr/bin/killall Veteris >/dev/null 2>&1 || true
        su mobile -c /usr/bin/uicache
        echo "Respring to restore the original application mode."
        ;;
esac
''')
(control / 'postrm').write_text('''#!/bin/sh
rmdir /var/lib/veteris-ipad 2>/dev/null || true
exit 0
''')
for name in ('postinst', 'prerm', 'postrm'):
    (control / name).chmod(0o755)
doc = stage / 'usr/share/doc/local.codex.veteris-ipad'
doc.mkdir(parents=True)
(doc / 'README').write_text('Veteris 4 native iPad mode, adaptive layout and app-only SGX shader disk cache suspension fix. Reuses native background support. iOS 7 uses the layout hooks without the iOS 6-only SGX cache workaround. Only iOS 6.1.3/iPad 2 is hardware-tested; iOS 7 build/API audit is not device layout validation. Requires a respring after install/remove. Remove this package before upgrading Veteris beyond version 4. Original metadata keys are restored on removal; application data is untouched. No daemon, background polling or SpringBoard hooks. Portrait interface follows the original app orientation policy. Source and verification accompany the release.\n')
shutil.copy2(ROOT / 'COPYING', doc / 'COPYING')
build_deb(stage, control, ROOT / ('dist/veteris-ipad_' + VERSION + '_iphoneos-arm.deb'))
