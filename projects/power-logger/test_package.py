from pathlib import Path
import io,tarfile,struct
R=Path(__file__).resolve().parent
raw=(R/'dist/local.legacypower_1.1.1_iphoneos-arm.deb').read_bytes();assert raw[:8]==b'!<arch>\n';at=8;members={}
while at<len(raw):
 h=raw[at:at+60];n=int(h[48:58]);name=h[:16].decode().strip().rstrip('/');members[name]=raw[at+60:at+60+n];at+=60+n+(n%2)
assert set(members)=={'debian-binary','data.tar.gz','control.tar.gz'}
with tarfile.open(fileobj=io.BytesIO(members['data.tar.gz']),mode='r:gz')as t:
 for remote,local in [('usr/libexec/legacypowerd','build/Powerd'),('Library/PreferenceBundles/LegacyPowerPrefs.bundle/LegacyPowerPrefs','build/Prefs.bundle')]:
  binary=t.extractfile('./'+remote).read();assert binary==(R/local).read_bytes();assert struct.unpack_from('>I',binary)[0]==0xcafebabe;arches={struct.unpack_from('>I',binary,8+i*20)[0]for i in range(struct.unpack_from('>I',binary,4)[0])};assert arches=={12,0x100000c}
 assert not any('profile' in n.lower()or n.endswith('.conf')or'private'in n.lower()for n in t.getnames())
 assert not any('com.local.legacypower.plist'in n for n in t.getnames()),'Do not ship enabled user preferences'
with tarfile.open(fileobj=io.BytesIO(members['control.tar.gz']),mode='r:gz')as t:
 control=t.extractfile('./control').read();assert b'firmware (<< 8.0)'in control
 for script in ('postinst','prerm','preinst'):
  s=t.extractfile('./'+script).read();assert b'SpringBoard'not in s and b'reboot'not in s
  assert b'--running'in s
print('Final DEB identity, gzip compatibility, default-OFF profile exclusion and scoped lifecycle scripts passed')

assert "dynamic_lookup"not in (R/"build.py").read_text(),"Executables must bind standard symbols explicitly"
