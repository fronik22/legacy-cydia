from pathlib import Path
import subprocess,sys,os,shutil
R=Path(__file__).resolve().parent
SDK=Path(os.environ.get('IOS_SDK','/Users/mak/Documents/work/iPhoneOS9.3.sdk'));STUB=Path(os.environ.get('IOS_STUB','/Users/mak/Documents/Codex/2026-10-09/new-chat/work/legacy-ipad-tools/build/sdk'));LDID=Path(os.environ.get('IOS_LDID','/Users/mak/Documents/Codex/2026-07-01/new-chat/work/oldpipe-toolchain/ldid'));SDK64=Path(os.environ.get('IOS_ARM64_SDK',str(R.parent/'perfoverlay/build/sdk-arm64')))
def build(name,kind='exe',frameworks=(),entitlements=None):
 out=R/'build';out.mkdir(exist_ok=True);binary=out/(name+('.bundle'if kind=='bundle'else''));slices=[]
 for arch in ('armv7','arm64'):
  sdk=SDK64 if arch=='arm64'else SDK;stub=SDK64 if arch=='arm64'else STUB;version='7.0'if arch=='arm64'else'6.0';obj=out/(name+'.'+arch+'.o');target=out/(name+'.'+arch)
  entry=['-bundle']if kind=='bundle'else ['-e','_main']if arch=='arm64'else ['-no_pie',SDK/'usr/lib/crt1.3.1.o']
  commands=[['xcrun','clang','-target',arch+'-apple-ios'+version,'-isysroot',sdk,'-fno-objc-arc','-fblocks','-Os','-Wall','-Wextra','-Wno-unused-parameter','-Wno-deprecated-declarations','-c',R/(name+'.m'),'-o',obj],['xcrun','ld-classic','-arch',arch,'-iphoneos_version_min',version,'-syslibroot',stub,'-L'+str(stub/'usr/lib'),'-F'+str(stub/'System/Library/PrivateFrameworks'),*entry,'-o',target,obj,'-framework','Foundation','-framework','CoreFoundation',*[a for f in frameworks for a in ['-framework',f]],'-lobjc','-lSystem',*(['-lgcc_s.1']if arch=='armv7'else[]),*([R/'build-support/ios7-system-symbols.tbd']if arch=='arm64'else[])]]
  for i,c in enumerate(commands):
   p=subprocess.run(list(map(str,c)),capture_output=True);(out/(name+'-'+arch+'-'+str(i)+'.log')).write_bytes(p.stdout+p.stderr)
   if p.returncode:raise RuntimeError(p.stderr.decode())
  slices.append(target)
 subprocess.run(['xcrun','lipo','-create',*map(str,slices),'-output',str(binary)],check=True)
 subprocess.run([str(LDID),'-Cadhoc','-Hsha1','-S'+str(entitlements)if entitlements else'-S',str(binary)],check=True)
 return binary
if __name__=='__main__':
 for name in sys.argv[1:]or['Powerd','Prefs']:
  if name not in('Powerd','Prefs','Probe','SettingsProbe','SettingsLoadProbe'):raise SystemExit('Unknown build target')
  print(build(name,'bundle'if name in('Prefs','SettingsProbe')else'exe',['Preferences','UIKit']if name=='Prefs'else['UIKit','CoreGraphics']if name=='SettingsProbe'else[]))
