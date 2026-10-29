#!/usr/bin/env python3
"""Build the flat APT repository served by GitHub Pages.

Inputs:  repo/packages.json, the .deb files referenced from it.
Outputs: docs/Packages, docs/Packages.gz, docs/Release, docs/debs/*.deb,
         docs/index.html, docs/depictions/*.html

No third-party tools (dpkg-deb, apt-ftparchive) are required.
"""
import datetime
import gzip
import hashlib
import html
import io
import json
import os
import shutil
import tarfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
DEBS = DOCS / "debs"
DEPICTIONS = DOCS / "depictions"
BASE_URL = os.environ.get("REPO_BASE_URL", "https://fronik22.github.io/legacy-cydia").rstrip("/")

FIELDS = [
    "Package", "Name", "Version", "Architecture", "Description", "Depends",
    "Conflicts", "Replaces", "Provides", "Section", "Priority", "Maintainer",
    "Author", "Installed-Size", "Homepage", "Icon", "Depiction", "Filename",
    "Size", "MD5sum", "SHA256",
]


def ar_members(raw):
    assert raw[:8] == b"!<arch>\n", "not a Debian archive"
    offset, members = 8, {}
    while offset < len(raw):
        header = raw[offset:offset + 60]
        assert len(header) == 60 and header[-2:] == b"`\n", "bad ar header"
        name = header[:16].decode().strip().rstrip("/")
        size = int(header[48:58])
        members[name] = raw[offset + 60:offset + 60 + size]
        offset += 60 + size + size % 2
    return members


def control_from_deb(path):
    members = ar_members(path.read_bytes())
    with tarfile.open(fileobj=io.BytesIO(members["control.tar.gz"]), mode="r:gz") as tar:
        names = tar.getnames()
        name = "./control" if "./control" in names else "control"
        text = tar.extractfile(name).read().decode("utf-8")
    fields, current = {}, None
    for line in text.splitlines():
        if line.startswith(" ") and current:
            fields[current] += "\n" + line
        elif ": " in line:
            current, value = line.split(": ", 1)
            fields[current] = value
        elif line == ".":
            if current:
                fields[current] += "\n ."
    return fields


def sha(path, algorithm):
    digest = hashlib.new(algorithm)
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()


def installed_size(deb):
    members = ar_members(deb.read_bytes())
    with tarfile.open(fileobj=io.BytesIO(members["data.tar.gz"]), mode="r:gz") as tar:
        return sum(m.size for m in tar.getmembers() if m.isfile()) // 1024


def stanza(fields):
    lines = []
    for key in FIELDS:
        value = fields.get(key)
        if value:
            lines.append("%s: %s" % (key, value))
    return "\n".join(lines)


def write_depiction(entry, fields):
    name = html.escape(entry.get("title") or fields.get("Name", entry["id"]))
    tagline = html.escape(entry.get("tagline", ""))
    status = html.escape(entry.get("status_text", ""))
    version = html.escape(fields.get("Version", ""))
    summary = html.escape(fields.get("Description", "").split("\n")[0])
    body = fields.get("Description", "")
    paragraphs = []
    for line in body.splitlines()[1:]:
        if line.strip() == ".":
            paragraphs.append("</p><p>")
        else:
            paragraphs.append(html.escape(line.strip()))
    description = "<p>" + " ".join(paragraphs).replace("</p><p>", "</p>\n<p>") + "</p>" if paragraphs else ""
    src = html.escape(entry.get("source", ""))
    archive = entry.get("source_archive")
    archive_link = ("<p><a href=\"https://github.com/fronik22/legacy-cydia/raw/refs/heads/main/source-archives/" + html.escape(archive, quote=True) + "\">Corresponding source ZIP</a></p>") if archive else ""
    page = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{name} — Legacy Cydia</title>
