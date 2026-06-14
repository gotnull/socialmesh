// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Offline Download Notifier — drives a bulk region tile pre-download into the
// durable built-in tile cache. Feature-local Riverpod 3 Notifier.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/logging.dart';
import '../../../core/map_config.dart';
import 'offline_tile_cache.dart';
import 'tile_math.dart';

/// Progress state of a region download.
@immutable
sealed class OfflineDownloadState {
  const OfflineDownloadState();
}

class OfflineDownloadIdle extends OfflineDownloadState {
  const OfflineDownloadIdle();
}

/// Actively downloading: [done] of [total] tiles processed, [failed] could not
/// be fetched, [bytes] written so far.
class OfflineDownloadRunning extends OfflineDownloadState {
  final int done;
  final int total;
  final int failed;
  final int bytes;
  const OfflineDownloadRunning({
    required this.done,
    required this.total,
    required this.failed,
    required this.bytes,
  });

  double get fraction => total == 0 ? 0 : done / total;
}

class OfflineDownloadCompleted extends OfflineDownloadState {
  final int downloaded;
  final int skipped;
  final int failed;
  final int bytes;
  const OfflineDownloadCompleted({
    required this.downloaded,
    required this.skipped,
    required this.failed,
    required this.bytes,
  });
}

class OfflineDownloadCancelled extends OfflineDownloadState {
  final int done;
  final int total;
  const OfflineDownloadCancelled({required this.done, required this.total});
}

class OfflineDownloadFailed extends OfflineDownloadState {
  final String message;
  const OfflineDownloadFailed(this.message);
}

class OfflineDownloadNotifier extends Notifier<OfflineDownloadState> {
  http.Client? _client;
  bool _cancelRequested = false;

  @override
  OfflineDownloadState build() {
    ref.onDispose(() {
      _cancelRequested = true;
      _client?.close();
    });
    return const OfflineDownloadIdle();
  }

  /// Request cancellation of an in-flight download. Workers stop at their next
  /// tile boundary.
  void cancel() => _cancelRequested = true;

  /// Return to idle so the sheet can re-estimate / re-run.
  void reset() {
    if (state is OfflineDownloadRunning) return;
    state = const OfflineDownloadIdle();
  }

  /// Download every tile covering [bounds] across [minZoom]..[maxZoom] for
  /// [style], skipping tiles already cached. No-op if already running.
  Future<void> start({
    required LatLngBounds bounds,
    required MapTileStyle style,
    required int minZoom,
    required int maxZoom,
  }) async {
    if (state is OfflineDownloadRunning) return;
    _cancelRequested = false;

    final cache = OfflineTileCache.instance;
    final tiles = tilesForBounds(bounds, minZoom, maxZoom).toList();
    final total = tiles.length;
    if (total == 0) {
      state = const OfflineDownloadCompleted(
        downloaded: 0,
        skipped: 0,
        failed: 0,
        bytes: 0,
      );
      return;
    }

    state = OfflineDownloadRunning(done: 0, total: total, failed: 0, bytes: 0);

    final client = _client = http.Client();
    var done = 0;
    var failed = 0;
    var skipped = 0;
    var bytes = 0;
    var index = 0;

    // OpenTopoMap (terrain) is the most rate-limited source; keep its
    // concurrency lowest. Dart's single isolate means the shared counters and
    // `index++` are safe between await points.
    final concurrency = style == MapTileStyle.terrain ? 2 : 4;

    Future<void> worker() async {
      while (!_cancelRequested) {
        final i = index++;
        if (i >= total) return;
        final coord = tiles[i];

        if (await cache.isCached(style, coord)) {
          skipped++;
        } else {
          try {
            final written = await cache.downloadTile(style, coord, client);
            if (written != null) {
              bytes += written;
            } else {
              failed++;
            }
          } on TileRateLimitedException {
            // Back off, then make a single retry before giving up on the tile.
            await Future<void>.delayed(const Duration(seconds: 2));
            if (_cancelRequested) return;
            int? retry;
            try {
              retry = await cache.downloadTile(style, coord, client);
            } catch (_) {
              retry = null;
            }
            if (retry != null) {
              bytes += retry;
            } else {
              failed++;
            }
          }
        }

        done++;
        if (done % 8 == 0 || done == total) {
          state = OfflineDownloadRunning(
            done: done,
            total: total,
            failed: failed,
            bytes: bytes,
          );
        }
      }
    }

    try {
      await Future.wait(List.generate(concurrency, (_) => worker()));
    } catch (e) {
      AppLogging.map('Region download failed: $e');
      _client?.close();
      _client = null;
      state = OfflineDownloadFailed(e.toString());
      return;
    }

    _client?.close();
    _client = null;

    if (_cancelRequested) {
      state = OfflineDownloadCancelled(done: done, total: total);
    } else {
      state = OfflineDownloadCompleted(
        downloaded: done - skipped - failed,
        skipped: skipped,
        failed: failed,
        bytes: bytes,
      );
    }
  }
}

final offlineDownloadProvider =
    NotifierProvider<OfflineDownloadNotifier, OfflineDownloadState>(
      OfflineDownloadNotifier.new,
    );
