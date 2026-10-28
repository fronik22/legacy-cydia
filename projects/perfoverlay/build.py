#!/usr/bin/env python3
"""Build PerfOverlay for armv7/iOS 4.3+ (and an arm64 slice for iOS 7+)."""
from pathlib import Path
import os
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
B = ROOT / 'build'
B.mkdir(exist_ok=True)

SDK = Path(os.environ.get('IOS4_SDK', '/Users/mak/Documents/work/iPhoneOS9.3.sdk'))
STUB = Path(os.environ.get('IOS4_STUB',
    '/Users/mak/Documents/Codex/2026-10-09/new-chat/work/legacy-ipad-tools/build/sdk'))
LDID = Path(os.environ.get('IOS4_LDID',
    '/Users/mak/Documents/Codex/2026-07-01/new-chat/work/oldpipe-toolchain/ldid'))

SRC = ROOT / 'tweak' / 'PerfOverlay.m'
TOGGLE_SRC = ROOT / 'ncsettings' / 'Toggle.m'
INSTALL_NAME = '/Library/MobileSubstrate/DynamicLibraries/PerfOverlay.dylib'
TOGGLE_INSTALL_NAME = '/usr/lib/PerfOverlayToggle.dylib'
ARM64_SDK = B / 'sdk-arm64'


def prepare_arm64_sdk():
    """The 9.3 SDK's libSystem re-exports /usr/lib/system/liblaunch.dylib,
    but the SDK omits that stub. Add an empty arm64 stub in a local copy."""
    if not ARM64_SDK.exists():
        print('+ copying iOS SDK for arm64 link overlay')
        shutil.copytree(SDK, ARM64_SDK, symlinks=True)
    stub = ARM64_SDK / 'usr/lib/system/liblaunch.tbd'
    if not stub.exists():
        stub.write_text("""--- !tapi-tbd-v2
archs:                   [ arm64 ]
platform:                ios
install-name:            '/usr/lib/system/liblaunch.dylib'
current-version:         1
compatibility-version:   1
exports:
  - archs:               [ arm64 ]
    symbols:             [ ]
...
""")
    return ARM64_SDK


def run(cmd):
    print('+', ' '.join(map(str, cmd)))
    p = subprocess.run(list(map(str, cmd)), capture_output=True, text=True)
    (B / 'last-build.log').write_text(p.stdout + p.stderr)
    if p.returncode:
        sys.stderr.write(p.stderr[-6000:])
        raise SystemExit(p.returncode)


def build_armv7():
    obj = B / 'PerfOverlay.armv7.o'
    out = B / 'PerfOverlay.armv7.dylib'
    run(['xcrun', 'clang', '-target', 'armv7-apple-ios4.3', '-isysroot', SDK,
         '-fno-objc-arc', '-Os', '-Wall', '-Wno-deprecated-declarations',
         '-c', SRC, '-o', obj])
    run(['xcrun', 'ld-classic', '-dylib', '-arch', 'armv7', '-iphoneos_version_min', '4.3',
         '-install_name', INSTALL_NAME, '-syslibroot', STUB, '-L' + str(STUB / 'usr/lib'),
         '-o', out, obj, '-framework', 'UIKit', '-framework', 'Foundation',
         '-framework', 'QuartzCore', '-framework', 'CoreGraphics', '-framework', 'CoreFoundation',
         '-lobjc', '-lSystem', '-lgcc_s.1'])
    run([LDID, '-Cadhoc', '-Hsha1', '-S', out])
    return out


def build_toggle():
    """NCSettings runs on armv7 iOS 6 only; no arm64 slice is needed."""
    obj = B / 'PerfOverlayToggle.armv7.o'
    out = B / 'PerfOverlayToggle.dylib'
    run(['xcrun', 'clang', '-target', 'armv7-apple-ios4.3', '-isysroot', SDK,
         '-fno-objc-arc', '-Os', '-Wall', '-Wno-deprecated-declarations',
         '-c', TOGGLE_SRC, '-o', obj])
    run(['xcrun', 'ld-classic', '-dylib', '-arch', 'armv7', '-iphoneos_version_min', '4.3',
         '-install_name', TOGGLE_INSTALL_NAME, '-syslibroot', STUB, '-L' + str(STUB / 'usr/lib'),
         '-o', out, obj, '-framework', 'Foundation', '-framework', 'CoreFoundation',
         '-lobjc', '-lSystem', '-lgcc_s.1'])
    run([LDID, '-Cadhoc', '-Hsha1', '-S', out])
    return out


def build_arm64():
    sdk = prepare_arm64_sdk()
    obj = B / 'PerfOverlay.arm64.o'
    out = B / 'PerfOverlay.arm64.dylib'
    run(['xcrun', 'clang', '-target', 'arm64-apple-ios7.0', '-isysroot', sdk,
         '-fno-objc-arc', '-Os', '-Wall', '-Wno-deprecated-declarations',
         '-c', SRC, '-o', obj])
    run(['xcrun', 'ld-classic', '-dylib', '-arch', 'arm64', '-iphoneos_version_min', '7.0',
         '-install_name', INSTALL_NAME, '-syslibroot', sdk, '-L' + str(sdk / 'usr/lib'),
         '-o', out, obj, '-framework', 'UIKit', '-framework', 'Foundation',
         '-framework', 'QuartzCore', '-framework', 'CoreGraphics', '-framework', 'CoreFoundation',
         '-lobjc', '-lSystem'])
    run([LDID, '-Cadhoc', '-Hsha1', '-S', out])
    return out


def build_preferences():
    slices=[]
    for arch,version,sdk,stub in [('armv7','4.3',SDK,STUB),('arm64','7.0',prepare_arm64_sdk(),prepare_arm64_sdk())]:
        obj=B/('PerfOverlayPrefs.'+arch+'.o');out=B/('PerfOverlayPrefs.'+arch)
        run(['xcrun','clang','-target',arch+'-apple-ios'+version,'-isysroot',sdk,'-fno-objc-arc','-Os','-Wall','-Wno-deprecated-declarations','-c',ROOT/'settings/PerfOverlayPrefs.m','-o',obj])
        run(['xcrun','ld-classic','-bundle','-arch',arch,'-iphoneos_version_min',version,'-syslibroot',stub,'-L'+str(stub/'usr/lib'),'-F'+str(stub/'System/Library/PrivateFrameworks'),'-o',out,obj,'-framework','Preferences','-framework','UIKit','-framework','Foundation','-framework','CoreFoundation','-lobjc','-lSystem',*(['-lgcc_s.1'] if arch=='armv7' else [])])
        slices.append(out)
    final=B/'PerfOverlayPrefs';run(['lipo','-create',*slices,'-output',final]);run([LDID,'-Cadhoc','-Hsha1','-S',final])
    return final


def main():
    armv7 = build_armv7()
    arm64 = build_arm64()
    final = B / 'PerfOverlay.dylib'
    run(['lipo', '-create', armv7, arm64, '-output', final])
    run([LDID, '-Cadhoc', '-Hsha1', '-S', final])
    run(['file', final])
    run(['xcrun', 'lipo', '-info', final])
    run(['xcrun', 'otool', '-l', final])
    preferences = build_preferences()
    print(preferences)
    toggle = build_toggle()
    run(['file', toggle])
    run(['xcrun', 'otool', '-L', toggle])
    print(final)
    print(toggle)


if __name__ == '__main__':
    main()
