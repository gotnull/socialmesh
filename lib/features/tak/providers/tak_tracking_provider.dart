// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging.dart';

/// Manages the set of tracked TAK entity UIDs.
///
/// Tracking state is persisted to SharedPreferences so it survives
/// app restarts. Tracked entities get movement trails on the map and
/// fire stale notifications.
class TakTrackingNotifier extends AsyncNotifier<Set<String>> {
  static const _storageKey = 'tak_tracked_uids';

  @override
  Future<Set<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_storageKey);
    final uids = stored?.toSet() ?? {};
    AppLogging.tak('TakTrackingNotifier: loaded ${uids.length} tracked UIDs');
    return uids;
  }

  /// Toggle tracking for the given UID. Returns true if now tracked.
  Future<bool> toggle(String uid) async {
    final current = Set<String>.of(state.value ?? {});
    final nowTracked = !current.contains(uid);
    if (nowTracked) {
      current.add(uid);
      AppLogging.tak('Entity tracked: uid=$uid');
    } else {
      current.remove(uid);
      AppLogging.tak('Entity untracked: uid=$uid');
    }
    state = AsyncData(current);
    await _persist(current);
    return nowTracked;
  }

  /// Track a specific UID.
  Future<void> track(String uid) async {
    final current = Set<String>.of(state.value ?? {});
    if (current.contains(uid)) return;
    current.add(uid);
    state = AsyncData(current);
    await _persist(current);
    AppLogging.tak('Entity tracked: uid=$uid');
  }

  /// Untrack a specific UID.
  Future<void> untrack(String uid) async {
    final current = Set<String>.of(state.value ?? {});
    if (!current.contains(uid)) return;
    current.remove(uid);
    state = AsyncData(current);
    await _persist(current);
    AppLogging.tak('Entity untracked: uid=$uid');
  }

  /// Untrack all entities at once.
  Future<void> untrackAll() async {
    final current = state.value ?? {};
    if (current.isEmpty) return;
    state = const AsyncData({});
    await _persist({});
    AppLogging.tak('All entities untracked (was ${current.length})');
  }

  /// Whether a UID is currently tracked.
  bool isTracked(String uid) {
    return (state.value ?? {}).contains(uid);
  }

  Future<void> _persist(Set<String> uids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, uids.toList());
    AppLogging.tak('Tracked UIDs persisted: ${uids.length} entities');
  }
}

/// Provider for TAK entity tracking state.
final takTrackingProvider =
    AsyncNotifierProvider<TakTrackingNotifier, Set<String>>(
      TakTrackingNotifier.new,
    );

/// Convenience provider that returns the tracking set synchronously.
final takTrackedUidsProvider = Provider<Set<String>>((ref) {
  final asyncUids = ref.watch(takTrackingProvider);
  return asyncUids.value ?? {};
});
