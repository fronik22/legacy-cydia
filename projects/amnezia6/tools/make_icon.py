#!/usr/bin/env python3
"""Export the selected artwork at native iOS icon sizes, preserving its alpha."""
from pathlib import Path
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "app"
    out.mkdir(parents=True, exist_ok=True)
    with Image.open(ROOT / "artwork" / "Icon-source.png") as source:
        art = source.convert("RGBA")
    assert art.width == art.height and art.getpixel((0, 0))[3] == 0
    for name, size in {"Icon.png": 57, "Icon@2x.png": 114,
                       "Icon-72.png": 72, "Icon-72@2x.png": 144,
                       "iTunesArtwork": 512}.items():
        path = out / name
        art.resize((size, size), Image.Resampling.LANCZOS).save(path, format="PNG", optimize=True)
        with Image.open(path) as icon:
            assert icon.size == (size, size) and icon.mode == "RGBA"
            assert icon.getpixel((0, 0))[3] == 0
    print("Exported five rounded icons with transparent corners")


if __name__ == "__main__":
    main()
