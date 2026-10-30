#!/usr/bin/env python3
"""Package the built dylib as an old-dpkg-compatible Debian package."""
from pathlib import Path
import plistlib
import shutil
import sys

ROOT = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT))
from package_deb import build_deb

VERSION = '0.1.12'
B = ROOT / 'build'
STAGE = B / 'stage'
CONTROL = B / 'control'
for p in (STAGE, CONTROL):
    shutil.rmtree(p, ignore_errors=True)
    p.mkdir(parents=True)

lib = STAGE / 'Library/MobileSubstrate/DynamicLibraries'
lib.mkdir(parents=True)
shutil.copy2(B / 'PerfOverlay.dylib', lib / 'PerfOverlay.dylib')
(lib / 'PerfOverlay.plist').write_bytes((ROOT / 'tweak/PerfOverlay.plist').read_bytes())

preferences=STAGE/'Library/PreferenceBundles/PerfOverlayPrefs.bundle'
preferences.mkdir(parents=True)
shutil.copy2(B/'PerfOverlayPrefs',preferences/'PerfOverlayPrefs')
for name in ('Info.plist','Root.plist'):shutil.copy2(ROOT/'settings'/name,preferences/name)
loader=STAGE/'Library/PreferenceLoader/Preferences';loader.mkdir(parents=True)
shutil.copy2(ROOT/'settings/PerfOverlay.plist',loader/'PerfOverlay.plist')

# NCSettings scans this folder on iOS 5/6. The toggle is harmless on other
# systems because NCSettings is not present there.
toggle = STAGE / 'var/mobile/Library/NCSettings/Toggles/PerfOverlay'
toggle.mkdir(parents=True)
shutil.copy2(B / 'PerfOverlayToggle.dylib', toggle / 'Toggle.dylib')
for theme in ('Default', 'Blue'):
    for name in ('PerfOverlay', 'HUD'):
        icons = STAGE / 'var/mobile/Library/NCSettings/Themes' / theme / name
        icons.mkdir(parents=True)
        for icon in ('on.png', 'on@2x.png', 'off.png', 'off@2x.png'):
            shutil.copy2(ROOT / 'ncsettings/icons' / theme / name / icon, icons / icon)

(CONTROL / 'control').write_text(f'''Package: local.perfoverlay
Name: Performance Overlay
Version: {VERSION}
Architecture: iphoneos-arm
Description: FPS / CPU / RAM / GPU HUD for iOS 4-9.
 Shows live system counters in a small non-interactive overlay.
 Includes an NCSettings toggle on iOS 5/6.
Maintainer: Local
Section: Tweaks
Depends: mobilesubstrate, preferenceloader, firmware (>= 4.3), firmware (<< 10.0)
''')

(CONTROL / 'postinst').write_text('''#!/bin/sh
set -e
for d in /var/mobile/Library/NCSettings/Toggles/PerfOverlay \\
         /var/mobile/Library/NCSettings/Themes/Default/PerfOverlay \\
         /var/mobile/Library/NCSettings/Themes/Default/HUD \\
         /var/mobile/Library/NCSettings/Themes/Blue/PerfOverlay \\
         /var/mobile/Library/NCSettings/Themes/Blue/HUD; do
    [ -e "$d" ] && chown -R mobile:mobile "$d" 2>/dev/null || true
done
/usr/bin/killall -9 SpringBoard >/dev/null 2>&1 || true
exit 0
''')
(CONTROL / 'postinst').chmod(0o755)

(CONTROL / 'postrm').write_text('''#!/bin/sh
/usr/bin/killall -9 SpringBoard >/dev/null 2>&1 || true
exit 0
''')
(CONTROL / 'postrm').chmod(0o755)

doc = STAGE / 'usr/share/doc/local.perfoverlay'
doc.mkdir(parents=True)
shutil.copy2(ROOT/'COPYING',doc/'COPYING')
(doc/'copyright').write_text('Own code: Copyright 2026 project contributors. GNU GPLv3; see COPYING. Corresponding source/build scripts accompany the repository. No Apple SDK or original game assets included.\n')
(doc / 'README').write_text('''Performance Overlay (PerfOverlay)
----------------------------------
A small HUD for jailbroken iOS 4-9 devices.

Rows:
  FPS   frames composited per second (global CARenderServer counter)
  CPU   system load averaged across all cores (0-100%)
  CPU1/CPU2/... individual core load (0-100% each)
  RAM   active + inactive + wired memory / physical memory
  GPU on  verified iOS7/A7 non-OFF residency; not shader occupancy
  GPUdrv  driver snapshot on other platforms; not calibrated interval load

FPS shows "idle" when fewer than one frame per second is composited.
The overlay is visual only; touches pass through it. It loads only into
SpringBoard. The HUD follows the foreground interface in both landscape
directions, portrait and upside-down portrait.

On iOS 5/6, NCSettings gets a "HUD" toggle. It is added once to the visible
list on first install; removing it later is respected. The state is stored in
com.local.perfoverlay/Enabled and survives a respring.

Settings > Performance HUD: metric switches, corner, font, background opacity,
update interval, and Blastron render target (requires Revival 0.1.10+).
Changes apply live and persist. Disabled metrics stop their sampling.

Remove with: dpkg -r local.perfoverlay.
Diagnostics: /tmp/perfoverlay.log
''')

out = B / f'local.perfoverlay_{VERSION}_iphoneos-arm.deb'
build_deb(STAGE, CONTROL, out)
print(out)
