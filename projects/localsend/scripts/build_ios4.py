"""Build the armv7 iOS 4.3–6 port with an external Apple SDK/ARClite."""
import concurrent.futures, os, re, subprocess, sys, json, shutil, plistlib, zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BUILD=ROOT/'build-ios4';BUILD.mkdir(exist_ok=True)
SDK=Path(os.environ['IOS4_SDK']);ARCLITE=Path(os.environ['IOS4_ARCLITE']);LDID=os.environ['IOS4_LDID']
STUB=BUILD/'sdk';CLANG=subprocess.check_output(['xcrun','--find','clang'],text=True).strip()
def symbols(text,key):
 return re.findall(r'\b'+key+r':\s*\[([^]]*)\]',text,re.S)

def prepare():
 for f in SDK.rglob('*.tbd'):
  dst=STUB/f.relative_to(SDK); dst.parent.mkdir(parents=True,exist_ok=True)
  text=f.read_text();text=re.sub(r'    re-exports:\s*\[[^]]*\]\n','',text,flags=re.S)
  dst.write_text(text)
 # Resolve libc symbols through libSystem on the target OS, not modern sublibraries.
 syms=set()
 for f in (SDK/'usr/lib/system').glob('*.tbd'):
  for group in symbols(f.read_text(),'symbols'):
   syms.update(x.strip() for x in group.split(',') if x.strip())
 syms.update(['_start','dyld_stub_binder','_bzero','_memchr','_memcmp','_memcpy','_memmove','_memset','_strchr','_strcmp','_strncmp'])
 text='---\narchs: [ armv7 ]\nplatform: ios\ninstall-name: /usr/lib/libSystem.B.dylib\ncompatibility-version: 1\nexports:\n  - archs: [ armv7 ]\n    symbols: [ '+', '.join(sorted(syms))+' ]\n...\n'
 (STUB/'usr/lib/libSystem.tbd').write_text(text)

 # ARM compiler helpers were exported by libgcc_s on iOS 4.
 gcc=json.loads((ROOT/'compat/gcc-symbols.json').read_text())
 f=STUB/'usr/lib/libSystem.tbd';text=f.read_text()
 for name in gcc:text=re.sub(re.escape(name)+r'\s*,\s*','',text)
 f.write_text(text)
 (STUB/'usr/lib/libgcc_s.1.tbd').write_text('---\narchs: [ armv7 ]\nplatform: ios\ninstall-name: /usr/lib/libgcc_s.1.dylib\nexports:\n  - archs: [ armv7 ]\n    symbols: [ '+', '.join(gcc)+' ]\n...\n')
 # NSObject lived in CoreFoundation before iOS 6.
 f=STUB/'usr/lib/libobjc.tbd';text=f.read_text();text=re.sub(r'(?<!\w)_NSObject\s*,\s*','',text);text=re.sub(r'_NSObject[.]isa\s*,\s*','',text);text=text.replace('    symbols:', '    symbols:', 1)
 text=text.replace('...','  - archs: [ armv7 ]\n    symbols: [ __objc_empty_vtable, _objc_loadClassref ]\n...')
 f.write_text(text)
 for framework,classes,extra in [('CoreFoundation',['_NSObject'],[]),('UIKit',['_UIFont'],['_NSFontAttributeName','_NSForegroundColorAttributeName']),('AVFoundation',['_AVAudioSession'],[])]:
  f=STUB/f'System/Library/Frameworks/{framework}.framework/{framework}.tbd'
  text=f.read_text();addition='  - archs: [ armv7 ]\n    objc-classes: [ '+', '.join(classes)+' ]\n'
  if framework=='CoreFoundation':addition+='    objc-ivars: [ _NSObject.isa ]\n'
  if extra:addition+='    symbols: [ '+', '.join(extra)+' ]\n'
  f.write_text(text.replace('...',addition+'...'))

 # Network Objective-C classes lived in Foundation on iOS 4.
 network=['_NSHTTPCookie','_NSHTTPCookieStorage','_NSHTTPURLResponse','_NSURLProtocol','_NSURLConnection','_NSURLRequest','_NSMutableURLRequest','_NSURLResponse','_NSURLCache','_NSCachedURLResponse','_NSURLAuthenticationChallenge','_NSURLCredential','_NSURLProtectionSpace']
 f=STUB/'System/Library/Frameworks/CFNetwork.framework/CFNetwork.tbd';text=f.read_text()
 for name in network:text=re.sub(re.escape(name)+r'\s*,\s*','',text)
 f.write_text(text)
 f=STUB/'System/Library/Frameworks/Foundation.framework/Foundation.tbd'
 text=f.read_text().replace('...','  - archs: [ armv7 ]\n    objc-classes: [ '+', '.join(network)+' ]\n...');f.write_text(text)



 # Authentication constants also lived in Foundation on iOS 4.
 f=STUB/'System/Library/Frameworks/CFNetwork.framework/CFNetwork.tbd';text=f.read_text()
 names=sorted(set(re.findall(r'_NSURLAuthenticationMethod\w+|_NSURLErrorDomain',text)))
 for name in names:text=re.sub(re.escape(name)+r'\s*,\s*','',text)
 f.write_text(text)
 f=STUB/'System/Library/Frameworks/Foundation.framework/Foundation.tbd'
 text=f.read_text().replace('...','  - archs: [ armv7 ]\n    symbols: [ '+', '.join(names)+' ]\n...');f.write_text(text)

