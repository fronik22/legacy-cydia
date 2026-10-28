"""Check universal metadata and 1x/2x legacy iPad assets in the actual IPA."""
import plistlib, struct, sys, zipfile
from pathlib import Path
ipa=Path(sys.argv[1]) if len(sys.argv)>1 else Path(__file__).resolve().parents[1]/'LocalSend-iOS4.3.3-6.ipa'
with zipfile.ZipFile(ipa) as z:
 assert z.testzip() is None
 base='Payload/LocalSend6.app/'
 info=plistlib.loads(z.read(base+'Info.plist'))
 assert info['UIDeviceFamily']==[1,2]
 assert info['MinimumOSVersion']=='4.3'
 assert set(info['UISupportedInterfaceOrientations'])=={'UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight'}
 assert set(info['UISupportedInterfaceOrientations~ipad'])==set(info['UISupportedInterfaceOrientations'])|{'UIInterfaceOrientationPortraitUpsideDown'}
 for scale in (1,2):
  suffix='@2x' if scale==2 else ''
  for filename,size in [(f'Default-Portrait{suffix}~ipad.png',(768*scale,1004*scale)),(f'Default-Landscape{suffix}~ipad.png',(1024*scale,748*scale)),(f'Icon-72{suffix}.png',(72*scale,72*scale))]:
   data=z.read(base+filename);assert data[:8]==b'\x89PNG\r\n\x1a\n'
   assert struct.unpack('!II',data[16:24])==size,filename
  assert f'Icon-72{suffix}.png' in info['CFBundleIconFiles']
 print('PASS universal iPad metadata, portrait/landscape 1x/2x launch images and 72/144px icons; build',info['CFBundleVersion'])
