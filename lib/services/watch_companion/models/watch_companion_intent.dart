// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Intent kind sent from Watch to phone. Wire-stable; serialized via [name].
enum WatchCompanionIntentType {
  quickMessage,
  sendImOk,
  refreshSnapshot;

  String toWire() => name;

  static WatchCompanionIntentType fromWire(String wire) {
    for (final value in WatchCompanionIntentType.values) {
      if (value.name == wire) return value;
    }
    throw FormatException('Unknown WatchCompanionIntentType: $wire');
  }
}

/// Where a quick-send intent should land. v1 carries only [channelIndex];
/// future versions may add nodeId / channelHash for direct-to-peer DM.
class WatchCompanionIntentTarget {
  const WatchCompanionIntentTarget({this.channelIndex});

  final int? channelIndex;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'channelIndex': channelIndex,
  };

  factory WatchCompanionIntentTarget.fromJson(Map<String, dynamic> json) {
    return WatchCompanionIntentTarget(
      channelIndex: json['channelIndex'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchCompanionIntentTarget && other.channelIndex == channelIndex;

  @override
  int get hashCode => channelIndex.hashCode;

  @override
  String toString() => 'WatchCompanionIntentTarget(ch: $channelIndex)';
}

/// Watch-originated intent payload. Carries only a canned-message key, never
/// a raw string; the phone resolves the key to localized text before
/// dispatching down the normal send path.
class WatchCompanionIntentPayload {
  const WatchCompanionIntentPayload({this.cannedKey});

  final String? cannedKey;

  Map<String, dynamic> toJson() => <String, dynamic>{'cannedKey': cannedKey};

  factory WatchCompanionIntentPayload.fromJson(Map<String, dynamic> json) {
    return WatchCompanionIntentPayload(cannedKey: json['cannedKey'] as String?);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchCompanionIntentPayload && other.cannedKey == cannedKey;

  @override
  int get hashCode => cannedKey.hashCode;

  @override
  String toString() => 'WatchCompanionIntentPayload(canned: $cannedKey)';
}

/// Top-level intent envelope sent from the Watch.
///
/// [wireVersion] is asserted by the phone-side codec; a mismatch returns a
/// clean failure result so an upgraded Watch never silently corrupts state.
class WatchCompanionIntent {
  const WatchCompanionIntent({
    required this.requestId,
    required this.type,
    required this.target,
    required this.payload,
    required this.createdAtMs,
  });

  /// Bumps whenever a field is added, removed, or changes meaning.
  static const int wireVersion = 1;

  final String requestId;
  final WatchCompanionIntentType type;
  final WatchCompanionIntentTarget target;
  final WatchCompanionIntentPayload payload;
  final int createdAtMs;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': wireVersion,
    'requestId': requestId,
    'type': type.toWire(),
    'target': target.toJson(),
    'payload': payload.toJson(),
    'createdAtMs': createdAtMs,
  };

  factory WatchCompanionIntent.fromJson(Map<String, dynamic> json) {
    final v = json['version'];
    if (v != wireVersion) {
      throw FormatException(
        'WatchCompanionIntent wire-version mismatch: expected '
        '$wireVersion, got $v',
      );
    }
    return WatchCompanionIntent(
      requestId: json['requestId'] as String,
      type: WatchCompanionIntentType.fromWire(json['type'] as String),
      target: WatchCompanionIntentTarget.fromJson(
        json['target'] as Map<String, dynamic>,
      ),
      payload: WatchCompanionIntentPayload.fromJson(
        json['payload'] as Map<String, dynamic>,
      ),
      createdAtMs: json['createdAtMs'] as int,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchCompanionIntent &&
          other.requestId == requestId &&
          other.type == type &&
          other.target == target &&
          other.payload == payload &&
          other.createdAtMs == createdAtMs;

  @override
  int get hashCode =>
      Object.hash(requestId, type, target, payload, createdAtMs);

  @override
  String toString() =>
      'WatchCompanionIntent(req: $requestId, type: $type, '
      'target: $target, payload: $payload)';
}
