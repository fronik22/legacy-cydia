import concurrent.futures, os, re, subprocess, sys, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BUILD=ROOT/'build-ios4'
BUILD.mkdir(exist_ok=True)
SDK=Path(os.environ['TROUBADOUR_IOS_SDK'])
STUB=BUILD/'sdk'
CLANG=subprocess.check_output(['xcrun','--find','clang'],text=True).strip()
ARCLITE=Path(os.environ['TROUBADOUR_ARCLITE'])

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
 gcc=json.loads((ROOT/'tools/gcc-symbols.json').read_text())
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

def compile_one(source):
 obj=BUILD/(str(source.relative_to(ROOT)).replace('/','_')+'.o') if source.is_relative_to(ROOT) else BUILD/(source.stem+'.o')
 header=ROOT/'src/compat/YTLegacy.h'
 if obj.exists() and obj.stat().st_mtime>=max(source.stat().st_mtime,header.stat().st_mtime if header.exists() else 0):return obj
 flags=['-target','armv7-apple-ios4.3','-isysroot',str(SDK),'-O1','-g','-fblocks','-Wno-everything','-fvisibility=hidden']
 if source.suffix=='.m':
  flags+=['-fobjc-arc','-Xclang','-fobjc-runtime-has-weak','-include',str(ROOT/'src/YTLog.h')]
  if source.name in ['JSONKit.m','MAZeroingWeakRef.m']: flags+=['-fno-objc-arc']
 flags+=['-I'+str(p) for p in (ROOT/'src').rglob('*') if p.is_dir()]
 flags+=['-I'+str(ROOT/'src'),'-I'+str(ROOT/'ThirdParty/JSONKit'),'-I'+str(ROOT/'ThirdParty/PLWeakCompatibility/PLWeakCompatibility')]
 if (ROOT/'src/compat/YTLegacy.h').exists(): flags+=['-include',str(ROOT/'src/compat/YTLegacy.h')]
 r=subprocess.run([CLANG,*flags,'-c',str(source),'-o',str(obj)],capture_output=True,text=True)
 return obj if not r.returncode else (source,r.stderr)

prepare()
sources=sorted((ROOT/'src').rglob('*.m'))+sorted((ROOT/'src/warp').glob('*.c'))
sources += [ROOT/'ThirdParty/PLWeakCompatibility/PLWeakCompatibility/PLWeakCompatibilityStubs.m',ROOT/'ThirdParty/JSONKit/JSONKit.m']
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
 results=list(pool.map(compile_one,sources))
errors=[r for r in results if isinstance(r,tuple)]
for source,error in errors:print(source.relative_to(ROOT.parent),error,sep='\n')
print('Compiled',len(results)-len(errors),'/',len(results))
if errors:sys.exit(1)
(BUILD/'objects.txt').write_text('\n'.join(map(str,results)))

frameworks=['Foundation','CoreFoundation','UIKit','CoreGraphics','QuartzCore','ImageIO','AVFoundation','CoreMedia','MediaPlayer','Security','SystemConfiguration','CoreText','CFNetwork']
cmd=['xcrun','ld-classic','-arch','armv7','-iphoneos_version_min','4.3','-no_pie','-syslibroot',str(STUB),'-L'+str(STUB/'usr/lib'),'-F'+str(STUB/'System/Library/Frameworks'),'-o',str(BUILD/'Troubadour'),str(SDK/'usr/lib/crt1.3.1.o'),'-force_load',str(ARCLITE),'-filelist',str(BUILD/'objects.txt'),'-weak-lobjc','-lgcc_s.1','-lSystem','-lstdc++','-weak_framework','AVKit','-U','_OBJC_CLASS_$_NSObject','-U','_OBJC_METACLASS_$_NSObject']
for fw in frameworks:cmd+=['-framework',fw]
cmd += ['-lz']
r=subprocess.run(cmd,capture_output=True,text=True);(BUILD/'link.log').write_text(r.stdout+r.stderr)
print('Link exit',r.returncode);sys.exit(r.returncode)
