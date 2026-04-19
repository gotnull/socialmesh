// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// A registered video stream from the TAK Gateway.
///
/// Mirrors the `VideoStream` interface in
/// `backend/tak-gateway/src/video/types.ts`.
class VideoStream {
  /// Server-generated ID: "vs-" + 8 hex chars.
  final String id;

  /// Stream key for RTMP authentication (32-char hex, 128 bits entropy).
  final String streamKey;

  /// Human-readable stream name.
  final String name;

  /// Firebase UID of the stream owner.
  final String owner;

  /// Callsign of the stream owner (for CoT contact element).
  final String ownerCallsign;

  /// Current status.
  final VideoStreamStatus status;

  /// HLS playback URL.
  final String url;

  /// RTSP playback URL.
  final String rtspUrl;

  /// RTMP publish URL (without stream key).
  final String rtmpUrl;

  /// WGS-84 latitude (nullable).
  final double? lat;

  /// WGS-84 longitude (nullable).
  final double? lon;

  /// Height above ellipsoid in meters (nullable).
  final double? hae;

  /// Freeform tags for filtering (max 10, each max 30 chars).
  final List<String> tags;

  /// Video resolution label (e.g. "1280x720").
  final String? resolution;

  /// Video bitrate in kbps.
  final int? bitrate;

  /// Stream creation time (epoch ms).
  final int createdAt;

  /// Last heartbeat time (epoch ms).
  final int lastHeartbeat;

  /// Expiry time — stream is removed after this (epoch ms).
  final int expiresAt;

  const VideoStream({
    required this.id,
    required this.streamKey,
    required this.name,
    required this.owner,
    required this.ownerCallsign,
    required this.status,
    required this.url,
    required this.rtspUrl,
    required this.rtmpUrl,
    this.lat,
    this.lon,
    this.hae,
    this.tags = const [],
    this.resolution,
    this.bitrate,
    required this.createdAt,
    required this.lastHeartbeat,
    required this.expiresAt,
  });

  /// Construct from gateway JSON map.
  factory VideoStream.fromJson(Map<String, dynamic> json) {
    return VideoStream(
      id: json['id'] as String,
      streamKey: json['streamKey'] as String? ?? '',
      name: json['name'] as String,
      owner: json['owner'] as String,
      ownerCallsign: json['ownerCallsign'] as String,
      status: VideoStreamStatus.fromString(json['status'] as String),
      url: json['url'] as String,
      rtspUrl: json['rtspUrl'] as String? ?? '',
      rtmpUrl: json['rtmpUrl'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lon: (json['lon'] as num?)?.toDouble(),
      hae: (json['hae'] as num?)?.toDouble(),
      tags:
          (json['tags'] as List<dynamic>?)?.map((t) => t as String).toList() ??
          const [],
      resolution: json['resolution'] as String?,
      bitrate: (json['bitrate'] as num?)?.toInt(),
      createdAt: json['createdAt'] as int,
      lastHeartbeat: json['lastHeartbeat'] as int,
      expiresAt: json['expiresAt'] as int,
    );
  }

  /// Convert to JSON map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'streamKey': streamKey,
    'name': name,
    'owner': owner,
    'ownerCallsign': ownerCallsign,
    'status': status.name,
    'url': url,
    'rtspUrl': rtspUrl,
    'rtmpUrl': rtmpUrl,
    'lat': lat,
    'lon': lon,
    'hae': hae,
    'tags': tags,
    'resolution': resolution,
    'bitrate': bitrate,
    'createdAt': createdAt,
    'lastHeartbeat': lastHeartbeat,
    'expiresAt': expiresAt,
  };

  /// Whether this stream has expired.
  bool get isExpired => DateTime.now().millisecondsSinceEpoch > expiresAt;

  /// Whether this stream has position data.
  bool get hasPosition => lat != null && lon != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoStream &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          status == other.status &&
          lastHeartbeat == other.lastHeartbeat;

  @override
  int get hashCode => Object.hash(id, status, lastHeartbeat);

  @override
  String toString() => 'VideoStream(id=$id, name=$name, status=${status.name})';
}

/// Video stream status enum matching backend `VideoStreamStatus`.
enum VideoStreamStatus {
  live,
  offline,
  error;

  static VideoStreamStatus fromString(String value) {
    return switch (value) {
      'live' => VideoStreamStatus.live,
      'offline' => VideoStreamStatus.offline,
      'error' => VideoStreamStatus.error,
      _ => VideoStreamStatus.offline,
    };
  }
}

/// Input for creating a video stream (matches backend `VideoStreamCreate`).
class VideoStreamCreateRequest {
  final String name;
  final String ownerCallsign;
  final double? lat;
  final double? lon;
  final double? hae;
  final List<String>? tags;
  final String? resolution;
  final int? bitrate;

  const VideoStreamCreateRequest({
    required this.name,
    required this.ownerCallsign,
    this.lat,
    this.lon,
    this.hae,
    this.tags,
    this.resolution,
    this.bitrate,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'ownerCallsign': ownerCallsign,
    if (lat != null) 'lat': lat,
    if (lon != null) 'lon': lon,
    if (hae != null) 'hae': hae,
    if (tags != null && tags!.isNotEmpty) 'tags': tags,
    if (resolution != null) 'resolution': resolution,
    if (bitrate != null) 'bitrate': bitrate,
  };
}

/// Input for heartbeat updates (matches backend `VideoStreamHeartbeat`).
class VideoStreamHeartbeatRequest {
  final double? lat;
  final double? lon;
  final double? hae;

  const VideoStreamHeartbeatRequest({this.lat, this.lon, this.hae});

  Map<String, dynamic> toJson() => {
    if (lat != null) 'lat': lat,
    if (lon != null) 'lon': lon,
    if (hae != null) 'hae': hae,
  };
}
