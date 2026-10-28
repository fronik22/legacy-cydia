from pathlib import Path
import os, subprocess, sys

ROOT = Path(__file__).resolve().parent
SDK = Path(os.environ['IOS_SDK'])
STUB = Path(os.environ['IOS_STUB'])
SIGNER = os.environ['IOS_LDID']
B = ROOT / 'build'
B.mkdir(exist_ok=True)
name = sys.argv[1]
kind = {'Launch': 'exe', 'Inspect': 'bundle', 'BackgroundTest': 'bundle', 'Setup': 'exe', 'VeterisIPad': 'dylib'}[name]
source = ROOT / ('tools' if name in ('Launch', 'Inspect', 'BackgroundTest') else 'src') / (name + '.m')
output = B / (name + {'exe': '', 'bundle': '.bundle', 'dylib': '.dylib'}[kind])
commands = [
    ['xcrun', 'clang', '-target', 'armv7-apple-ios5.0', '-isysroot', SDK, '-fno-objc-arc', '-fblocks', '-Os', '-Wno-deprecated-declarations', '-c', source, '-o', B / (name + '.o')],
    ['xcrun', 'ld-classic', '-arch', 'armv7', '-iphoneos_version_min', '5.0', '-syslibroot', STUB, '-L' + str(STUB / 'usr/lib'), '-o', output,
     *({'exe': ['-no_pie', SDK / 'usr/lib/crt1.3.1.o'], 'bundle': ['-bundle'], 'dylib': ['-dylib', '-install_name', '/Library/MobileSubstrate/DynamicLibraries/VeterisIPad.dylib']}[kind]), B / (name + '.o'),
     '-framework', 'Foundation', '-framework', 'CoreFoundation', '-framework', 'UIKit', '-framework', 'CoreGraphics', '-framework', 'QuartzCore', '-lobjc', '-lSystem', '-lgcc_s.1'],
    [SIGNER, '-Cadhoc', '-Hsha1', '-S' + str(ROOT / 'tools/launch-entitlements.plist') if name == 'Launch' else '-S', output],
]
for i, args in enumerate(commands):
    p = subprocess.run(list(map(str, args)), capture_output=True, text=True)
    (B / (name + '-' + str(i) + '.log')).write_text(p.stdout + p.stderr)
    if p.returncode:
        raise RuntimeError(p.stderr[-4000:])
print(output)
