# Native switch regression (developer only)

Build `make build/ToggleRegression.bundle` with the device toolchain. Foreground a test Amnezia6 app, inject the bundle with the existing jailbroken-device test tooling, resume the target after the injector exits, and read `/var/mobile/Library/Caches/a6-toggle-regression.json`. This mocks the app-side daemon methods without changing the real VPN. The five cases must pass, including zero reloads for an unchanged status while the switch value is changing. Terminate/relaunch the app afterward to unload the helper. It must never be installed as a Substrate tweak or shipped inside the app.

Legacy UISwitch can track through child gesture recognizers. A status poll must not reset a tracked gesture; responses captured before a control operation must not overwrite its result, even if delivered after the operation completes. Native physical-input checks are separate from these deterministic interleaving tests.
