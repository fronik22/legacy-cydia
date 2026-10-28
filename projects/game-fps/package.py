from pathlib import Path
import shutil,plistlib
from package_deb import build_deb
R=Path(__file__).resolve().parent;B=R/'build';stage=B/'stage';control=B/'control'
for p in [stage,control]:shutil.rmtree(p,ignore_errors=True);p.mkdir(parents=True)
lib=stage/'Library/MobileSubstrate/DynamicLibraries';lib.mkdir(parents=True);shutil.copy2(B/'GameFPS.dylib',lib/'LegacyGameFPS.dylib');(lib/'LegacyGameFPS.plist').write_bytes(plistlib.dumps({'Filter':{'Bundles':['com.team17.worms2','com.team17.worms3','com.chillingo.minigorehd','ms.games.minigore2']}}))
if(B/'Prefs').exists():
 dest=stage/'Library/PreferenceBundles/LegacyGameFPSPrefs.bundle';dest.mkdir(parents=True);shutil.copy2(B/'Prefs',dest/'LegacyGameFPSPrefs')
 for name in ['Root.plist','Info.plist']:shutil.copy2(R/'settings'/name,dest/name)
 dest=stage/'Library/PreferenceLoader/Preferences';dest.mkdir(parents=True);shutil.copy2(R/'settings/LegacyGameFPS.plist',dest/'LegacyGameFPS.plist')
(control/'control').write_text('''Package: local.legacy-game-fps
Name: Legacy Game FPS
Version: 0.2.1
Architecture: iphoneos-arm
Maintainer: Local
Section: Tweaks
Depends: mobilesubstrate, preferenceloader, firmware (>= 6.0), firmware (<< 8.0)
Description: Per-game frame pacing for explicitly verified legacy game builds.
 Reopen supported games after installation; reopen Settings if already running. No respring.
''')
build_deb(stage,control,R/'dist/legacy-game-fps_0.2.1_iphoneos-arm.deb')
