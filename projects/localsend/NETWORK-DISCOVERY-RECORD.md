Latest: build4340 makes the added automatic search optional and OFF by default. The following is the historical4339 verification; see AUTOMATIC-DISCOVERY-RECORD.md for4340.

# Network discovery correction — build5.7.4339

2026-10-16. Tested on iPad2,1/iOS4.3.3 and iPad2,2/iOS6.1.3. Previous4338 retained.

The initial one-way discovery coincided with a Wi-Fi transmit-path stall on6: receiving broadcasts worked, but generated ARP replies were not received by the other iPad. Numeric router/LAN/InternetTCP and DNS failed together. Radio reset recovered actual LAN connectivity. A separate Mac proxy was stopped and restored persistently.

The app additionally announced only at startup/manual scan, joined multicast on the default interface and did not refresh discovery on foreground/reconnection.4339 centralizes announcements, explicitly joins/sends on en0, refreshes group membership and announces every10s while active, announces immediately on foreground and stops its timer when inactive. No DNS server, TLS verification, transfer protocol, saved identity or user data is changed by the IPA.

Both upgraded devices retained every saved preference key and exact packaged executable bytes. With both apps foreground, clearing their in-memory peer lists followed by15s wait rediscovered each other without any manual scan. Actual app transfers passed over real Wi-Fi both directions:128KiB binary per direction, identical bytes/SHA256, discovered-peer HTTPS pinning and receiver Accept. The first QA attempt did not accept an offer because its temporary observer used the wrong UI state field; the app was waiting normally. Corrected the observer, rejected only the synthetic offer, reran successfully, restored original preferences/history and removed test files. No diagnostic command reader is included in the clean IPA.

Separate recovery package `Legacy Network Recovery1.0.0` monitors gateway ARP and can reset a stuck radio. It is not required for healthy discovery; the app itself cannot repair a failed physical Wi-Fi path. See the network-recovery report for activation requirements and limits. No firmware/AP internal trigger or long-term battery behavior has been established. iOS5, other6.x versions, router isolation/multicast blocking and Retina hardware remain untested here.
