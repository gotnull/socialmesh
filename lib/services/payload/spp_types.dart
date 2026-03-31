// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'spp_constants.dart';

/// SPP negotiation state for a single payload transfer session.
enum SppNegotiationState {
  /// Offer sent, awaiting ACCEPT/DECLINE.
  offerSent,

  /// Offer received, awaiting user decision or auto-accept evaluation.
  offerPending,

  /// Transfer accepted, chunks may flow.
  accepted,

  /// Transfer declined by receiver.
  declined,

  /// Transfer aborted by either party.
  aborted,

  /// Negotiation timed out (no response to offer).
  timedOut,
}

/// SPP payload type enumeration for type-safe usage in Dart code.
enum SppPayload {
  /// Generic file transfer.
  file,

  /// Compressed image.
  image,

  /// Codec2 voice message.
  voice,

  /// TAK/CoT attachment.
  tak,

  /// Custom/future extension.
  custom;

  /// Convert from wire constant to enum.
  static SppPayload fromWire(int value) => switch (value) {
    SppPayloadType.file => file,
    SppPayloadType.image => image,
    SppPayloadType.voice => voice,
    SppPayloadType.tak => tak,
    _ => custom,
  };

  /// Convert to wire constant.
  int get wireValue => switch (this) {
    file => SppPayloadType.file,
    image => SppPayloadType.image,
    voice => SppPayloadType.voice,
    tak => SppPayloadType.tak,
    custom => SppPayloadType.custom,
  };
}

/// Auto-accept configuration for incoming payload offers.
class SppAutoAcceptConfig {
  /// Whether auto-accept is enabled at all.
  final bool enabled;

  /// Only auto-accept from trusted nodes.
  final bool trustedOnly;

  /// Maximum payload size to auto-accept (bytes).
  final int maxSizeBytes;

  /// Payload types that may be auto-accepted.
  final Set<SppPayload> allowedTypes;

  const SppAutoAcceptConfig({
    this.enabled = false,
    this.trustedOnly = true,
    this.maxSizeBytes = 4096,
    this.allowedTypes = const {
      SppPayload.image,
      SppPayload.voice,
      SppPayload.file,
    },
  });

  /// Default configuration: auto-accept disabled.
  static const SppAutoAcceptConfig defaultConfig = SppAutoAcceptConfig();

  /// Evaluate whether an offer should be auto-accepted.
  ///
  /// Returns `true` if all auto-accept criteria are met.
  /// The caller must verify trust status separately via [isTrusted].
  bool shouldAutoAccept({
    required SppPayload payloadType,
    required int payloadSize,
    required bool isTrusted,
  }) {
    if (!enabled) return false;
    if (trustedOnly && !isTrusted) return false;
    if (payloadSize > maxSizeBytes) return false;
    if (!allowedTypes.contains(payloadType)) return false;
    return true;
  }

  SppAutoAcceptConfig copyWith({
    bool? enabled,
    bool? trustedOnly,
    int? maxSizeBytes,
    Set<SppPayload>? allowedTypes,
  }) => SppAutoAcceptConfig(
    enabled: enabled ?? this.enabled,
    trustedOnly: trustedOnly ?? this.trustedOnly,
    maxSizeBytes: maxSizeBytes ?? this.maxSizeBytes,
    allowedTypes: allowedTypes ?? this.allowedTypes,
  );
}

/// An incoming payload offer for UI presentation.
class SppPayloadOffer {
  /// Unique payload transfer ID (hex string).
  final String payloadIdHex;

  /// Raw 128-bit payload ID.
  final Uint8List payloadId;

  /// Payload type.
  final SppPayload payloadType;

  /// Filename (may be empty for untitled payloads).
  final String filename;

  /// MIME type.
  final String mimeType;

  /// Total payload size in bytes.
  final int payloadSize;

  /// Source node number.
  final int? sourceNodeNum;

  /// When the offer was received.
  final DateTime receivedAt;

  /// Current negotiation state.
  final SppNegotiationState state;

  const SppPayloadOffer({
    required this.payloadIdHex,
    required this.payloadId,
    required this.payloadType,
    required this.filename,
    required this.mimeType,
    required this.payloadSize,
    required this.receivedAt,
    this.sourceNodeNum,
    this.state = SppNegotiationState.offerPending,
  });

  SppPayloadOffer copyWith({SppNegotiationState? state}) => SppPayloadOffer(
    payloadIdHex: payloadIdHex,
    payloadId: payloadId,
    payloadType: payloadType,
    filename: filename,
    mimeType: mimeType,
    payloadSize: payloadSize,
    sourceNodeNum: sourceNodeNum,
    receivedAt: receivedAt,
    state: state ?? this.state,
  );
}
