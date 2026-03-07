// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MRRP frame data class representing a parsed MRRP protocol frame.
///
/// Holds all header fields plus the raw payload bytes. Instances are
/// produced by [MrrpCodec.decode] and consumed by [MrrpCodec.encode].
library;

import 'dart:typed_data';

import 'mrrp_types.dart';

/// A parsed MRRP TLV header extension entry.
class MrrpTlvEntry {
  /// TLV type code.
  final int type;

  /// TLV value bytes.
  final Uint8List value;

  const MrrpTlvEntry({required this.type, required this.value});

  /// Known TLV type, if recognized.
  MrrpTlvType? get knownType => MrrpTlvType.fromCode(type);

  @override
  String toString() =>
      'MrrpTlvEntry(type=0x${type.toRadixString(16)}, len=${value.length})';
}

/// A single MRRP protocol frame.
///
/// The frame consists of a fixed 20-byte header, optional TLV header
/// extensions, and a service-specific payload.
class MrrpFrame {
  /// Protocol magic byte 0 (offset 0). Must be 0x4D ('M').
  final int magic0;

  /// Protocol magic byte 1 (offset 1). Must be 0x52 ('R').
  final int magic1;

  /// Protocol major version (offset 2).
  final int versionMajor;

  /// Protocol minor version (offset 3).
  final int versionMinor;

  /// MRRP message type (offset 4).
  final MrrpMessageType msgType;

  /// Flags bitfield (offset 5).
  final int flags;

  /// Total header length in bytes (offsets 6-7, LE). Minimum 20.
  final int headerLen;

  /// Request correlation ID (offsets 8-11, LE).
  final int requestId;

  /// Target service identifier (offsets 12-15, LE).
  final int serviceId;

  /// Action within service (offsets 16-17, LE).
  final int actionId;

  /// Payload byte count (offsets 18-19, LE).
  final int payloadLen;

  /// Parsed TLV header extensions (empty if no extensions present).
  final List<MrrpTlvEntry> headerExtensions;

  /// Service-specific payload bytes.
  final Uint8List payload;

  const MrrpFrame({
    this.magic0 = 0x4D,
    this.magic1 = 0x52,
    required this.versionMajor,
    required this.versionMinor,
    required this.msgType,
    required this.flags,
    required this.headerLen,
    required this.requestId,
    required this.serviceId,
    required this.actionId,
    required this.payloadLen,
    this.headerExtensions = const [],
    required this.payload,
  });

  /// Whether the ACK_REQUIRED flag is set.
  bool get ackRequired => (flags & MrrpFlags.ackRequired) != 0;

  /// Whether the IS_RESPONSE flag is set.
  bool get isResponse => (flags & MrrpFlags.isResponse) != 0;

  /// Whether the IS_ERROR flag is set.
  bool get isError => (flags & MrrpFlags.isError) != 0;

  /// Look up a TLV extension by known type.
  MrrpTlvEntry? findExtension(MrrpTlvType type) {
    for (final ext in headerExtensions) {
      if (ext.type == type.code) return ext;
    }
    return null;
  }

  /// Human-readable service name.
  String get serviceName => MrrpServiceId.nameOf(serviceId);

  @override
  String toString() =>
      'MrrpFrame(v$versionMajor.$versionMinor, '
      'type=${msgType.name}(0x${msgType.code.toRadixString(16)}), '
      'flags=0x${flags.toRadixString(16)}, '
      'hdrLen=$headerLen, '
      'reqId=0x${requestId.toRadixString(16)}, '
      'service=${MrrpServiceId.nameOf(serviceId)}, '
      'action=0x${actionId.toRadixString(16)}, '
      'payload=$payloadLen B'
      '${headerExtensions.isNotEmpty ? ', ext=${headerExtensions.length}' : ''}'
      ')';
}
