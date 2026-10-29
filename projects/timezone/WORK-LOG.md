# Legacy timezone update — 2026-10-20

## Scope
Remove Wi-Fi monitoring from the attached original iPad2,2 (iOS 6.1.3); build a distributable timezone fix for armv7 iOS 4.3–6. User reports Wi-Fi works on another access point. No radio/driver changes needed.

## Completed observations and changes
1. Archived actual installed monitor executable, launch plist, package metadata and logs. Removed `local.codex.network-recovery`; verified job, executable and launch plist absent. Logs retained. Backup: `../network-recovery/removal-2026-10-20/`. Other disconnected iPad unchanged; screen-access helper retained.
2. Confirmed system TZif and ICU timezone data both report **2012j**. Moscow incorrectly returns UTC+4 in January, July and October 2026 through NSTimeZone, libc localtime and NSDateFormatter. Stock historical 2010 winter UTC+3 / 2014 summer UTC+4 remain valid and must be preserved.
3. Downloaded IANA tzdata/tzcode **2026e**, built `zic`, generated fat TZif files for old 32-bit readers. Downloaded Unicode's ICU44+ compatible little-endian four-resource set for 2026e. Sources and hashes will accompany release.
4. Implemented on-device ICU repacking: keep system package and replace only zoneinfo64, metaZones, timezoneTypes and windowsZones. Apple's full ICU file stays private and is not included in distribution.
5. Host tests pass: 2,428 resource names retained; **2,424 unrelated resources byte-identical**. Reject truncated package, wrong endianness, invalid count and invalid resource header.
6. Modern Apple clang crashed generating ARM exception tables at -O0. Syntax/host compile passed; ARM `-Os` build succeeds. Build script now consistently uses -Os.
7. First device installation refused a canonical-path validation check **before modifying timezone files**: jailbreak stashes `/usr/share` behind a symlink. Fixed validation to resolve both trusted root and destination parents, preserving containment checks. Device remained on stock 2012j after refusal. Package reinstallation test pending.

## Design
No background process, fixed-hour adjustment or MobileSubstrate dependency. Updates both data consumers, keeps selected zone and UTC clock unchanged. Original files and symlink metadata are saved with SHA256 checks under `/var/lib/legacy-timezone/backup`. Atomic replacement, receipt, verification, idempotent apply and uninstall restoration are built in. Running processes must reload cached ICU data after installation/removal.

## Remaining validation
Install / verify Russia and representative foreign zones / remove and verify original hashes / reinstall final package / verify running UI reload. Physical iOS 4/5 testing requires those devices; only iOS 6.1.3 is attached.

## Installer interruption diagnosis
8. Second installer attempt was killed with signal 9 after writing data but before finalizing its receipt. Moscow already converted correctly in fresh probes, but this was not accepted as a completed install. Original backups and the prepared receipt were intact.
9. Instrumented native installer stages and resident memory. Uninstall preflight retained mapped original/updated ICU buffers in the outer autorelease pool: resident use grew above 43 MB. No definitive kernel kill-reason log was available; an ASL probe initially needed older `aslresponse_next` API and subsequently returned no matching stored events.
10. Shortened buffer lifetimes: hashing uses a scoped autorelease pool; packing/snapshot/restoration loops release temporary data after use. Rollback preflight resident use dropped to about 1–2 MB. Complete rollback passed, including original-file verification.
11. A separate host comparison verified the restored 19,400,560-byte ICU file byte-for-byte against the original SHA256 `27f1ad3515ff5e42fd02ca8be8c025d23694879c3216d68f014e2861975200ce`. Stock 2012j conversions and original selected-zone link were verified. See `rollback-verification.json`.
12. Device disappeared from USB after rollback; no further mutations were attempted until it reappeared. Final package now requests a reboot through Cydia and constrains installation to armv7 firmware 4.3–6.x. Removal handles failed-before-apply installations with no rollback receipt.
13. Reconnection exposed a leftover prepared receipt with some backup files absent, although the target ICU had already been restored. Recovery now accepts each verified original target as its own rollback source; it requires a backup only for targets still carrying updated bytes. It also verifies backup-directory removal and flushes filesystem changes before/after transaction boundaries. No missing original is reconstructed from the new timezone payload.
14. Final native/data package installed successfully. Stage measurements: about 21–27 MB after repacking, snapshot, file writes and receipt completion. Prepared-state retry succeeded; installed-state repeated apply verified all file hashes and exited without rewriting data.
15. **155 date/region combinations passed** across 31 zones (all 26 Russia entries in IANA zone.tab, Europe/Simferopol, London, New York, Tokyo and Sydney). NSTimeZone, libc localtime and NSDateFormatter/ICU each match compiled IANA 2026e values for all tested dates (2026 winter/summer/October and historical 2010/2014 dates). See `device-zone-tests.log` and `device-verification.json`.
16. Normal `dpkg -r` passed and verified all original targets; the host confirmed the full original ICU bytes, absence of backup directory and removal of package-owned checker. Reinstalled the exact same `.deb`; installed and backup ICU files independently matched the host's updated/original full-byte fixtures. See roundtrip verification and uninstall/reinstall logs.
17. The host verification script initially quoted `${Status}` incorrectly, causing only its final `dpkg-query` check to fail after successful removal/reinstallation. Corrected the host check and independently re-ran final package status, Moscow offsets, installed ICU and backup comparisons. No device code change was needed.
18. Temporary diagnostic executables and install copy were removed. A normal device reboot was requested through Apple's diagnostics service to clear timezone caches in all processes. Post-reboot verification pending.
19. Reboot completed normally. Fresh ICU reports 2026e; Moscow remains UTC+3 in January/July/October 2026, UTC+3 in January 2010 and UTC+4 in July 2014. The selected Europe/Moscow link remains unchanged. All 600 installed file hashes pass idempotent verification after boot. Wi-Fi monitoring executable, boot plist and launchd job remain absent.

## Final result
Installed `local.codex.legacy-timezone` **2026e-1** on the attached iPad2,2 / iOS6.1.3 and rebooted it. Runtime, integrity, interrupted-transaction recovery, ordinary removal, reinstall and post-reboot checks pass. Distribution contains a `.deb`, source kit, licenses, provenance and test evidence. No background timezone service is installed.

**Not physically tested:** iOS4.3.3 / iOS5; those devices were not attached. Binary targets armv7 iOS4.3 and uses ICU44–49-compatible resources, with runtime layout checks. armv6 / iOS4.0–4.2 / iOS7+ are outside this release. No future 2038-limit repair or NTP-clock repair is claimed.

Raw diagnostics and private Apple-data fixtures are retained in `work/legacy-timezone/` in the local workspace, excluded from the shareable archive. The final package SHA256 is recorded in `SHA256SUMS` and all artifact-specific device reports.
20. Extracted the distributable source kit into a clean temporary directory. Repackaged its included prebuilt native tools/data and reproduced the **exact installed `.deb` bytes**. Built and ran the parser tests from that extracted kit using a private original ICU fixture: all 2,424 unrelated resources remained byte-identical and malformed-input tests passed. Temporary private fixtures were deleted with the temporary directory. No task-owned proxy forwards or background test processes remain on the Mac.
