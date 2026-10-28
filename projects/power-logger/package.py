from pathlib import Path
import plistlib,shutil,sys
R=Path(__file__).resolve().parent;sys.path.insert(0,str(R));from package_deb import build_deb
B=R/'build';S=B/'stage';C=B/'control'
for p in(S,C):shutil.rmtree(p,ignore_errors=True);p.mkdir(parents=True)
def copy(src,path,mode=0o644):
 p=S/path;p.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,p);p.chmod(mode)
copy(B/'Powerd','usr/libexec/legacypowerd',0o755)
copy(B/'Prefs.bundle','Library/PreferenceBundles/LegacyPowerPrefs.bundle/LegacyPowerPrefs',0o755)
for name in ('Root.plist','Info.plist'):copy(R/'settings'/name,'Library/PreferenceBundles/LegacyPowerPrefs.bundle/'+name)
copy(R/'settings/LegacyPower.plist','Library/PreferenceLoader/Preferences/LegacyPower.plist')
launch={'Label':'com.local.legacypowerd','ProgramArguments':['/usr/libexec/legacypowerd'],'RunAtLoad':True,'KeepAlive':True,'ThrottleInterval':30,'ProcessType':'Background'}
p=S/'Library/LaunchDaemons/com.local.legacypowerd.plist';p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(plistlib.dumps(launch))
(C/'control').write_text('''Package: local.legacypower
Name: Power Logger
Version: 1.1.0
Architecture: iphoneos-arm
Section: Utilities
Maintainer: Local
Depends: preferenceloader, firmware (>= 6.0), firmware (<< 8.0)
Description: Switchable local battery and per-process CPU logger for iOS6-7 (armv7/arm64).
 Records signed battery current, charging, process CPU, GPU and traffic.
 No per-app watt claims, network probes or wake assertions. Bounded logs.
''')
for name,body in {
 'preinst':'''launchctl unload /Library/LaunchDaemons/com.local.legacypowerd.plist >/dev/null 2>&1 || true
if [ -x /usr/libexec/legacypowerd ] && /usr/libexec/legacypowerd --running >/dev/null 2>&1; then
 pid=$(cat /var/run/legacypowerd.lock)
 case "$pid" in ''|*[!0-9]*) ;; *) kill -TERM "$pid" >/dev/null 2>&1 || true ;; esac
fi
sleep 1
''',
 'postinst':'''mkdir -p /var/mobile/Library/Logs/LegacyPower
chown root:mobile /var/mobile/Library/Logs/LegacyPower
chmod 0750 /var/mobile/Library/Logs/LegacyPower
launchctl load /Library/LaunchDaemons/com.local.legacypowerd.plist >/dev/null 2>&1 || true
sleep 1
/usr/libexec/legacypowerd --running >/dev/null 2>&1 || /usr/libexec/legacypowerd --daemonize
''',
 'prerm':'''launchctl unload /Library/LaunchDaemons/com.local.legacypowerd.plist >/dev/null 2>&1 || true
if [ -x /usr/libexec/legacypowerd ] && /usr/libexec/legacypowerd --running >/dev/null 2>&1; then
 pid=$(cat /var/run/legacypowerd.lock)
 case "$pid" in ''|*[!0-9]*) ;; *) kill -TERM "$pid" >/dev/null 2>&1 || true ;; esac
fi
# Keep recordings and the user's preferences on removal.
'''
}.items():
 p=C/name;p.write_text('#!/bin/sh\nset -e\n'+body+'exit 0\n');p.chmod(0o755)
if(R/'README.md').exists():copy(R/'README.md','usr/share/doc/local.legacypower/README.md')
build_deb(S,C,R/'dist/local.legacypower_1.1.0_iphoneos-arm.deb')
