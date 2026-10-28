"""Generate legacy portrait/landscape iPad launch backgrounds and native 72/144px icons."""
from pathlib import Path
import struct, subprocess, zlib
root=Path(__file__).resolve().parents[1]
def chunk(kind,data):
 return struct.pack('!I',len(data))+kind+data+struct.pack('!I',zlib.crc32(kind+data)&0xffffffff)
for scale in (1,2):
 suffix='@2x' if scale==2 else ''
 for orientation,(width,height) in {'Portrait':(768,1004),'Landscape':(1024,748)}.items():
  w,h=width*scale,height*scale
  pixels=(b'\0'+bytes((243,250,248))*w)*h
  png=b'\x89PNG\r\n\x1a\n'+chunk(b'IHDR',struct.pack('!2I5B',w,h,8,2,0,0,0))+chunk(b'IDAT',zlib.compress(pixels,9))+chunk(b'IEND',b'')
  (root/f'Resources/Default-{orientation}{suffix}~ipad.png').write_bytes(png)
 subprocess.run(['sips','-z',str(72*scale),str(72*scale),str(root/'Assets/AppIcon.png'),'--out',str(root/f'Resources/Icon-72{suffix}.png')],check=True,capture_output=True)
