# Current audit —1.1.1

See README.md iOS7 audit for native32/64 sampler and Settings-loader checks. New package is built; live service upgrade is coordinated by the parent task. Historical1.0.0 device results below are retained, not relabeled as new-version installation.

# Power Logger — installed result

Installed1.0.0 on iPad2,2 / iOS6.1.3. Settings > Power Logger > Recording. ON,15seconds. It runs without USB; OFF halts sampling. Default OFF in the distributable package.

Captures net battery current/voltage/temperature/charge/charging, per-process CPU/RAM, total CPU cores, GPU3D, interface traffic and actual Amnezia status.32MiB JSONL cap. Logs: /var/mobile/Library/Logs/LegacyPower/. analyze.py summarizes sessions and flags candidate high load, heat and sample gaps. CPU is not per-app energy.

Actual native Settings ON/OFF/ON,18s no-write OFF, remove/reinstall preservation, installed payload hashes, own-CPU99.43% calibration and host math/rotation/parser/package tests passed. In short idle traces, logger~0.17–0.19% of one CPU core and~1.1MiB RSS. See WORKLOG.md for rejected attempts and exact limits.

Battery reports~84.8% of design capacity and619cycles; USB charging is currently active. This does not establish the drain cause. Leave VPN on, unplug and record at least15minutes of the usual video, optionally with playback pauses. A later cached-local-copy comparison can isolate network/VPN cost. No cause or per-app watt claim until suitable traces exist. Reboot supervision/other devices not tested.
