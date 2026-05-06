// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/security/stl_middleware.dart';
import '../services/security/stl_signing_service.dart';
import 'app_providers.dart';

/// STL (SocialMesh Trust Layer) middleware — singleton.
///
/// Provides the middleware instance used to wrap/unwrap STL envelopes
/// on the file transfer pipeline.
final stlMiddlewareProvider = Provider<StlMiddleware>((ref) {
  return StlMiddleware(signingService: StlSigningService());
});

/// Whether STL signing is enabled for outbound file transfers.
///
/// Reads from [SettingsService.stlSigningEnabled] (persisted preference).
/// Default: false (opt-in).
final stlSigningEnabledProvider = Provider<bool>((ref) {
  final settingsAsync = ref.watch(settingsServiceProvider);
  return settingsAsync.maybeWhen(
    data: (s) => s.stlSigningEnabled,
    orElse: () => false,
  );
});
