# Published source kits — 2026-10-29

Scope: `repo/build_sources.py`, `source-archives/`, this note only. No devices, package payloads, repository metadata, Git publication or original project source were changed.

`python3 repo/build_sources.py` writes 13 deterministic source ZIPs (24,177,557 bytes total), `source-archives/manifest.json`, and `source-archives/SHA256SUMS`. The manifest is keyed by source project; each entry exposes `archive` (basename), `sha256`, `bytes`, `files`, `license`, and `origin`. Link archives at `source-archives/{archive}`. Each ZIP includes a build-input notice and a SHA256 inventory of its own files. ZIP timestamps are fixed at 1980-01-01; member order and Unix file modes are stable.

| Manifest key | Corresponding package/version | Source license |
| --- | --- | --- |
| amnezia6 | Amnezia6 1.2.1 | GPLv2; third-party notices preserved |
| perfoverlay | Performance Overlay 0.1.10 | GPLv3 |
| power-logger | Power Logger 1.1.1 | GPLv3 |
| game-fps | Legacy Game FPS 0.2.2 | GPLv3 |
| veteris-ipad | Veteris Native iPad 1.2.0 | GPLv3 |
| localsend | LocalSend IPA installer 5.7.4340 | GPLv3; component licenses preserved |
| troubadour | Troubadour IPA installer 1.6.447 | GPLv3; component/font notices preserved |
| device-access | Device Access 1.1.0 | GPLv3 |
| blastron | Blastron Revival 0.1.15 | GPLv3 |
| timezone-stable | Stable timezone 2026e-1 | Own code 0BSD; IANA public domain; Unicode resources |
| timezone | Preview timezone 2026e-2 | Own code 0BSD; IANA public domain; Unicode resources |
| legacy-ipad-tools | libcxx-ios4 1.0.0 and legacy60 1.0.0 | Own build/tweak code GPLv3; LLVM UIUC/MIT notices |
| localsend-photos | LocalSend Photos Without Location 1.0.0 | GPLv3 |

The GPLv2 labels previously used for Blastron, Veteris and Device Access were inconsistent with their actual COPYING files, which contain GPLv3. Timezone is not GPL: its own license is 0BSD. This inventory reports the licenses found in the supplied source; it is not a new license grant or a claim that all third-party material is owned by this repository.

## Included inputs and exclusions

LocalSend includes its ignored `vendor/` sources: libheif 1.18.2, libde265 1.0.16, mbedTLS 3.6.7, LLVM libc++ headers/runtime, and libc++abi 3.5.2, plus compatibility code, resources, tests and package/build scripts. Compiled static libraries are excluded; their source and rebuilding scripts are included. All C/C++/assembly source and header files beneath the current vendor directory were checked against the ZIP. Source names such as `private_typeinfo.cpp` and `private_access.h` are retained: they are library implementation, not private configuration.

Troubadour includes ignored `ThirdParty/` (JSONKit/PLWeakCompatibility), source, all app Resources, tools and installer scripts. Roboto font metadata identifies the SIL Open Font License 1.1 and copyright “2011 The Roboto Project Authors.” The absent notice was retrieved from the matching official project at <https://raw.githubusercontent.com/googlefonts/roboto-classic/main/OFL.txt>, stored in `source-archives/notices/Roboto-OFL.txt`, and added to the kit as `Resources/Roboto-OFL.txt`. Existing distributed IPA bytes were not modified by this source operation.

Blastron source is selected from the **released 0.1.15 ZIP**, never the unfinished 0.1.16 project. Every included `src/*` byte matches that original archive. The 0.1.15 package/build scripts, AOT address map, own backend source and catalog extraction tools are preserved; only the example backend endpoint is replaced with localhost. Actual endpoint config, device-control/SSH harnesses, observations, screenshots and account state are excluded. Original game executables/assets/catalog are not redistributed. The solver fixture is numerical test input, not a game executable.

Stable timezone uses its original released 2026e source ZIP; preview timezone uses the current 2026e-2 project. They have separate archive names and manifests. Both include source, IANA TZif data, Unicode resource files and relevant license notices. Neither contains cached original Apple ICU package data. Their native ICU adapters and package guards differ; use the version matching the desired DEB.

Runtime/legacy60 and Photos kits are filtered from the original released source archives, preserving their source, build/package scripts and applicable vendor license files. Device validation dumps and original DEB files are excluded.

All kits are allowlisted by project source directories, source/build file formats and explicit resource paths. SDKs, import-stub files, build/dist trees, `.git`, original proprietary game binaries, IPA/DEB/object/dylib/static-library outputs, signing profiles, private configuration, PEM/private-key files, observations and device validation artifacts are excluded. Public DER trust roots are retained as app resources. Amnezia's explicitly synthetic test fixture key (32 repeated `0x01` bytes, documentation endpoint `192.0.2.1`) is permitted exactly; real WireGuard `PrivateKey=` values are rejected. The private-key-content check distinguishes real PEM data from mbedTLS parser documentation/marker strings.

## Verification and failed attempts

- Final generator run succeeded. Rebuilding without input changes produced byte-identical SHA256SUMS for all 13 archives.
- All ZIP CRC checks, per-file SHA256 inventories, final archive SHA256 hashes, unique/relative path checks, forbidden-output/path audit, LocalSend vendor source/header completeness check, and Blastron exact-native-source comparison passed.
- Generator self-check rejects traversal/absolute paths, build/SDK paths, private configuration, provisioning files and PEM key content. Source inputs are regular files; symlinks are not followed into the kits.
- Initial overly broad `private` filename filtering omitted legitimate LLVM/mbedTLS implementation files. Final filtering rejects the `.private` configuration token; explicit required-source assertions prevent that omission recurring.
- Initial credential check rejected the synthetic Amnezia fixture and mbedTLS's PEM parser marker. It now allows only that exact synthetic fixture and requires actual PEM body data for key detection. No real credentials were added to an archive.
- Initial required-file assertion used libheif's former `libheif/heif.cc` location; corrected to this release's `libheif/api/libheif/heif.cc`.
- Local Python has no fontTools; read the font's standard sfnt/name records using Python `struct` to establish Roboto copyright/license. No dependency was installed.

## Limits

These are source availability/content checks. Fresh app/tweak builds from extracted kits and byte-identical reproduction of shipped binaries were not attempted. Apple SDK/linker sysroots, ARClite and signing tools remain external developer inputs; project scripts/documentation retain their required settings. Troubadour's legacy IPA packaging helper also accepts an original app archive for its packaging template/artwork; its source/resources and helper implementation are included, but that packaging path was not recreated here.

The older direct-install LocalSend 0.5.7 DEB has no established exact source match in the available snapshots. The 5.7.4340 kit explicitly does not claim that match; parent removed the obsolete DEB from the active repository index. Do not reintroduce it as source-covered by the newer archive without locating its corresponding source.

Physical iOS7 workflow coverage remains as documented by the package/device agents. Source publication does not promote unverified UI/gameplay/preview behavior to verified support. No publication/push was performed by this source worker.
