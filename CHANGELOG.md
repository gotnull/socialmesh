# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed (map)

- Node transparency is now applied consistently after reopening the app. Markers built before the saved "Node transparency" setting finished loading were cached fully opaque and stayed that way, so some nodes rendered faded and others solid with no settings changed. The marker cache now tracks the overlay opacity, so every peer marker follows the setting from the first frame
- Node markers no longer tilt with the map when "Cluster markers" is enabled: the cluster layer now counter-rotates its markers the same way the plain marker layer always did, so icons and cluster count badges stay upright while the map rotates in free-rotate or follow-heading mode
- The map compass mode (north-locked / free-rotate / follow-heading) is now remembered across tab switches and app relaunches instead of silently resetting to north-locked every time the Map tab is reopened. North-locked stays the first-run default
- The map overflow menu toggle is now labelled "Show cluster markers", matching the "Show ..." wording of every sibling toggle (previously just "Cluster markers")

### Fixed (automations)

- Automation message templates no longer render a missing battery level as "?%": `{{battery}}`, `{{location}}`, `{{node.name}}`, and `{{sensor.name}}` now all fall back to a localized lowercase "unknown" when the source value has never been reported, so a welcome message reads "your battery level is unknown" instead of "?%"

### Fixed (firmware update)

- The in-app "Start Update" button no longer does nothing while the app is disconnected from the radio. The button rendered from cached node data even with no live Bluetooth link, and tapping it gave haptic feedback then silently returned. It now disables with a "connect via Bluetooth" hint while disconnected, and shows an error snackbar if the link drops in the instant between render and tap
- A failed firmware release check (no network, GitHub error) now shows the "update check failed" banner instead of quietly looking like "you're up to date"

### Added (connection diagnostics)

- Every BLE link teardown is now recorded with its origin (OS-reported disconnect with the platform reason code, notification stream closing, app watchdog, or user action), the session uptime, and the age of the last received packet. The detail is logged as `BLE_DISCONNECT` / `DISCONNECT_CONTEXT` lines and embedded in in-app bug reports, so "the app disconnects after about an hour" reports can be traced to the exact path that ended the link
- While backgrounded the app now allows two reconnect attempts per background session (previously one) before waiting for foreground, improving recovery from mid-session drops during long background use

### Added (messaging filters)

- The Channels and Contacts list filter chips (All / Unread / ...) now remember the last selection across app launches, so unread-first users land on their filter instead of resetting to All every cold start

### Added (telemetry)

- The Air Quality Log now includes gas-resistance readings from BME680/688 VOC sensors, merged in from environment telemetry (historical readings included), with a gas-only card for nodes that share no other air-quality metrics
- Air Quality and Environment Metrics log cards now show which node shared each reading, and tapping a card jumps to the map centred on that node (when it has a position); the back button returns straight to the log

### Added (messaging)

- Message details (long-press a message) and the expanded technical info now show the node that relayed a received message, matching the official Meshtastic iOS app. The radio only sends the last byte of the relayer's ID, so the name is a best-effort match against known nodes and falls back to a hex byte (for example `0xC4`) when it cannot be resolved to a single node (#223)

### Changed (messaging)

- The hop count is no longer a separate pill under each received message. The bubble's timestamp line now reads time, hop count, and SNR in one line (for example `2:05 PM - Direct - SNR 6.5 dB`), so reception quality is visible at a glance without expanding the message (#224)

### Changed (nodes)

