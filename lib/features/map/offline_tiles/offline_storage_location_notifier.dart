// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Offline Storage Location Notifier — exposes whether a removable SD card is
// available and which storage root the offline tile cache currently uses,
// and performs the destroy-and-recreate switch between locations.
// Feature-local Riverpod 3 AsyncNotifier.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/app_providers.dart';
import 'offline_tile_cache.dart';
import 'offline_tile_storage.dart';

/// Storage state for the offline map download UI.
@immutable
class OfflineStorageState {
  /// True when a mounted removable SD card offers an app-specific directory.
  /// The storage picker is hidden entirely when false.
  final bool sdAvailable;

  /// Location the cache is currently rooted at.
  final OfflineTileStorageLocation location;

  /// True when SD card storage is preferred but boot fell back to internal
  /// because the card was missing or unwritable.
  final bool fellBack;

  const OfflineStorageState({
    required this.sdAvailable,
    required this.location,
    required this.fellBack,
  });
}

/// A leftover cache at the previous storage root, offered for deletion after
/// a successful switch.
typedef AbandonedCache = ({String path, int bytes});

class OfflineStorageLocationNotifier
    extends AsyncNotifier<OfflineStorageState> {
  @override
  Future<OfflineStorageState> build() async {
    final cache = OfflineTileCache.instance;
    final sdRoot = await cache.storage.removableRoot();
    final settings = await ref.watch(settingsServiceProvider.future);
    return OfflineStorageState(
      sdAvailable: sdRoot != null,
      location: settings.offlineMapStorageOnSdCard && !cache.fellBackToInternal
          ? OfflineTileStorageLocation.sdCard
          : OfflineTileStorageLocation.internal,
      fellBack: cache.fellBackToInternal,
    );
  }

  /// Switch the tile cache to [target]. Returns the abandoned cache at the
  /// previous root when it still holds data, so the UI can offer deletion.
  /// Rethrows [OfflineStorageUnavailableException] when the SD card is
  /// requested but unusable; state is left untouched in that case.
  Future<AbandonedCache?> switchTo(OfflineTileStorageLocation target) async {
    final cache = OfflineTileCache.instance;
    final previous = state.value;
    if (previous == null) return null;
    // Same location with no fallback pending is a no-op; when a fallback IS
    // pending, choosing "internal" persists that choice and clears the
    // warning, so let it through.
    if (previous.location == target && !previous.fellBack) return null;

    final oldRoot = cache.activeCacheRoot;
    await cache.switchStorageLocation(target);
    state = AsyncData(
      OfflineStorageState(
        sdAvailable: previous.sdAvailable,
        location: target,
        fellBack: false,
      ),
    );

    if (oldRoot == null || oldRoot == cache.activeCacheRoot) return null;
    final bytes = await cache.storage.directorySizeBytes(oldRoot);
    if (bytes <= 0) return null;
    return (path: oldRoot, bytes: bytes);
  }

  /// Delete the abandoned cache directory left at a previous storage root.
  Future<void> deleteAbandonedCache(String path) {
    return OfflineTileCache.instance.storage.deleteDirectory(path);
  }
}

final offlineStorageLocationProvider =
    AsyncNotifierProvider<OfflineStorageLocationNotifier, OfflineStorageState>(
      OfflineStorageLocationNotifier.new,
    );
