#!/usr/bin/env python3
"""Check the actual Debian archive consumed by ancient iOS dpkg."""
import io
import plistlib
import sys
import tarfile
from pathlib import Path

path = Path(sys.argv[1])
raw = path.read_bytes()
assert raw[:8] == b"!<arch>\n"
offset = 8
members = {}
while offset < len(raw):
    header = raw[offset:offset + 60]
    assert len(header) == 60 and header[-2:] == b"`\n"
    name = header[:16].decode().strip().rstrip("/")
    size = int(header[48:58])
    assert name not in members
    members[name] = raw[offset + 60:offset + 60 + size]
    assert len(members[name]) == size
    offset += 60 + size + size % 2
assert offset == len(raw)
assert set(members) == {"debian-binary", "control.tar.gz", "data.tar.gz"}
assert members["debian-binary"] == b"2.0\n"
for archive in ("control.tar.gz", "data.tar.gz"):
    with tarfile.open(fileobj=io.BytesIO(members[archive]), mode="r:gz") as tar:
        entries = tar.getmembers()
        names = [e.name for e in entries]
        assert len(set(names)) == len(names)
        assert all(n.startswith("./") and ".." not in n.split("/") for n in names)
        assert all(e.uid == 0 and e.gid == 0 and not e.issym() for e in entries)
        if archive == "control.tar.gz":
            for name in ("preinst", "postinst", "prerm", "postrm"):
                assert tar.getmember("./" + name).mode == 0o755
        else:
            for installed, built in (
                ("./usr/libexec/amnezia6/amnezia6d", "amnezia6d"),
                ("./usr/bin/amnezia6ctl", "amnezia6ctl"),
                ("./Applications/Amnezia6.app/Amnezia6", "Amnezia6.app/Amnezia6"),
            ):
                assert tar.getmember(installed).mode == 0o755
                assert tar.extractfile(installed).read() == (path.parent / built).read_bytes()
            for icon in ("Icon.png", "Icon@2x.png", "Icon-72.png", "Icon-72@2x.png", "iTunesArtwork"):
                assert tar.extractfile("./Applications/Amnezia6.app/" + icon).read() == (path.parent / "Amnezia6.app" / icon).read_bytes()
            assert not any(n.endswith(".conf") for n in names)
            assert "./usr/share/doc/com.mak.amnezia6/copyright" in names
            assert tar.extractfile("./Library/MobileSubstrate/DynamicLibraries/A6Status.dylib").read() == (path.parent / "A6Status.dylib").read_bytes()
            assert "./Library/MobileSubstrate/DynamicLibraries/A6Status.plist" in names
            info=plistlib.loads(tar.extractfile("./Applications/Amnezia6.app/Info.plist").read())
            assert info["CFBundleVersion"]=="1.3.0" and info["MinimumOSVersion"]=="4.3"
            assert "vpn" in info["CFBundleURLTypes"][0]["CFBundleURLSchemes"]
            assert info["CFBundleDocumentTypes"] and info["NSCameraUsageDescription"]
            assert not any(n.endswith("profiles.plist") for n in names)
            for license in ("quirc-LICENSE","Senko-LICENSE","cJSON-LICENSE","WireGuard-MIT.txt"):
                assert "./usr/share/doc/com.mak.amnezia6/"+license in names

print("Debian paths, scripts, binary contents, licenses and profile exclusion passed")
