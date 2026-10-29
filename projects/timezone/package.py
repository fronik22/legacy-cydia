"""Assemble the distributable data update; never includes Apple's ICU data."""
from pathlib import Path
import hashlib, os, plistlib, shutil
from package_deb import build_deb
R=Path(__file__).resolve().parent
stage=R/'build/stage';control=R/'build/control'
for p in (stage,control):
 if p.exists():shutil.rmtree(p)
 p.mkdir(parents=True)
payload=stage/'usr/share/legacy-timezone';payload.mkdir(parents=True)
shutil.copytree(R/'zoneinfo',payload/'zoneinfo')
(payload/'zoneinfo/+VERSION').write_text('2026e\n')
shutil.copy2(R/'iana-zone.tab',payload/'zoneinfo/zone.tab')
shutil.copytree(R/'resources',payload/'resources')
licenses=payload/'licenses';licenses.mkdir()
for n in ('iana-LICENSE','unicode-data-LICENSE'):shutil.copy2(R/n,licenses/n)
manifest={p.relative_to(payload).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for folder in ('zoneinfo','resources') for p in sorted((payload/folder).rglob('*')) if p.is_file()}
(payload/'files.plist').write_bytes(plistlib.dumps(manifest,fmt=plistlib.FMT_XML,sort_keys=True))
bins=stage/'usr/local/bin';bins.mkdir(parents=True)
for source,target in [('TimezoneUpdate','legacy-timezone'),('TZProbe','legacy-timezone-check')]:
 shutil.copy2(R/'build'/source,bins/target);(bins/target).chmod(0o755)
(control/'control').write_text('''Package: local.codex.legacy-timezone
Name: Legacy Timezone Update
Version: 2026e-2
Architecture: iphoneos-arm
Depends: firmware (>= 4.3), firmware (<< 8.0), gsc.armv7
Section: System
Priority: optional
Maintainer: Legacy iOS compatibility project
Description: IANA 2026e time rules for iOS 4.3-7 on armv7 devices.
 Updates system and ICU timezone data, including Russian UTC offsets.
 Preserves chosen timezone and UTC clock. Removal restores original data.
''')
finish = r'''
fd=${CYDIA%% *}
case "$fd" in
 ''|*[!0-9]*) ;;
 *) eval "printf 'finish:reboot\n' >&$fd" 2>/dev/null || true ;;
esac
'''
scripts={
 'postinst':'case "$1" in configure) /usr/local/bin/legacy-timezone apply ;; *) exit 0 ;; esac',
 'prerm':'case "$1" in remove|deconfigure) if [ -f /var/lib/legacy-timezone/backup/receipt.plist ]; then /usr/local/bin/legacy-timezone restore; fi ;; *) exit 0 ;; esac'
}
for name,body in scripts.items():
 p=control/name;p.write_text('#!/bin/sh\nset -e\n'+body+'\n'+finish);p.chmod(0o755)
out=Path(os.environ.get('OUTPUT_DIR',str(R/'dist')));out.mkdir(parents=True,exist_ok=True)
file=out/'local.codex.legacy-timezone_2026e-2_iphoneos-arm.deb'
build_deb(stage,control,file)
(out/'SHA256SUMS').write_text(hashlib.sha256(file.read_bytes()).hexdigest()+'  '+file.name+'\n')
print(f'{len(manifest)} verified data files; {file.stat().st_size} bytes')
