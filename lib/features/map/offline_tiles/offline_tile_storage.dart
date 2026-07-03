// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Offline Tile Storage — resolves where the offline tile cache lives.
//
// Android supports app-specific directories on removable SD cards
// (Context.getExternalFilesDirs), which need no runtime permissions and are
// cleaned up on uninstall. This module asks the platform for mounted,
// genuinely removable volumes and resolves the user's storage preference to a
// concrete cache root, falling back to internal storage whenever the card is
// missing or unwritable. The writability probe is mandatory: handing an
// unwritable directory to flutter_map's built-in caching provider raises an
// unhandled async error inside its constructor and every later cache call
// then awaits a completer that never completes.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Where the offline tile cache is rooted.
enum OfflineTileStorageLocation { internal, sdCard }

/// A resolved cache root. [fellBack] is true when SD card storage was
/// preferred but unavailable, so the internal path was used instead.
typedef OfflineTileRoot = ({String path, bool fellBack});

/// Thrown by explicit storage switches when the requested location cannot be
/// used (no card mounted, or the card refused a probe write).
class OfflineStorageUnavailableException implements Exception {
  const OfflineStorageUnavailableException();
}

/// Resolves offline tile cache roots across internal and removable storage.
class OfflineTileStorage {
  OfflineTileStorage({
    MethodChannel? channel,
    Future<Directory> Function()? internalDir,
    bool? isAndroid,
  }) : _channel = channel ?? const MethodChannel('com.socialmesh/settings'),
       _internalDir = internalDir ?? getApplicationDocumentsDirectory,
       _isAndroid = isAndroid ?? Platform.isAndroid;

  /// Folder name shared by every storage root, so switching locations keeps
  /// each cache recognisable (and re-adoptable) at its old location.
  static const String cacheFolderName = 'offline_map_cache';

  final MethodChannel _channel;
  final Future<Directory> Function() _internalDir;
  final bool _isAndroid;

  /// Cache root on the first mounted removable volume, or null when the
  /// platform has none (iOS, SD-less devices, adoptable-formatted cards —
  /// those are merged into internal storage and are not separate volumes).
  Future<String?> removableRoot() async {
    if (!_isAndroid) return null;
    try {
      final dirs = await _channel.invokeListMethod<String>(
        'getRemovableStorageDirs',
      );
      if (dirs == null || dirs.isEmpty) return null;
      return p.join(dirs.first, cacheFolderName);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Cache root on internal storage. Matches the pre-feature path exactly so
  /// existing installs keep their downloaded tiles.
  Future<String> internalRoot() async {
    final docs = await _internalDir();
    return p.join(docs.path, cacheFolderName);
  }

  /// Whether [dir] can be created and written to right now. A removable card
  /// can disappear between launches, so callers must probe before pointing
  /// the cache provider at it.
  Future<bool> probeWritable(String dir) async {
    final probe = File(p.join(dir, '.write_probe'));
    try {
      await Directory(dir).create(recursive: true);
      await probe.writeAsBytes(const [0], flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Resolve [preference] to a usable cache root, degrading to internal
  /// storage (never throwing) when the SD card is missing or unwritable.
  Future<OfflineTileRoot> resolveRoot(
    OfflineTileStorageLocation preference,
  ) async {
    if (preference == OfflineTileStorageLocation.sdCard) {
      final sd = await removableRoot();
      if (sd != null && await probeWritable(sd)) {
        return (path: sd, fellBack: false);
      }
      return (path: await internalRoot(), fellBack: true);
    }
    return (path: await internalRoot(), fellBack: false);
  }

  /// Total size of [dir] in bytes; 0 when missing or unreadable.
  Future<int> directorySizeBytes(String dir) async {
    var total = 0;
    try {
      await for (final entity in Directory(
        dir,
      ).list(recursive: true, followLinks: false)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
    } catch (_) {
      // Best effort: a vanished or unreadable directory sizes as whatever
      // was accumulated before the failure.
    }
    return total;
  }

  /// Delete [dir] recursively, ignoring failures (already gone, ejected).
  Future<void> deleteDirectory(String dir) async {
    try {
      await Directory(dir).delete(recursive: true);
    } catch (_) {
      // Best effort: nothing to reclaim if the directory is already gone.
    }
  }
}
