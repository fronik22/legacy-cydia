# Actions / findings

2026-10-28: user requests addable GitHub-hosted Cydia repo containing our work, with iOS7-specific support. Existing account fronik22 authenticated. Current iOS6 inventory and old released sources reused. Senko is excluded permanently. Scope includes apps/tweaks, not republishing third-party dependency packages or original games.

2026-10-28 repo build: created flat APT generator (`repo/build_repo.py`), manifest
(`repo/packages.json`), validator (`repo/validate_repo.py`) and nine package
entries. Rebuilt Amnezia6 1.2.0 (armv7 app/daemon/CLI + universal arm64 status
hook), Performance Overlay 0.1.9, Power Logger 1.1.0, Game FPS 0.2.1 and Veteris
1.2.0. Imported Device Access source under `projects/device-access`; Blastron and
Legacy Timezone stay binary-only because their build inputs contain game-derived
addresses and Apple ICU data. `docs/` now has Packages, Packages.gz, Release,
checksums, depictions, icons and nine debs.

Device checks: Amnezia6 1.2.0 installed on iPad4,5/7.1.2; daemon started, utun0
and route installed, status/stop work. Handshake stayed `connecting`; both iPads
cannot reach 83.171.227.17 from the test LAN, while the same profile handshakes
from the Mac. Performance Overlay 0.1.9 universal hook loaded and SpringBoard
survived respawn. Power Logger 1.1.0 arm64 daemon started under launchd and wrote
status.json. iOS 7 app launch and screenshots remain blocked (SBSLaunch returns 9
for every app; no iOS 7 Developer Disk Image). Game FPS, Veteris and LocalSend
remain unverified on iOS 7 despite their declared ranges.

Local validation: `python3 repo/validate_repo.py` passes; Packages.gz matches
Packages byte-for-byte; Release MD5/SHA256 entries match all nine debs; local HTTP
fetch of Packages, Release, a deb and a depiction succeeds. Scrubbed the real VPS
endpoint and a device UDID from public test/worklog text; live profiles and
private runtime dumps stay under ignored `private/`.
