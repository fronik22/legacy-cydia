"""Build deterministic, allowlisted source kits without local SDKs or device data."""
from pathlib import Path, PurePosixPath
import hashlib
import json
import re
import stat
from zipfile import ZipFile, ZipInfo, ZIP_DEFLATED

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'source-archives'
RELEASES = ROOT.parent / 'outputs'
PROJECTS = {
    'amnezia6': ('1.3.4', 'GPL-2.0', 'src app status tools tests third_party packaging'),
    'perfoverlay': ('0.1.12', 'GPL-3.0', 'tweak settings ncsettings probe build-support'),
    'power-logger': ('1.1.1', 'GPL-3.0', 'settings build-support'),
    'game-fps': ('0.2.2', 'GPL-3.0', 'src settings tools'),
    'veteris-ipad': ('1.2.0', 'GPL-3.0', 'src tools tests'),
    'localsend': ('5.7.4340', 'GPL-3.0', 'compat scripts tests packaging Resources Assets vendor'),
    'troubadour': ('1.6.447', 'GPL-3.0', 'src tools ThirdParty Resources layout'),
    'timezone': ('2026e-2', '0BSD; IANA public domain; Unicode data license', 'resources zoneinfo'),
    'device-access': ('1.1.0', 'GPL-3.0', 'src build-support'),
}
EXTENSIONS = set('c h m mm cc cpp hpp hh inc S s py sh ps1 js json plist strings entitlements mk cmake txt TXT md markdown ac am in m4 vc7 bat cfg modulemap pch ipp go yml yaml css html exp cmd supp hook pc tsv png svg ttf der pgm conf vpn service'.split())
NAMES = {'Makefile', 'CMakeLists.txt', 'LICENSE', 'COPYING', 'AUTHORS', 'NOTICE', 'README', 'NEWS', 'ChangeLog', 'VERSION', 'control', 'preinst', 'postinst', 'prerm', 'postrm', 'buildit', 'testit', 'PkgInfo', 'iTunesArtwork', 'iana-LICENSE', 'unicode-data-LICENSE', 'iana-zone.tab'}
EXCLUDED = {'build', 'dist', '.git', '.theos', '__pycache__', 'oldlibs', 'packages', 'observations', 'validation', 'previews', 'screens', 'toolchain', 'sdk'}
BINARY_SUFFIXES = {'.a', '.o', '.dylib', '.bundle', '.deb', '.ipa', '.tbd', '.mobileprovision', '.p12', '.pfx', '.key', '.pem', '.dat', '.log'}
MAGICS = (b'\xcf\xfa\xed\xfe', b'\xce\xfa\xed\xfe', b'\xfe\xed\xfa\xcf', b'\xfe\xed\xfa\xce', b'\xca\xfe\xba\xbe', b'!<arch>\n')


def safe_path(name):
    p = PurePosixPath(name)
    return bool(p.parts) and not p.is_absolute() and '..' not in p.parts and '\\' not in name


def allowed(name, project):
    p = PurePosixPath(name)
    if not safe_path(name):
        return False
    if (project, name) in {('perfoverlay','build-support/libGPUTimeC.tbd'), ('power-logger','build-support/ios7-system-symbols.tbd'), ('device-access','build-support/libAccessC.tbd')}:
        return True
    if any(x in EXCLUDED or x.startswith('build-') or x.endswith('.sdk') for x in p.parts):
        return False
    if re.search(r'(^|\.)private($|\.)', p.name.lower()) or p.suffix in BINARY_SUFFIXES:
        return False
    if project.startswith('timezone') and p.parts[0] in {'resources', 'zoneinfo'}:
        return True
    if project == 'blastron' and name == 'tests/solver-fixture.bin':
        return True
    # LLVM's standard C++ headers intentionally have no extension.
    if 'vendor' in p.parts and 'include' in p.parts and not p.suffix:
        return True
    return p.name in NAMES or p.suffix.lstrip('.') in EXTENSIONS


def check(name, data, project):
    assert allowed(name, project), name
    assert not data.startswith(MAGICS), 'Compiled input: ' + name
    if name.endswith('.tbd'):
        assert len(data)<4096 and re.search(rb"(?m)^install-name:\s*[\"']?/usr/lib/libSystem\.B\.dylib[\"']?\s*$",data), 'Not an owned minimal ABI declaration: '+name
    assert not re.search(rb'-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----\r?\n[A-Za-z0-9+/]{32}', data), 'Private key: ' + name
    keys = re.findall(rb'(?im)^\s*PrivateKey\s*=\s*([A-Za-z0-9+/]{43}=)', data)
    assert not keys or (project == 'amnezia6' and name == 'tests/fixtures/profile.conf' and
        keys == [b'AQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQE=']), 'VPN credential: ' + name
    if project.startswith('timezone') and name.startswith('zoneinfo/'):
        assert data.startswith(b'TZif'), name


