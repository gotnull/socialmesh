// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Phone-to-Watch response for a [WatchCompanionIntent]. Every intent always
/// gets exactly one result; the bridge guarantees no silent drop.
///
/// [userVisibleReason] is localized (resolved via the active phone locale
/// before being put on the wire); the Watch renders it verbatim. The Watch
/// holds no string table in v1. [diagnosticReason] is an English machine
/// string for logs; it is never shown to the user.
class WatchCompanionIntentResult {
  const WatchCompanionIntentResult({
    required this.requestId,
    required this.accepted,
    required this.timestampMs,
    this.userVisibleReason,
    this.diagnosticReason,
  });

  static const int wireVersion = 1;

  final String requestId;
  final bool accepted;
  final int timestampMs;
  final String? userVisibleReason;
  final String? diagnosticReason;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'version': wireVersion,
    'requestId': requestId,
    'accepted': accepted,
    'userVisibleReason': userVisibleReason,
    'diagnosticReason': diagnosticReason,
    'timestampMs': timestampMs,
  };

  factory WatchCompanionIntentResult.fromJson(Map<String, dynamic> json) {
    final v = json['version'];
    if (v != wireVersion) {
      throw FormatException(
        'WatchCompanionIntentResult wire-version mismatch: expected '
        '$wireVersion, got $v',
      );
    }
    return WatchCompanionIntentResult(
      requestId: json['requestId'] as String,
      accepted: json['accepted'] as bool,
      timestampMs: json['timestampMs'] as int,
      userVisibleReason: json['userVisibleReason'] as String?,
      diagnosticReason: json['diagnosticReason'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchCompanionIntentResult &&
          other.requestId == requestId &&
          other.accepted == accepted &&
          other.timestampMs == timestampMs &&
          other.userVisibleReason == userVisibleReason &&
          other.diagnosticReason == diagnosticReason;

  @override
  int get hashCode => Object.hash(
    requestId,
    accepted,
    timestampMs,
    userVisibleReason,
    diagnosticReason,
  );

  @override
  String toString() =>
      'WatchCompanionIntentResult(req: $requestId, '
      'accepted: $accepted, diag: $diagnosticReason)';
}
