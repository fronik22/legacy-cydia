# iOS6 validation — 2026-10-16

Installed the exact existing LocalSend5.7.4338 IPA on iPad2,2 / iOS6.1.3(10B329). Executable SHA2561759a6e6c606d2429e73de1ab67d308ffe1867f6719ac923b22dd678c62a8adc, identical to the verified iOS4 release. No application code or build change required. No Photos bypass tweak installed on this device.

## Observed results

- Native iOS6 Photos permission dialog appeared; approved only LocalSend's Photos access. Authorization changed0(not determined)→3(authorized). No Location permission prompt or bypass was used. Global Location Services was already on and was left unchanged; an off-state iOS6 run was not performed.
- The initial Photos library was empty. Added only two generated32×32 PNG images and one generated160×120 H.264 test clip through public ALAssetsLibrary save APIs. All returned native asset URLs were recorded privately.
- Actual clean app gallery: Select all/deselect, mixed3-item selection, back/re-entry and rotation preserve the selection. Native widths768portrait /1024landscape pass.
- Exported all3 originals without re-encoding. Native filenames were used on iOS6. Byte hashes match the generated inputs and the remote-received bodies. One certificate-pinned HTTPS offer, three accepted uploads.
- Native receiving: certificate-pinned info/offer/Accept and exact256KiB binary receipt pass.
- Removed only the3 recorded test Photos, restored the original empty library, removed own Documents/test exports and test history/host. Restarted exact clean app to flush app-side one-shot test code. Ordinary Photos permission remains granted for normal use. No persistent testing service or auto-loaded tweak installed. A one-shot SpringBoard permission helper, like the existing device-access helper, stays mapped until SpringBoard exits; it has no timer, hook or command listener, and its files were removed.
- The existing Cydia audit reports missing md5sums on old packages; unchanged before/after. No Cydia package was installed, removed or repaired by this test. Firmware, proxy/VPN and Location Services settings unchanged.

## Limits

Verified on iPad2,2/iOS6.1.3, alongside the earlier iPad2,1/iOS4.3.3 validation. Other iOS6 versions, iOS5, Retina hardware and large-file stress remain untested. Transfers used authenticated USB forwarding to a local TLS fixture; this does not measure Wi-Fi/VPN throughput. Only standard one-time Photos approval is needed for the tested iOS6 multi-select workflow; the iOS4-specific tweak is not used.
