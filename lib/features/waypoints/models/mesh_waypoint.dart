// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../../services/protocol/protocol_service.dart'
    show MeshWaypointEvent;
import '../../../utils/text_sanitizer.dart' show isValidUnicodeScalar;

// A shared Meshtastic waypoint (POI) — the in-app representation of the
// firmware `Waypoint` proto (PortNum WAYPOINT_APP). Coordinates are stored as
// decimal degrees (the wire carries 1e7-scaled sfixed32, converted at the
// protocol boundary). The feature layer never touches the generated proto; the
// protocol layer hands us a plain [MeshWaypointEvent] and accepts plain fields
// on send.
class MeshWaypoint {
  // Wire `id` (u32). Stable across edits — the upsert key.
  final int id;

  // Decimal degrees (= latitude_i / 1e7, longitude_i / 1e7).
  final double latitude;
  final double longitude;

  // Expiry as Unix epoch seconds. 0 = never expires. 1 is the firmware
  // "delete for everyone" sentinel (a broadcast forcing immediate expiry),
  // never a real expiry time — see [isExpired] / [hasExpiry].
  final int expire;

  // Node number permitted to edit. 0 = open to any mesh member; otherwise
  // only that node may update the waypoint.
  final int lockedTo;

  // Max 30 chars on the wire.
  final String name;

  // Max 100 chars on the wire.
  final String description;

  // Designator emoji as a single Unicode scalar (the wire `icon` fixed32).
  // 0 = no icon (render the default pin). Multi-scalar ZWJ sequences (flags,
  // family/profession emoji) collapse to their base rune to match the
  // single-scalar wire format used by the official Meshtastic clients.
  final int icon;

  // Node that authored/last broadcast this waypoint (`packet.from`), or our
  // own node for locally created ones.
  final int sourceNodeNum;

  // Local receipt (or creation) time.
  final DateTime receivedAt;

  // True when [sourceNodeNum] is our node — drives "delete for everyone" and
  // edit affordances.
  final bool isMine;

  const MeshWaypoint({
    required this.id,
    required this.latitude,
    required this.longitude,
    this.expire = 0,
    this.lockedTo = 0,
    this.name = '',
    this.description = '',
    this.icon = 0,
    required this.sourceNodeNum,
    required this.receivedAt,
    this.isMine = false,
  });

  // Only the locking node may edit when locked.
  bool get isLocked => lockedTo != 0;

  // A real (non-sentinel) expiry time is set.
  bool get hasExpiry => expire > 1;

  // Past its real expiry. expire <= 1 is never "expired" (0 = never,
  // 1 = delete sentinel handled separately on the event path).
  bool get isExpired =>
      expire > 1 && expire * 1000 <= DateTime.now().millisecondsSinceEpoch;

  // True when [icon] is set and is a renderable Unicode scalar. A peer fully
  // controls the wire `icon` field, so a malformed value (surrogate half or
  // out-of-range scalar) must fall back to the default pin rather than reach
  // a Text/EmojiGlyph and crash the paragraph builder.
  bool get hasRenderableIcon => icon != 0 && isValidUnicodeScalar(icon);

  // The emoji glyph for [icon], or '' when no icon is set or the value is not
  // a renderable scalar. Uses the full-codepoint form so scalars above U+FFFF
  // render correctly.
  String get iconEmoji => hasRenderableIcon ? String.fromCharCodes([icon]) : '';

  // True when [other] carries the same user-visible content as this waypoint.
  // A scheduled rebroadcast of an unchanged waypoint must compare equal so
  // the notification path can stay silent instead of re-alerting on every
  // repeat. Local bookkeeping ([sourceNodeNum], [receivedAt], [isMine]) is
  // ignored, and so is [expire]: rebroadcasters roll the expiry forward on
  // every transmission, and a new expiry alone changes nothing worth an
  // alert. The delete sentinel never reaches this comparison - the event
  // path handles expire == 1 before reconciliation.
  bool sameContentAs(MeshWaypoint other) {
    return id == other.id &&
        latitude == other.latitude &&
        longitude == other.longitude &&
        lockedTo == other.lockedTo &&
        name == other.name &&
        description == other.description &&
        icon == other.icon;
  }

  // Build from a decoded protocol event. [myNodeNum] resolves [isMine].
  factory MeshWaypoint.fromEvent(MeshWaypointEvent event, {int? myNodeNum}) {
    return MeshWaypoint(
      id: event.id,
      latitude: event.latitude,
      longitude: event.longitude,
      expire: event.expire,
      lockedTo: event.lockedTo,
      name: event.name,
      description: event.description,
      icon: event.icon,
      sourceNodeNum: event.fromNodeNum,
      receivedAt: event.receivedAt,
      isMine: myNodeNum != null && event.fromNodeNum == myNodeNum,
    );
  }

  MeshWaypoint copyWith({
    int? id,
    double? latitude,
    double? longitude,
    int? expire,
    int? lockedTo,
    String? name,
    String? description,
    int? icon,
    int? sourceNodeNum,
    DateTime? receivedAt,
    bool? isMine,
  }) {
    return MeshWaypoint(
      id: id ?? this.id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      expire: expire ?? this.expire,
      lockedTo: lockedTo ?? this.lockedTo,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      sourceNodeNum: sourceNodeNum ?? this.sourceNodeNum,
      receivedAt: receivedAt ?? this.receivedAt,
      isMine: isMine ?? this.isMine,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'expire': expire,
      'locked_to': lockedTo,
      'name': name,
      'description': description,
      'icon': icon,
      'source_node_num': sourceNodeNum,
      'received_at_ms': receivedAt.millisecondsSinceEpoch,
      'is_mine': isMine ? 1 : 0,
    };
  }

  factory MeshWaypoint.fromMap(Map<String, Object?> map) {
    return MeshWaypoint(
      id: (map['id'] as num).toInt(),
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      expire: (map['expire'] as num?)?.toInt() ?? 0,
      lockedTo: (map['locked_to'] as num?)?.toInt() ?? 0,
      name: (map['name'] as String?) ?? '',
      description: (map['description'] as String?) ?? '',
      icon: (map['icon'] as num?)?.toInt() ?? 0,
      sourceNodeNum: (map['source_node_num'] as num?)?.toInt() ?? 0,
      receivedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['received_at_ms'] as num).toInt(),
      ),
      isMine: ((map['is_mine'] as num?)?.toInt() ?? 0) == 1,
    );
  }
}
