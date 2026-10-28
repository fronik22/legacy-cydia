from pathlib import Path
import os,sys,subprocess
R=Path(__file__).resolve().parent;B=R/'build';B.mkdir(exist_ok=True)
SDK=Path(os.environ.get('IOS_SDK','/Users/mak/Documents/work/iPhoneOS9.3.sdk'))
STUB=Path(os.environ.get('IOS_STUB','/Users/mak/Documents/Codex/2026-10-09/new-chat/work/legacy-ipad-tools/build/sdk'))
SDK64=Path(os.environ.get('IOS_ARM64_SDK',str(R.parent/'perfoverlay/build/sdk-arm64')))
SIGNER=os.environ.get('IOS_LDID','/Users/mak/Documents/Codex/2026-07-01/new-chat/work/oldpipe-toolchain/ldid')
name=sys.argv[1];kind='dylib'if name=='GameFPS'else'bundle'if name in ('Prefs','SettingsOpen')else'exe';src=R/('src'if kind=='dylib'else'settings'if name=='Prefs'else'tools')/(name+'.m');final=B/(name+('.dylib'if kind=='dylib'else'.bundle'if name=='SettingsOpen'else''))
arches=['armv7','arm64']if name=='Prefs'else['armv7'];slices=[]
for arch in arches:
 sdk=SDK64 if arch=='arm64'else SDK;stub=SDK64 if arch=='arm64'else STUB;version='7.0'if arch=='arm64'else'6.0';obj=B/(name+'.'+arch+'.o');output=B/(name+'.'+arch)
 commands=[['xcrun','clang','-target',arch+'-apple-ios'+version,'-isysroot',sdk,'-fno-objc-arc','-fblocks','-Os','-Wall','-Wno-deprecated-declarations',*(['-DFPS_DIAGNOSTIC']if name=='GameFPS'and os.environ.get('FPS_DIAGNOSTIC')=='1'else[]),'-c',src,'-o',obj],['xcrun','ld-classic','-arch',arch,'-iphoneos_version_min',version,'-syslibroot',stub,'-L'+str(stub/'usr/lib'),'-F'+str(stub/'System/Library/PrivateFrameworks'),*(['-dylib','-install_name','/Library/MobileSubstrate/DynamicLibraries/LegacyGameFPS.dylib']if kind=='dylib'else['-bundle']if kind=='bundle'else['-no_pie',sdk/'usr/lib/crt1.3.1.o']),'-o',output,obj,'-framework','Foundation','-framework','UIKit','-framework','QuartzCore','-framework','CoreFoundation',*(['-framework','Preferences']if kind=='bundle'else[]),'-lobjc','-lSystem',*(['-lgcc_s.1']if arch=='armv7'else[])]]
 for i,cmd in enumerate(commands):
  p=subprocess.run(list(map(str,cmd)),capture_output=True,text=True);(B/f'{name}-{arch}-{i}.log').write_text(p.stdout+p.stderr)
  if p.returncode:raise RuntimeError(p.stderr[-5000:])
 slices.append(output)
subprocess.run(['xcrun','lipo','-create',*map(str,slices),'-output',str(final)],check=True)if len(slices)>1 else __import__('shutil').copyfile(slices[0],final)
subprocess.run([SIGNER,'-Cadhoc','-Hsha1','-S'+str(R/'tools/launch-entitlements.plist')if name=='Launch'else'-S',str(final)],check=True)
print(final)
