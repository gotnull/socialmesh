// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform_capabilities.dart';

/// Canonical Riverpod source of truth for the host platform's capability
/// bundle.
///
/// Resolved once in `main()` and pushed into the root `ProviderScope` as
/// an override. Any provider, service, or widget that needs to gate a
/// feature on platform capability watches this provider rather than
/// reaching into `dart:io` `Platform.is*` directly.
///
/// Tests override this with `overrideWithValue(...)` to exercise web /
/// desktop branches without changing the host OS.
final platformCapabilitiesProvider = Provider<PlatformCapabilities>((ref) {
  // The override in main() supplies the real bundle. This default keeps
  // tests that build a ProviderContainer without the override from
  // throwing (e.g. provider unit tests for unrelated providers). It picks
  // the safest mobile-ish baseline so any unexpectedly-uncovered consumer
  // gets behaviour closest to today's production.
  return PlatformCapabilities.detect();
});
