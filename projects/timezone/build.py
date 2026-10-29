from pathlib import Path
import subprocess,sys
import json,os
r=Path(__file__).resolve().parent
build=r/'build';build.mkdir(exist_ok=True)
private=r/'toolchain.private.json'
config=json.loads(private.read_text()) if private.exists() else {}
def setting(env,key):
 value=os.environ.get(env) or config.get(key)
 if not value:raise SystemExit('Set '+env+' (see README)')
 return value
sdk=Path(setting('IOS_SDK','sdk'));stub=Path(setting('IOS_LINK_SYSROOT','linkSysroot'));signer=setting('LDID','ldid')
name=sys.argv[1];bundle='--bundle' in sys.argv;source=r/(name+'.m');obj=build/(name+'.o');output=build/(name+('.bundle' if bundle else ''))
commands=[['xcrun','clang','-target','armv7-apple-ios4.3','-isysroot',str(sdk),'-fno-objc-arc','-fblocks','-Os','-Wno-deprecated-declarations','-c',str(source),'-o',str(obj)],['xcrun','ld-classic',*(['-bundle'] if bundle else []),'-arch','armv7','-iphoneos_version_min','4.3','-syslibroot',str(stub),'-L'+str(stub/'usr/lib'),'-o',str(output),*([str(sdk/'usr/lib/crt1.3.1.o')] if not bundle else []),str(obj),'-framework','Foundation','-framework','CoreFoundation','-lobjc','-lSystem','-lgcc_s.1'],[signer,'-Cadhoc','-Hsha1','-S',str(output)]]
for i,args in enumerate(commands):
 p=subprocess.run(args,capture_output=True,text=True);(build/f'{name}-build-{i}.log').write_text(p.stdout+p.stderr);assert not p.returncode,p.stderr
