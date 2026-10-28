# Optional automatic LocalSend discovery — 2026-10-20

Requested: make the added foreground automatic discovery optional, disabled by default. Preserve manual scanning, passive discovery, receiver/transfers, user preferences and compatibility with iOS4.3.3–6.

Scope: AppDelegate preference/settings/lifecycle/timer guards, settings layout, RU/EN/UK localization catalogs, build version/IPA, focused native tests, installed-app upgrade, release source/notes. Original source/catalog/build script/IPA retained under before/. Existing app data will be preserved by upgrade semantics. No radio, VPN, DNS or daemon changes.

Implementation choice: off disables the repeated 10-second search and automatic search on returning to the foreground. Startup retains its original single announcement; refresh still performs a single scan; passive protocol responses remain available. On restores the existing foreground automatic behavior. The choice persists across launches.

Completed:
1. Added persisted `automaticDiscovery` BOOL, default NO when absent, and a Settings → General → Автопоиск / Auto discovery / Автопошук switch with an explanation. Extended settings layout for the fifth row and added RU/EN/UK catalogs.
2. Gated both periodic timer creation and automatic foreground rescan. Switching off invalidates an existing timer immediately; switching on scans immediately and creates the foreground-only timer. Existing inactive/termination cleanup retained. Startup single announcement, manual refresh and passive UDP responses remain enabled.
3. Built clean armv7/minimum4.3 IPA4340. Temporary native QA bundle first needed CoreGraphics added to its linker frameworks; no app code change was required.
4. Upgraded the connected original iPad2,2 / iOS6.1.3 using device-specific upgrade semantics. Installed executable equals packaged bytes; every pre-existing saved preference survived upgrade.
5. Native tests on the exact clean IPA: default OFF and no periodic calls across12s; manual refresh emits one announcement without creating a timer; enabling creates a timer, announces immediately and repeats across12s; ON survives full app relaunch; inactive/active lifecycle callbacks stop/restart the enabled timer; switching OFF stops it across12s; manual refresh still works; OFF survives another full relaunch. Receiver-ready and passive UDP socket checks passed throughout.
6. Native text/bounds checks passed for RU/EN/UK at320,768,1024 widths (9 cases). Actual iPad settings rendering reviewed: switch and explanation visible, OFF state clear. This is layout testing, not Retina hardware testing.
7. Compared prior/new IPAs: only executable, Info.plist and three translation catalogs changed. HEIC modules and all other resources are byte-identical. Test observer bundles/requests/results removed; clean app relaunched with automaticDiscovery=false. All unrelated preference values retained.

Not measured/retested: battery/CPU consumption; physical iOS4.3.3/5 and second-iPad interoperability on this build (only iOS6.1.3 attached). Previous protocol/transfer tests remain historical; transport code and receiver code are unchanged.
