#!/usr/bin/env python3
"""Generate NCSettings theme icons from the HUD glyph alpha mask.

NCSettings draws these on a dark Notification Center background:
  Default: opaque white when on, white at roughly 30% alpha when off.
  Blue:    light-blue gradient when on, neutral grey when off.

The Default/on.png files are the source of the glyph mask. Running this script
again is safe because it recolours that mask and never accumulates alpha changes.
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent / "icons"
NAMES = ("PerfOverlay", "HUD")
SIZES = ("", "@2x")

# Blue theme on-state gradient, sampled from NCSettings' built-in icons.
BLUE_TOP = (139, 212, 244)
BLUE_BOTTOM = (59, 165, 235)


def blue_color(y, height):
    t = y / max(1, height - 1)
    return tuple(round(top + (bottom - top) * t) for top, bottom in zip(BLUE_TOP, BLUE_BOTTOM))


def recolour(source, theme, enabled):
    image = source.convert("RGBA")
    out = Image.new("RGBA", image.size, (0, 0, 0, 0))
    src = image.load()
    dst = out.load()
    height = image.height
    for y in range(height):
        for x in range(image.width):
            a = src[x, y][3]
            if not a:
                continue
            if theme == "Blue" and enabled:
                rgb = blue_color(y, height)
            elif theme == "Blue":
                rgb = (175, 175, 175)
            else:
                rgb = (255, 255, 255)
            if not enabled:
                a = round(a * (76 / 255 if theme == "Default" else 1.0))
            dst[x, y] = rgb + (a,)
    return out


def main():
    for name in NAMES:
        for suffix in SIZES:
            source = Image.open(ROOT / "Default" / name / f"on{suffix}.png")
            for theme, enabled in (("Default", True), ("Default", False),
                                   ("Blue", True), ("Blue", False)):
                target = ROOT / theme / name / f"{'on' if enabled else 'off'}{suffix}.png"
                target.parent.mkdir(parents=True, exist_ok=True)
                recolour(source, theme, enabled).save(target)
                print(target)


if __name__ == "__main__":
    main()
