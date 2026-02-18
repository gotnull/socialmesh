// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

/// A normalized CoT (Cursor on Target) event received from the TAK Gateway.
///
/// Mirrors the JSON shape produced by backend/tak-gateway:
/// ```json
/// { "uid": "...", "type": "...", "callsign": "...", "lat": 0.0,
///   "lon": 0.0, "timeUtcMs": 0, "staleUtcMs": 0, "receivedUtcMs": 0 }
/// ```
class TakEvent {
  /// CoT event UID (identifies the entity, e.g. "ANDROID-357...").
  final String uid;

  /// CoT type atom (e.g. "a-f-G-U-C" = friendly ground unit).
  final String type;

  /// Human-readable callsign from the `contact` element.
  final String? callsign;

  /// WGS-84 latitude.
  final double lat;

  /// WGS-84 longitude.
  final double lon;

  /// Event timestamp (UTC epoch milliseconds).
  final int timeUtcMs;

  /// Stale-out timestamp (UTC epoch milliseconds).
  final int staleUtcMs;

  /// Gateway receive timestamp (UTC epoch milliseconds).
  final int receivedUtcMs;

  /// Raw JSON payload for debugging (null in production).
  final String? rawPayloadJson;

  const TakEvent({
    required this.uid,
    required this.type,
    this.callsign,
    required this.lat,
    required this.lon,
    required this.timeUtcMs,
    required this.staleUtcMs,
    required this.receivedUtcMs,
    this.rawPayloadJson,
  });

  /// Construct from gateway JSON map.
  factory TakEvent.fromJson(Map<String, dynamic> json) {
    return TakEvent(
      uid: json['uid'] as String,
      type: json['type'] as String,
      callsign: json['callsign'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      timeUtcMs: json['timeUtcMs'] as int,
      staleUtcMs: json['staleUtcMs'] as int,
      receivedUtcMs: json['receivedUtcMs'] as int,
      rawPayloadJson: json['rawXml'] as String?,
    );
  }

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
    'uid': uid,
    'type': type,
    'callsign': callsign,
    'lat': lat,
    'lon': lon,
    'timeUtcMs': timeUtcMs,
    'staleUtcMs': staleUtcMs,
    'receivedUtcMs': receivedUtcMs,
    'rawXml': rawPayloadJson,
  };

  /// Construct from SQLite row map.
  factory TakEvent.fromDbRow(Map<String, dynamic> row) {
    return TakEvent(
      uid: row['uid'] as String,
      type: row['type'] as String,
      callsign: row['callsign'] as String?,
      lat: row['lat'] as double,
      lon: row['lon'] as double,
      timeUtcMs: row['time_utc'] as int,
      staleUtcMs: row['stale_utc'] as int,
      receivedUtcMs: row['received_utc'] as int,
      rawPayloadJson: row['raw_payload_json'] as String?,
    );
  }

  /// Convert to SQLite row map.
  Map<String, dynamic> toDbRow() => {
    'uid': uid,
    'type': type,
    'callsign': callsign,
    'lat': lat,
    'lon': lon,
    'time_utc': timeUtcMs,
    'stale_utc': staleUtcMs,
    'received_utc': receivedUtcMs,
    'raw_payload_json': rawPayloadJson,
  };

  /// Whether this event has expired (stale time has passed).
  bool get isStale => DateTime.now().millisecondsSinceEpoch > staleUtcMs;

  /// Display name: callsign if available, otherwise uid.
  String get displayName => callsign ?? uid;

  /// Human-readable CoT type description.
  String get typeDescription => _describeType(type);

  /// Encode the full event as a JSON string.
  String toJsonString() => jsonEncode(toJson());

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TakEvent &&
          uid == other.uid &&
          type == other.type &&
          timeUtcMs == other.timeUtcMs;

  @override
  int get hashCode => Object.hash(uid, type, timeUtcMs);

  @override
  String toString() =>
      'TakEvent(uid=$uid, type=$type, callsign=$callsign, '
      'lat=$lat, lon=$lon)';
}

/// Decode the leading CoT type atoms into a human-readable label.
String _describeType(String type) {
  if (type.startsWith('a-f')) return 'Friendly';
  if (type.startsWith('a-h')) return 'Hostile';
  if (type.startsWith('a-u')) return 'Unknown';
  if (type.startsWith('a-n')) return 'Neutral';
  if (type.startsWith('a-')) return 'Atom';
  if (type.startsWith('b-')) return 'Bits';
  if (type.startsWith('t-')) return 'Tasking';
  return type;
}
