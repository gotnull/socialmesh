# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
