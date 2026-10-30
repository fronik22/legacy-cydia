# Imported server names — 2026-10-30

## Official behavior

Current official dev commit checked: 7f9b7db482b8b1662b7466937e578008cbcb716e.
Self-hosted shares serialize the server's root `description` and `hostName`.
The official self-hosted user/admin readers initialize displayName from
`description`, falling back to `hostName`. This is metadata in the imported
bundle, not a reverse-DNS/network name lookup. Unrelated `name`, `serverName`
or `displayName` fields are not the self-hosted export contract.

Primary sources:

- [Self-hosted user model, serialization and display fallback](https://github.com/amnezia-vpn/amnezia-client/blob/7f9b7db482b8b1662b7466937e578008cbcb716e/client/core/models/selfhosted/selfHostedUserServerConfig.cpp)
- [Self-hosted admin model](https://github.com/amnezia-vpn/amnezia-client/blob/7f9b7db482b8b1662b7466937e578008cbcb716e/client/core/models/selfhosted/selfHostedAdminServerConfig.cpp)
- [Connection-share generation](https://github.com/amnezia-vpn/amnezia-client/blob/7f9b7db482b8b1662b7466937e578008cbcb716e/client/core/controllers/selfhosted/exportController.cpp)
- [Import decoding](https://github.com/amnezia-vpn/amnezia-client/blob/7f9b7db482b8b1662b7466937e578008cbcb716e/client/core/controllers/selfhosted/importController.cpp)

Two guessed constants/model paths returned404 during discovery; inspected the
pinned official tree to locate configKeys.h and selfHostedUserServerConfig.cpp.
No app/device/private profile was read for this source investigation.

## Implementation

The existing C bundle decoder now has an optional named extraction entrypoint;
the previous config-only API remains a wrapper with unchanged callers. Both
metadata fields come from the same parsed bundle as the config. Only official
case-sensitive root keys are used. Optional metadata is bounded to512UTF-8bytes
per field; wrong types/overlong fields are ignored rather than invalidating an
otherwise usable VPN profile. The shared Objective-C importer validates UTF-8,
trims surrounding whitespace, rejects internal control/format characters and
limits the displayed name to128UTF-16units. Unusable description falls back to
hostName; absent metadata falls back to the existing file-name/endpoint behavior.

JSON NUL text is explicitly rejected before exposing config/name C strings,
preventing silent truncation. Escaped literal backslash-u0000 remains ordinary
text. No metadata field is inserted into native network configuration.

A6ImportConfigWithName is shared by clipboard, file, vpn URL, photo QR and live
animated QR import. The live scanner still validates completion for its sticky
error handling, then forwards the original assembled data to the importer;
forwarding normalized config previously discarded all naming metadata. Review
opens with the imported name, which the user can edit before saving. Nothing
saves, activates or renames an existing profile automatically.

Already imported profiles cannot recover metadata discarded by older versions;
reimport their original share/QR to populate the name. Existing manual names,
configuration and active VPN state are untouched by this implementation.

## Verification

- Full make test passed after the change.
- Profiles regression covers rawJSON, vpn://qCompress, bare compressed body and
  Base64-wrapped JSON; official description/hostName priority, UTF-8/Unicode,
  whitespace,128-unit boundary, long/type/control rejection fallback, unknown
  name-key omission, NUL rejection, plain config without metadata, legacy API and
  output reset on failure. Existing migration/selection/manual-rename/restart/
  OFF/rollback tests continue to pass.
- FullAWG3.1 fixture now has a public synthetic description and hostname. Actual
  two-part QR images→BGRA/quirc→collector→shared importer preserve that name and
  both DNS resolvers/range parameters. Existing QR negative/lifecycle parsing
  tests pass.
- ASAN+UBSan profile/import and QR tests pass; Foundation process-global leak
  detection disabled, matching the previous suite policy.
- Device-only QRRegression now checks both initialName and actual editor field
  against the synthetic fixture, using app version1.3.4. This agent did not run
  it, install/restart apps or access a device.

Private ignored logs/source snapshots: build/import-name-audit/ and sanitizer
executables build/import-name-asan/. Final package/device verification belongs
to the parent integration pass. No new network/server compatibility claim.
