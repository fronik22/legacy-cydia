# Legacy Device Access 1.1.0

Explicit root-operated screen status/lock/unlock for iOS 4.3.3, 6.1.3 and capability-checked iOS 7. No daemon, network listener, SUID executable, startup auto-unlock or passcode bypass. Configured passcodes and unknown runtime signatures are refused.

```
codex-device-access status
codex-device-access unlock
codex-device-access lock
codex-device-access unlock --simulate-passcode
```

The root CLI is armv7; the one-shot SpringBoard payload has armv7 and arm64 slices for A7 devices. iOS 7 uses SBLockScreenManager, MCProfileConnection.isPasscodeSet and SBUserAgent's native lock path. The old SBAwayController adapters remain separate. A matching method name alone is insufficient: signatures are checked before invocation. Current-state passcode lock is not used as a substitute for whether a passcode is configured.

Native iOS 7.1.2 tests: status, unlock, lock, status roundtrip and simulated-passcode refusal. Earlier iOS 4.3.3/6.1.3 adapters were tested in the original release; those physical devices were not changed during the iOS 7 port. The first iOS 7 lockUIFromSource attempt returned without locking; it was replaced with the verified SBUserAgent.lockAndDimDevice path. No passcode was set/removed by testing.

Build with external SDK/stubs and ldid:

```
export IOS4_SDK=/path/to/iPhoneOS.sdk
export IOS4_STUB=/path/to/legacy/link/sysroot
export IOS7_STUB=/path/to/arm64/link/sysroot
export IOS4_LDID=/path/to/ldid
python3 build.py
python3 package.py
```

The arm64 System supplemental TBD declares only standard exports missing from the external stub set; SDKs are not distributed. Remove using `dpkg -r local.codex.device-access`. Logs remain at `/var/log/codex-device-access.log`; temporary request/result bundles are removed after each operation. The one-shot image stays mapped until SpringBoard exits so queued code remains valid; it has no later timer or command reader.

License: GNU GPLv3; see COPYING.