def project_files(project, directories):
    root = ROOT / 'projects' / project
    files = {}
    roots = set(directories.split())
    docs = {'README.md', 'README-UPSTREAM.md', 'README-iOS4.md', 'BUILD.md', 'PORTING.md', 'PORT-IOS4.md', 'CYDIA-INSTALLER.md', 'THIRD_PARTY.md', 'PROVENANCE.json', 'SUPPORTED-BUILDS.json', 'TEMPLATE-AUDIT-1.3.3.md', 'IMPORT-NAMES.md', 'KEEPALIVE-AUDIT-1.3.4.md'}
    for path in sorted(root.rglob('*')):
        rel = path.relative_to(root).as_posix()
        if not path.is_file() or path.is_symlink() or not allowed(rel, project):
            continue
        if '/' not in rel:
            if path.suffix in {'.md', '.json'} and path.name not in docs:
                continue
        elif rel.split('/')[0] not in roots:
            continue
        data = path.read_bytes()
        check(rel, data, project)
        files[rel] = (data, bool(path.stat().st_mode & 0o111))
    return files


def released_files(archive, prefix, project, directories, names):
    files = {}
    with ZipFile(RELEASES / archive) as z:
        for item in z.infolist():
            if item.is_dir() or not item.filename.startswith(prefix + '/'):
                continue
            name = item.filename[len(prefix) + 1:]
            if name.split('/')[0] not in directories and name not in names:
                continue
            if not allowed(name, project):
                continue
            assert not stat.S_ISLNK(item.external_attr >> 16), name
            data = z.read(item)
            check(name, data, project)
            files[name] = (data, bool(item.external_attr >> 16 & 0o111))
    return files


