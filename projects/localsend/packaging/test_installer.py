"""Run actual maintainer scripts in a temporary command/filesystem fixture."""
from pathlib import Path
import io,os,shlex,subprocess,tarfile,tempfile,unittest,zipfile,hashlib
from ipa_package import scripts,build
class InstallerTests(unittest.TestCase):
 def setUp(self):
  self.temp=tempfile.TemporaryDirectory();self.r=Path(self.temp.name);self.tools=self.r/'bin';self.tools.mkdir();self.apps=self.r/'Applications';self.apps.mkdir();self.log=self.r/'calls'
  self.env=dict(os.environ,PATH=str(self.tools)+':'+os.environ['PATH'],FW='7.1.2',TEST_LOG=str(self.log),APPINST_RC='0')
  self.command('dpkg-query','#!/bin/sh\nprintf "%s" "$FW"\n')
  self.command('dpkg','''#!/usr/bin/env python3
import sys
try:a=tuple(int(x)for x in sys.argv[2].split('.'));b=tuple(int(x)for x in sys.argv[4].split('.'));sys.exit(0 if (a>=b if sys.argv[3]=='ge' else a<b)else 1)
except Exception:sys.exit(2)
''')
  self.command('appinst','#!/bin/sh\nprintf "%s\\n" "$*" >> "$TEST_LOG"\nexit "$APPINST_RC"\n')
  self.text=scripts('LocalSend','5.7.4340','com.unlocalsend.ios6',['LocalSend6','LocalSend'])
  for name,text in self.text.items():
   text=text.replace('/Applications/',str(self.apps)+'/').replace('/usr/bin/appinst',str(self.tools/'appinst'))
   (self.r/name).write_text(text)
 def tearDown(self):self.temp.cleanup()
 def command(self,name,text):p=self.tools/name;p.write_text(text);p.chmod(0o755)
 def runscript(self,name,arg):return subprocess.run(['/bin/sh',str(self.r/name),arg],env=self.env,capture_output=True)
 def test_os_gate(self):
  for value,expected in [('4.3.3',False),('5.0',True),('6.1.3',True),('7.0',True),('7.1.2',True),('8.0',False),('bad',False)]:
   self.env['FW']=value;self.assertEqual(self.runscript('preinst','install').returncode==0,expected,value)
 def test_refuse_duplicate_without_touching_data(self):
  existing=self.apps/'LocalSend6.app';existing.mkdir();f=existing/'sentinel';f.write_text('preserve');self.assertNotEqual(self.runscript('preinst','install').returncode,0);self.assertEqual(f.read_text(),'preserve');self.assertFalse(self.log.exists())
 def test_call_installer_once_and_propagate_failure(self):
  self.assertEqual(self.runscript('postinst','configure').returncode,0);self.assertEqual(self.log.read_text().splitlines(),['/usr/share/legacy-ipa/com.unlocalsend.ios6/application.ipa']);self.env['APPINST_RC']='19';self.assertEqual(self.runscript('postinst','configure').returncode,19)
 def test_nonconfigure_and_removal_do_not_install_or_remove(self):
  keep=self.r/'Documents';keep.mkdir();(keep/'data').write_text('preserve');self.assertEqual(self.runscript('postinst','abort-upgrade').returncode,0);self.assertEqual(self.runscript('prerm','remove').returncode,0);self.assertFalse(self.log.exists());self.assertEqual((keep/'data').read_text(),'preserve');self.assertNotIn('rm ',self.text['prerm'])
class InputValidationTests(unittest.TestCase):
 def badzip(self,kind):
  with tempfile.TemporaryDirectory()as folder:
   r=Path(folder);ipa=r/'bad.ipa';license=r/'LICENSE';license.write_text('test')
   import plistlib
   info={'CFBundleIdentifier':'com.unlocalsend.ios6','CFBundleVersion':'WRONG'if kind=='version'else'5.7.4340','CFBundleExecutable':'LocalSend6'}
   with zipfile.ZipFile(ipa,'w')as z:
    z.writestr('Payload/LocalSend6.app/Info.plist',plistlib.dumps(info))
    e=zipfile.ZipInfo('Payload/LocalSend6.app/LocalSend6');e.external_attr=0o100755<<16;z.writestr(e,b'fixture')
    if kind=='traversal':z.writestr('../outside','refuse')
    if kind=='symlink':
     e=zipfile.ZipInfo('Payload/LocalSend6.app/link');e.external_attr=0o120777<<16;z.writestr(e,'/outside')
   with self.assertRaises(AssertionError):build(r,ipa,'local.codex.localsend-installer','com.unlocalsend.ios6','5.7.4340','LocalSend',['LocalSend6'],license)
   self.assertFalse((r/'dist').exists())
 def test_wrong_build_rejected_before_output(self):self.badzip('version')
 def test_archive_traversal_rejected_before_output(self):self.badzip('traversal')
 def test_archive_symlink_rejected_before_output(self):self.badzip('symlink')
if __name__=='__main__':unittest.main()
