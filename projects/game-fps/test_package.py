from pathlib import Path
import unittest,struct,io,tarfile,plistlib,re
R=Path(__file__).resolve().parent
class Package(unittest.TestCase):
 def test_profiles_match_settings(self):
  profiles=re.findall(r'\{"([^" ]+)","([^" ]+)","([0-9a-f]{64})","([^" ]+)",(YES|NO)\}',(R/'src/GameFPS.m').read_text())
  self.assertEqual(len(profiles),4)
  self.assertEqual(len({p[0]for p in profiles}),4)
  cells={x['key']:x for x in plistlib.loads((R/'settings/Root.plist').read_bytes())['items']if x.get('key')}
  for _,_,_,key,_ in profiles:
   self.assertEqual(cells[key]['validValues'],[0,1])
   self.assertEqual(cells[key]['default'],0)
  self.assertEqual(cells['BlastronFPS']['validValues'],[-1,30,60])
 def test_release_payload_and_scope(self):
  raw=(R/'dist/legacy-game-fps_0.2.1_iphoneos-arm.deb').read_bytes();self.assertEqual(raw[:8],b'!<arch>\n');pos=8;members={}
  while pos<len(raw):
   h=raw[pos:pos+60];size=int(h[48:58]);members[h[:16].decode().strip().rstrip('/')]=raw[pos+60:pos+60+size];pos+=60+size+(size%2)
  with tarfile.open(fileobj=io.BytesIO(members['data.tar.gz']),mode='r:gz')as t:
   files={x.name.removeprefix('./'):t.extractfile(x).read()for x in t if x.isfile()}
  binary=files['Library/MobileSubstrate/DynamicLibraries/LegacyGameFPS.dylib'];self.assertEqual(binary,(R/'build/GameFPS.dylib').read_bytes());self.assertIn(b'MSHookFunction',binary);self.assertNotIn(b'draw_stack',binary);self.assertNotIn(b'logicMilliseconds',binary)
  self.assertEqual(plistlib.loads(files['Library/MobileSubstrate/DynamicLibraries/LegacyGameFPS.plist'])['Filter']['Bundles'],['com.team17.worms2','com.team17.worms3','com.chillingo.minigorehd','ms.games.minigore2'])
  self.assertFalse(any('var/tmp/'in n or'original.private'in n or'Worms2iPhone.app/'in n for n in files))
  root=plistlib.loads(files['Library/PreferenceBundles/LegacyGameFPSPrefs.bundle/Root.plist']);cells=[x for x in root['items']if x.get('key')];self.assertEqual(len(cells),5)
  for x in cells:self.assertEqual(len(x['validValues']),len(x['validTitles']));self.assertIn(x['default'],x['validValues'])
  pos=28;versions=[]
  for _ in range(struct.unpack_from('<I',binary,16)[0]):
   cmd,size=struct.unpack_from('<II',binary,pos)
   if cmd==0x25:versions.append(struct.unpack_from('<I',binary,pos+8)[0])
   pos+=size
  self.assertEqual(versions,[0x60000]);self.assertEqual(struct.unpack_from('<I',binary,4)[0],12,'Verified native hooks must stay armv7')
if __name__=='__main__':unittest.main()
