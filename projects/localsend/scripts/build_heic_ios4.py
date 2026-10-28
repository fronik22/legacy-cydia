"""Build bundled HEIC decoder archives for armv7/iOS 4.3, without a system C++ runtime."""
import os,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];SDK=Path(os.environ['IOS4_SDK']);PREFIX=ROOT/'vendor/heic-ios4';BUILD=ROOT/'build-ios4/heic-archives';HEADERS=ROOT/'vendor/libcxx-3.5-headers/include'
flags=f'-nostdinc++ -I"{HEADERS}" -Wno-deprecated-builtins -Wno-reserved-user-defined-literal'
common=['-G','Ninja','-DCMAKE_POLICY_VERSION_MINIMUM=3.5','-DCMAKE_SYSTEM_NAME=iOS',f'-DCMAKE_OSX_SYSROOT={SDK}','-DCMAKE_OSX_ARCHITECTURES=armv7','-DCMAKE_OSX_DEPLOYMENT_TARGET=4.3','-DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY',f'-DCMAKE_CXX_FLAGS={flags}','-DCMAKE_BUILD_TYPE=Release',f'-DCMAKE_INSTALL_PREFIX={PREFIX}','-DBUILD_SHARED_LIBS=OFF']
for name,extra in [('libde265-1.0.16',['-DENABLE_SDL=OFF','-DENABLE_DECODER=OFF','-DENABLE_ENCODER=OFF']),('libheif-1.18.2',[f'-DLIBDE265_INCLUDE_DIR={PREFIX}/include',f'-DLIBDE265_LIBRARY={PREFIX}/lib/libde265.a','-DENABLE_PLUGIN_LOADING=OFF','-DWITH_EXAMPLES=OFF','-DWITH_GDK_PIXBUF=OFF','-DBUILD_TESTING=OFF','-DWITH_X265=OFF','-DWITH_AOM_DECODER=OFF','-DWITH_AOM_ENCODER=OFF','-DWITH_LIBSHARPYUV=OFF','-DENABLE_MULTITHREADING_SUPPORT=OFF','-DENABLE_PARALLEL_TILE_DECODING=OFF'])]:
 build=BUILD/name
 with (ROOT/'build-ios4'/f'{name}-ios4-build.log').open('w') as log:
  for cmd in [['cmake','-S',str(ROOT/'vendor'/name),'-B',str(build),*common,*extra],['cmake','--build',str(build),'-j6'],['cmake','--install',str(build)]]:subprocess.run(cmd,check=True,stdout=log,stderr=subprocess.STDOUT)
 print('Built',name,flush=True)
