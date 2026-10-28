# Power logger plan — 2026-10-25
1. Reuse older VPNBench battery/network concept and existing PreferenceLoader/build/package patterns; inspect actual iPad2/iOS6 telemetry before choosing APIs.
2. Native low-frequency recorder: battery charge/current/voltage/temperature/charger state, total/per-process CPU/RAM, GPU where available, interface bytes/rates, brightness/frontmost app and Amnezia state. Missing metrics explicit; never invent per-app watts.
3. Switchable Settings pane; default OFF on other installs, enable this user's recording after verification. OFF must stop sampling; no shell/ps polling, network requests, wake lock, reboot or respring. Bounded local logs and session markers for VPN/video comparisons.
4. Tests: delta/PID reuse/wrap/invalid units, rotation/space cap, off/on lifecycle, actual Settings switch, overhead and installed payload identity. Document source, failures and limits. Export shareable deb+source+analysis tool.
5. Record an initial live window; do not stop ongoing playback or VPN to manufacture a comparison. Unplugged same-video/quality/brightness VPN ON/OFF sessions needed to attribute battery drain, separate current measured under USB charging.