- Finished removing the accent-colour special treatment for your own node: the node detail hero and the node card tint now follow the same identity-colour and presence rules as every other node, so your node appears in the same colour other users see (#222)

### Fixed (nodes)

- Unfavoriting a node now sticks across reconnects. Previously the un-favourite admin message was fire-and-forget: if the radio missed it (or never saved its node database to flash before powering off), the radio kept reporting the node as a favourite and the app re-favourited it on every reconnect with no way to turn it off. The app now remembers an explicit un-favourite, refuses to let a stale device flag resurrect it, and automatically re-sends the un-favourite (and any lost favourites) to the radio after each reconnect until the radio confirms
- Reset Node Database no longer races the radio: the app waited only half a second before re-requesting the radio's configuration, so a slow reset commit could replay the old node list straight back into the app. The wait now outlasts the firmware's commit window. Note that nodes still legitimately return over time as the radio re-hears them from the mesh, and immediately over MQTT while downlink is enabled

### Added (security hardening)

- Sensitive local databases (direct messages, saved routes, waypoints, peer-safety state, and the NodeDex journal) are now encrypted at rest with SQLCipher. The key is generated on-device and held in the iOS Keychain / Android Keystore, so message text, locations, and travel history are no longer readable from the raw database files (for example from a device backup, or on a lost or rooted/jailbroken phone). Existing data is migrated in place on first launch with no loss of history; if the one-time migration is ever interrupted it safely retries on the next launch
- Tightened the Android network security configuration so first-party services and the fixed third-party APIs (socialmesh.app, Firebase/Google) are pinned to HTTPS and can no longer be silently downgraded to plain HTTP, while user-configured private/LAN webhooks continue to work over HTTP as before

### Added (offline maps)

- On Android, offline map tiles can be stored on a removable SD card instead of internal memory. The storage picker lives in the "Download this area" sheet and in a new Settings > Data & Storage > Offline Map Storage tile (shown only when a card is present or a fallback needs explaining), which also shows the current cache size and offers to delete the old cache after a switch. Portable/removable cards only: cards formatted as internal (adopted) storage are part of internal memory by Android design. If the card goes missing the cache falls back to internal storage with a visible warning
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

- Fatal iOS background crash (`NSInternalInconsistencyException - Sending a message before the FlutterEngine has been run`): the shake-to-report service now cancels its accelerometer subscription whenever the app leaves the foreground and resubscribes on resume, and no longer starts the 50 Hz sensor stream at all when shake-to-report is disabled
- Peer-sent waypoint icons are validated as Unicode scalars at protocol ingestion (a surrogate half or out-of-range code point ingests as "no icon"), closing the last peer-controlled text field that previously relied on render-time guards alone against the fatal `string is not well-formed UTF-16` paragraph-builder crash
- Remote-config watcher no longer disposes itself mid-sync: it read (not watched) the settings service it invalidates to notify watchers, and now also guards its `ref` after awaits, fixing the `Cannot use the Ref of StreamProvider<MeshConfigData?> after it has been disposed` error and the related circular-dependency provider read
- Map tile updates now drop events that carry a non-finite camera snapshot (new `finiteCameraTileUpdateTransformer` applied to every `TileLayer`, enforced by a new `require-tile-update-transformer` lint rule), closing the residual `LatLng is not finite` path where a queued tile-update event computed with a NaN camera before the existing snap-back recovery ran
- Google Play "device isn't compatible" on devices whose reported feature profile does not advertise all hardware features (e.g. GrapheneOS with sandboxed Google Play). Bluetooth, BLE, location, GPS, microphone, WiFi (implied required by the WiFi state permissions), touchscreen (implied required for every app by default), and the CameraX-injected `camera.any` features are now soft-declared (`required="false"`) in the Android manifest so the Play Store no longer filters out those installs. None of these are mandatory: the app connects over BLE or USB and runs fully offline.
- Chat-bubble body font size unified to **14pt** across all three chat surfaces (MeshCore chat, SIP DM, Meshtastic messaging) for both inbound and outbound bubbles. Pre-D30, MeshCore and Meshtastic used 14pt outbound vs 15pt inbound, and SIP DM used 14pt for both — surfacing as inconsistent text rhythm in mixed-protocol conversations. **Canonical chat-body size is 14pt.** Note: commit `f3ece320`'s message text incorrectly says "15pt"; the diff in that commit is 14pt — the message is stale auto-generated text and the code outcome is what's documented here.
- Compass widget now updates in real-time during programmatic "tap-to-north" animation (was frozen until manual gesture)
- Measurement mode indicator text no longer clips on smaller screens
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
- Traceroute help topic with guided tour (8 steps covering sending, cooldowns, results, history, and export)
- Help menu integration on the Traceroute History screen
- SQLite-backed message persistence (`MessageDatabase`) replacing SharedPreferences JSON blob
- Per-conversation message retention (500 messages per conversation, up from global 100)
- Full message field serialization (status, packetId, routingError, errorMessage)
- Automatic one-time migration from legacy SharedPreferences storage on first launch
- Indexed queries by conversation key, node number, and packet ID
- Aether full-screen airport picker with 900+ airports including international airfields
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

### Changed

- MaterialApp now applies accessibility theme preferences via AccessibilityThemeAdapter
- Theme integration includes font family, visual density, and high contrast adjustments
- Animation durations respect reduce motion preference throughout the app
- Aether flight search uses server-side cache instead of direct OpenSky calls (zero credit burn)
- Aether flight validation proxied through Aether API (search cache + server-side fallback)
- Aether route enrichment proxied through Aether API route cache (zero client-side credits)
- Aether flight search changed from auto-search-on-keystroke to explicit submit
- Aether flight status logic prioritizes time-based checks over GPS proximity
- Aether flight lifecycle checks scoped to current user's flights only

### Fixed

- Chat messages no longer disappear across app restarts (SQLite replaces lossy SharedPreferences blob)
- Channel message deduplication no longer fails when push notification `to` field differs from mesh broadcast address
- Removed dead `MessageStorageService` class (replaced by `MessageDatabase`)
- Aether departure/arrival time handling: lastSeen is no longer used as arrival time for active flights
- Aether skeleton shimmer transitions use AnimatedSwitcher with proper keyed children
- Aether stale partial-match search results no longer overwrite newer results (generation counter)

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
