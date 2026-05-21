// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// One row in the Watch nearby-nodes preview. Protocol-neutral shape; the
/// phone-side facade fills it from the NodeDex (already neutral) or the
/// MeshCore contact list as appropriate.
class WatchCompanionNodePreview {
  const WatchCompanionNodePreview({
    required this.nodeId,
    required this.lastHeardMs,
    this.shortName,
    this.longName,
    this.rssi,
    this.hops,
  });

  /// Wire-stable string node identifier. For Meshtastic this is the
  /// decimal node number; for MeshCore it is the hex public-key prefix.
  /// Tests compare on the string; the Watch UI never parses it.
  final String nodeId;

  final int lastHeardMs;
  final String? shortName;
  final String? longName;
  final int? rssi;
  final int? hops;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'nodeId': nodeId,
    'lastHeardMs': lastHeardMs,
    'shortName': shortName,
    'longName': longName,
    'rssi': rssi,
    'hops': hops,
  };

  factory WatchCompanionNodePreview.fromJson(Map<String, dynamic> json) {
    return WatchCompanionNodePreview(
      nodeId: json['nodeId'] as String,
      lastHeardMs: json['lastHeardMs'] as int,
      shortName: json['shortName'] as String?,
      longName: json['longName'] as String?,
      rssi: json['rssi'] as int?,
      hops: json['hops'] as int?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchCompanionNodePreview &&
          other.nodeId == nodeId &&
          other.lastHeardMs == lastHeardMs &&
          other.shortName == shortName &&
          other.longName == longName &&
          other.rssi == rssi &&
          other.hops == hops;

  @override
  int get hashCode =>
      Object.hash(nodeId, lastHeardMs, shortName, longName, rssi, hops);

  @override
  String toString() =>
      'WatchCompanionNodePreview(id: $nodeId, '
      'short: $shortName, lastHeard: $lastHeardMs)';
}
