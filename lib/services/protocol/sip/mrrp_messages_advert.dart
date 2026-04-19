// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Encode/decode helpers for MRRP SERVICE_ADVERT, SERVICE_DIR_REQ,
/// and SERVICE_DIR_RESP payloads.
///
/// These are the message-specific payload formats inside MRRP frames
/// whose msg_type is serviceAdvert(0x01), serviceDirReq(0x02), or
/// serviceDirResp(0x03).
library;

import 'dart:typed_data';

import 'mrrp_constants.dart';
import 'mrrp_types.dart';

/// A parsed service descriptor from a SERVICE_ADVERT or SERVICE_DIR_RESP.
class MrrpAdvertDescriptor {
  final int serviceId;
  final MrrpServiceType serviceType;
  final int versionMajor;
  final int versionMinor;
  final int serviceFlags;
  final Uint8List metadata;

  const MrrpAdvertDescriptor({
    required this.serviceId,
    required this.serviceType,
    required this.versionMajor,
    required this.versionMinor,
    required this.serviceFlags,
    required this.metadata,
  });

  /// Human-readable service name.
  String get serviceName => MrrpServiceId.nameOf(serviceId);
}

/// Helpers for encoding/decoding advertisement message payloads.
abstract final class MrrpMessagesAdvert {
  /// Decode the payload of a SERVICE_ADVERT or SERVICE_DIR_RESP message.
  ///
  /// Payload format:
  ///   [0]       service_count (uint8)
  ///   [1..]     repeated service descriptors:
  ///     [0..3]  service_id (uint32 LE)
  ///     [4]     service_type (uint8)
  ///     [5]     version_major (uint8)
  ///     [6]     version_minor (uint8)
  ///     [7..8]  service_flags (uint16 LE)
  ///     [9]     metadata_len (uint8)
  ///     [10..]  metadata (metadata_len bytes)
  ///
  /// Returns null if the payload is malformed.
  static List<MrrpAdvertDescriptor>? decodeAdvertPayload(Uint8List payload) {
    if (payload.isEmpty) return null;

    final count = payload[0];
    if (count == 0) return const [];
    if (count > MrrpConstants.mrrpServiceAdvertMaxServices) return null;

    final descriptors = <MrrpAdvertDescriptor>[];
    var offset = 1;

    for (var i = 0; i < count; i++) {
      if (offset + MrrpConstants.mrrpServiceDescriptorMin > payload.length) {
        return null;
      }

      final bd = ByteData.sublistView(payload, offset);
      final serviceId = bd.getUint32(0, Endian.little);
      final serviceTypeCode = payload[offset + 4];
      final serviceType = MrrpServiceType.fromCode(serviceTypeCode);
      if (serviceType == null) return null;
      final vMajor = payload[offset + 5];
      final vMinor = payload[offset + 6];
      final flags = bd.getUint16(7, Endian.little);
      final metaLen = payload[offset + 9];

      if (metaLen > MrrpConstants.mrrpServiceMetadataMaxLen) return null;
      if (offset + MrrpConstants.mrrpServiceDescriptorMin + metaLen >
          payload.length) {
        return null;
      }

      final metadata = metaLen > 0
          ? Uint8List.sublistView(
              payload,
              offset + MrrpConstants.mrrpServiceDescriptorMin,
              offset + MrrpConstants.mrrpServiceDescriptorMin + metaLen,
            )
          : Uint8List(0);

      descriptors.add(
        MrrpAdvertDescriptor(
          serviceId: serviceId,
          serviceType: serviceType,
          versionMajor: vMajor,
          versionMinor: vMinor,
          serviceFlags: flags,
          metadata: metadata,
        ),
      );

      offset += MrrpConstants.mrrpServiceDescriptorMin + metaLen;
    }

    return descriptors;
  }

  /// Encode a SERVICE_DIR_RESP payload from a list of descriptors.
  ///
  /// Same format as SERVICE_ADVERT payload.
  static Uint8List? encodeDirectoryResponse(
    List<MrrpAdvertDescriptor> descriptors,
  ) {
    if (descriptors.isEmpty) {
      return Uint8List.fromList([0]);
    }

    var totalSize = 1; // service_count byte
    for (final d in descriptors) {
      totalSize += MrrpConstants.mrrpServiceDescriptorMin + d.metadata.length;
    }

    if (totalSize > MrrpConstants.mrrpMaxPayload) return null;

    final buffer = Uint8List(totalSize);
    buffer[0] = descriptors.length;

    var offset = 1;
    for (final d in descriptors) {
      final bd = ByteData.sublistView(buffer, offset);
      bd.setUint32(0, d.serviceId, Endian.little);
      buffer[offset + 4] = d.serviceType.code;
      buffer[offset + 5] = d.versionMajor;
      buffer[offset + 6] = d.versionMinor;
      bd.setUint16(7, d.serviceFlags, Endian.little);
      buffer[offset + 9] = d.metadata.length;
      if (d.metadata.isNotEmpty) {
        buffer.setRange(
          offset + MrrpConstants.mrrpServiceDescriptorMin,
          offset + MrrpConstants.mrrpServiceDescriptorMin + d.metadata.length,
          d.metadata,
        );
      }
      offset += MrrpConstants.mrrpServiceDescriptorMin + d.metadata.length;
    }

    return buffer;
  }
}
