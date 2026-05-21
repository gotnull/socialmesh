// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Protocol-neutral link status surfaced to the Watch. The Watch never sees
/// the underlying transport kind (BLE / USB / TCP) or the protocol family
/// (Meshtastic / MeshCore); the facade collapses both into one of these.
enum WatchCompanionConnectionStatus {
  disconnected,
  connecting,
  ready,
  degraded,
  unsupported;

  String toWire() => name;

  static WatchCompanionConnectionStatus fromWire(String wire) {
    for (final value in WatchCompanionConnectionStatus.values) {
      if (value.name == wire) return value;
    }
    throw FormatException('Unknown WatchCompanionConnectionStatus: $wire');
  }
}

/// Connection slice of a watch snapshot.
class WatchCompanionConnectionState {
  const WatchCompanionConnectionState({
    required this.status,
    this.activeProtocolDisplayName,
    this.activeDeviceName,
    this.readinessReason,
  });

  final WatchCompanionConnectionStatus status;

  /// e.g. "Meshtastic" or "MeshCore". Null when [status] is unsupported.
  final String? activeProtocolDisplayName;

  /// e.g. "Heltec V3". Null when no device is currently bound.
  final String? activeDeviceName;

  /// Short human-readable reason for non-[ready] states, e.g.
  /// "Awaiting NodeDB". Null when status is [ready] or [disconnected].
  final String? readinessReason;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'status': status.toWire(),
    'activeProtocolDisplayName': activeProtocolDisplayName,
    'activeDeviceName': activeDeviceName,
    'readinessReason': readinessReason,
  };

  factory WatchCompanionConnectionState.fromJson(Map<String, dynamic> json) {
    return WatchCompanionConnectionState(
      status: WatchCompanionConnectionStatus.fromWire(json['status'] as String),
      activeProtocolDisplayName: json['activeProtocolDisplayName'] as String?,
      activeDeviceName: json['activeDeviceName'] as String?,
      readinessReason: json['readinessReason'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchCompanionConnectionState &&
          other.status == status &&
          other.activeProtocolDisplayName == activeProtocolDisplayName &&
          other.activeDeviceName == activeDeviceName &&
          other.readinessReason == readinessReason;

  @override
  int get hashCode => Object.hash(
    status,
    activeProtocolDisplayName,
    activeDeviceName,
    readinessReason,
  );

  @override
  String toString() =>
      'WatchCompanionConnectionState(status: $status, '
      'protocol: $activeProtocolDisplayName, device: $activeDeviceName, '
      'reason: $readinessReason)';
}
