// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/providers/app_providers.dart'
    show settingsServiceProvider;

import '_internal/composing_watch_companion_service.dart';
import '_internal/watch_channels_facade.dart';
import 'models/watch_companion_channel_preview.dart';
import 'models/watch_companion_snapshot.dart';
import 'watch_companion_channel_bridge.dart';
import 'watch_companion_feature_flags.dart';
import 'watch_companion_service.dart';

/// Public handle to the watch-companion facade. Returns the real
/// composing implementation when [watchCompanionFeatureFlagsProvider]
/// reports the surface enabled; otherwise returns the no-op so any
/// downstream subscriber (the iOS bridge in Slice 4) gets deterministic
/// "feature is off" behaviour with no crashes and no protocol traffic.
///
/// Callers (iOS bridge, settings UI) read this provider; they never
/// instantiate the service directly. The composing implementation lives
/// under `_internal/`; this file imports the concrete class but not any
/// protocol-specific symbol, keeping the isolation tripwire green.
final watchCompanionServiceProvider = Provider<WatchCompanionService>((ref) {
  final flags = ref.watch(watchCompanionFeatureFlagsProvider);
  if (!flags.enabled) {
    return NoOpWatchCompanionService();
  }
  final service = ComposingWatchCompanionService(ref);
  ref.onDispose(service.dispose);
  return service;
});

/// Stream of watch snapshots as the composer emits them. The iOS bridge
/// subscribes here to push updates to the paired Watch via
/// WatchConnectivity's `updateApplicationContext`.
final watchCompanionSnapshotProvider = StreamProvider<WatchCompanionSnapshot>((
  ref,
) {
  return ref.watch(watchCompanionServiceProvider).snapshots;
});

/// Master kill-switch + future per-capability flags for the Watch surface.
/// Read once at boot from dotenv; bumps when [invalidateCaches] downstream
/// fires a rebuild via [Ref.invalidateSelf]. Slice 4 (iOS bridge) gates
/// `WCSession` activation on `enabled`; Slice 3c (send facade) returns
/// `accepted=false, diagnosticReason="feature_disabled"` when this flips
/// to disabled at runtime.
final watchCompanionFeatureFlagsProvider = Provider<WatchCompanionFeatureFlags>(
  (ref) {
    return WatchCompanionFeatureFlags.fromEnv();
  },
);

/// Owns the lifetime of the iOS WatchConnectivity bridge. Call
/// `bridge.start()` once from app boot (gated on `Platform.isIOS`);
/// the provider's `onDispose` tears the bridge down on ProviderScope
/// rebuild. Tests can override this provider to inject a bridge with
/// a mocked `MethodChannel`.
final watchCompanionChannelBridgeProvider =
    Provider<WatchCompanionChannelBridge>((ref) {
      final bridge = WatchCompanionChannelBridge(
        readFlags: () => ref.read(watchCompanionFeatureFlagsProvider),
        readService: () => ref.read(watchCompanionServiceProvider),
      );
      ref.onDispose(() {
        // Fire-and-forget: ProviderScope teardown doesn't await futures.
        bridge.dispose();
      });
      return bridge;
    });

/// The channel index pre-selected on the Watch quick-send screen. Reads
/// the persisted `watchDefaultChannelIndex` setting from
/// [settingsServiceProvider]; returns 0 (primary channel) while settings
/// are still loading or unavailable, matching the `SettingsService` default.
///
/// Lives in this file (rather than inside `_internal/`) because the value
/// is protocol-neutral — it is just an integer — and downstream consumers
/// across the package read it directly without going through an adapter.
final watchDefaultChannelIndexProvider = Provider<int>((ref) {
  final settingsAsync = ref.watch(settingsServiceProvider);
  return settingsAsync.maybeWhen(
    data: (settings) => settings.watchDefaultChannelIndex,
    orElse: () => 0,
  );
});

/// Public projection of the channels currently available to the Watch
/// surface (protocol-resolved + empty-name-fallback applied). Consumed
/// by Settings -> Watch so the default-channel picker only renders
/// chips for indices that actually exist on the active radio, instead
/// of presenting 0-7 unconditionally and silently dropping
/// non-configured picks.
///
/// Re-exports the internal facade so the settings screen and the
/// snapshot composer share one source of truth for "what channels
/// does the Watch know about right now" — they cannot drift.
final watchCompanionAvailableChannelsProvider =
    Provider<List<WatchCompanionChannelPreview>>((ref) {
      return ref.watch(watchChannelsFacadeProvider);
    });
