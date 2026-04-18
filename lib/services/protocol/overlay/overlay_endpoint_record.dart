// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Immutable data model for a row in `endpoints.db`.
///
/// Per `docs/sip/OVERLAY_V0_2.md` §13.3 (adapted for P3):
///   - `endpoint_id` is the primary, authoritative truth key.
///   - `persona_hint`, `peer_node_num_hint` are secondary lookup keys.
///   - `trust_level` reflects the observation source (observed vs
///     signature-verified). Advisory, overwriteable, timestamped.
library;

import 'dart:typed_data';

/// How the endpoint record was last validated. Codes are frozen.
enum OverlayEndpointTrustLevel {
  /// Passively observed (e.g., inbound unsigned LINK_OPEN, or an
  /// inbound CAP_BEACON capability TLV before signature verification
  /// exists). Advisory only.
  observed(0),

  /// The most recent binding included a valid Ed25519 signature over
  /// the endpoint's claim. Highest confidence for P3.
  signatureVerified(1);

  const OverlayEndpointTrustLevel(this.code);
  final int code;

  static OverlayEndpointTrustLevel? fromCode(int code) {
    for (final l in values) {
      if (l.code == code) return l;
    }
    return null;
  }
}

/// Where the most recent observation came from (column string).
abstract final class OverlayEndpointObservationSource {
  static const String linkFrame = 'link_frame';
  static const String capBeacon = 'cap_beacon';
  static const String idClaim = 'id_claim';
  static const String local = 'local';
}

/// Immutable endpoint row.
class OverlayEndpointRecord {
  /// 8-byte derived endpoint ID (primary key).
  final Uint8List endpointId;

  /// 32-byte Ed25519 public key (persona).
  final Uint8List personaPubEd;

  /// 8-byte persona hint = `SHA-256(personaPubEd)[:8]`.
  final Uint8List personaHint;

  /// Service scope (`0` for root).
  final int serviceId;

  /// Most recently observed Meshtastic node num (hint, not truth).
  final int? peerNodeNumHint;

  /// Capability bitset observed for this endpoint.
  final int supportedFeatures;

  /// Peer-advertised chunk ceiling, if any.
  final int? maxChunkBytes;

  /// Peer-advertised resource ceiling, if any.
  final int? maxResourceBytes;

  /// Wall-clock ms when the row was first inserted.
  final int firstSeenMs;

  /// Wall-clock ms of the most recent refresh.
  final int lastSeenMs;

  /// Trust level of the last binding.
  final OverlayEndpointTrustLevel trustLevel;

  /// Source of the last observation ([OverlayEndpointObservationSource]).
  final String source;

  const OverlayEndpointRecord({
    required this.endpointId,
    required this.personaPubEd,
    required this.personaHint,
    required this.serviceId,
    this.peerNodeNumHint,
    required this.supportedFeatures,
    this.maxChunkBytes,
    this.maxResourceBytes,
    required this.firstSeenMs,
    required this.lastSeenMs,
    required this.trustLevel,
    required this.source,
  });

  /// Return a copy with selected fields replaced.
  OverlayEndpointRecord copyWith({
    int? peerNodeNumHint,
    int? supportedFeatures,
    int? maxChunkBytes,
    int? maxResourceBytes,
    int? lastSeenMs,
    OverlayEndpointTrustLevel? trustLevel,
    String? source,
  }) {
    return OverlayEndpointRecord(
      endpointId: endpointId,
      personaPubEd: personaPubEd,
      personaHint: personaHint,
      serviceId: serviceId,
      peerNodeNumHint: peerNodeNumHint ?? this.peerNodeNumHint,
      supportedFeatures: supportedFeatures ?? this.supportedFeatures,
      maxChunkBytes: maxChunkBytes ?? this.maxChunkBytes,
      maxResourceBytes: maxResourceBytes ?? this.maxResourceBytes,
      firstSeenMs: firstSeenMs,
      lastSeenMs: lastSeenMs ?? this.lastSeenMs,
      trustLevel: trustLevel ?? this.trustLevel,
      source: source ?? this.source,
    );
  }

  @override
  String toString() =>
      'OverlayEndpointRecord('
      'id=${_hex(endpointId)}, hint=${_hex(personaHint)}, '
      'service=$serviceId, trust=${trustLevel.name}, '
      'features=0x${supportedFeatures.toRadixString(16)}, '
      'nodeHint=$peerNodeNumHint)';

  static String _hex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }
}
