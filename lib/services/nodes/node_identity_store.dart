// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging.dart';
import '../../utils/text_sanitizer.dart';

class NodeIdentity {
  final int nodeNum;
  final String? longName;
  final String? shortName;
  final int lastUpdatedAt;
  final int? lastSeenAt;

  const NodeIdentity({
    required this.nodeNum,
    this.longName,
    this.shortName,
    required this.lastUpdatedAt,
    this.lastSeenAt,
  });

  NodeIdentity copyWith({
    String? longName,
    String? shortName,
    int? lastUpdatedAt,
    int? lastSeenAt,
  }) {
    return NodeIdentity(
      nodeNum: nodeNum,
      longName: longName ?? this.longName,
      shortName: shortName ?? this.shortName,
      lastUpdatedAt: lastUpdatedAt ?? this.lastUpdatedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'longName': longName,
      'shortName': shortName,
      'lastUpdatedAt': lastUpdatedAt,
      'lastSeenAt': lastSeenAt,
    };
  }

  static NodeIdentity fromJson(int nodeNum, Map<String, dynamic> json) {
    return NodeIdentity(
      nodeNum: nodeNum,
      longName: _sanitizedName(json['longName']),
      shortName: _sanitizedName(json['shortName']),
      lastUpdatedAt: json['lastUpdatedAt'] as int? ?? 0,
      lastSeenAt: json['lastSeenAt'] as int?,
    );
  }

  /// Sanitised form of a persisted name, or null when absent or empty.
  ///
  /// `jsonEncode` escapes a lone UTF-16 surrogate to `\uD800` rather than
  /// rejecting it, so this store round-trips a malformed name byte-perfectly
  /// and indefinitely. Repairing on read is what stops a blob written by an
  /// older build from reaching the renderer.
  static String? _sanitizedName(Object? value) {
    if (value is! String || value.isEmpty) return null;
    final sanitized = sanitizeExternalText(value);
    return sanitized.isEmpty ? null : sanitized;
  }
}

class NodeIdentityStore {
  static const String _key = 'node_identities';
  SharedPreferences? _prefs;
  static final RegExp _bleDefaultPattern = RegExp(
    r'^Meshtastic_[0-9a-fA-F]{4}$',
  );

  bool _isBleDefaultName(String value) {
    return _bleDefaultPattern.hasMatch(value);
  }

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw Exception('NodeIdentityStore not initialized');
    }
    return _prefs!;
  }

  /// Load every persisted identity.
  ///
  /// A corrupt or shape-shifted blob yields an empty map rather than
  /// throwing. The caller sets its loaded flag only after this returns, so an
  /// escaping exception would leave the notifier permanently unloaded and
  /// re-throw on every rebuild, silently dropping every node's cached name.
  /// A malformed entry is also skipped individually so one bad record cannot
  /// discard the rest of the cache.
  Future<Map<int, NodeIdentity>> getAllIdentities() async {
    final raw = _preferences.getString(_key);
    if (raw == null || raw.isEmpty) return {};

    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      AppLogging.nodes('NODE_IDENTITY_LOAD_FAILED reason=decode error=$e');
      return {};
    }

    final identities = <int, NodeIdentity>{};

    for (final entry in decoded.entries) {
      final nodeNum = int.tryParse(entry.key, radix: 16);
      if (nodeNum == null) continue;
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      try {
        identities[nodeNum] = NodeIdentity.fromJson(nodeNum, value);
      } catch (e) {
        AppLogging.nodes(
          'NODE_IDENTITY_LOAD_SKIPPED nodeNum=$nodeNum error=$e',
        );
      }
    }

    return identities;
  }

  Future<void> saveAllIdentities(Map<int, NodeIdentity> identities) async {
    final map = <String, dynamic>{};
    for (final entry in identities.entries) {
      final key = entry.key.toRadixString(16).toUpperCase();
      map[key] = entry.value.toJson();
    }
    await _preferences.setString(_key, jsonEncode(map));
  }

  String? normalizeName(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<Map<int, NodeIdentity>> upsert({
    required Map<int, NodeIdentity> current,
    required int nodeNum,
    String? longName,
    String? shortName,
    int? updatedAtMs,
    int? lastSeenAtMs,
  }) async {
    var normalizedLong = normalizeName(longName);
    var normalizedShort = normalizeName(shortName);
    if (normalizedLong != null && _isBleDefaultName(normalizedLong)) {
      AppLogging.protocol(
        'NODE_NAME_BLOCK_BLE_IDENTITY node=!${nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')} '
        'old=$normalizedLong',
      );
      normalizedLong = null;
    }
    if (normalizedShort != null && _isBleDefaultName(normalizedShort)) {
      AppLogging.protocol(
        'NODE_NAME_BLOCK_BLE_IDENTITY node=!${nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')} '
        'old=$normalizedShort',
      );
      normalizedShort = null;
    }
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final updateAt = updatedAtMs ?? nowMs;

    final existing = current[nodeNum];
    if (existing == null &&
        normalizedLong == null &&
        normalizedShort == null &&
        lastSeenAtMs == null) {
      return current;
    }

    // Determine effective new values
    final effectiveLong = normalizedLong ?? existing?.longName;
    final effectiveShort = normalizedShort ?? existing?.shortName;
    final effectiveSeenAt = lastSeenAtMs ?? existing?.lastSeenAt;

    // Skip save if no material change to names or lastSeenAt
    if (existing != null &&
        existing.longName == effectiveLong &&
        existing.shortName == effectiveShort &&
        existing.lastSeenAt == effectiveSeenAt) {
      return current;
    }

    final next = Map<int, NodeIdentity>.from(current);
    final merged =
        (existing ??
                NodeIdentity(
                  nodeNum: nodeNum,
                  lastUpdatedAt: updateAt,
                  lastSeenAt: lastSeenAtMs,
                ))
            .copyWith(
              longName: effectiveLong,
              shortName: effectiveShort,
              lastUpdatedAt: updateAt > (existing?.lastUpdatedAt ?? 0)
                  ? updateAt
                  : existing?.lastUpdatedAt,
              lastSeenAt: effectiveSeenAt,
            );

    next[nodeNum] = merged;
    await saveAllIdentities(next);

    if (normalizedLong != null || normalizedShort != null) {
      AppLogging.protocol(
        'NODE_IDENTITY_UPSERT node=!${nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')} '
        'long=${normalizedLong ?? merged.longName ?? ''} '
        'short=${normalizedShort ?? merged.shortName ?? ''}',
      );
    }

    return next;
  }
}
