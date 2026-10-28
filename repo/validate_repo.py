#!/usr/bin/env python3
"""Validate the generated flat APT repository without dpkg or apt tools.

Checks:
  * Packages parses into unique package/version stanzas
  * required fields exist and paths are relative
  * every referenced .deb exists and matches Size, MD5sum and SHA256
  * Packages.gz decompresses byte-identically to Packages
  * Release MD5/SHA256 entries match the files on disk
  * every Depiction and Icon URL maps to a file in docs/
  * no file:// or local absolute paths leaked into the index
"""
import gzip
import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
BASE = "https://fronik22.github.io/legacy-cydia"
REQUIRED = ("Package", "Version", "Architecture", "Description", "Filename", "Size", "SHA256")

errors = []


def fail(message):
    errors.append(message)


def digest(path, algorithm):
    value = hashlib.new(algorithm)
    value.update(path.read_bytes())
    return value.hexdigest()


def stanzas(text):
    result = []
    current = {}
    key = None
    for line in text.splitlines():
        if not line.strip():
            if current:
                result.append(current)
            current, key = {}, None
        elif line.startswith(" ") and key:
            current[key] += "\n" + line
        elif ": " in line:
            key, value = line.split(": ", 1)
            current[key] = value
        else:
            fail("unparseable Packages line: %r" % line)
    if current:
        result.append(current)
    return result


def check_url(url, label):
    if url.startswith(BASE + "/"):
        relative = url[len(BASE) + 1:]
    elif url.startswith("./"):
        relative = url[2:]
    else:
        fail("%s is not under %s: %s" % (label, BASE, url))
        return
    target = DOCS / relative
    if not target.is_file():
        fail("%s target missing: %s" % (label, target))


def main():
    packages_path = DOCS / "Packages"
    if not packages_path.is_file():
        raise SystemExit("docs/Packages missing; run repo/build_repo.py first")
    packages_text = packages_path.read_text()
    packages = stanzas(packages_text)
    if not packages:
        fail("Packages is empty")

    seen = set()
    for fields in packages:
        name = fields.get("Package", "<unnamed>")
        for key in REQUIRED:
            if not fields.get(key):
                fail("%s: missing %s" % (name, key))
        key = (name, fields.get("Version"))
        if key in seen:
            fail("duplicate stanza: %s %s" % key)
        seen.add(key)

        filename = fields.get("Filename", "")
        if filename.startswith("/") or filename.startswith("file:"):
            fail("%s: absolute Filename %s" % (name, filename))
        deb = DOCS / filename.lstrip("./")
        if not deb.is_file():
            fail("%s: deb missing: %s" % (name, deb))
            continue
        if str(deb.stat().st_size) != fields.get("Size"):
            fail("%s: Size mismatch" % name)
        if digest(deb, "sha256") != fields.get("SHA256"):
            fail("%s: SHA256 mismatch" % name)
        if fields.get("MD5sum") and digest(deb, "md5") != fields["MD5sum"]:
            fail("%s: MD5 mismatch" % name)
        if "Icon" in fields:
            check_url(fields["Icon"], name + " Icon")
        if "Depiction" in fields:
            check_url(fields["Depiction"], name + " Depiction")
        for value in (fields.get("Homepage", ""), fields.get("Filename", "")):
            if "file://" in value or "/Users/" in value:
                fail("%s: leaked local path %s" % (name, value))

    gz = gzip.decompress((DOCS / "Packages.gz").read_bytes())
    if gz != packages_text.encode():
        fail("Packages.gz does not match Packages")

    release = (DOCS / "Release").read_text()
    section = None
    release_files = {"MD5Sum": {}, "SHA256": {}}
    for line in release.splitlines():
        if line in ("MD5Sum:", "SHA256:"):
            section = line[:-1]
            continue
        if line.startswith(" ") and section:
            parts = line.split()
            if len(parts) == 3:
                release_files[section][parts[2]] = (parts[0], int(parts[1]))
        elif line and not line.startswith(" "):
            section = None

    for algorithm, hashlib_name in (("MD5Sum", "md5"), ("SHA256", "sha256")):
        if not release_files[algorithm]:
            fail("Release has no %s section" % algorithm)
            continue
        for relative, (checksum, size) in release_files[algorithm].items():
            target = DOCS / relative.lstrip("./")
            if not target.is_file():
                fail("Release %s references missing %s" % (algorithm, relative))
                continue
            if target.stat().st_size != size:
                fail("Release %s size mismatch for %s" % (algorithm, relative))
            if digest(target, hashlib_name) != checksum:
                fail("Release %s checksum mismatch for %s" % (algorithm, relative))

    if errors:
        for error in errors:
            print("FAIL:", error)
        return 1
    print("OK: %d packages, %d debs, Packages.gz and Release checksums match"
          % (len(packages), len(list((DOCS / "debs").glob("*.deb")))))
    return 0


if __name__ == "__main__":
    sys.exit(main())
