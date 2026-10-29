# Corresponding source archives

Every archive includes its project license and required source/vendor inputs. Apple SDKs/import stubs, original game binaries, device/account data and private VPN profiles are excluded. SHA256SUMS and manifest.json cover the archives; each ZIP includes a per-file SHA256 inventory.

| Archive | License | SHA256 |
| --- | --- | --- |
| [amnezia6-1.2.1-source.zip](amnezia6-1.2.1-source.zip) | GPL-2.0 | `39aceabb7ffbf9d77f5cba84cda90c2a6c528c5a7fe1b329032ac28757808c50` |
| [blastron-0.1.15-source.zip](blastron-0.1.15-source.zip) | GPL-3.0 | `56b996999c402e7166c3afc65cdd2009545b2acd132ec8be26e29263ac644f20` |
| [device-access-1.1.0-source.zip](device-access-1.1.0-source.zip) | GPL-3.0 | `5d6cce2e066c773aa4d79e7c8a9091d422a7e0ae9fe38a0a019782e97eb1144d` |
| [game-fps-0.2.2-source.zip](game-fps-0.2.2-source.zip) | GPL-3.0 | `154b62255014aca1b2e7e9e7aaff86ef3efafae1d6721cafae56d8757433c34f` |
| [legacy-ipad-tools-1.0.0-source.zip](legacy-ipad-tools-1.0.0-source.zip) | GPL-3.0; LLVM UIUC/MIT notices | `1ad187d09cf408b450f1d3652b539bb1aee0b4aceb98721b276ef6698cd391f2` |
| [localsend-5.7.4340-source.zip](localsend-5.7.4340-source.zip) | GPL-3.0 | `2b4e75c31f768f03a253f8b279f570f03c5306a485c29592a8205a899d5a87b9` |
| [localsend-photos-1.0.0-source.zip](localsend-photos-1.0.0-source.zip) | GPL-3.0 | `866c0d70c7884caf46b8e4803c09346ac49eb06652ea2c79ee6e3f09a20b075a` |
| [perfoverlay-0.1.10-source.zip](perfoverlay-0.1.10-source.zip) | GPL-3.0 | `b13a6bf5b9d52f70bb3774e4d723ce0c71a35112f39909fcb34cb5ab28902ac0` |
| [power-logger-1.1.1-source.zip](power-logger-1.1.1-source.zip) | GPL-3.0 | `ddb74b86c6a3d10795b404fb1b78ae40ab5d431f8545c34192d9b4215a38fc94` |
| [timezone-2026e-2-source.zip](timezone-2026e-2-source.zip) | 0BSD; IANA public domain; Unicode data license | `3e1c1b6c10adf2d19ed85eae0499b9b7c6c9dc07f3b37e988f255e6804b31774` |
| [timezone-stable-2026e-1-source.zip](timezone-stable-2026e-1-source.zip) | 0BSD; IANA public domain; Unicode data license | `855e6a180b6ea334d36499e0e95d3d16479e5dbfb18ad6fb5274f13727a780e8` |
| [troubadour-1.6.447-source.zip](troubadour-1.6.447-source.zip) | GPL-3.0 | `9ebfbc61bb7c13c52e41220bbc47947e980e57b807893f29717241bf226dc278` |
| [veteris-ipad-1.2.0-source.zip](veteris-ipad-1.2.0-source.zip) | GPL-3.0 | `c11e3eb14cf1900521310918bf1345e0c88bdf8c68245da48ce3e7c7c0c0dcc9` |

Blastron is the matching0.1.15source, not the unfinished0.1.16worktree. timezone-stable matches the active2026e-1package; timezone2026e-2 is a separate staged preview. The legacy iPad tools archive covers both the shared iOS4C++runtime and the guarded1080p60tweak. The older direct LocalSend0.5.7was retired; current LocalSend source targets5.7.4340.

Extract an archive and use its build instructions with an external compatible SDK/link sysroot and signer. Rebuilding archival snapshots with repo/build_sources.py additionally requires the retained historical release inputs referenced by that script; it is not required to build the supplied corresponding source or regenerate the APT index. No device credentials are needed.