<style>body{{font:16px/1.5 -apple-system,system-ui,sans-serif;max-width:720px;margin:2rem auto;padding:0 1rem;color:#111}}code{{background:#f2f2f2;padding:.1rem .3rem;border-radius:4px}}.badge{{display:inline-block;background:#0a7;color:#fff;padding:.2rem .5rem;border-radius:6px;font-size:.8rem}}</style>
</head><body>
<p><a href="../index.html">← All packages</a></p>
<h1>{name}</h1>
<p><strong>{tagline}</strong></p>
<p>{summary}</p>
{description}
<p><span class="badge">{status}</span></p>
<h2>Details</h2>
<ul>
<li>Package: <code>{html.escape(entry["id"])}</code></li>
<li>Version: <code>{version}</code></li>
<li>Section: {html.escape(fields.get("Section", ""))}</li>
<li>Requires: <code>{html.escape(fields.get("Depends", "—"))}</code></li>
</ul>
<h2>Source</h2>
<p><code>{src}</code> — license: {html.escape(entry.get("license", "see project"))}</p>
{archive_link}
</body></html>
"""
    (DEPICTIONS / (entry["id"] + ".html")).write_text(page)


def main():
    manifest = json.loads((ROOT / "repo" / "packages.json").read_text())
    for directory in (DOCS, DEBS, DEPICTIONS):
        directory.mkdir(parents=True, exist_ok=True)
    for old in DEBS.glob("*.deb"):
        old.unlink()
    for old in DEPICTIONS.glob("*.html"):
        old.unlink()

    entries = []
    for entry in manifest["packages"]:
        deb = (ROOT / entry["deb"]).resolve()
        if not deb.exists():
            raise SystemExit("missing deb: %s" % deb)
        fields = control_from_deb(deb)
        if fields.get("Package") != entry["id"]:
            raise SystemExit("%s: control Package %s != %s" % (deb, fields.get("Package"), entry["id"]))
        target = DEBS / deb.name
        shutil.copy2(deb, target)
        fields["Filename"] = "./debs/" + target.name
        fields["Size"] = str(target.stat().st_size)
        fields["MD5sum"] = sha(target, "md5")
        fields["SHA256"] = sha(target, "sha256")
        fields["Installed-Size"] = fields.get("Installed-Size") or str(installed_size(target))
        fields["Depiction"] = "%s/depictions/%s.html" % (BASE_URL, entry["id"])
        fields.pop("Icon", None)
        if entry.get("icon"):
            icon = ROOT / "repo" / entry["icon"]
            if not icon.exists():
                raise SystemExit("missing icon: %s" % icon)
            (DOCS / "assets").mkdir(exist_ok=True)
            shutil.copy2(icon, DOCS / "assets" / icon.name)
            fields["Icon"] = "%s/assets/%s" % (BASE_URL, icon.name)
        if entry.get("homepage"):
            fields["Homepage"] = entry["homepage"]
        entry["_deb"] = target
        entry["_fields"] = fields
        entries.append(entry)
        write_depiction(entry, fields)

    entries.sort(key=lambda e: (e.get("order", 99), e["_fields"].get("Name", e["id"])))
    packages = "\n\n".join(stanza(e["_fields"]) for e in entries) + "\n"
    (DOCS / "Packages").write_text(packages)
    with gzip.GzipFile(filename="", mode="wb", fileobj=(buffer := io.BytesIO()), mtime=0) as gz:
        gz.write(packages.encode())
    (DOCS / "Packages.gz").write_bytes(buffer.getvalue())

    now = datetime.datetime.now(datetime.timezone.utc).strftime("%a, %d %b %Y %H:%M:%S UTC")
    checksums = [("Packages", DOCS / "Packages"), ("Packages.gz", DOCS / "Packages.gz")]
    checksums += [("./debs/" + e["_deb"].name, e["_deb"]) for e in entries]
    release = [
        "Origin: Mak Legacy",
        "Label: Mak Legacy",
        "Suite: stable",
        "Version: 1.0",
        "Codename: ios-legacy",
        "Architectures: iphoneos-arm",
        "Components: main",
        "Description: Legacy iOS apps and tweaks by mak",
        "Date: " + now,
        "MD5Sum:",
    ]
    release += [" %s %d %s" % (sha(path, "md5"), path.stat().st_size, name) for name, path in checksums]
    release.append("SHA256:")
    release += [" %s %d %s" % (sha(path, "sha256"), path.stat().st_size, name) for name, path in checksums]
    release.append("")
    (DOCS / "Release").write_text("\n".join(release))

    rows = "\n".join(
        '<tr><td><a href="depictions/%s.html">%s</a></td><td>%s</td><td>%s</td><td>%s</td></tr>'
        % (e["id"], html.escape(e["_fields"].get("Name", e["id"])), html.escape(e["_fields"].get("Version", "")),
           html.escape(e.get("status_label", "")), html.escape(e.get("tagline", "")))
        for e in entries)
    index = f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Mak Legacy Cydia repository</title>
<style>body{{font:16px/1.5 -apple-system,system-ui,sans-serif;max-width:860px;margin:2rem auto;padding:0 1rem;color:#111}}code{{background:#f2f2f2;padding:.15rem .35rem;border-radius:4px}}table{{border-collapse:collapse;width:100%}}td,th{{border-bottom:1px solid #ddd;padding:.5rem;text-align:left;vertical-align:top}}</style>
</head><body>
<h1>Mak Legacy Cydia repository</h1>
<p>Packages for jailbroken 32-bit and early 64-bit iOS devices. Add this source in Cydia:</p>
<p><code>{BASE_URL}/</code></p>
<p>Every package states its tested range. iOS 7 support is only claimed after an
install and runtime check on a real device. Packages that are not ready are
marked <strong>untested</strong>; incompatible <code>firmware</code> dependencies prevent installation rather than guaranteeing that Cydia hides an entry.</p>
<table><thead><tr><th>Package</th><th>Version</th><th>iOS 7</th><th>Summary</th></tr></thead>
<tbody>
{rows}
</tbody></table>
<p>No account credentials, private dumps, original game assets or SDKs are
published here. Senko and the Wi-Fi monitor are not part of this repository.</p>
</body></html>
"""
    (DOCS / "index.html").write_text(index)
    print("built %d packages into %s" % (len(entries), DOCS))


if __name__ == "__main__":
    main()
