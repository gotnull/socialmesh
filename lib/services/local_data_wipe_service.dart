// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/logging.dart';

/// Deletes all local SQLite database files and signal image caches.
///
/// Used during account deletion cascade (Sprint 006 W2.2) to ensure
/// no user data survives on-device after server-side wipe.
///
/// **Important:** SQLite database connections MUST be closed before deleting
/// their backing files. Deleting a file while SQLite still holds an open
/// file descriptor causes "vnode unlinked while in use" integrity errors
/// and subsequent "disk I/O error" failures. Callers should provide a
/// [closeAllDatabases] callback that closes every open database handle
/// before file deletion begins.
class LocalDataWipeService {
  /// All 10 SQLite database filenames that live directly under
  /// `getApplicationDocumentsDirectory()`.
  static const List<String> _dbFiles = [
    'messages.db',
    'signals.db',
    'telemetry.db',
    'routes.db',
    'nodedex.db',
    'traceroute_history.db',
    'automations.db',
    'widgets.db',
    'tak_events.db',
  ];

  /// Database in a subdirectory.
  static const String _dedupeDbPath = 'cache/mesh_seen_packets.db';

  /// Signal image cache directories under documents dir.
  static const List<String> _signalCacheDirs = [
    'signals/images',
    'signals/cache',
  ];

  /// Delete all local databases and signal image caches.
  ///
  /// When [closeAllDatabases] is provided it is awaited **before** any files
  /// are deleted, giving callers the chance to gracefully close every open
  /// SQLite connection. Skipping this step risks SQLite integrity errors.
  ///
  /// Best-effort: logs failures but does not throw. Returns the count of
  /// files successfully deleted.
  static Future<int> wipeAll({
    Future<void> Function()? closeAllDatabases,
  }) async {
    var deleted = 0;

    try {
      // Close all open database handles before touching the filesystem.
      if (closeAllDatabases != null) {
        AppLogging.privacy(
          'LocalDataWipeService: closing all database connections',
        );
        try {
          await closeAllDatabases();
          AppLogging.privacy(
            'LocalDataWipeService: all database connections closed',
          );
        } catch (e) {
          AppLogging.debug(
            'LocalDataWipeService: error closing databases (continuing): $e',
          );
        }
      }

      final dir = await getApplicationDocumentsDirectory();

      // Delete the 9 databases in the root documents directory
      for (final dbFile in _dbFiles) {
        deleted += await _deleteFile(p.join(dir.path, dbFile));
        // Also delete SQLite journal/WAL files if present
        deleted += await _deleteFile(p.join(dir.path, '$dbFile-journal'));
        deleted += await _deleteFile(p.join(dir.path, '$dbFile-wal'));
        deleted += await _deleteFile(p.join(dir.path, '$dbFile-shm'));
      }

      // Delete dedup store in cache/ subdirectory
      deleted += await _deleteFile(p.join(dir.path, _dedupeDbPath));
      deleted += await _deleteFile(p.join(dir.path, '$_dedupeDbPath-journal'));
      deleted += await _deleteFile(p.join(dir.path, '$_dedupeDbPath-wal'));
      deleted += await _deleteFile(p.join(dir.path, '$_dedupeDbPath-shm'));

      // Delete signal image caches
      for (final cacheDir in _signalCacheDirs) {
        deleted += await _deleteDirectory(p.join(dir.path, cacheDir));
      }

      AppLogging.privacy('LocalDataWipeService: deleted $deleted files');
    } catch (e) {
      AppLogging.debug('LocalDataWipeService.wipeAll error: $e');
    }

    return deleted;
  }

  static Future<int> _deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
        return 1;
      }
    } catch (e) {
      AppLogging.debug('LocalDataWipeService: failed to delete $path: $e');
    }
    return 0;
  }

  static Future<int> _deleteDirectory(String path) async {
    try {
      final dir = Directory(path);
      if (await dir.exists()) {
        final contents = await dir.list(recursive: true).toList();
        final count = contents.length;
        await dir.delete(recursive: true);
        return count;
      }
    } catch (e) {
      AppLogging.debug('LocalDataWipeService: failed to delete dir $path: $e');
    }
    return 0;
  }
}
