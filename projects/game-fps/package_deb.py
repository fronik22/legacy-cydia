"""Build old-dpkg-compatible .deb archives using only Python's standard library."""
from pathlib import Path
import gzip,hashlib,io,os,tarfile
EPOCH=1792022400

def archive(folder):
 raw=io.BytesIO()
 with tarfile.open(fileobj=raw,mode='w',format=tarfile.GNU_FORMAT) as tar:
  for p in [folder,*sorted(folder.rglob('*'))]:
   name='.' if p==folder else './'+p.relative_to(folder).as_posix();info=tar.gettarinfo(str(p),arcname=name)
   info.uid=info.gid=0;info.uname='root';info.gname='wheel';info.mtime=EPOCH
   if info.isfile():
    with p.open('rb') as f:tar.addfile(info,f)
   else:tar.addfile(info)
 return gzip.compress(raw.getvalue(),mtime=0)

def build_deb(stage,control,output):
 output.parent.mkdir(parents=True,exist_ok=True)
 payload=[p for p in sorted(stage.rglob('*')) if p.is_file() and not p.is_symlink()]
 (control/'md5sums').write_text(''.join(hashlib.md5(p.read_bytes()).hexdigest()+'  '+p.relative_to(stage).as_posix()+'\n' for p in payload))
 with output.open('wb') as ar:
  ar.write(b'!<arch>\n')
  for name,data in [('debian-binary',b'2.0\n'),('control.tar.gz',archive(control)),('data.tar.gz',archive(stage))]:
   header=f'{name+"/":<16}{0:<12}{0:<6}{0:<6}{100644:<8}{len(data):<10}`\n'.encode();assert len(header)==60
   ar.write(header);ar.write(data)
   if len(data)%2:ar.write(b'\n')
 print(output)
