// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/tapback.dart';

/// Storage service for message tapbacks
class TapbackStorageService {
  static const _tapbacksKey = 'tapbacks';
  static const _dedupCleanupDoneKey = 'tapbacks_dedup_cleanup_done';

  final SharedPreferences _prefs;

  TapbackStorageService(this._prefs);

  /// One-time cleanup: remove duplicate tapbacks that accumulated
  /// before the write-side dedup was added. Safe to call multiple
  /// times - it no-ops after the first successful run.
  Future<void> purgeExistingDuplicates() async {
    if (_prefs.getBool(_dedupCleanupDoneKey) == true) return;

    final tapbacks = await _getAllTapbacks();
    final seen = <String>{};
    final deduped = <MessageTapback>[];
    for (final t in tapbacks) {
      final key = '${t.messageId}|${t.fromNodeNum}|${t.emoji}';
      if (seen.add(key)) {
        deduped.add(t);
      }
    }

    if (deduped.length < tapbacks.length) {
      await _saveTapbacks(deduped);
    }
    await _prefs.setBool(_dedupCleanupDoneKey, true);
  }

  /// Get all tapbacks for a message (deduplicated at read time).
  Future<List<MessageTapback>> getTapbacksForMessage(String messageId) async {
    final allTapbacks = await _getAllTapbacks();
    final matching = allTapbacks
        .where((t) => t.messageId == messageId)
        .toList();

    // Deduplicate by (messageId, fromNodeNum, emoji) to handle any
    // pre-existing duplicates that slipped through before the write guard.
    final seen = <String>{};
    return matching.where((t) {
      final key = '${t.fromNodeNum}|${t.emoji}';
      return seen.add(key);
    }).toList();
  }

  /// Add a tapback to a message.
  ///
  /// Deduplicates by (messageId, fromNodeNum, emoji) so that device
  /// message replays on reconnect do not create duplicate reactions.
  Future<void> addTapback(MessageTapback tapback) async {
    final tapbacks = await _getAllTapbacks();

    final alreadyExists = tapbacks.any(
      (t) =>
          t.messageId == tapback.messageId &&
          t.fromNodeNum == tapback.fromNodeNum &&
          t.emoji == tapback.emoji,
    );
    if (alreadyExists) return;

    tapbacks.add(tapback);
    await _saveTapbacks(tapbacks);
  }

  /// Remove a tapback
  Future<void> removeTapback(String messageId, int fromNodeNum) async {
    final tapbacks = await _getAllTapbacks();
    tapbacks.removeWhere(
      (t) => t.messageId == messageId && t.fromNodeNum == fromNodeNum,
    );
    await _saveTapbacks(tapbacks);
  }

  Future<List<MessageTapback>> _getAllTapbacks() async {
    final jsonList = _prefs.getStringList(_tapbacksKey) ?? [];
    return jsonList
        .map((json) => MessageTapback.fromJson(jsonDecode(json)))
        .toList();
  }

  Future<void> _saveTapbacks(List<MessageTapback> tapbacks) async {
    await _prefs.setStringList(
      _tapbacksKey,
      tapbacks.map((t) => jsonEncode(t.toJson())).toList(),
    );
  }

  /// Clear old tapbacks (older than 30 days)
  Future<void> cleanupOldTapbacks() async {
    final tapbacks = await _getAllTapbacks();
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    tapbacks.removeWhere((t) => t.timestamp.isBefore(cutoff));
    await _saveTapbacks(tapbacks);
  }
}
