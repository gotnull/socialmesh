# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
