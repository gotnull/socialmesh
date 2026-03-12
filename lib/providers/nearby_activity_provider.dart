// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Riverpod provider for nearby activity in Mesh Explorer.
///
/// Derives activity events from MRRP service advert cache changes.
/// Each time the advert cache epoch bumps, we compare the current
/// snapshot against previously seen services and emit new activity
/// items for services that appeared since the last rebuild.
///
/// Activity items have a TTL and are capped to avoid noise.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/mesh_explorer/models/nearby_activity.dart';
import '../features/mesh_explorer/models/service_presentation.dart';
import '../l10n/l10n_utils.dart';
import '../services/protocol/sip/mrrp_advert_engine.dart';
import '../services/protocol/sip/mrrp_types.dart';
import 'mrrp_providers.dart';

/// Maximum activity items displayed in the feed.
const int kNearbyActivityMaxItems = 8;

/// Activity TTL in seconds — items expire after this duration.
const int kNearbyActivityTtlSeconds = 600;

/// Provider for nearby activity events.
///
/// Watches the MRRP advert epoch and derives activity from cache changes.
/// Returns a list of recent, non-expired activity items sorted newest first.
final nearbyActivityProvider =
    NotifierProvider<NearbyActivityNotifier, List<NearbyActivity>>(
      NearbyActivityNotifier.new,
    );

/// Notifier that maintains the nearby activity feed.
class NearbyActivityNotifier extends Notifier<List<NearbyActivity>> {
  /// Previously seen service keys: `nodeId:serviceId`.
  final Set<String> _seenKeys = {};

  /// Activity buffer — newest first.
  final List<NearbyActivity> _buffer = [];

  /// Whether this is the first build (suppress initial flood).
  bool _isFirstBuild = true;

  @override
  List<NearbyActivity> build() {
    // Watch the advert epoch to rebuild when cache changes.
    ref.watch(mrrpAdvertEpochProvider);

    // Read the current snapshot of cached services.
    final cachedServices = ref.watch(mrrpCachedServicesProvider);

    _processSnapshot(cachedServices);

    return _visibleItems();
  }

  /// Manually dismiss all activity items.
  void clearAll() {
    _buffer.clear();
    state = const [];
  }

  void _processSnapshot(Map<int, List<MrrpCachedService>> snapshot) {
    final now = DateTime.now();
    final currentKeys = <String>{};

    for (final entry in snapshot.entries) {
      final nodeId = entry.key;
      for (final service in entry.value) {
        final serviceId = service.descriptor.serviceId;
        final flags = service.descriptor.serviceFlags;

        // Only track public, non-test services.
        if (flags & MrrpServiceFlags.testOnly != 0) continue;

        final key = '$nodeId:$serviceId';
        currentKeys.add(key);

        // Skip if already seen (deduplication).
        if (_seenKeys.contains(key)) continue;

        // On first build, populate the seen set without emitting activity.
        // This prevents a flood of stale activity items on app launch.
        if (_isFirstBuild) continue;

        // New service discovered — emit activity.
        final presentation = ServicePresentationCatalog.forServiceId(
          serviceId,
          safeL10n(),
        );
        final subtitle = _subtitleForService(serviceId);

        _buffer.insert(
          0,
          NearbyActivity(
            id: key,
            type: NearbyActivityType.serviceAppeared,
            serviceId: serviceId,
            nodeId: nodeId,
            title: presentation.title,
            subtitle: subtitle,
            icon: presentation.icon,
            occurredAt: now,
            expiresAt: now.add(
              const Duration(seconds: kNearbyActivityTtlSeconds),
            ),
          ),
        );
      }
    }

    // Update the seen set to match current snapshot.
    _seenKeys
      ..clear()
      ..addAll(currentKeys);

    // After first build, future changes will produce activity.
    _isFirstBuild = false;

    // Purge expired items.
    _buffer.removeWhere((item) => item.isExpired);

    // Cap the buffer.
    if (_buffer.length > kNearbyActivityMaxItems) {
      _buffer.removeRange(kNearbyActivityMaxItems, _buffer.length);
    }
  }

  List<NearbyActivity> _visibleItems() {
    // Return a defensive copy — already sorted newest first.
    return List.unmodifiable(_buffer);
  }

  /// Generate a concise, human-readable subtitle for a service type.
  static String _subtitleForService(int serviceId) {
    switch (serviceId) {
      case MrrpServiceId.boardV1:
        return 'New board nearby'; // lint-allow: hardcoded-string
      case MrrpServiceId.profileV1:
        return 'Peer profile available'; // lint-allow: hardcoded-string
      case MrrpServiceId.meetupV1:
        return 'Coordination available'; // lint-allow: hardcoded-string
      case 0x00000004: // signal.v1
        return 'Signal published'; // lint-allow: hardcoded-string
      default:
        return 'New service nearby'; // lint-allow: hardcoded-string
    }
  }
}
