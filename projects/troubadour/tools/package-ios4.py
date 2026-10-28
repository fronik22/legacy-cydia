#!/usr/bin/env python3
"""Package a built iOS 4 binary with the original release's artwork."""
import argparse
import os
from pathlib import Path, PurePosixPath
import plistlib
import shutil
import stat
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def safe_path(name):
    path = PurePosixPath(name)
    if path.is_absolute() or '..' in path.parts or '\\' in name:
        raise ValueError('Unsafe archive path: ' + name)
    return path


def package(original, output):
    binary = ROOT / 'build-ios4/Troubadour'
    if not binary.is_file():
        raise FileNotFoundError('Run tools/build-ios4.py first')
    signer = os.environ.get('TROUBADOUR_LDID') or shutil.which('ldid')
    if not signer:
        raise RuntimeError('Set TROUBADOUR_LDID to your ldid executable')
    with tempfile.TemporaryDirectory(prefix='troubadour-ios4-') as temporary:
        staging = Path(temporary)
        with zipfile.ZipFile(original) as archive:
            for entry in archive.infolist():
                relative = safe_path(entry.filename)
                if stat.S_ISLNK(entry.external_attr >> 16):
                    raise ValueError('Symlink in release archive: ' + entry.filename)
                if relative.parts[:2] != ('Payload', 'Troubadour.app'):
                    continue
                destination = staging / str(relative)
                if entry.is_dir():
                    destination.mkdir(parents=True, exist_ok=True)
                else:
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    destination.write_bytes(archive.read(entry))
        app = staging / 'Payload/Troubadour.app'
        info_path = app / 'Info.plist'
        info = plistlib.loads(info_path.read_bytes())
        if info['CFBundleIdentifier'] != 'ru.computershik.troubadour':
            raise ValueError('Unexpected bundle identifier')
        info['MinimumOSVersion'] = '4.3'
        info['CFBundleVersion'] = '1.6.447'
        info['UIRequiredDeviceCapabilities'] = ['armv7']
        for obsolete in ['_CodeSignature', 'CodeResources', 'embedded.mobileprovision', 'legacy-ca.pem']:
            path = app / obsolete
            if path.is_dir():
                shutil.rmtree(path)
            else:
                path.unlink(missing_ok=True)
        shutil.copytree(ROOT / 'Resources', app, dirs_exist_ok=True)
        info_path.write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_BINARY))
        executable = app / info['CFBundleExecutable']
        shutil.copyfile(binary, executable)
        executable.chmod(0o755)
        if (app / 'iconswitch').exists():
            (app / 'iconswitch').chmod(0o755)
        subprocess.run([signer, '-Cadhoc', '-Iru.computershik.troubadour', '-Hsha1', '-S', str(executable)], check=True)
        output.parent.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(staging.rglob('*')):
                if path.is_file():
                    archive.write(path, path.relative_to(staging))
        with zipfile.ZipFile(output) as archive:
            assert archive.testzip() is None
            assert plistlib.loads(archive.read('Payload/Troubadour.app/Info.plist'))['MinimumOSVersion'] == '4.3'
            for resource in ['legacy-es3.js', 'legacy-es5.js', 'JSONKit-LICENSE.txt', 'PLWeakCompatibility-LICENSE.txt']:
                assert archive.read('Payload/Troubadour.app/' + resource)
    print(output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('original', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    package(args.original, args.output)
