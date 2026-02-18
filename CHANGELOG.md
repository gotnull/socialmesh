# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
- Traceroute help topic with guided tour (8 steps covering sending, cooldowns, results, history, and export)
- Help menu integration on the Traceroute History screen
- SQLite-backed message persistence (`MessageDatabase`) replacing SharedPreferences JSON blob
- Per-conversation message retention (500 messages per conversation, up from global 100)
- Full message field serialization (status, packetId, routingError, errorMessage)
- Automatic one-time migration from legacy SharedPreferences storage on first launch
- Indexed queries by conversation key, node number, and packet ID
- Aether full-screen airport picker with 900+ airports including military airfields
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

## [1.2.0] - 2026-02-01

### Added

- Open-sourced the Socialmesh mobile client under GPL-3.0
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