def run(command,log):
 r=subprocess.run(list(map(str,command)),capture_output=True,text=True)
 (BUILD/log).write_text(r.stdout+r.stderr)
 if r.returncode:raise RuntimeError(str(log)+'\n'+r.stderr[-12000:])

def compile_one(source):
 obj=BUILD/(str(source.relative_to(ROOT)).replace('/','_')+('.diagnostic' if '--diagnostics' in sys.argv and source.name=='AppDelegate.m' else '')+'.o')
 if obj.exists() and obj.stat().st_mtime>=max(source.stat().st_mtime,(ROOT/'compat/LSLegacy.h').stat().st_mtime):return obj
 flags=['-target','armv7-apple-ios4.3','-isysroot',str(SDK),'-O2','-g','-fblocks','-fvisibility=hidden','-Wno-deprecated-declarations','-Wno-arc-retain-cycles']
 if source.suffix=='.m':
  flags+=['-fobjc-arc','-Xclang','-fobjc-runtime-has-weak']
  if '--diagnostics' in sys.argv:flags+=['-DLS_DEVICE_CHECKS']
  if source.name in ['JSONKit.m','MAZeroingWeakRef.m']:flags+=['-fno-objc-arc','-Wno-everything']
  if source.parent==ROOT or source.parent.name=='compat':flags+=['-include',str(ROOT/'compat/LSLegacy.h')]
 flags+=['-DMBEDTLS_PLATFORM_MS_TIME_ALT']
 for p in [ROOT,ROOT/'compat',ROOT/'compat/JSONKit',ROOT/'compat/PLWeakCompatibility/PLWeakCompatibility',ROOT/'vendor/mbedtls-3.6.7/include',ROOT/'vendor/mbedtls-3.6.7/library',ROOT/'vendor/mbedtls-3.6.7/3rdparty/everest/include',ROOT/'vendor/mbedtls-3.6.7/3rdparty/p256-m',ROOT/'vendor/mbedtls-3.6.7/3rdparty/p256-m/p256-m']:flags+=['-I'+str(p)]
 r=subprocess.run([CLANG,*flags,'-c',str(source),'-o',str(obj)],capture_output=True,text=True)
 (BUILD/(obj.name+'.log')).write_text(r.stderr)
 if r.returncode:raise RuntimeError(source.name+'\n'+r.stderr)
 return obj
prepare()
run([sys.executable,ROOT/'scripts/build_heic_ios4_runtime.py'],'heic-runtime-build.log')
if not (ROOT/'vendor/heic-ios4/lib/libheif.a').exists():
 run([sys.executable,ROOT/'scripts/build_heic_ios4.py'],'heic-archives-build.log')
