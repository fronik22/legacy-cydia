"""Build the nonpersistent metrics CLI for either legacy architecture."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from build import ROOT,B,SDK,STUB,LDID,prepare_arm64_sdk,run
arch=sys.argv[1]if len(sys.argv)>1 else'arm64'
assert arch in ('armv7','arm64')
name=sys.argv[2]if len(sys.argv)>2 else'native-metrics'
assert name in ('native-metrics','gpu-time-native') and len(sys.argv)<=3
sdk=prepare_arm64_sdk()if arch=='arm64'else SDK;stub=sdk if arch=='arm64'else STUB;version='7.0'if arch=='arm64'else'4.3'
obj=B/(name+'.'+arch+'.o');out=B/(name+'.'+arch)
run(['xcrun','clang','-target',arch+'-apple-ios'+version,'-isysroot',sdk,'-fno-objc-arc','-fblocks','-Os','-Wall','-Wno-deprecated-declarations','-c',ROOT/'probe'/(name+'.m'),'-o',obj])
run(['xcrun','ld-classic','-arch',arch,'-iphoneos_version_min',version,'-syslibroot',stub,'-L'+str(stub/'usr/lib'),*(['-e','_main']if arch=='arm64'else['-no_pie',SDK/'usr/lib/crt1.3.1.o']),'-o',out,obj,'-framework','UIKit','-framework','Foundation','-framework','QuartzCore','-framework','CoreGraphics','-framework','CoreFoundation','-lobjc','-lSystem',*(['-lgcc_s.1']if arch=='armv7'else['-L'+str(ROOT/'build-support'),'-lGPUTimeC'])])
run([LDID,'-Cadhoc','-Hsha1','-S',out]);print(out)
