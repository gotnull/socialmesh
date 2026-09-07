# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.63.0] - 2026-09-07

### Fixed (Live Activity disappearing while connected)

- The iOS Live Activity no longer stays gone after the system ends it while the radio is still connected (#320, thanks lnx13). iOS can end a Live Activity on its own, and the app only ever created one on connect, so once it was gone the only way back was to disconnect and reconnect the radio. The app now checks the activity's real state whenever it returns to the foreground and every 30 seconds while it is in front and connected, and recreates the activity if it has ended. The Dynamic Island and Lock Screen switch is still respected, an activity that is merely stale is left alone, and a momentary failure to query the system does not replace a healthy activity. Recovery while the app is suspended is not guaranteed

### Added (Mesh Beacon notice on Channels)

- A compact notice at the top of the Channels screen announces new Mesh Beacon offers as they arrive (#321, thanks Nullvoid3771). Tapping it opens the Mesh Beacon screen and marks the offers it showed as reviewed; the close button does the same without leaving Channels. Only the offers on screen at that moment are acknowledged, so a beacon that arrives later still surfaces, a beacon repeating the same offer on its interval does not, and an offer whose channel, region or preset has changed counts as new. Reviewed offers are remembered per radio across restarts. Channel offers and radio-setting offers both qualify; a beacon carrying only a message does not

## [1.62.0] - 2026-09-06

### Added (Continuous GPS)

- The GPS Update Interval in Position settings gains a "Continuous (5s)" option (#319, thanks lnx13). Meshtastic firmware never powers the GPS down between fixes when the interval is under 10 seconds, so this is the setting for a tracker that needs a live fix at all times. A caution under the chips spells out the battery cost while it is selected. A radio already set below 10 seconds from the CLI used to be shown, and on save silently rewritten, as "Default"; it now shows as continuous and keeps that on save. Meshtastic only; MeshCore has no equivalent setting

### Fixed (own node ignored the map transparency setting)

- The Mesh Map's node transparency setting now applies to your own node marker as well (#311, thanks markusgritsch). 1.61.0 claimed this fix but applied it only to the shared map widget used by the dashboard, geofence and position-history maps; the Mesh Map tab draws its markers itself and kept its own always-opaque rule for the connected node, so the setting still looked ignored where it was reported. Your marker stays easy to find because it is drawn larger than the others

### Fixed (App Log empty on store builds)

- Settings > Tools > App Log no longer shows "0 entries" on App Store and Play builds (#298, thanks markusgritsch). Store builds ship with every console logging flag off, and the in-app log was only fed from those same flags, so the boot timeline, session readiness and handshake retry lines that 1.61.0 added for launch and connection triage could never be exported from a phone. Those lines now always reach the in-app log. Console output is unchanged
### Changed (Mesh Map zoom)

- The Mesh Map now zooms in to level 21 instead of 18 (#315, #316, thanks Lynxie), close enough to place a nearby tracker on a single building or yard. Past each tile source's real limit the last real tiles are enlarged rather than left blank. Dark, Light and Satellite are requested no deeper than level 18, because CARTO and Esri hand back placeholder or empty tiles at their advertised deeper levels outside city centres; MapTiler terrain serves to 20 and OpenTopoMap to 17. Offline region downloads keep their existing detail presets, so this does not change how many tiles a region fetches. The MeshCore map, World Mesh, the geofence picker and the position history map zoom to the same level
- The map's zoom-in button no longer stays greyed out after zooming out again. It read the zoom level only when something else redrew the screen, so hitting the maximum with the button and then pinching out left it disabled. The controls now follow the camera directly

### Fixed (Terrain map when MapTiler refuses the key)

- The Terrain style no longer fills the map with "invalid key" placeholder tiles when MapTiler disables the app's key (#317). MapTiler's free plan pulls the key for the rest of the month once its monthly request cap is hit, which happened in late July and again from 16th August, and every terrain tile came back as the placeholder for the rest of that month. The app now notices the refusal on the first tile and moves Terrain onto OpenTopoMap for the rest of the session, on every map surface, with the credit line updated to match. Each launch tries MapTiler again, so the sharper MapTiler terrain returns on its own once the key is back. Dark, Light and Satellite are not affected

### Changed (offline terrain regions)

- Offline region downloads of the Terrain style now come from OpenTopoMap, never MapTiler. MapTiler Cloud's terms prohibit bulk download of tiles, and since 1.55.0 the downloader had been filling terrain regions from MapTiler whenever its key was configured. The live map still uses the sharper MapTiler terrain while online; the moment the phone loses its connection it reads the OpenTopoMap tiles the downloader wrote, and the credit line follows. The Offline Maps screen always shows the downloaded source, so what you see there is what you have. Terrain regions downloaded between 1.55.0 and 1.61.0 came from MapTiler and need downloading again; Dark and Light regions are unaffected

### Fixed (Builds without backend credentials)

- A simulator or contributor build with no RevenueCat API key no longer crashes shortly after launch (#318, thanks Lynxie). The cloud sync entitlement service asked the RevenueCat SDK for customer info as soon as an anonymous Firebase sign-in completed, and the native SDK aborts when it is used before being configured. Every RevenueCat call in that service is now gated on the SDK reporting itself configured, so a build with an empty key resolves to "no cloud sync" instead of dying. Demo mode (`--dart-define=SOCIALMESH_DEMO=1`) now skips purchases and cloud entitlement entirely, so paywalls show no products and nothing is sold while the app runs on sample data
- Demo mode now actually switches on. Dart reads a `SOCIALMESH_DEMO=1` define as off, because its boolean parser accepts only the literal "true", so the documented flag had never enabled demo mode at all. Both `=1` and `=true` now work
- A fresh clone can now build. The `.env.example` template was caught by the `.env.*` ignore rule and never reached the repository, so the bootstrap script had nothing to copy and the `.env.client` asset the app bundles was never generated, which fails every build before demo mode is reached. The template is tracked, and the bootstrap script now generates `.env.client` after installing dependencies; the README explains the two files
- Demo mode no longer touches the backend at all: it skips the anonymous Firebase sign-in, the remote flag overrides and the online presence write, so a sample-data build leaves nothing in the live project. Log lines added for the demo and no-key paths are plain text
- The auth channel no longer prints the whole Firebase user, refresh token included, when the profile provider rebuilds. It logs the uid and whether the account is anonymous. The channel is off in store builds, but a debug capture or App Log export with it on carried a live credential

### Fixed (Mesh Map distance labels)

- The distance pills drawn between your node and nearby nodes on the Mesh Map no longer read "0 m" for anything under half a kilometre (#313, #314, thanks Lynxie). The 1.61.0 rounding fix reached the measure tool and the Nodes list but missed the label layer, which was still rounding to whole kilometres. The labels also now follow the connection-distance limit picked in the map menu rather than a fixed 15 km, and only show while connection lines are on. The default limit is 10 km, which the menu offers; 15 km never was a preset, so a fresh install showed no ticked option

## [1.61.0] - 2026-09-05

### Changed (Meshtastic protobufs 2.8.0)

- The app now speaks the firmware 2.8.0 protocol definitions (#306). New modem presets Tiny Fast, Tiny Slow and Medium Turbo, and the ITU amateur 70cm and 1.25m regions, appear in the radio configuration and region pickers
- Traffic Management settings work again on firmware 2.8. The module's on/off switches were removed from the protocol in favour of "a non-zero value means enabled" on each numeric field, so the screen read every setting as off and wrote nothing the radio understood. Each feature's switch now maps onto its field, and the position precision and hop management controls, which 2.8 dropped, are gone
- Configuration sliders no longer crash the screen when the radio holds a value outside the slider's range. Firmware 2.8 defaults the position suppression window to 18000 seconds against a slider that stops at 600, which asserted the moment Traffic Management opened; every radio-driven slider now pins at its nearest end while keeping the radio's real value until you move it
- The modem preset picker honours the region-to-preset legality map a 2.8 radio sends when it connects: only presets legal for the selected region are offered, choosing a region where the current preset is illegal moves to the radio's default for that region and says so, and amateur bands carry a licensed-operators-only notice (#308). Radios on older firmware send no map and see no change
- Firmware update targets refreshed against the upstream hardware table: 18 new boards, and the three hardware IDs firmware 2.8 reassigned (Makerfabs Tracker, Makerfabs reserved, MeshPager X2) report "update not supported" until their chipset is confirmed rather than inheriting the previous board's update path

### Added (Mesh Beacon, firmware 2.8)

- New Mesh Beacon module screen under Settings > Modules, shown for radios on firmware 2.8 or newer (#307). Listen and Broadcast switches map onto the module's flag bits, with the beacon message (100 bytes), the broadcast interval in hours (the firmware's one-hour floor is the slider's start), the legacy split option, and the channel, region and modem preset the beacon offers. Broadcast targets the radio already holds are carried across a save untouched
- Beacons received from other nodes are decoded from the MESH_BEACON_APP port. Their text is delivered into the channel conversation like any other message, and the beacon itself, with whatever it offers, is listed on the Mesh Beacon screen with the sender and time. An offered channel can be added to the first free slot with one tap; a channel whose key you already hold says so instead. Offered regions and presets are shown for information and are never applied automatically, matching the firmware's own rule

### Fixed (Dark and Light map watermark)

- The Dark and Light map styles no longer carry CARTO's repeated "API key required" overlay (#303). CARTO, which serves those two basemaps, started watermarking every tile requested without a key in late August, so the overlay appeared on every app version at once. The app now sends a CARTO basemaps key with those tile requests on every map surface, including the offline tile downloader and the flight route map. Satellite and Terrain were never affected. Offline regions downloaded for Dark or Light before this version need downloading again, since the tile addresses changed and the old tiles no longer match

### Added (radios that share one dataset)

- Two or more radios can now share one set of messages, nodes and history (#302). On Settings > Data & Storage > Radio data, each identified radio has a share action: pick another radio and from then on both read and write the same dataset, so switching between a home node and a mobile node on the same network shows one merged conversation history. Nothing is moved or merged on disk: the sharing radio's own data stays listed as a separate entry until you delete it, and Stop sharing returns the radio to it. Radios you do not group keep their separate storage, so a node on a different network stays separate. Sharing into a radio that is itself sharing follows through to the radio that owns the data, and deleting a dataset ends any sharing arrangements on it

### Fixed (Radio data only reachable through search)

- The Radio data screen, which lists what is stored under each radio and lets you switch between radios or delete one radio's data, now has its own tile in Settings > Data & Storage. It was registered for the settings search but missing from the browsable list, so it could only be found by typing its name (#302)

### Changed (faster first screen)

- The main screen appears sooner after a cold launch (#298). Notification setup, the slowest single step on the way to the first screen, now runs once the screen decision has been made instead of before it, and the offline map cache lookup overlaps the other start-up steps instead of adding to them. Nothing users can see changes except the wait: a notification tap that launched the app is still routed once setup completes
- The app log now carries a single BOOT_TIMELINE line per launch that times every step the app waits on before its first screen (environment, bundled data, Firebase, sign-in) and again when the main shell becomes ready, so a slow launch can be attributed from an exported log instead of a video

### Changed (dependencies)

- Firebase libraries, notifications, photo library access and the encrypted database driver updated to their current releases

### Fixed (distances rounded to whole kilometres)

- Distances on the map, in the measurement tool and in the MeshCore contact list are no longer rounded to whole kilometres. The distance library rounds its results to a whole unit unless told otherwise, so anything under 500 m read as "0 m" and everything beyond stepped 1 km, 2 km, 3 km. All geographic distances now go through one unrounded helper, so a node 400 m away reads 400 m and one 1.3 km away reads 1.3 km

### Fixed (radios renumbered by firmware 2.8)

- A radio upgraded to firmware 2.8 keeps its messages, nodes and history in the app. Firmware 2.8 derives the node number from the radio's public key, so an upgraded radio reports a new number, and the app files data per radio under that number: the radio came back looking brand new with everything filed under its old number. The app now records each radio's public key and, when a known key shows up under a new number, moves the old history under the new one. Where the key is not yet known, a Bluetooth identity that belonged to the old number is trusted as the same radio; a TCP endpoint is not, since those are shared between radios (#310)

### Fixed (recovering banner)

- Retry on the "Connection is still recovering" banner now does something. That banner means the link to the radio is up but the configuration handshake failed, typically after the radio rebooted a few times mid-setup. Retry used to hand off to the reconnect path, which declined to act because the device already counted as connected, so the button was inert exactly when it was needed. It now re-runs the handshake on the existing link. Tapping the banner body in that state does the same instead of flashing the Devices screen and bouncing back

### Fixed (region picker after a re-flash)

- A radio that comes back with no region set, after a re-flash or factory reset, now gets the region picker again. Once a region had been applied to a device in the running app, that "applied" state kept suppressing the picker for every later reconnect to the same device, so a wiped radio sat on region UNSET with no way to set it short of restarting the app. The suppression now only covers the three minutes around the apply's own reboot and reconnect

### Fixed (region setup on firmware 2.8)

- Choosing a region on a radio running firmware 2.8.0 or newer no longer ends in "Timed out waiting for device to reconnect after region change" a minute and a half later, with the region silently applied all along. Firmware 2.8 reprograms the radio in place instead of rebooting, so the app was waiting for a disconnect and reconnect that never came. The app now also reads the LoRa configuration back a few seconds after the write and accepts the region the moment the radio reports it, while radios that still reboot are handled exactly as before. Reproduced against the 2.8.0 simulator radio

### Fixed (opening a conversation from a notification)

- Opening Channels or Messages from a notification while the app was showing the Devices screen left you on a screen with no bottom bar and a menu button that did nothing. The screen is pushed above the main shell, whose drawer is not built in that state, so the menu had nothing to open. A screen pushed above the shell now shows a back arrow in place of the menu button, and tapping it returns to the shell with its bottom bar

### Fixed (resending direct messages)

- A direct message that was acknowledged only by a relay node, never by the recipient, can now be resent from the long-press menu. Such a message counted as delivered, so it was excluded from the Resend action and from the unconfirmed timeout, leaving no way to try again short of typing it out afresh

### Fixed (channel chat sender labels)

- A node whose short name is an emoji, or any other non-ASCII text, now shows that short name on its channel messages. The chat label kept only printable ASCII, so such a name came out empty and the message fell back to the node's ID digits

### Fixed (help cards on the light theme)

- The text of an Ico help card after its highlighted words was drawn in white regardless of theme, so on the light theme the tail of every card message vanished into the card. It now follows the theme's text colour like the rest of the card

### Fixed (requests to nodes on secondary channels)

- Long-pressing the traceroute button on a node's page opens a channel picker, with the channel the node was last heard on preselected, for nodes that live behind a bridged secondary channel (#312)
- Traceroute and position requests are now sent on the channel the target node was last heard on, as node info requests already were. A request sent on the primary channel never decrypts for a node that lives on a secondary channel, including nodes reached through an MQTT or UDP bridge, so it could never be relayed or answered (#312)

### Fixed (reconnecting on iOS)

- A radio that went out of range for a few minutes is no longer treated as a lost pairing. Three missed reconnect scans within two minutes used to forget the saved radio outright and show the "pairing needs to be refreshed" guidance, even though the radio still sat in the device list and connected on a single tap; a missing radio is now simply unreachable, and the saved pairing survives. Re-pair guidance is reserved for an actual authentication or bond failure
- Automatic reconnect on iOS now connects straight to the saved radio before scanning for it. iOS can reconnect to a radio it has met before by identity alone, completing the moment it is back in range, whereas the short filtered scan often missed a radio that had just returned. The scan remains as the fallback

### Fixed (traceroute)

- Tapping Traceroute the instant the button re-enabled no longer earns a "can only be sent once every 30 seconds" refusal from the radio and a second full wait. The radio times its window from when it received the request, later than the app's countdown started, so the countdown now runs two seconds longer than the radio's window (#305)

### Fixed (contacts)

- The "All roles" chip on the Contacts tab now counts the same nodes as the "All" chip. It was counting every node including your own radio, which the contacts list rightly excludes, so the two numbers disagreed by one (#304)

### Fixed (map)

- The map's node transparency setting now applies to your own node as well. Your marker was exempt by design, which read as the setting not working; it stays distinguishable by its larger marker (#311)

### Changed (settings)

- Range Test settings are hidden when the connected radio runs firmware 2.8.0 or newer, where the module no longer exists and every write to it was silently dropped (#309)

### Fixed (first connect to a radio)

- Connecting to a radio the app has never seen before no longer wrecks the session seconds after it configures. Storage is filed per radio, and a never-seen radio's identity only arrives once it reports its node number, so the storage layer re-homed its files mid-session - and one of the rebuilt stores dragged the live protocol session down with it, replacing a fully configured session with one that had never spoken to the radio. The app then looked connected but showed an empty channel list, no configuration, and never recovered until a manual disconnect and reconnect. Switching between radios hit the same path, which is how it was reported ("switching between few nodes all channels are lost"). The store now re-homes itself without touching the protocol session

### Fixed (device config backup)

- Backing up the device config no longer sits on a spinner for minutes when the radio does not answer. The backup reads up to nineteen configuration sections and waited out each unanswered request in sequence, so a radio that answered none of them (seen on 2.8.0 alpha firmware) held the spinner for the sum of every timeout; the sections are now requested together, the whole capture is bounded by a single timeout, and the partial-backup notice reports what did not answer

### Fixed (battery optimisation guide)

- Android no longer re-prompts about battery optimisation after the exemption has been granted. The guide sheet only remembered "don't show again"; it never asked the system whether the app was already exempt, so anyone who granted the exemption but dismissed the sheet another way was nagged on every connect

### Fixed (waypoint notifications)

- Repeated broadcasts of an unchanged waypoint no longer alert every time. Some relay tools rebroadcast their waypoints on a schedule, and each repeat raised a fresh notification even though nothing about the waypoint had changed; now only a new waypoint or an actual edit alerts
- Waypoint alerts can be silenced on their own. Settings > Notifications has a Waypoints switch, so schedule-heavy meshes can turn just those off without losing message notifications. The switch syncs across devices with the rest of the notification preferences
- Waypoint alerts now respect the master notification switch, which they previously ignored

## [1.59.0] - 2026-08-26

### Fixed (organisation membership)

- Joining an organisation from an invite link now actually gives you the organisation. The membership row was written correctly when you accepted the invite, but the app's query for "which organisations do I belong to" was refused by the security rules and never returned anything, so the organisation stayed invisible no matter how many times you rejoined. Only people who had *created* an organisation were unaffected, because that case is answered by a different query
- Packs an organisation had bought for you now unlock. Org-owned entitlements require both a seat and a recognised membership, and since membership never resolved, the seat had nothing to match against. Anyone who joined rather than created an organisation had been paying into a pack they could not use
- The failure was silent. The membership query treats an error as "you belong to nothing", which is the right call for deciding what to unlock but meant the refusal looked exactly like a legitimately empty account. It surfaced only once the app started distinguishing "we could not check" from "we checked and there is nothing"

### Changed (NodeDex navigation)

- NodeDex now has its own bottom bar with NodeDex, Map and Groups. The map used to be a sub-item under NodeDex in the drawer and a line in the overflow menu, and node groups were reachable only from a button inside the list; all three are now the same kind of thing in the same place
- Opening NodeDex no longer builds its map. The map is constructed the first time you tap the Map tab and kept alive after that, so switching back and forth holds its position
- If you had hidden or reordered "NodeDex Map" in the drawer, that setting is now discarded rather than leaving an entry you could never restore in the drawer customise sheet

### Changed (switching between radios)

- Each radio now keeps its own data. Messages, nodes, favourites, telemetry, routes, traceroutes, NodeDex entries, waypoints, the mesh feed and the rest of the mesh-observed stores are filed under the radio they were heard through, so connecting a second radio shows that radio's mesh instead of the first one's leftovers. Switching back restores what was there
- Connecting a different radio no longer deletes the previous one's history. The old behaviour wiped the node cache, telemetry and routes on every switch - and left messages, favourites, traceroutes, waypoints and everything else behind - so going A to B to A lost A's data for good while B still showed A's conversations
- The direct-message list no longer invents contacts after a switch. Sent messages were matched against the currently connected radio's node number, so every message you had sent from the previous radio resolved its peer to that radio itself and it appeared in the contact list, alongside conversations with peers the new radio has never heard
- Channel history no longer merges across radios. It was keyed on the channel slot alone, so two radios on different channel sets shared one "Primary" thread
- Existing data is moved to the radio it came from on first launch, and a radio is identified by its own node number, so a rotated Bluetooth address or reaching the same radio over Wi-Fi instead of Bluetooth still lands in the right place
- Settings > Data & Storage > Radio data lists what each radio has stored, with its name, node id and size, and deletes the ones you no longer want. The radio you are connected to is listed but cannot be deleted while it is in use
- A radio's name no longer degrades to its address. Reconnecting to a saved Wi-Fi radio passed the endpoint as the device name, overwriting the name the radio actually advertises, so a radio that showed as "0864_0864" became "tcp:192.168.5.104:4403" after the next launch
- Fixed the store that remembers which radio a device belongs to losing its entries on iOS, which made a known radio start from an empty mesh for a moment on connect before it recovered

### Fixed (profile images)

- A profile banner whose local file has gone missing now falls back to the default banner instead of throwing. The network branch already had a fallback; the local-file branch did not, so a banner picked from the gallery and later deleted from the phone raised an error every time the profile screen was built
- An avatar or banner that fails to download no longer files a crash report. A timed-out or dropped image fetch is the network, not a defect, but it reached reporting because the failure carries the HTTP stack rather than an image one and its message never mentions an image. A genuinely malformed image URL still reports, since that one is a defect

### Fixed (connection errors)

- A connect attempt that fails because the phone tore down the Bluetooth service under it no longer files a crash report. The app already knew that message was a normal lifecycle event, but only when it arrived bare; by the time the connect path had restated it for the error banner it was no longer recognised, and an explicit report from the scanner's error handler filed it anyway. The banner still tells you the connection failed
- Errors reported by hand from a catch block now go through the same "is this actually a defect" check the automatic reporting already used, so the two paths no longer disagree about what is worth recording

### Fixed (background downloads)

- A background download whose connection closes part-way through no longer files a crash report. Which exception a dropped connection raises depends on which end gave up first, and only the client-side half was recognised as transient, so a server or proxy closing the response mid-body was reported as though the app had done something wrong. A response that arrives and is simply an error still reports

### Fixed (databases at launch)

- A database that could not be opened because the phone's keystore was not ready yet is now retried instead of failing outright. The encryption key lives in the iOS Keychain / Android Keystore, and an app launched in the background moments before the keystore becomes readable got one attempt and gave up, leaving the store it was opening in an error state for the rest of that launch
- When a database open still fails, the app now records what it found - whether the file was there, how big it was, whether it was still unencrypted, and whether the key had just been created - so the cause is visible in crash reporting instead of a bare "open failed". No behaviour change beyond the report

### Fixed (incomplete installs)

- An Android install that is missing the app's native code now explains itself instead of disappearing behind "SocialMesh keeps stopping". A copy installed from a bare APK file rather than Google Play, cloned into a container app, or left half-written by an interrupted update has no engine to start, so it died on every launch with nothing to tell the user why. Those launches now land on a screen that names the problem and offers a one-tap route back to the Play listing
- A background wake-up on such an install stays silent. A push message or a scheduled task that hits the same missing library fails on its own rather than throwing a full-screen error over whatever you were doing at the time

### Fixed (device scanning)

- Tapping your saved radio in the Devices list now always starts a connection. The saved-device row was routed through the same protocol guesswork as anonymous scan results, so a radio renamed away from the stock "Name 1234" pattern was treated as an unknown device and the tap was silently ignored - the only workaround was to unpair and pair again. The device's protocol is already known from when it was first paired, so the row now connects directly
- Android's "SCAN_FAILED_APPLICATION_REGISTRATION_FAILED" plugin error is no longer shown raw (and untranslated) in the scan error banner. When Android's Bluetooth service refuses to start a scan - a phone-side state that clears after toggling Bluetooth off and on - the app now shows a plain-language recovery card with a shortcut to Bluetooth settings, and clears it automatically once scanning recovers
- A failing scan no longer retries every 3 seconds. Android limits apps to five scan starts per 30 seconds and slows down offenders, so the fixed retry loop could keep the scanner stuck in the very throttled state it was trying to escape. Failed scans now back off (5, 10, 20, 40, then 60 seconds between retries) until a scan succeeds

### Fixed (message length limit)

- Sending a maximum-length direct message no longer fails with "Message too large" (#270). The composer's byte counter budgeted every message against the plain-text ceiling (228 bytes), but a DM to a node with a known public key is sent encrypted, and the radio reserves 14 extra bytes on those packets: 12 bytes of crypto overhead plus a 2-byte flags field the firmware stamps onto the payload before its size check. The counter now shows the encrypted ceiling (220 bytes) for those conversations and the app blocks an oversized send before the radio has to reject it
- The message input now enforces its limit in UTF-8 bytes rather than characters, so multi-byte text (umlauts, emoji) can no longer be typed past the wire budget

### Fixed (reactions)

- Reactions in busy channels are no longer swallowed by the rapid-fire duplicate filter. The filter keyed on channel + text + a one-second-resolution timestamp, so when several members reacted with the same emoji within the same second (typical of MQTT-fed rooms, where the broker delivers in bursts) every reaction after the first was silently dropped. The filter now also keys on the sender and the reacted-to message, so only true cross-path copies of the same reaction are collapsed
- A reaction is no longer suppressed when the same member posted the same emoji as a normal message moments earlier

### Fixed (telemetry charts)

- Battery % no longer draws a spurious staircase step at every reconnect (#285). The connect handshake replays the radio's cached node records, and the cached battery reading was being logged as a fresh sample at the current time, repeating the pre-disconnect value. Cached records now update the display only; chart history rows are written only from live telemetry packets

### Fixed (notification taps)

- Tapping notification after notification for the same conversation no longer stacks a pile of identical screens. If the thread the notification is about is already the screen you are on, the tap keeps you there instead of pushing another copy, so one back tap returns you to where you started rather than to another copy of the same chat. Applies to Meshtastic channels and direct messages and to MeshCore channels and contacts, whichever way the thread was opened
- The channel list and conversation list a notification falls back to when the thread cannot be resolved no longer stack either. Repeated taps while the radio was still sending its channel config used to pile a channel list on top of whatever you were reading
- Notification taps that previously did nothing at all now open the right screen. Batched message and node summaries open the matching list, a discovered node opens its detail screen, a detection-sensor trigger opens the sensor log for the node that reported it, a shared waypoint opens the map centred on it, a TAK event opens its detail screen, an Aether flight opens its flight screen, NodePet milestone and care alerts open the pet, a firmware notice opens the updater, MeshCore adverts open the contact list, an incoming SIP direct message opens that conversation, a SIP Play turn opens the game thread, and a bug-report reply opens the report

### Fixed (hostile node names)

- A nearby node whose name contains emoji can no longer crash the app. Avatar and marker initials were cut by UTF-16 code unit, which could slice an emoji in half and leave a malformed character that crashes the system text renderer during layout. Names are now cut on character boundaries everywhere they are shortened, so the node list, node detail, messaging, remote admin and background notifications all stay up regardless of what a peer advertises
- Node names arriving from the mesh are now capped in length. The radio firmware limits a long name to 40 bytes, but the over-the-air format does not, so a non-conforming node could advertise a name of any length and have it flow untruncated into every list and map label
- Names read back from the NodeDex database, from NodeDex cloud sync, from the saved node-identity cache and from the World Mesh API are now repaired before display. Previously only the live radio path cleaned them, so a name saved by an older build, or synced from another device, could still reach the screen with characters that crash text layout
- The saved node-identity cache no longer discards every stored name when a single record is unreadable, and a corrupt cache file no longer leaves node names permanently missing for the rest of the session

### Fixed (Bluetooth connection)

- Occasional undecodable data from a radio no longer builds up over a session until the app drops the connection. The counter that watches for a run of unreadable packets was never cleared by a packet that read correctly, so ten bad packets spread across hours of healthy traffic would force a disconnect, and the cycle then repeated every ten packets
- Radios that miss the app's first configuration request no longer hang the connection on "configuring" until Bluetooth drops: the app now re-sends the request once (with a wake-up heartbeat) after 8 seconds if the radio has not started its config dump. Previously only network (TCP) connections retried; Bluetooth and USB waited the full 30 seconds and often disconnected mid-wait, producing a constant connect/drop loop on some radios
- If configuration still times out while the Bluetooth link is up, the app now performs a quick clean reconnect (up to 3 attempts) instead of sitting on "configuring" until the system kills the link
- Bug reports and disconnect logs now record how far the configuration handshake got (phase, config frames received, start time) so stalled connections can be diagnosed from a single report
- Going out of Bluetooth range and back no longer leaves the app permanently stuck on "Configuring SocialMesh" with every send blocked (#249). The second phase of the connect handshake previously gave up silently after three attempts; it now keeps retrying on a widening schedule (about a minute in total) and, if the radio still does not answer while the link is up, performs the same bounded clean reconnect as a configuration timeout - so the session heals itself instead of needing a manual disconnect/reconnect
- The two automatic reconnect paths (in-app scan and system-level Bluetooth reconnect) no longer race each other: both now run the same canonical session restore, closing a gap where a system-level reconnect during scanning could leave the app connected but never re-run the configuration handshake

### Fixed (timestamps)

- NodePet timeline entries (including the hatch date and stage-start dates), the NodePet recent-activity card, and the incident list's created-at label showed times in UTC instead of the phone's time zone - out by the full UTC offset for anyone not on UTC. All three now render in local time; message timestamps were already correct

### Added (automations)

- Automations can now be duplicated: a copy button on each automation card creates a "(Copy)" of the automation with fresh run stats and opens it in the editor. The copy starts disabled so it cannot double-fire the original's trigger before you adjust it

### Added (nodes)

- Remove Node is now available directly in the node long-press quick-actions sheet (with the same confirmation step as the detail screen), instead of only via the detail screen's overflow menu

### Added (messages)

- Message formatting, matching the official Meshtastic iOS app (#250). The composer shows a formatting toolbar while typing: bold, italic, strikethrough, code, and link buttons wrap or toggle the selected text with the same markdown markers the official app uses, and the link button prompts for a URL. Message bubbles render the formatting - styled text, monospaced code, and tappable links (behind the existing confirm-before-open sheet) - while malformed markup falls back to plain text

### Changed (messages)

- The Contacts and Channels tabs now remember their card/compact view style independently. The existing preference carries over to both tabs, and the view toggle in the overflow menu applies to whichever tab is on screen

### Fixed (messaging)

- Messages composed while disconnected from the radio are no longer silently lost if the app restarts before reconnecting: they now show as failed with a retry button instead of appearing queued forever. Queued messages also send more reliably after reconnect (the queue now waits for the radio's config exchange to finish instead of giving up after 10 seconds)
- Messages composed on a disconnected cold start (before the app has spoken to the radio this session) are now attributed to your own node via the last known device identity, instead of rendering as incoming bubbles after a restart
- Messages the radio pulls directly from an MQTT broker are now labelled MQTT: transport classification treats the packet's transport mechanism (TRANSPORT_MQTT) as authoritative alongside the via-MQTT gateway flag, so a broker-sourced message can no longer read as RF (#256)

### Fixed (nodes list accessibility)

- The coloured node avatar circles in the Nodes list (both the expanded card and the compact tile) are now top-aligned with the card text instead of floating vertically centred beside multi-line entries (#227)

### Fixed (notifications)

- The iOS app icon unread badge now updates when a message arrives while the app is in the background, instead of only after opening and closing the app (#248). The badge count now travels inside the notification itself, so iOS applies it the moment the banner is delivered
- Automation notifications (such as "node silent" alerts from a Dead Man's Switch automation) now respect the master notifications toggle, and a new "Automation alerts" switch on Settings > Notifications can silence them without disabling the automation. A still-silent node also alerts once per silent stretch instead of repeating every few minutes, re-arming only after the node is heard from again

## [1.55.0] - 2026-07-10

### Fixed (telemetry charts)

- Chart legends no longer clip when they wrap to a second line: the pinned legend header now measures its labels at the current text size and grows to fit every row instead of using a fixed 40px height (device metrics, environment metrics). The two screens now share one legend widget (#228)
- The topmost axis label on telemetry charts (e.g. "100%") is no longer cut in half: charts reserve headroom above the plot so the label renders whole, scaling with text size (#228)
- Telemetry and node-history graphs now draw straight lines between readings instead of smoothed curves, so the plot follows the actual samples without invented dips or bumps (#225)

### Fixed (nodes list accessibility)

- The coloured node avatar circles in the Nodes list now grow with the text-size setting (up to 1.5x) instead of staying fixed while the text scales (#227)

### Fixed (MeshCore notifications)

- MeshCore channel-message notifications now show who posted: the sender name that MeshCore radios embed at the start of every channel message is parsed into the notification title ("Alice in #general") and stripped from the body, instead of a generic "MeshCore (----) in channel" title (#226)

### Added (distribution)

- Official signed APKs now accompany GitHub releases so devices that Google Play filters out (e.g. GrapheneOS) can sideload, with a published SHA-256 checksum per build (#179). Note: Play installs and GitHub APK installs are signed differently and cannot update each other

### Fixed (notifications)

- Incoming-message notifications work again: versions 1.52 and 1.53 shipped with an internal CarPlay flag mistakenly enabled, which silently suppressed every new-message banner on both iOS and Android while the messages themselves still arrived in-app. Suppression is now additionally gated so it can only engage when a CarPlay communication banner is guaranteed to replace the standard one (explicit opt-in, iOS only), so a stray flag flip can never silence messages again
- Muting a channel no longer silences direct messages: a DM arriving on the Primary Channel slot (index 0) was suppressed when channel 0 was muted; per-channel mute now applies to channel broadcasts only

### Fixed (map)

- Node transparency is now applied consistently after reopening the app. Markers built before the saved "Node transparency" setting finished loading were cached fully opaque and stayed that way, so some nodes rendered faded and others solid with no settings changed. The marker cache now tracks the overlay opacity, so every peer marker follows the setting from the first frame
- Node markers no longer tilt with the map when "Cluster markers" is enabled: the cluster layer now counter-rotates its markers the same way the plain marker layer always did, so icons and cluster count badges stay upright while the map rotates in free-rotate or follow-heading mode
- The map compass mode (north-locked / free-rotate / follow-heading) is now remembered across tab switches and app relaunches instead of silently resetting to north-locked every time the Map tab is reopened. North-locked stays the first-run default
- The map overflow menu toggle is now labelled "Show cluster markers", matching the "Show ..." wording of every sibling toggle (previously just "Cluster markers")

### Added (automations)

- The "Send Message" action can now reply to the sender: a new "Reply to sender" toggle (offered for message, keyword, channel-activity, and detection-sensor triggers) answers whichever node produced the triggering event instead of a fixed target node, so a "reply pong when anyone messages ping" bot no longer needs a pinned node. Available in both the standard action editor and the visual flow builder; a reply-to-sender action that fires from a senderless trigger (scheduled/manual) fails with a clear log message instead of sending anywhere

### Added (messaging)

- Channels can now be reordered: a "Reorder channels" action (long-press any channel, or the Channels screen menu) opens a drag-to-reorder sheet, and the chosen display order is remembered across app launches. Reordering is presentational only - the radio's channel slots and message routing are untouched, and channels added later simply follow the ordered ones
- The Messages screen gains a "Compact View" toggle in its overflow menu, mirroring the Nodes screen option: both the Contacts and Channels lists switch to dense flat rows (smaller avatars and badges, single metadata line), and the choice is remembered across app launches
- The Quick Responses sheet gains a "Send alert bell" action: one tap sends a message whose radio payload is exactly the ASCII bell character, byte-identical to the official clients' quick-message bell, so recipients whose radios have the External Notification module configured get a buzzer ring and official apps show their native bell rendering. Locally the message appears as a bell emoji, since a raw control character can never be shown in chat text
- Message details (long-press a message) and the expanded technical info now show the node that relayed a received message, matching the official Meshtastic iOS app. The radio only sends the last byte of the relayer's ID, so the name is a best-effort match against known nodes and falls back to a hex byte (for example `0xC4`) when it cannot be resolved to a single node (#223)

### Added (map)

- Pasting coordinates ("51.911157, 14.492985") into the map's node search now shows a "Go to coordinates" row that jumps the camera there, with a companion action that opens the waypoint form pre-filled with the pair; the offline map's place search recognises pasted coordinates too and jumps directly without the geocoder (so it works fully offline)

### Added (nodes)

- The node long-press quick-actions sheet gains "Message" (jumps straight into the direct-message chat) and "Show on Map" (centres the map on the node, shown only when it has a position), so neither needs the detail-screen detour. The Contacts list's long-press sheet hides the redundant "Message" entry since tapping the contact already opens the chat

### Fixed (automations)

- Automation message templates no longer render a missing battery level as "?%": `{{battery}}`, `{{location}}`, `{{node.name}}`, and `{{sensor.name}}` now all fall back to a localized lowercase "unknown" when the source value has never been reported, so a welcome message reads "your battery level is unknown" instead of "?%"

### Fixed (firmware update)

- The in-app "Start Update" button no longer does nothing while the app is disconnected from the radio. The button rendered from cached node data even with no live Bluetooth link, and tapping it gave haptic feedback then silently returned. It now disables with a "connect via Bluetooth" hint while disconnected, and shows an error snackbar if the link drops in the instant between render and tap
- A failed firmware release check (no network, GitHub error) now shows the "update check failed" banner instead of quietly looking like "you're up to date"

### Fixed (WiFi/TCP connection)

- The app now notices a dead WiFi/TCP link in under a minute instead of after several minutes. The TCP socket gets tuned OS keepalive (20s idle, 10s probe interval, 3 probes): a powered-off or vanished radio cannot answer the kernel's probes, so the connection resets ~50s after the last exchange and the connection state flips immediately, foreground or background. A quiet-but-alive radio still answers the probes, so silent meshes never trigger a false disconnect

### Added (connection diagnostics)

- Every BLE link teardown is now recorded with its origin (OS-reported disconnect with the platform reason code, notification stream closing, app watchdog, or user action), the session uptime, and the age of the last received packet. The detail is logged as `BLE_DISCONNECT` / `DISCONNECT_CONTEXT` lines and embedded in in-app bug reports, so "the app disconnects after about an hour" reports can be traced to the exact path that ended the link
- While backgrounded the app now allows two reconnect attempts per background session (previously one) before waiting for foreground, improving recovery from mid-session drops during long background use

### Added (messaging filters)

- The Channels and Contacts list filter chips (All / Unread / ...) now remember the last selection across app launches, so unread-first users land on their filter instead of resetting to All every cold start

### Added (telemetry)

- The Air Quality Log now includes gas-resistance readings from BME680/688 VOC sensors, merged in from environment telemetry (historical readings included), with a gas-only card for nodes that share no other air-quality metrics
- Air Quality and Environment Metrics log cards now show which node shared each reading, and tapping a card jumps to the map centred on that node (when it has a position); the back button returns straight to the log

### Changed (messaging)

- The hop count is no longer a separate pill under each received message. The bubble's timestamp line now reads time, hop count, and SNR in one line (for example `2:05 PM - Direct - SNR 6.5 dB`), so reception quality is visible at a glance without expanding the message (#224)

### Changed (nodes)

- Finished removing the accent-colour special treatment for your own node: the node detail hero and the node card tint now follow the same identity-colour and presence rules as every other node, so your node appears in the same colour other users see (#222)

### Fixed (nodes)

- Unfavoriting a node now sticks across reconnects. Previously the un-favourite admin message was fire-and-forget: if the radio missed it (or never saved its node database to flash before powering off), the radio kept reporting the node as a favourite and the app re-favourited it on every reconnect with no way to turn it off. The app now remembers an explicit un-favourite, refuses to let a stale device flag resurrect it, and automatically re-sends the un-favourite (and any lost favourites) to the radio after each reconnect until the radio confirms
- Reset Node Database no longer races the radio: the app waited only half a second before re-requesting the radio's configuration, so a slow reset commit could replay the old node list straight back into the app. The wait now outlasts the firmware's commit window. Note that nodes still legitimately return over time as the radio re-hears them from the mesh, and immediately over MQTT while downlink is enabled

### Added (offline maps)

- On Android, offline map tiles can be stored on a removable SD card instead of internal memory. The storage picker lives in the "Download this area" sheet and in a new Settings > Data & Storage > Offline Map Storage tile (shown only when a card is present or a fallback needs explaining), which also shows the current cache size and offers to delete the old cache after a switch. Portable/removable cards only: cards formatted as internal (adopted) storage are part of internal memory by Android design. If the card goes missing the cache falls back to internal storage with a visible warning

## [1.54.0] - 2026-07-06

### Added (security hardening)

- Sensitive local databases (direct messages, saved routes, waypoints, peer-safety state, and the NodeDex journal) are now encrypted at rest with SQLCipher. The key is generated on-device and held in the iOS Keychain / Android Keystore, so message text, locations, and travel history are no longer readable from the raw database files (for example from a device backup, or on a lost or rooted/jailbroken phone). Existing data is migrated in place on first launch with no loss of history; if the one-time migration is ever interrupted it safely retries on the next launch

## [1.52.0] - 2026-06-26

### Added (security hardening)

- Tightened the Android network security configuration so first-party services and the fixed third-party APIs (socialmesh.app, Firebase/Google) are pinned to HTTPS and can no longer be silently downgraded to plain HTTP, while user-configured private/LAN webhooks continue to work over HTTP as before

## [1.51.0] - 2026-06-15

### Added (offline maps)

- The map is now reachable without pairing a device: a new "Explore the map without a device" action on the scanner opens a lightweight, mesh-free map so a user can browse and pre-download an area before they have a node (for example, prepping for an off-grid trip). It carries no protocol state and offers a clear "Pair a node to unlock mesh features" return path
- The offline map has a place-search bar (type a town/area to jump there) and a center-on-my-location button, so finding the region to pre-download no longer means panning the whole way by hand
- New "Download this area" feature pre-downloads the visible region's tiles for true offline use: pick a detail level, see a live tile-count and storage estimate, and run the download with progress and cancel. Bulk download is allowed for the Terrain, Dark, and Light styles only (Satellite and the optional Mapbox styles are excluded per provider terms); Terrain uses a lower request concurrency and backs off on rate-limit responses
- Map tile caching is now durable: the built-in tile cache is moved off the OS-evictable cache directory into app storage with a long freshness window, so cached and pre-downloaded tiles survive app restarts and stay usable offline for weeks instead of expiring or being purged

### Removed (Nothing Phone Glyph)

- Removed the beta Nothing Phone Glyph Matrix integration (the Glyph test screen, the "Glyph pattern" automation action and its flow node, and the bundled Nothing GlyphMatrix SDK). The SDK declared a minSdk of 34, which made Google Play mark the app incompatible with every device below Android 14; removing it restores installability on older Android devices. Existing automations that used the Glyph action fall back to a push notification.

### Fixed (map state persistence)

- The map now remembers where you left it when you switch tabs. Previously the Map tab was rebuilt from scratch on every visit, so the camera reset to a default view, the zoom level was lost, and the map could show a blank blue background until you pinched to refresh. The camera (center and zoom) is now retained for the session and restored on return
- User-dropped local waypoints (the yellow pins) now survive leaving and returning to the Map tab, matching how shared mesh waypoints already persisted
- Switching the map style (Dark / Satellite / Terrain / Light) now redraws the tiles immediately instead of leaving a blank background until the map is panned or zoomed

### Fixed (map interaction)

- Pinch-zoom no longer "wiggles" the map off north on any map: rotation gestures are disabled by default across every map surface (Meshtastic map, World Mesh, MeshCore map, the new offline map, and all preview/picker maps), so an uneven two-finger zoom can no longer rotate the map. The main Meshtastic map and the offline map additionally get a three-state compass control (north-locked → free-rotate → follow-heading) with a distinct look per state

### Changed (map tiles)

- Zooming past a tile source's native maximum now "over-zooms" (upscales the last real tiles) instead of requesting non-existent tiles. On the Terrain (OpenTopoMap) style this removes the server's "max zoom" placeholder tile beyond zoom 17
- Retina tiles are now requested only for sources that actually serve `@2x` tiles. Terrain no longer uses simulated retina, which lightens its tile-server load and keeps the offline download in sync with what the live map requests

## [1.50.0] - 2026-06-12

### Changed (node visual identity)

- Node and contact list tiles no longer fade with presence: the whole-card opacity ramp (active → unknown) is removed from the Meshtastic Nodes tab (both tile styles) and the Messages Contacts list, since presence is already carried by the status dot and the "Seen … ago" text, and the fade made tappable rows read as disabled while hurting legibility
- Mesh map markers now use the node's identity colour (low three bytes of the node number as RGB, user-set avatar colour wins) with a solid fill and a luminance-contrast label, matching how other Meshtastic clients colour nodes, instead of presence-tier gray/green fills; the age-based marker ghosting (down to 30% opacity after 24h) is removed entirely, and the cached-position "?" badge stays as the staleness signal
- Map range circles and node movement trails are tinted per-node as well, replacing the flat purple fallback

### Fixed (chart tooltips)

- Metric chart tooltips can no longer escape the chart area: the environment metrics charts and the node history chart now fit their touch tooltips inside the plot (the device metrics chart already did), and the multi-series telemetry tooltips show the sample date once on the bottom entry instead of repeating it per series, so the tooltip stays shorter than the chart even at large accessibility text scales

### Added (license compliance)

- The in-app license page (Settings > Open Source) now lists notices for third-party material bundled outside the pub dependency graph: the OFL-1.1 fonts (Inter, JetBrains Mono, Caveat), the vendored Codec2 speech codec (LGPL-2.1+), the vendored vs_node_view package (BSD-3-Clause), and the Meshtastic protobuf attribution (GPL-3.0-only), registered lazily via `LicenseRegistry` with texts bundled under `assets/licenses/`
- `licenses/LGPL-2.1` reference text added beside the existing APACHE-2.0/LGPL-3.0 copies, matching the vendored Codec2 license version; root `NOTICE.md` corrected (flutter_blue_plus license name) and extended with codec2, fonts, sounds, vs_node_view, and GlyphMatrix SDK sections

### Added (test hardening wave)

- ProtocolService-layer regression tests for the SIP v0.2 target_node_id privacy boundary: overheard HS_HELLO/CHALLENGE/RESPONSE/ACCEPT/DECLINE frames driven through the full wire pipeline must mutate no handshake state and queue no consent request (with a correctly-targeted control frame proving the pipeline is live)
- Airtime-budget single-accounting tests at the ProtocolService boundary: the gated send path deducts the wire size exactly once, the pre-accounted path deducts nothing, and an exhausted budget puts zero bytes on the air
- Message identity dedup pins: local messages (NULL packet_id) replace by stable id and never duplicate on re-save; distinct instances with the same packet identity collapse via the unique index; distinct local sends are never falsely deduped

### Changed (cleanup wave)

- The duplicated find-then-upload share core (fingerprint dedup + Firestore upload-or-reuse) for automations and widgets collapsed into one `SharedContentUploader` in `lib/services/share/`, with the fingerprint contract pinned by unit tests; channel sharing keeps its separate crypto-service flow by design
- `MeshNodeBrain` moved from the onboarding feature to `lib/core/widgets/`, fixing four core-imports-feature inversions (help system, what's-new sheet, help content, splash provider) and the help-center cross-feature import in one move
- Signal detail's sign-in action now navigates via the `/account` named route instead of importing the settings feature's screen directly
- Removed three never-referenced core widgets (`SecretGestureDetector`, `TransformableText`, `DraggableTextWidget`) and the stale `petDrawerLabel` localization key across all 8 locales (references re-verified before each removal)

### Changed (UX and accessibility wave)

- All close, clear-search, back, and apply-key icon buttons in the core widget library now carry localized tooltips (VoiceOver/TalkBack labels + long-press hints), cascading to every screen that uses them; new `commonClose` / `commonClear` / `commonClearSearch` / `commonBack` / `channelKeyApply` strings translated across all 8 locales
- Device metrics chart renders a node's first sample as a dot instead of silently hiding the chart until a second sample arrives; the chart x-domain is pinned so a single sample cannot collapse the horizontal span
- NodeDex signal-quality reds now use the theme's semantic `errorRed` alongside `successGreen`/`warningYellow` instead of a one-off hex value
- NodeDex encounter-row node names wrap instead of truncating with an ellipsis
- NodeBoard creation wizard title and Back/Next/Create Board buttons are localized (previously hardcoded English)
- Remote flags admin sheet dismisses the keyboard on outside tap
- Telemetry retention policy (1000 entries per node per metric type) documented with its cadence-dependent time window

### Changed (performance hardening wave)

- Map layers (node markers, range circles, heatmap, trails, connection lines, distance labels) are now cached per build input and rebuilt only when their inputs change, instead of being reconstructed wholesale on every received packet; in cluster mode the stable marker-list identity also lets the cluster layer skip a full re-cluster when nothing changed
- Connection-lines pair loop screens candidates with a conservative haversine prefilter before the iterative Vincenty calculation (the emitted line set is provably identical, pinned by a randomized property test that also accounts for the decision function's whole-kilometer rounding)
- Per-packet node presence updates now recompute only the changed nodes (identity diff) instead of every node; untouched nodes keep presence-object identity so per-node watchers stop rebuilding, and the 30s full refresh tick is unchanged
- Messaging contact summaries (last message, unread count) moved to a memoized provider, so the full message scan reruns only when the message list changes, not on every node or presence tick
- Per-packet node updates coalesce into one state emission per 250ms window behind the remote-flippable `NODE_EMISSION_COALESCING_ENABLED` flag (default on); new-node discovery, own-node updates, and position changes still commit synchronously, and per-event side effects (saves, counters, automations) are unchanged
- Map, messaging, and nodes screens emit build-profile diagnostics behind their existing logging flags for before/after rebuild-efficiency measurement

### Fixed (stability hardening wave)

- NodeDex schema downgrade no longer wipes the local collection: the downgrade handler now retains the on-disk schema (encounters, regions, co-seen edges, presence timeline, and identity history survive opening the database with an older binary), and all v2-v14 migrations are idempotent so the eventual re-upgrade re-runs cleanly instead of routing into corruption recovery
- Messages database now pins an explicit no-op downgrade handler and guards all ALTER-based migrations, so a version down-stamp followed by re-upgrade can never fail the open over existing message history
- MeshCore frame reader `readInt8` consumed two bytes for negative values, corrupting any subsequent reads (latent: no current callsites)
- Protocol service per-connection state (`remote admin sessions`, remote LoRa config cache, replay-log timestamps, telemetry request cooldowns) is now cleared on every `start()`, so caches from a previous radio can never leak into a new session, and expired admin sessions are evicted instead of accumulating for the app lifetime
- Telemetry ingestion now treats non-finite (NaN/Infinity) float samples from peer firmware as absent, keeping the node's prior finite value; device metrics charts also exclude non-finite samples so one bad voltage sample cannot poison the axis range
- On-demand telemetry requests are deduplicated at the protocol layer (30s per node per type), so non-UI callers and double-taps that race the UI countdown cannot put duplicate requests on the air
- Telemetry and traceroute local-history write failures now reach Crashlytics via a site-keyed throttled reporter (one report per 5 minutes per site) instead of being visible only in debug logs
- Saved TCP endpoints normalize their host at storage time (trim + lowercase, RFC 4343) so two casings of one hostname collapse to a single endpoint; legacy raw entries are cleaned on load and out-of-range stored ports fall back to the protocol default
- A device-connection init failure during app startup is now retryable on the next initialize() trigger instead of silently killing auto-reconnect for the entire session; the retry never re-runs one-time service initialization
- MeshCore background reconnect's unfiltered scan is now preceded by the same BLE cleanup (stop scan, drop stale system-device handles, settle delay) the Meshtastic path performs, fixing scans blinded by a stale GATT handle after a failed direct connect
- Overlay secure sessions handle AEAD nonce-counter exhaustion gracefully: the spent session is discarded (in-memory only) and the next outbound renegotiates fresh keys, instead of every subsequent encrypted send throwing forever
- BLE transport disconnect now null-sets each stream subscription before awaiting its cancel, so a concurrent connect can no longer have its fresh subscriptions orphaned by a late bulk null-set
- Orphan protocol data-subscription detection now leaves a Crashlytics breadcrumb so lifecycle violations are visible in crash reports, not only debug logs

### Fixed

- Fatal iOS background crash (`NSInternalInconsistencyException - Sending a message before the FlutterEngine has been run`): the shake-to-report service now cancels its accelerometer subscription whenever the app leaves the foreground and resubscribes on resume, and no longer starts the 50 Hz sensor stream at all when shake-to-report is disabled
- Peer-sent waypoint icons are validated as Unicode scalars at protocol ingestion (a surrogate half or out-of-range code point ingests as "no icon"), closing the last peer-controlled text field that previously relied on render-time guards alone against the fatal `string is not well-formed UTF-16` paragraph-builder crash
- Remote-config watcher no longer disposes itself mid-sync: it read (not watched) the settings service it invalidates to notify watchers, and now also guards its `ref` after awaits, fixing the `Cannot use the Ref of StreamProvider<MeshConfigData?> after it has been disposed` error and the related circular-dependency provider read
- Map tile updates now drop events that carry a non-finite camera snapshot (new `finiteCameraTileUpdateTransformer` applied to every `TileLayer`, enforced by a new `require-tile-update-transformer` lint rule), closing the residual `LatLng is not finite` path where a queued tile-update event computed with a NaN camera before the existing snap-back recovery ran

## [1.49.0] - 2026-06-09

### Fixed

- Google Play "device isn't compatible" on devices whose reported feature profile does not advertise all hardware features (e.g. GrapheneOS with sandboxed Google Play). Bluetooth, BLE, location, GPS, microphone, WiFi (implied required by the WiFi state permissions), touchscreen (implied required for every app by default), and the CameraX-injected `camera.any` features are now soft-declared (`required="false"`) in the Android manifest so the Play Store no longer filters out those installs. None of these are mandatory: the app connects over BLE or USB and runs fully offline.

## [1.39.0] - 2026-05-16

### Fixed

- Chat-bubble body font size unified to **14pt** across all three chat surfaces (MeshCore chat, SIP DM, Meshtastic messaging) for both inbound and outbound bubbles. Pre-D30, MeshCore and Meshtastic used 14pt outbound vs 15pt inbound, and SIP DM used 14pt for both — surfacing as inconsistent text rhythm in mixed-protocol conversations. **Canonical chat-body size is 14pt.** Note: commit `f3ece320`'s message text incorrectly says "15pt"; the diff in that commit is 14pt — the message is stale auto-generated text and the code outcome is what's documented here.

## [1.25.0] - 2026-03-23

### Added

- iOS Live Activity toggle in Background Connection settings — "LIVE ACTIVITY" section with a "Dynamic Island & Lock Screen" switch; toggling off confirms via bottom sheet and ends any running activity immediately
- In-app language selector re-enabled in Appearance & Accessibility settings (was previously hidden behind `LANGUAGE_SELECTOR_ENABLED` feature flag)

### Changed

- `LiveActivityManagerNotifier._startLiveActivity()` now checks the `live_activity_enabled` SharedPreferences key before starting a Live Activity; disabled state is respected across reconnections
- `LiveActivityManagerNotifier` exposes a public `endLiveActivity()` method for use by settings UI

### Dependencies

- `subosito/flutter-action` 2.21.0 → 2.22.0 (CI GitHub Action)
- `ffi` 2.1.5 → 2.2.0
- `build_runner` 2.10.5 → 2.13.0 (up to 4× faster incremental builds)
- `logger` 2.6.2 → 2.7.0
- `purchases_flutter` 9.14.0 → 9.15.0
- `fl_chart` 1.1.1 → 1.2.0
- `json` gem 2.16.0 → 2.17.1.2 (iOS/Bundler — security fix CVE-2026-33210)

## [1.19.0] - 2026-03-05

### Added

- Aether full-screen airport picker with 900+ airports including international airfields

## [1.17.0] - 2026-03-03

### Added

- RF vs MQTT transport indicator on message context menu (cloud icon for MQTT, cell tower icon for RF)
- RF vs MQTT transport chip on node info card with hop count display
- `TransportPath` enum and `classifyTransport()` helper (`lib/core/transport_path.dart`)
- `viaMqtt` field on `Message` model, populated from protobuf `via_mqtt` (tag 14)
- Node-to-node measurement mode: tap node markers on map to measure between named nodes
- Bearing display (degrees + 16-point cardinal direction) on measurement card
- Altitude display per measurement endpoint when node altitude is known
- Elevation delta with trending icon between measurement endpoints
- Line-of-sight analysis engine using earth curvature (4/3 refraction model) and Fresnel zone clearance at 906 MHz (`lib/core/los_analysis.dart`)
- LOS verdict panel (Clear/Marginal/Obstructed/Unknown) toggleable from measurement card actions
- Long-press actions sheet on measurement card: LOS Analysis, Share, Copy Summary, Copy Coordinates, Open Midpoint in Maps, Swap A/B, RF Link Budget (FSPL)
- Free-space path loss (FSPL) estimation at 906 MHz, copyable from measurement actions
- Unit tests for transport path classification (9 tests)
- Unit tests for LOS analysis, bearing calculation, and cardinal formatting (31 tests)
- Engineering documentation (`docs/engineering/TRANSPORT_PATH.md`)

### Changed

- Measurement card upgraded from `StatelessWidget` to `StatefulWidget` to support expandable LOS panel and actions sheet
- Measurement mode indicator now uses `Flexible` text with ellipsis overflow to prevent clipping on narrow screens
- Measurement mode indicator positioning adjusted (removed hardcoded 140px left inset) for better centering
- Share button moved from inline measurement card to long-press actions sheet, reducing visual clutter

### Fixed

- Compass widget now updates in real-time during programmatic "tap-to-north" animation (was frozen until manual gesture)
- Measurement mode indicator text no longer clips on smaller screens

## [1.16.0] - 2026-02-24

### Added

- SQLite-backed message persistence (`MessageDatabase`) replacing SharedPreferences JSON blob
- Per-conversation message retention (500 messages per conversation, up from global 100)
- Full message field serialization (status, packetId, routingError, errorMessage)
- Automatic one-time migration from legacy SharedPreferences storage on first launch
- Indexed queries by conversation key, node number, and packet ID
- Aether airport search by name, IATA/ICAO code, and country with GPS distance sorting
- Aether live flight data sticky header on the schedule screen (frosted-glass overlay with slide/fade/blur animations)
- Aether flight search "En route" indicator when arrival airport is unavailable
- Aether flight conflict detection warning for overlapping schedules
- Aether skeleton loading shimmer for initial flight list
- Aether flight time validation on the scheduling form
- Aether enhanced flight detail screen with airport data and route information
- Aether server-side OpenSky search cache (GET /api/flights/search) -- zero client-side credit cost
- Aether server-side route cache (GET /api/flights/route/:icao24) -- 30-min TTL, zero client-side credit cost
- Aether server-side validate endpoint (GET /api/flights/validate/:callsign) -- search cache first, zero credits
- Cloudflare Worker proxy (opensky-proxy) for OpenSky API routing from Railway
- Telegram bot /opensky_cache command for monitoring search cache freshness

### Fixed

- Chat messages no longer disappear across app restarts (SQLite replaces lossy SharedPreferences blob)
- Channel message deduplication no longer fails when push notification `to` field differs from mesh broadcast address
- Removed dead `MessageStorageService` class (replaced by `MessageDatabase`)
- Aether departure/arrival time handling: lastSeen is no longer used as arrival time for active flights
- Aether skeleton shimmer transitions use AnimatedSwitcher with proper keyed children
- Aether stale partial-match search results no longer overwrite newer results (generation counter)

### Changed

- Aether flight search uses server-side cache instead of direct OpenSky calls (zero credit burn)
- Aether flight validation proxied through Aether API (search cache + server-side fallback)
- Aether route enrichment proxied through Aether API route cache (zero client-side credits)
- Aether flight search changed from auto-search-on-keystroke to explicit submit
- Aether flight status logic prioritizes time-based checks over GPS proximity
- Aether flight lifecycle checks scoped to current user's flights only

## [1.14.1] - 2026-02-11

### Added

- Traceroute help topic with guided tour (8 steps covering sending, cooldowns, results, history, and export)
- Help menu integration on the Traceroute History screen

## [1.13.0] - 2026-02-06

### Added

- Appearance & Accessibility settings screen with live preview
- Font mode selection: Branded (JetBrainsMono), System, or Accessibility (Inter)
- Text size presets: System Default, Default, Large (15%), Extra Large (30%)
- Display density modes: Compact, Comfortable, Large Touch
- High contrast mode for enhanced visibility
- Reduce motion option for minimal animations
- Safe text scaling with layout-safe caps (max 1.5x)
- Accessibility-aware animated widgets (AccessibleAnimatedContainer, AccessibleAnimatedOpacity)
- AccessibleTapTarget widget for minimum tap target enforcement
- Comprehensive unit and widget tests for accessibility layer

### Changed

- MaterialApp now applies accessibility theme preferences via AccessibilityThemeAdapter
- Theme integration includes font family, visual density, and high contrast adjustments
- Animation durations respect reduce motion preference throughout the app

## [1.2.0] - 2026-02-01

### Added

- Open-sourced the SocialMesh mobile client under GPL-3.0
- Architecture documentation (`docs/ARCHITECTURE.md`)
- Backend boundary documentation (`docs/BACKEND.md`)
- GitHub Actions CI pipeline with automated testing
- Issue templates for bugs, features, and new contributors
- Demo mode for running without backend configuration (`--dart-define=SOCIALMESH_DEMO=1`)
- Developer bootstrap script (`tool/dev_bootstrap.sh`)
- SPDX license headers on all source files
- Security policy (`SECURITY.md`)
- Contributing guide (`CONTRIBUTING.md`)
- Third-party notices (`NOTICE.md`)

### Changed

- README updated with contributor-focused documentation
- Firebase initialization made non-blocking for offline-first operation

### Fixed

- CI test stability improvements for timezone-sensitive tests
