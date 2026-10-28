# Legacy Device Access

One-shot, root-operated screen access helper for two exact legacy systems:
iOS 4.3.3 and iOS 6.1.3. It is a diagnostic tool, not a general unlock service.

The CLI (`/usr/bin/codex-device-access`) accepts `status`, `unlock` and `lock`.
It refuses configured passcodes, installs no daemon or listener, has no SUID
mode and adds no boot hook. The payload (`AccessOnce.dylib`) is loaded only for
the explicit one-shot operation.

The package intentionally caps firmware below 7.0 and the source refuses any
other OS version. There is no iOS 7 support claim.

## Build

```sh
export IOS4_SDK=/path/to/iPhoneOS.sdk
export IOS4_STUB=/path/to/compatible/import-sysroot
export IOS4_LDID=/path/to/ldid
python3 build.py
python3 package.py
```

Apple SDKs, signing identities and device data are not included.

## License

GPL-2.0; see `COPYING`.
