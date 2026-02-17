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

### Changed

- MaterialApp now applies accessibility theme preferences via AccessibilityThemeAdapter
- Theme integration includes font family, visual density, and high contrast adjustments
- Animation durations respect reduce motion preference throughout the app

### Fixed

- Chat messages no longer disappear across app restarts (SQLite replaces lossy SharedPreferences blob)
- Channel message deduplication no longer fails when push notification `to` field differs from mesh broadcast address
- Removed dead `MessageStorageService` class (replaced by `MessageDatabase`)

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
