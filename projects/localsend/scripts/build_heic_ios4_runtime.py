"""Build an app-private LLVM 3.5 C++ runtime for the legacy HEIC module."""
import os,subprocess,concurrent.futures
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];BUILD=ROOT/'build-ios4/heic-runtime';BUILD.mkdir(parents=True,exist_ok=True)
SDK=Path(os.environ['IOS4_SDK']);CXX=ROOT/'vendor/libcxx-3.5-runtime';ABI=ROOT/'vendor/libcxxabi-3.5.2.src';HEADERS=ROOT/'vendor/libcxx-3.5-headers/include'
flags=['-target','armv7-apple-ios4.3','-isysroot',str(SDK),'-nostdinc++','-std=c++11','-Os','-fvisibility=hidden','-fvisibility-inlines-hidden','-D_LIBCPP_BUILDING_LIBRARY','-D_LIBCXXABI_BUILDING_LIBRARY','-I'+str(HEADERS),'-I'+str(ABI/'include'),'-Wno-deprecated-builtins','-Wno-reserved-user-defined-literal','-Wno-deprecated-declarations','-Wno-unevaluated-expression']
sources=list((CXX/'src').glob('*.cpp'))+list((ABI/'src').glob('*.cpp'))
def compile(source):
 obj=BUILD/(source.parent.parent.name+'-'+source.stem+'.o')
 if obj.exists() and obj.stat().st_mtime>=source.stat().st_mtime:return obj
 p=subprocess.run(['xcrun','clang++',*flags,'-c',str(source),'-o',str(obj)],capture_output=True,text=True);(obj.with_suffix('.log')).write_text(p.stderr)
 if p.returncode:raise RuntimeError(source.name+'\n'+p.stderr[-5000:])
 return obj
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:objects=list(pool.map(compile,sources))
subprocess.run(['xcrun','libtool','-static','-o',str(BUILD/'libcxx-private.a'),*map(str,objects)],check=True)
print(BUILD/'libcxx-private.a')
