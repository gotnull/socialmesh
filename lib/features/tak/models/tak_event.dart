// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

/// A normalized CoT (Cursor on Target) event received from the TAK Gateway.
///
/// Mirrors the JSON shape produced by backend/tak-gateway:
/// ```json
/// { "uid": "...", "type": "...", "callsign": "...", "lat": 0.0,
///   "lon": 0.0, "timeUtcMs": 0, "staleUtcMs": 0, "receivedUtcMs": 0,
///   "speed": 12.5, "course": 45.0, "hae": 152.3 }
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

  /// Speed in meters per second from the CoT `<track>` element.
  final double? speed;

  /// Course/heading in degrees from true north (0–360).
  final double? course;

  /// Height above ellipsoid in meters from the CoT `<point>` element.
  final double? hae;

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
    this.speed,
    this.course,
    this.hae,
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
      speed: (json['speed'] as num?)?.toDouble(),
      course: (json['course'] as num?)?.toDouble(),
      hae: (json['hae'] as num?)?.toDouble(),
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
    if (speed != null) 'speed': speed,
    if (course != null) 'course': course,
    if (hae != null) 'hae': hae,
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
      speed: row['speed'] as double?,
      course: row['course'] as double?,
      hae: row['hae'] as double?,
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
    'speed': speed,
    'course': course,
    'hae': hae,
  };

  /// Whether this event has expired (stale time has passed).
  bool get isStale => DateTime.now().millisecondsSinceEpoch > staleUtcMs;

  /// Display name: callsign if available, otherwise uid.
  String get displayName => callsign ?? uid;

  /// Human-readable CoT type description.
  String get typeDescription => _describeType(type);

  /// Encode the full event as a JSON string.
  String toJsonString() => jsonEncode(toJson());

  /// Whether this entity has motion data (speed, course, or altitude).
  bool get hasMotionData => speed != null || course != null || hae != null;

  /// Speed formatted as km/h, or "Stationary" if null or zero.
  String get formattedSpeed {
    if (speed == null || speed == 0.0) return 'Stationary';
    final kmh = speed! * 3.6;
    final knots = speed! * 1.94384;
    return '${kmh.toStringAsFixed(1)} km/h (${knots.toStringAsFixed(1)} kn)';
  }

  /// Course formatted as degrees with compass direction.
  String? get formattedCourse {
    if (course == null) return null;
    final deg = course!.round();
    return '${deg.toString().padLeft(3, '0')}\u00B0 (${_compassDirection(course!)})';
  }

  /// Altitude formatted as meters and feet.
  String? get formattedAltitude {
    if (hae == null) return null;
    final meters = hae!.round();
    final feet = (hae! * 3.28084).round();
    return '$meters m ($feet ft)';
  }

  /// Deep equality check covering all mutable fields.
  ///
  /// Unlike [operator ==] (which only compares identity keys uid+type+timeUtcMs
  /// for Set/Map membership), this method compares every field that could
  /// trigger a UI rebuild — position, staleness, motion data, and callsign.
  /// Used by persistence notifiers to skip redundant state emissions.
  bool contentEquals(TakEvent other) =>
      uid == other.uid &&
      type == other.type &&
      timeUtcMs == other.timeUtcMs &&
      staleUtcMs == other.staleUtcMs &&
      receivedUtcMs == other.receivedUtcMs &&
      lat == other.lat &&
      lon == other.lon &&
      callsign == other.callsign &&
      speed == other.speed &&
      course == other.course &&
      hae == other.hae;

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
      'lat=$lat, lon=$lon, '
      'speed=$speed, course=$course, hae=$hae)';
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

/// Convert a course in degrees to a compass direction string.
String _compassDirection(double degrees) {
  // Normalize to 0–360 range
  final d = degrees % 360;
  if (d >= 337.5 || d < 22.5) return 'N';
  if (d < 67.5) return 'NE';
  if (d < 112.5) return 'E';
  if (d < 157.5) return 'SE';
  if (d < 202.5) return 'S';
  if (d < 247.5) return 'SW';
  if (d < 292.5) return 'W';
  return 'NW';
}
