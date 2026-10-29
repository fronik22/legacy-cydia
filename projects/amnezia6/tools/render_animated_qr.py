#!/usr/bin/env python3
"""Display the public four-part fixture; optional Pillow is test tooling only."""
import base64
import io
from pathlib import Path
from PIL import Image
root = Path(__file__).resolve().parent.parent
frames = []
urls = []
for i in range(4):
    image = Image.open(root / "tests/fixtures" / ("animated-%d.pgm" % i)).convert("RGB")
    frame = Image.new("RGB", (605, 605), "white")
    frame.paste(image, ((605-image.width)//2, (605-image.height)//2))
    frames.append(frame)
    png = io.BytesIO()
    frame.save(png, format="PNG")
    urls.append("data:image/png;base64," + base64.b64encode(png.getvalue()).decode())
output = root / "build"
output.mkdir(exist_ok=True)
frames[0].save(output / "animated-qr.gif", save_all=True, append_images=frames[1:], duration=500, loop=0, optimize=False)
import json
html = '''<!doctype html><meta charset="utf-8"><title>Public Amnezia6 four-part test</title>
<style>body{background:#eee;text-align:center;font:20px sans-serif}img{width:min(80vh,95vw);image-rendering:pixelated}</style>
<p>Public synthetic profile — review only, never connect</p><img id="qr"><p id="part"></p>
<script>const frames=%s;let i=0;function show(){document.getElementById('qr').src=frames[i];document.getElementById('part').textContent=`Part ${i+1} / 4`;i=(i+1)%%4;}show();setInterval(show,500);</script>''' % json.dumps(urls)
(output / "animated-qr.html").write_text(html)
print(output / "animated-qr.html")
print(output / "animated-qr.gif")
