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
///
/// [replyToMessageId] (v2+) is the wire-stable id of the inbox message the
/// canned send is replying to. It stays opaque on the Watch — the phone
/// resolves it to a Meshtastic packet id. Null for a standalone send.
class WatchCompanionIntentPayload {
  const WatchCompanionIntentPayload({this.cannedKey, this.replyToMessageId});

  final String? cannedKey;
  final String? replyToMessageId;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'cannedKey': cannedKey,
    'replyToMessageId': replyToMessageId,
  };

  factory WatchCompanionIntentPayload.fromJson(Map<String, dynamic> json) {
    return WatchCompanionIntentPayload(
      cannedKey: json['cannedKey'] as String?,
      replyToMessageId: json['replyToMessageId'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchCompanionIntentPayload &&
          other.cannedKey == cannedKey &&
          other.replyToMessageId == replyToMessageId;

  @override
  int get hashCode => Object.hash(cannedKey, replyToMessageId);

  @override
  String toString() =>
      'WatchCompanionIntentPayload(canned: $cannedKey, '
      'replyTo: $replyToMessageId)';
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

  /// Bumps whenever a field is added, removed, or changes meaning. v2 added
  /// [WatchCompanionIntentPayload.replyToMessageId].
  static const int wireVersion = 2;

  /// Oldest wire version this build still decodes. New fields are optional, so
  /// a v1 intent (no replyToMessageId) decodes cleanly under v2.
  static const int minWireVersion = 1;

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
    if (v is! int || v < minWireVersion || v > wireVersion) {
      throw FormatException(
        'WatchCompanionIntent wire-version unsupported: accept '
        '$minWireVersion..$wireVersion, got $v',
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
