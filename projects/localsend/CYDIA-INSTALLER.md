# Cydia IPA installer

This package uses official appinst+AppSync Unified from https://cydia.akemi.ai/ on iOS5–7. Its app remains an ordinary platform-installed IPA with the same bundle identifier and existing container. Removing this Cydia installer leaves the installed app/data; delete the app via Home Screen separately. Existing /Applications app bundles are refused for explicit manual migration. iOS4 users retain the standalone IPA route.

Read ../../notes/APPS-IOS7.md for exact builds, API audit, real runtime checks and limitations. App workflows on iOS7 remain unverified. Package building requires the unchanged matching released IPA. Shared packager/tests live in ../localsend/packaging; source licensing includes vendor/ThirdParty components. No Apple SDK/stubs or user data belong in source releases.
