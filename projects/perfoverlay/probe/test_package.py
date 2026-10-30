"""Verify the exact distributable, not only staging files."""
from pathlib import Path
import io,tarfile,struct
R=Path(__file__).resolve().parents[1]
raw=(R/'build/local.perfoverlay_0.1.12_iphoneos-arm.deb').read_bytes();assert raw[:8]==b'!<arch>\n';at=8;parts={}
while at<len(raw):
 h=raw[at:at+60];n=int(h[48:58]);name=h[:16].decode().strip().rstrip('/');parts[name]=raw[at+60:at+60+n];at+=60+n+(n%2)
assert set(parts)=={'debian-binary','data.tar.gz','control.tar.gz'}
with tarfile.open(fileobj=io.BytesIO(parts['data.tar.gz']))as t:
 for path,local in [('Library/MobileSubstrate/DynamicLibraries/PerfOverlay.dylib','build/PerfOverlay.dylib'),('Library/PreferenceBundles/PerfOverlayPrefs.bundle/PerfOverlayPrefs','build/PerfOverlayPrefs')]:
  binary=t.extractfile('./'+path).read();assert binary==(R/local).read_bytes();assert struct.unpack_from('>I',binary)[0]==0xcafebabe
  arches={}
  for i in range(struct.unpack_from('>I',binary,4)[0]):
   cpu,subtype,off,size,align=struct.unpack_from('>IIIII',binary,8+i*20);b=binary[off:off+size];pos=32 if cpu&0x1000000 else 28;minimum=None
   for _ in range(struct.unpack_from('<I',b,16)[0]):
    cmd,n=struct.unpack_from('<II',b,pos)
    if cmd==0x25:minimum=struct.unpack_from('<I',b,pos+8)[0]
    pos+=n
   arches[cpu]=minimum
  assert arches=={12:0x40300,0x100000c:0x70000},arches
 assert t.extractfile('./usr/share/doc/local.perfoverlay/COPYING').read()==(R/'COPYING').read_bytes()
 assert not any('.sdk/'in n or'Preferences/com.local.perfoverlay.plist'in n for n in t.getnames())
print('HUD exact payload, armv7/iOS4.3 +arm64/iOS7 minima, license and no shipped user preferences passed')