app_sources=[ROOT/n for n in ['main.m','AppDelegate.m','LSLocalization.m','LSDesign.m','LSFilesystemPicker.m','LSMediaPicker.m','LSReceiver.m','LSPhotoImporter.m','LSClock.c','LSTransport.m','LSConnection.m','LSIdentity.m']]
mbed=[ROOT/n for n in re.findall(r'vendor/[^\s\\]+[.]c',(ROOT/'mbedtls-sources.mk').read_text())]
if '--diagnostics' in sys.argv:app_sources+=[ROOT/'scripts/UIDiagnostics.m']
sources=app_sources+mbed+list((ROOT/'compat').glob('*.m'))+[ROOT/'compat/LSHEICLegacy.c',ROOT/'compat/JSONKit/JSONKit.m',ROOT/'compat/PLWeakCompatibility/PLWeakCompatibility/PLWeakCompatibilityStubs.m',ROOT/'compat/PLWeakCompatibility/PLWeakCompatibility/MAZeroingWeakRef.m']
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:objects=list(pool.map(compile_one,sources))
print('Compiled',len(objects),'sources',flush=True)
(BUILD/'objects.txt').write_text('\n'.join(map(str,objects)))
frameworks=['Foundation','CoreFoundation','UIKit','CoreGraphics','QuartzCore','ImageIO','AssetsLibrary','AVFoundation','CoreMedia','Security','CFNetwork','MobileCoreServices']
cmd=['xcrun','ld-classic','-arch','armv7','-iphoneos_version_min','4.3','-no_pie','-syslibroot',STUB,'-L'+str(STUB/'usr/lib'),'-F'+str(STUB/'System/Library/Frameworks'),'-o',BUILD/'LocalSend6',SDK/'usr/lib/crt1.3.1.o','-force_load',ARCLITE,'-filelist',BUILD/'objects.txt','-weak-lobjc','-lgcc_s.1','-lSystem','-lstdc++','-U','_OBJC_CLASS_$_NSObject','-U','_OBJC_METACLASS_$_NSObject']
for fw in frameworks:cmd+=['-framework',fw]
run(cmd,'link.log')
# Preserve the upstream HEIC decoder on iOS 6 without requiring libc++ at iOS 4 startup.
run([CLANG,'-target','armv7-apple-ios6.0','-isysroot',SDK,'-O2','-I'+str(ROOT/'vendor/heic-ios/include'),'-c',ROOT/'LSHEICDecoder.c','-o',BUILD/'LSHEIC.o'],'heic-compile.log')
run(['xcrun','ld-classic','-dylib','-arch','armv7','-iphoneos_version_min','6.0','-syslibroot',STUB,'-L'+str(STUB/'usr/lib'),'-L'+str(ROOT/'vendor/heic-ios/lib'),'-o',BUILD/'LSHEIC.dylib',BUILD/'LSHEIC.o','-lheif','-lde265','-lc++','-lc++abi','-lgcc_s.1','-lSystem','-framework','CoreFoundation','-framework','CoreGraphics'],'heic-link.log')
# iOS 4/5 use an isolated, statically bundled C++ runtime; no system-library install.
run([CLANG,'-target','armv7-apple-ios4.3','-isysroot',SDK,'-O2','-I'+str(ROOT/'vendor/heic-ios4/include'),'-c',ROOT/'LSHEICDecoder.c','-o',BUILD/'LSHEIC4.o'],'heic4-compile.log')
run(['xcrun','ld-classic','-dylib','-arch','armv7','-iphoneos_version_min','4.3','-dead_strip','-exported_symbol','_LSDecodeHEIC','-install_name','@loader_path/LSHEIC4.dylib','-syslibroot',STUB,'-L'+str(STUB/'usr/lib'),'-L'+str(ROOT/'vendor/heic-ios4/lib'),'-o',BUILD/'LSHEIC4.dylib',BUILD/'LSHEIC4.o','-lheif','-lde265',BUILD/'heic-runtime/libcxx-private.a','-lgcc_s.1','-lSystem','-framework','CoreFoundation','-framework','CoreGraphics'],'heic4-link.log')
app=BUILD/'Payload/LocalSend6.app';shutil.rmtree(app.parent,ignore_errors=True);shutil.copytree(ROOT/'Resources',app)
info=plistlib.loads((ROOT/'Info.plist').read_bytes());info['MinimumOSVersion']='4.3';info['CFBundleVersion']='5.7.4340';info['CFBundleShortVersionString']='0.5.7-ios4';info['CFBundleDisplayName']='LocalSend';info['CFBundleSupportedPlatforms']=['iPhoneOS']
(app/'Info.plist').write_bytes(plistlib.dumps(info));shutil.copy2(BUILD/'LocalSend6',app/'LocalSend6');shutil.copy2(BUILD/'LSHEIC.dylib',app/'LSHEIC.dylib');shutil.copy2(BUILD/'LSHEIC4.dylib',app/'LSHEIC4.dylib')
shutil.copy2(ROOT/'LICENSE',app/'LICENSE.txt')
run([LDID,'-Cadhoc','-Hsha1','-S',app/'LSHEIC4.dylib'],'sign-heic4.log');run([LDID,'-Cadhoc','-Hsha1','-S',app/'LSHEIC.dylib'],'sign-heic.log');run([LDID,'-Cadhoc','-Hsha1','-S'+str(ROOT/'LocalSend6.entitlements'),app/'LocalSend6'],'sign.log')
output=ROOT/('LocalSend-iOS4.3.3-6-diagnostic.ipa' if '--diagnostics' in sys.argv else 'LocalSend-iOS4.3.3-6.ipa')
with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as z:
 for file in sorted(app.rglob('*')):
  if file.is_file():z.write(file,'Payload/LocalSend6.app/'+file.relative_to(app).as_posix())
with zipfile.ZipFile(output) as z:
 assert z.testzip() is None
 assert plistlib.loads(z.read('Payload/LocalSend6.app/Info.plist'))['MinimumOSVersion']=='4.3'
 assert plistlib.loads(z.read('Payload/LocalSend6.app/Info.plist'))['UIDeviceFamily']==[1,2]
 assert z.getinfo('Payload/LocalSend6.app/LocalSend6').external_attr>>16&0o111
print(output,flush=True)
if '--checks' in sys.argv:
 test=compile_one(ROOT/'scripts/legacy_checks.m')
 checks=[o for o in objects if o.name not in ['main.m.o','AppDelegate.m.o']]+[test]
 (BUILD/'check-objects.txt').write_text('\n'.join(map(str,checks)))
 checkcmd=[str(x).replace(str(BUILD/'LocalSend6'),str(BUILD/'legacy-checks')).replace(str(BUILD/'objects.txt'),str(BUILD/'check-objects.txt')) for x in cmd]
 run(checkcmd,'check-link.log');run([LDID,'-Cadhoc','-Hsha1','-S',BUILD/'legacy-checks'],'check-sign.log')
 print('Native test helper built',flush=True)
