import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/tapback.dart';

/// Storage service for message tapbacks
class TapbackStorageService {
  static const _tapbacksKey = 'tapbacks';

  final SharedPreferences _prefs;

  TapbackStorageService(this._prefs);

  /// Get all tapbacks for a message
  Future<List<MessageTapback>> getTapbacksForMessage(String messageId) async {
    final allTapbacks = await _getAllTapbacks();
    return allTapbacks.where((t) => t.messageId == messageId).toList();
  }

  /// Add a tapback to a message
  Future<void> addTapback(MessageTapback tapback) async {
    final tapbacks = await _getAllTapbacks();
    // Remove existing tapback from same user on same message
    tapbacks.removeWhere(
      (t) =>
          t.messageId == tapback.messageId &&
          t.fromNodeNum == tapback.fromNodeNum,
    );
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

  /// Get grouped tapbacks by type for a message
  Future<Map<TapbackType, List<int>>> getGroupedTapbacks(
    String messageId,
  ) async {
    final tapbacks = await getTapbacksForMessage(messageId);
    final grouped = <TapbackType, List<int>>{};
    for (final tapback in tapbacks) {
      grouped.putIfAbsent(tapback.type, () => []).add(tapback.fromNodeNum);
    }
    return grouped;
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
