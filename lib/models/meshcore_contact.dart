// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import '../core/meshcore_constants.dart';
import '../services/meshcore/protocol/meshcore_messages.dart' as msgs;

/// Advertisement types for MeshCore contacts.
class MeshCoreAdvType {
  MeshCoreAdvType._();

  static const int chat = 1;
  static const int repeater = 2;
  static const int room = 3;
  static const int sensor = 4;

  static String label(int type) {
    switch (type) {
      case chat:
        return 'Chat';
      case repeater:
        return 'Repeater';
      case room:
        return 'Room';
      case sensor:
        return 'Sensor';
      default:
        return 'Unknown';
    }
  }
}

/// A MeshCore contact (discovered via advertisement or manually added).
class MeshCoreContact {
  /// Public key (32 bytes) - unique identifier for the contact.
  final Uint8List publicKey;

  /// Display name from advertisement or manual entry.
  final String name;

  /// Advertisement type (chat, repeater, room, sensor).
  final int type;

  /// Path length: -1 = flood, 0+ = direct hops.
  final int pathLength;

  /// Path bytes from device.
  final Uint8List path;

  /// User's path override: -1 = force flood, null = auto.
  final int? pathOverride;

  /// User's path override bytes.
  final Uint8List? pathOverrideBytes;

  /// Latitude (if advertised).
  final double? latitude;

  /// Longitude (if advertised).
  final double? longitude;

  /// When this contact was last seen.
  final DateTime lastSeen;

  /// When the last message was received.
  final DateTime lastMessageAt;

  /// Unread message count.
  final int unreadCount;

  /// D-Q3: firmware-side contact flags bitset (offset 33 of the
  /// CONTACT frame). Bit 0 = favorite; remaining bits reserved.
  /// Defaults to `0` for in-memory / test contacts that didn't come
  /// from a firmware refresh.
  final int flags;

  /// D28: latest known SNR for this contact, encoded as the firmware's
  /// raw int8 value scaled by 4 (so dB = snrQuarter / 4.0). Sourced
  /// from inbound V3 message frames at receive time.
  ///
  /// Session-only: not persisted to the contact store. Cleared on
  /// app restart and on contact-store reload from firmware. UI hides
  /// the badge when this is null.
  final int? snrQuarter;

  MeshCoreContact({
    required this.publicKey,
    required this.name,
    required this.type,
    required this.pathLength,
    required this.path,
    this.pathOverride,
    this.pathOverrideBytes,
    this.latitude,
    this.longitude,
    required this.lastSeen,
    DateTime? lastMessageAt,
    this.unreadCount = 0,
    this.snrQuarter,
    this.flags = 0,
  }) : lastMessageAt = lastMessageAt ?? lastSeen;

  /// D-Q3: convenience getter for the `favorite` bit.
  bool get isFavorite =>
      (flags & MeshCoreContactFlags.favorite) == MeshCoreContactFlags.favorite;

  /// D28: SNR in dB derived from the raw firmware quarter encoding,
  /// or null when no message has carried SNR for this contact yet.
  double? get snrDb => snrQuarter == null ? null : snrQuarter! / 4.0;

  /// Public key as hex string.
  String get publicKeyHex => _bytesToHex(publicKey);

  /// Short version of public key for display.
  String get shortPubKeyHex {
    final hex = publicKeyHex;
    if (hex.length < 16) return hex;
    return '<${hex.substring(0, 8)}…${hex.substring(hex.length - 8)}>';
  }

  /// User-facing display name with a deterministic, non-localized
  /// fallback when the firmware contact entry has an empty name field
  /// (D23 — auto-added contacts from inbound adverts that did not
  /// carry a friendly name). Order:
  ///
  /// 1. [name] if non-empty
  /// 2. [shortPubKeyHex] (`<79426d8d…0831782b>`) when the public key
  ///    is large enough to fingerprint
  /// 3. empty string — caller is expected to fall through to a
  ///    localized "Unknown" placeholder
  ///
  /// Never exposes the full 64-char public-key hex; the bracketed
  /// 8-head + 8-tail shape is the canonical UI fingerprint, mirroring
  /// the log channel's pubkey redaction format.
  String get displayName {
    if (name.isNotEmpty) return name;
    if (publicKey.isEmpty) return '';
    if (publicKey.length < 8) return '';
    return shortPubKeyHex;
  }

  /// Human-readable type label.
  String get typeLabel => MeshCoreAdvType.label(type);

  /// Human-readable path description.
  String get pathLabel {
    if (pathOverride != null) {
      if (pathOverride! < 0) return 'Flood (forced)';
      if (pathOverride == 0) return 'Direct (forced)';
      return '$pathOverride hops (forced)';
    }
    if (pathLength < 0) return 'Flood';
    if (pathLength == 0) return 'Direct';
    return '$pathLength hops';
  }

  /// Whether this contact has location data.
  bool get hasLocation => latitude != null && longitude != null;

  /// Whether this is a chat-type contact.
  bool get isChat => type == MeshCoreAdvType.chat;

  /// Whether this is a repeater.
  bool get isRepeater => type == MeshCoreAdvType.repeater;

  /// Whether this is a room.
  bool get isRoom => type == MeshCoreAdvType.room;

  /// Whether this is a sensor.
  bool get isSensor => type == MeshCoreAdvType.sensor;

