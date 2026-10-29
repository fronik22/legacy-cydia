"""Package a validated, unchanged IPA for official appinst (no bundle relocation)."""
from pathlib import Path
import gzip,hashlib,io,plistlib,shutil,stat,tarfile,zipfile

def tarball(root):
    out=io.BytesIO()
    with tarfile.open(fileobj=out,mode="w",format=tarfile.GNU_FORMAT) as tar:
        for path in sorted(root.rglob("*")):
            info=tar.gettarinfo(str(path),arcname="./"+path.relative_to(root).as_posix())
            info.uid=info.gid=0;info.uname="root";info.gname="wheel";info.mtime=0
            if path.is_file():
                with path.open("rb") as src:tar.addfile(info,src)
            else:tar.addfile(info)
    return gzip.compress(out.getvalue(),mtime=0)

def ar_member(name,data):
    header=name.ljust(16)+"0".ljust(12)+"0".ljust(6)+"0".ljust(6)+"100644".ljust(8)+str(len(data)).ljust(10)+"`\n"
    return header.encode("ascii")+data+(b"\n"if len(data)%2 else b"")

def scripts(bundle,version,identifier,old_names):
    # An old /Applications package has different data semantics; never silently relocate it.
    checks="\n".join('if [ -e "/Applications/'+n+'.app" ]; then echo "An existing /Applications/'+n+'.app must be migrated manually; refusing a duplicate app or data relocation." >&2; exit 1; fi'for n in old_names)
    preinst="""#!/bin/sh
set -eu
os=$(dpkg-query -W -f='${Version}' firmware)
if ! dpkg --compare-versions "$os" ge 5.0 || ! dpkg --compare-versions "$os" lt 8.0; then
 echo "This IPA installer is audited for iOS 5-7; use the standalone IPA on iOS 4." >&2; exit 1
fi
"""+checks+"\n"
    postinst="""#!/bin/sh
set -eu
[ "${1:-}" = configure ] || exit 0
/usr/bin/appinst /usr/share/legacy-ipa/"""+identifier+"""/application.ipa
echo """+bundle+" "+version+""" installed through MobileInstallation. Existing IPA container/data retained by the platform installer.
echo 'Removing this Cydia installer leaves the app and its data; delete the app from the Home Screen separately.'
"""
    prerm="""#!/bin/sh
set -eu
case "${1:-}" in remove|deconfigure) echo 'Only this IPA installer package is removed. The installed app and user data stay on the device.';; esac
"""
    return {"preinst":preinst,"postinst":postinst,"prerm":prerm}

def build(project,ipa,package,bundle_id,version,title,old_names,license_file):
    project=Path(project);ipa=Path(ipa)
    with zipfile.ZipFile(ipa)as z:
        assert z.testzip()is None
        names=z.namelist()
        assert all(not Path(n).is_absolute()and ".."not in Path(n).parts for n in names)
        assert len(names)<=8192 and sum(e.file_size for e in z.infolist())<=256*1024*1024
        assert all(not stat.S_ISLNK(e.external_attr>>16) for e in z.infolist())
        top=[n for n in names if n.count("/")==2 and n.endswith("/Info.plist")]
        assert len(top)==1
        info=plistlib.loads(z.read(top[0]))
        assert info["CFBundleIdentifier"]==bundle_id and info["CFBundleVersion"]==version
        exe=top[0].removesuffix("Info.plist")+info["CFBundleExecutable"]
        assert z.getinfo(exe).external_attr>>16&0o111
        assert not any(n.endswith((".mobileprovision",".private"))or "/Documents/"in n for n in names)
    out=project/"build/cydia";stage=out/"stage";control=out/"control"
    for d in(stage,control):
        shutil.rmtree(d,ignore_errors=True);d.mkdir(parents=True)
    payload=stage/"usr/share/legacy-ipa"/bundle_id;payload.mkdir(parents=True)
    shutil.copyfile(ipa,payload/"application.ipa");(payload/"application.ipa").chmod(0o644)
    doc=stage/"usr/share/doc"/package;doc.mkdir(parents=True)
    shutil.copyfile(license_file,doc/"COPYING")
    text=("This is an IPA installer package, using official ai.akemi.appinst and AppSync Unified from https://cydia.akemi.ai/. "
          "It upgrades an existing IPA installation in its platform-managed container. It never copies an app into /Applications or moves/deletes Documents/Library. "
          "Removing the Cydia installer leaves the app and its data installed. To remove the app itself, use its Home Screen delete action. "
          "Existing /Applications installs are refused for manual migration. "
          "iOS7 is API/build-audited; see repository verification matrix for actual device tests. "
          "iOS4 users use the standalone IPA with their existing compatible AppSync.\n")
    (doc/"README").write_text(text)
    (control/"control").write_text(f"""Package: {package}
Name: {title} (IPA Installer)
Version: {version}
Architecture: iphoneos-arm
Maintainer: Legacy iPad Tools
Section: Applications
Depends: firmware (>= 5.0), firmware (<< 8.0), ai.akemi.appinst (>= 2.0), ai.akemi.appsyncunified
Description: Install the adapted {title} application using appinst.
 Preserves existing IPA containers and user data on upgrade.
 Cydia removal leaves the installed app and its data intact.
 Requires Karen's official repository: https://cydia.akemi.ai/.
Homepage: https://github.com/fronik22/legacy-cydia
""")
    (control/"md5sums").write_text("".join(hashlib.md5(p.read_bytes()).hexdigest()+"  "+p.relative_to(stage).as_posix()+"\n"for p in sorted(stage.rglob("*"))if p.is_file()))
    for name,text in scripts(title,version,bundle_id,old_names).items():
        (control/name).write_text(text);(control/name).chmod(0o755)
    deb=project/"dist"/(package+"_"+version+"_iphoneos-arm.deb");deb.parent.mkdir(exist_ok=True)
    deb.write_bytes(b"!<arch>\n"+ar_member("debian-binary",b"2.0\n")+ar_member("control.tar.gz",tarball(control))+ar_member("data.tar.gz",tarball(stage)))
    result={"package":package,"version":version,"bundle_id":bundle_id,"deb":str(deb),"ipa_sha256":hashlib.sha256(ipa.read_bytes()).hexdigest(),"deb_sha256":hashlib.sha256(deb.read_bytes()).hexdigest(),"app_bundle_metadata":info,"runtime_tested_ios7":False,"installer_semantics":"official appinst IPA upgrade; Cydia removal retains installed app/data"}
    import json
    (out/"checks.json").write_text(json.dumps(result,indent=2,default=str)+"\n")
    print(deb)
    return deb
