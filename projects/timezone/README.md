# Legacy Timezone preview — 2026e-2

The stable Cydia index retains2026e-1 for iOS4–6. This source builds a preview adding iOS7/ICU51 validation; do not mistake staged tests for a completed system-install/reboot/rollback test on7.

The preview repacker preserved2882unrelated ICU51resources byte-for-byte and passed malformed-layout tests. Native7.1.2 staged common-data loading changed Moscow2026offsets fromUTC+4 toUTC+3; six region/date sets passed without replacing system data. Native `legacy-timezone validate PAYLOAD` checked600planned system files with the original ICUfile hash unchanged. No full Apple ICUdata is distributed.

`validate` accepts an alternate payload path only for a read-only check. `apply`/`restore` retain the fixed installed payload/backup locations and atomic hash-checked rollback. The original603payload manifest entries are unchanged from2026e-1. Both CLI utilities remainarmv7 and run through the7compatibilityruntime; no injection into64bit processes is needed. Source/tooling0BSD; data IANA/Unicode notices included.

The original stable-release documentation follows and describes its narrower validated range.

---

# Legacy Timezone Update — 2026e-1

Updates obsolete iOS timezone rules, including current Russian regional offsets, using IANA 2026e and Unicode ICU timezone resources. Moscow becomes UTC+3 in winter and summer; historical offsets remain date-dependent.

## Compatibility
- Jailbroken **armv7 iOS 4.3–6.x**; no MobileSubstrate or background daemon required.
- Installer accepts little-endian system ICU versions 44–49 and validates the package layout before modifying files.
- Tested on iPad2,2 with iOS 6.1.3: 155 date/region combinations through three system consumers, installation, removal and reinstallation. iOS 4.3.3/5 physical tests remain outstanding. armv6 devices and iOS 7+ are not supported by this binary.
- This does not remove the operating system's 32-bit date/time limits or repair an incorrect underlying UTC clock.

## Install / remove
Install `local.codex.legacy-timezone_2026e-1_iphoneos-arm.deb` using a Debian-package installer, or as root:

```
dpkg -i local.codex.legacy-timezone_2026e-1_iphoneos-arm.deb
```

**Reboot once after installation or removal.** Existing processes can retain old ICU timezone rules in memory. Cydia is asked to show its reboot button; command-line installation does not force a reboot.

No manual hour adjustment is required. Keep the correct geographical timezone selected. The UTC clock, selected zone, automatic-time preference and saved events are not rewritten. Applications receive corrected local-time conversions; a locally scheduled alarm may consequently move to its correct local time.

Remove through Cydia or:

```
dpkg -r local.codex.legacy-timezone
```

Removal verifies and restores original files, ownership, permissions and symlink targets. Originals are stored only on that device under `/var/lib/legacy-timezone/backup`. Do not delete that directory while the package is installed. External changes to managed files cause removal to stop rather than overwrite them.

Check installed data in a fresh process:

```
legacy-timezone status
legacy-timezone-check Europe/Moscow
```

## What changes
System `/usr/share/zoneinfo` data and four timezone resources inside the device's own `/usr/share/icu/icudt*l.dat`. All timezone data is updated together so system functions and ICU-based formatters agree, including when traveling outside Russia. Other ICU resources are retained byte-for-byte. The full Apple ICU file is **not distributed**.

No Wi-Fi, proxy, VPN, radio, GPS or location-permission changes are made by this package.

## Sources
- [IANA timezone database](https://www.iana.org/time-zones), release 2026e.
- [Unicode compatible ICU timezone resources](https://github.com/unicode-org/icu-data/tree/main/tzdata/icunew/2026e/44/le).
- [ICU timezone-data replacement documentation](https://unicode-org.github.io/icu/userguide/datetime/timezone/).

See `PROVENANCE.json`, `SHA256SUMS`, `WORK-LOG.md` and device test results in this folder. Redistribution includes the IANA and Unicode licenses. Device credentials and Apple data are excluded from the source archive.
