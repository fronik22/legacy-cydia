#!/usr/bin/env python3
"""Build a device playback regression probe; restore the release source/binary.

Sign and install build-ios4/Troubadour-playback-test in the existing app bundle.
Keep the iPad unlocked, make no taps, and capture syslog's [Troubadour/Test].
Success is ALL PASS; FAIL or a crash fails the check. The public test video
must remain playable and at least four minutes long. Do not ship the test binary.
"""
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
delegate = ROOT / 'src/YTAppDelegate.m'
original = delegate.read_bytes()
source = original.decode()
assert source.count('@implementation YTAppDelegate') == 1
source = source.replace('@implementation YTAppDelegate', '''@interface UIViewController (CodexPlaybackTest)
- (void)restartForTrackChangeAt:(NSTimeInterval)time;
- (void)playPauseTapped;
@end
@implementation YTAppDelegate''', 1)
source = source.replace('    return YES;', '''    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [YTNav openVideo:@"DrACJvV8GbI" title:@"iOS 4 playback check" playlist:nil resumeAt:66];
        [self performSelector:@selector(codexPlaybackSample) withObject:nil afterDelay:5];
    });
    return YES;''', 1)
end = source.rfind('@end')
source = source[:end] + (ROOT / 'tools/ios4-playback-check.inc').read_text() + '\n' + source[end:]
try:
    delegate.write_text(source)
    subprocess.run([sys.executable, str(ROOT / 'tools/build-ios4.py')], check=True)
    shutil.copy2(ROOT / 'build-ios4/Troubadour', ROOT / 'build-ios4/Troubadour-playback-test')
finally:
    delegate.write_bytes(original)
    subprocess.run([sys.executable, str(ROOT / 'tools/build-ios4.py')], check=True)
print('Device probe: build-ios4/Troubadour-playback-test (release binary restored)')