  MeshCoreContact copyWith({
    Uint8List? publicKey,
    String? name,
    int? type,
    int? pathLength,
    Uint8List? path,
    int? pathOverride,
    Uint8List? pathOverrideBytes,
    bool clearPathOverride = false,
    double? latitude,
    double? longitude,
    DateTime? lastSeen,
    DateTime? lastMessageAt,
    int? unreadCount,
    int? snrQuarter,
    bool clearSnrQuarter = false,
    int? flags,
  }) {
    return MeshCoreContact(
      publicKey: publicKey ?? this.publicKey,
      name: name ?? this.name,
      type: type ?? this.type,
      pathLength: pathLength ?? this.pathLength,
      path: path ?? this.path,
      pathOverride: clearPathOverride
          ? null
          : (pathOverride ?? this.pathOverride),
      pathOverrideBytes: clearPathOverride
          ? null
          : (pathOverrideBytes ?? this.pathOverrideBytes),
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      lastSeen: lastSeen ?? this.lastSeen,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      flags: flags ?? this.flags,
      snrQuarter: clearSnrQuarter ? null : (snrQuarter ?? this.snrQuarter),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshCoreContact &&
          runtimeType == other.runtimeType &&
          publicKeyHex == other.publicKeyHex;

  @override
  int get hashCode => publicKeyHex.hashCode;

  @override
  String toString() => 'MeshCoreContact($name, $typeLabel, $pathLabel)';

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Parse a contact from a `RESP_CODE_CONTACT (0x03)` or
/// `PUSH_CODE_NEW_ADVERT (0x8A)` payload (after the leading code byte
/// has been stripped by the codec) into a [MeshCoreContact] model.
///
/// **Layout owner:** the byte-accurate firmware layout is documented
/// and pinned by the canonical parser at
/// [services/meshcore/protocol/meshcore_messages.dart] (`parseContact`)
/// + tests in `test/services/meshcore/protocol/parse_contact_layout_test.dart`.
/// This function is a thin model-typed adapter over that canonical
/// parser so callers that only need a [MeshCoreContact] (rather than
/// the richer [MeshCoreContactInfo]) get the corrected layout for
/// free without duplicating the byte arithmetic.
///
/// Pre-D34c-A this was an out-of-date inline parser that read a
/// phantom `[pubkey][adv_type][path_len][lastmod-u16][lat][lon][name]`
/// shape — the actual firmware layout is `[pubkey][type][flags]
/// [out_path_len][out_path×64][name×32][last_advert_ts][lat][lon][lastmod]`.
/// The legacy body returned `path = Uint8List(0)` unconditionally,
/// silently dropping the firmware's path bytes. D34c-A delegates to
/// the canonical parser so the path bytes survive into the model.
///
/// Returns `null` when the payload is shorter than the minimum
/// canonical layout, or when the canonical parser otherwise rejects
/// it. Callers must handle null (e.g., refresh contacts via the live
/// `getContacts` flow on the session).
MeshCoreContact? parseContact(Uint8List payload) {
  final result = msgs.parseContact(payload);
  if (!result.isSuccess) return null;
  final info = result.value!;
  return MeshCoreContact(
    publicKey: info.publicKey,
    name: info.name,
    type: info.advType,
    pathLength: info.pathLength,
    path: info.pathBytes,
    latitude: info.latitudeDegrees,
    longitude: info.longitudeDegrees,
    lastSeen: DateTime.now(),
  );
}

/// D46-A: legacy SocialMesh-only `<pubkeyhex>:<name>` contact-code
/// format. Pre-D46-A this was the primary share path; superseded by
/// the canonical `meshcore://<hex>` URL form in
/// `lib/services/meshcore/protocol/meshcore_contact_url.dart`.
///
/// Still used by:
///   - the discovery screen's "copy code" affordance (a heard advert
///     isn't yet in the firmware roster, so `CMD_EXPORT_CONTACT` is
///     not available — the stub-only legacy form is the honest
///     fallback).
///   - the typed-contact-code paste sheet on the contacts screen
///     (one-release backwards-compat for users with saved codes).
///
/// New paths should prefer `MeshCoreContactUrl.encode` +
/// `meshCoreContactsProvider.exportContactUrl` for share, and
/// `previewContactImport` for import.
String generateContactCode(MeshCoreContact contact) {
  return '${contact.publicKeyHex}:${contact.name}';
}

/// D46-A: paired legacy parser. See [generateContactCode] for the
/// deprecation note. New code paths should call `previewContactImport`
/// on `meshCoreContactsProvider` — it accepts both `meshcore://<hex>`
/// and the legacy `<pubkeyhex>:<name>` form and surfaces a typed
/// preview suitable for a confirmation sheet.
MeshCoreContact? parseContactCode(String code) {
  final parts = code.split(':');
  if (parts.length < 2) return null;

  final hexKey = parts[0];
  final name = parts.sublist(1).join(':');

  if (hexKey.length != 64) return null; // 32 bytes = 64 hex chars

  try {
    final pubKey = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      pubKey[i] = int.parse(hexKey.substring(i * 2, i * 2 + 2), radix: 16);
    }

    return MeshCoreContact(
      publicKey: pubKey,
      name: name,
      type: MeshCoreAdvType.chat,
      pathLength: -1, // Flood by default
      path: Uint8List(0),
      lastSeen: DateTime.now(),
    );
  } catch (_) {
    return null;
  }
}
