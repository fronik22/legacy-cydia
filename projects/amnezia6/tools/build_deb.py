#!/usr/bin/env python3
"""Assemble com.mak.amnezia6_<version>_iphoneos-arm.deb from build artefacts.

The Debian package is a plain ar archive holding three members:

    debian-binary   "2.0\\n"
    control.tar.gz  DEBIAN/control, maintainer scripts
    data.tar.gz     the filesystem tree

dpkg-deb is not available on macOS, so the archive is written directly.
"""

import gzip
import io
import os
import shutil
import stat
import sys
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"
PACKAGING = ROOT / "packaging"
STAGE = BUILD / "deb-root"

PACKAGE = "com.mak.amnezia6"


def read_control_field(name):
    for line in (PACKAGING / "DEBIAN" / "control").read_text().splitlines():
        if line.startswith(name + ":"):
            return line.split(":", 1)[1].strip()
    raise SystemExit("control file has no %s field" % name)


def add_tree(tar, base, mode_overrides=None):
    """Add every entry under `base` to `tar` with a `./`-rooted name."""
    overrides = mode_overrides or {}
    entries = sorted(base.rglob("*"))
    # directories first so extraction never races on implicit parents
    for path in [p for p in entries if p.is_dir()]:
        rel = str(path.relative_to(base)).replace(os.sep, "/")
        info = tar.gettarinfo(str(path), arcname="./" + rel)
        info.mode = stat.S_IMODE(path.stat().st_mode)
        info.uid = info.gid = 0
        info.uname = info.gname = "root"
        tar.addfile(info)
    for path in [p for p in entries if not p.is_dir()]:
        rel = str(path.relative_to(base)).replace(os.sep, "/")
        info = tar.gettarinfo(str(path), arcname="./" + rel)
        info.mode = overrides.get(rel, stat.S_IMODE(path.stat().st_mode))
        info.uid = info.gid = 0
        info.uname = info.gname = "root"
        with path.open("rb") as handle:
            tar.addfile(info, handle)


def tar_gz(base, mode_overrides=None):
    """Build a gzip-compressed tar of `base` with deterministic headers."""
    raw = io.BytesIO()
    with tarfile.open(fileobj=raw, mode="w", format=tarfile.GNU_FORMAT) as tar:
        add_tree(tar, base, mode_overrides)
    packed = io.BytesIO()
    with gzip.GzipFile(fileobj=packed, mode="wb", mtime=0) as gz:
        gz.write(raw.getvalue())
    return packed.getvalue()


def ar_member(name, payload):
    header = "{:<16}{:<12}{:<6}{:<6}{:<8}{:<10}`\n".format(
        name, 0, 0, 0, "100644", len(payload))
    body = payload + (b"\n" if len(payload) % 2 else b"")
    return header.encode("ascii") + body


def main():
    version = read_control_field("Version")

    app = BUILD / "Amnezia6.app"
    daemon = BUILD / "amnezia6d"
    cli = BUILD / "amnezia6ctl"
    for required in (app / "Amnezia6", daemon, cli):
        if not required.exists():
            raise SystemExit("missing %s - run `make app device` first" % required)

    if STAGE.exists():
        shutil.rmtree(STAGE)

    app_stage = STAGE / "Applications" / "Amnezia6.app"
    app_stage.parent.mkdir(parents=True)
    shutil.copytree(app, app_stage)

    (STAGE / "usr" / "libexec" / "amnezia6").mkdir(parents=True)
    shutil.copy2(daemon, STAGE / "usr" / "libexec" / "amnezia6" / "amnezia6d")

    (STAGE / "usr" / "bin").mkdir(parents=True)
    shutil.copy2(cli, STAGE / "usr" / "bin" / "amnezia6ctl")

    (STAGE / "Library" / "LaunchDaemons").mkdir(parents=True)
    shutil.copy2(PACKAGING / "com.mak.amnezia6d.plist",
                 STAGE / "Library" / "LaunchDaemons" / "com.mak.amnezia6d.plist")

    docs = STAGE / "usr" / "share" / "doc" / PACKAGE
    docs.mkdir(parents=True)
    shutil.copy2(ROOT / "LICENSE", docs / "copyright")
    shutil.copy2(ROOT / "THIRD_PARTY.md", docs / "THIRD_PARTY.md")
    shutil.copy2(ROOT / "third_party" / "monocypher" / "LICENCE.md", docs / "Monocypher-LICENCE.md")
    for relative, name in (
        ("quirc/LICENSE", "quirc-LICENSE"),
        ("senko/LICENSE", "Senko-LICENSE"),
        ("senko/third_party/LICENSE", "cJSON-LICENSE"),
        ("WireGuard-MIT.txt", "WireGuard-MIT.txt"),
    ):
        shutil.copy2(ROOT / "third_party" / relative, docs / name)

    tweaks = STAGE / "Library" / "MobileSubstrate" / "DynamicLibraries"
    tweaks.mkdir(parents=True)
    shutil.copy2(BUILD / "A6Status.dylib", tweaks / "A6Status.dylib")
    shutil.copy2(ROOT / "status" / "A6Status.plist", tweaks / "A6Status.plist")
    os.chmod(tweaks / "A6Status.dylib", 0o755)
    os.chmod(tweaks / "A6Status.plist", 0o644)

    modes = {
        "usr/libexec/amnezia6/amnezia6d": 0o755,
        "usr/bin/amnezia6ctl": 0o755,
        "Applications/Amnezia6.app/Amnezia6": 0o755,
        "Applications/Amnezia6.app/Info.plist": 0o644,
        "Library/LaunchDaemons/com.mak.amnezia6d.plist": 0o644,
    }
    for rel, mode in modes.items():
        os.chmod(STAGE / rel, mode)
    for icon in app_stage.glob("Icon*"):
        os.chmod(icon, 0o644)
    art = app_stage / "iTunesArtwork"
    if art.exists():
        os.chmod(art, 0o644)

    control_tar = tar_gz(PACKAGING / "DEBIAN", {
        "control": 0o644, "preinst": 0o755, "postinst": 0o755, "prerm": 0o755, "postrm": 0o755,
    })
    data_tar = tar_gz(STAGE)

    deb = BUILD / ("%s_%s_iphoneos-arm.deb" % (PACKAGE, version))
    with deb.open("wb") as handle:
        handle.write(b"!<arch>\n")
        handle.write(ar_member("debian-binary", b"2.0\n"))
        handle.write(ar_member("control.tar.gz", control_tar))
        handle.write(ar_member("data.tar.gz", data_tar))

    print("wrote %s (%d bytes)" % (deb, deb.stat().st_size))
    return 0


if __name__ == "__main__":
    sys.exit(main())