def write_archive(project, version, license_name, files, origin):
    assert files and any(n in files for n in ('LICENSE', 'COPYING'))
    assert any(n.endswith(('.c', '.m', '.cpp')) for n in files)
    instructions = ('Source kit: ' + project + ' ' + version + '\nLicense: ' + license_name +
        '\nOrigin: ' + origin + '\n\nIncludes source, build/installation scripts, notices and applicable app resources.\n' +
        'Apple SDKs, linker sysroots/import stubs, signing tools, ARClite, proprietary\n' +
        'games and device/account data are external inputs and are not redistributed.\n' +
        'Use the included build scripts and project documentation; set their SDK,\n' +
        'linker and signer environment variables for your own development setup.\n' +
        'Source availability does not imply a reproducible or device-tested build.\n')
    if project in {'perfoverlay', 'power-logger', 'device-access'}:
        instructions = instructions.replace('sysroots/import stubs', 'sysroots/SDK import stubs')
        instructions += 'Includes the project-owned minimal libSystem ABI declaration in build-support/.\n'
    if project == 'localsend':
        instructions += 'Rebuild HEIC dependencies with scripts/build_heic.py and scripts/build_heic_ios4.py;\nthen scripts/build_heic_ios4_runtime.py, scripts/build_ios4.py and packaging/package_cydia.py.\nThis kit corresponds to 5.7.4340, not an asserted match for the older 0.5.7 direct DEB.\n'
    if project == 'blastron':
        instructions += 'This is released 0.1.15 source, not the unfinished 0.1.16 tree.\nCopy config.example.json to config.json and choose your backend endpoint (at most 27 ASCII bytes).\nSet IOS_SDK, IOS_STUB, IOS_LDID; run build.py Client, build.py Setup, package.py.\nOriginal game assets/catalog are external; this archive does not ship them or account state.\n'
    if project.startswith('timezone'):
        instructions += '2026e-1 is the stable iOS4-6 release; 2026e-2 is the separate iOS7 preview.\nUse the source archive whose version matches the DEB; the preview changes the native ICU adapter and firmware guard.\n'
    files['SOURCE-KIT.txt'] = (instructions.encode(), False)
    inventory = {n: hashlib.sha256(d).hexdigest() for n, (d, _) in sorted(files.items())}
    files['SOURCE-SHA256.json'] = ((json.dumps(inventory, indent=2, sort_keys=True) + '\n').encode(), False)
    path = OUT / f'{project}-{version}-source.zip'
    with ZipFile(path, 'w', compression=ZIP_DEFLATED, compresslevel=9) as z:
        for name, (data, executable) in sorted(files.items()):
            info = ZipInfo(f'{project}/{name}', (1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.external_attr = (stat.S_IFREG | (0o755 if executable else 0o644)) << 16
            z.writestr(info, data, compress_type=ZIP_DEFLATED, compresslevel=9)
    with ZipFile(path) as z:
        assert z.testzip() is None
        assert len(z.namelist()) == len(set(z.namelist())) == len(files)
        for name, digest in inventory.items():
            assert hashlib.sha256(z.read(project + '/' + name)).hexdigest() == digest
    return {'archive': path.name, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
            'bytes': path.stat().st_size, 'files': len(files), 'license': license_name, 'origin': origin}


def main():
    OUT.mkdir(exist_ok=True)
    for name in ('../bad.c', '/bad.c', 'build/bad.c', 'foo.mobileprovision', 'config.private.json', 'sdk/a.h'):
        assert not allowed(name, 'localsend'), name
    for project, name in [('perfoverlay','libGPUTimeC.tbd'), ('power-logger','ios7-system-symbols.tbd'), ('device-access','libAccessC.tbd')]:
        assert allowed('build-support/' + name, project)
        assert not allowed('build-support/SDK.tbd', project)
    try:
        check('secret.c', b'-----BEGIN PRIVATE KEY-----\n' + b'A' * 40, 'localsend')
    except AssertionError:
        pass
    else:
        raise AssertionError('Private key self-check failed')
    manifest = {}
    for project, (version, license_name, directories) in PROJECTS.items():
        files = project_files(project, directories)
        if project == 'localsend':
            for name in ('vendor/libheif-1.18.2/libheif/api/libheif/heif.cc', 'vendor/mbedtls-3.6.7/library/ssl_tls.c', 'vendor/mbedtls-3.6.7/include/mbedtls/private_access.h', 'vendor/libcxxabi-3.5.2.src/src/cxa_exception.cpp', 'vendor/libcxxabi-3.5.2.src/src/private_typeinfo.cpp'):
                assert name in files, name
        if project == 'troubadour':
            assert 'ThirdParty/JSONKit/JSONKit.m' in files
            files['Resources/Roboto-OFL.txt'] = ((OUT / 'notices/Roboto-OFL.txt').read_bytes(), False)
        manifest[project] = write_archive(project, version, license_name, files, 'projects/' + project)
    files = released_files('blastron/0.1.15/blastron-revival-0.1.15-source.zip', 'blastron-revival', 'blastron',
        {'src', 'server'}, {'COPYING', 'build.py', 'package.py', 'package_deb.py', 'aot-map.json', 'extract_catalog.py', 'extract_parts.py', 'test_solver_kernel.py', 'tools/PerfPair.inc', 'tools/SolverKernelTest.c', 'tests/solver-fixture.bin'})
    files['config.example.json'] = (b'{"endpoint": "http://127.0.0.1:18080/", "port": 18080}\n', False)
    assert b"version='0.1.15'" in files['package.py'][0]
    manifest['blastron'] = write_archive('blastron', '0.1.15', 'GPL-3.0', files, 'released 0.1.15 source ZIP; example endpoint replaced with localhost')
    files = released_files('legacy-timezone/LegacyTimezone-2026e-source.zip', 'LegacyTimezone-2026e', 'timezone-stable',
        {'zoneinfo', 'resources'}, {'LICENSE', 'iana-LICENSE', 'unicode-data-LICENSE', 'iana-zone.tab', 'ICUPack.h', 'TimezoneUpdate.m', 'TZProbe.m', 'TestICUPack.m', 'build.py', 'package.py', 'package_deb.py', 'PROVENANCE.json', 'BUILD.md'})
    assert b'2026e-1' in files['package.py'][0]
    manifest['timezone-stable'] = write_archive('timezone-stable', '2026e-1', '0BSD; IANA public domain; Unicode data license', files, 'released LegacyTimezone-2026e-source.zip, source/data-only subset')
    files = released_files('legacy-ipad-tools/legacy-ipad-tools-1.0.0.zip', 'legacy-ipad-tools', 'legacy-ipad-tools',
        {'runtime', 'video-fix', 'vendor', 'compat'}, {'LICENSE', 'prepare_sdk.py', 'package_deb.py'})
    assert 'runtime/build.py' in files and 'video-fix/Legacy60.c' in files
    manifest['legacy-ipad-tools'] = write_archive('legacy-ipad-tools', '1.0.0', 'GPL-3.0; LLVM UIUC/MIT notices', files, 'released legacy-ipad-tools-1.0.0.zip, source-only subset')
    files = released_files('localsend-photos-tweak/LocalSend-Photos-Without-Location-1.0.0-source.zip', 'localsend-photos-tweak', 'localsend-photos',
        {'tests'}, {'LICENSE', 'Policy.h', 'policy_test.c', 'PhotosWithoutLocation.m', 'build.py', 'package.py', 'package_deb.py'})
    manifest['localsend-photos'] = write_archive('localsend-photos', '1.0.0', 'GPL-3.0', files, 'released LocalSend Photos 1.0.0 source ZIP')
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    (OUT / 'SHA256SUMS').write_text(''.join(f"{v['sha256']}  {v['archive']}\n" for _, v in sorted(manifest.items())))
    print(json.dumps({k: {'files': v['files'], 'bytes': v['bytes']} for k, v in manifest.items()}, indent=2))


if __name__ == '__main__':
    main()
