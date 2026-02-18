// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:typed_data';

import 'sm_constants.dart';

/// Node trait enum matching the wire encoding (0-8).
///
/// Mirrors [NodeTrait] from nodedex but is protocol-independent.
enum SmNodeTrait {
  unknown, // 0
  wanderer, // 1
  beacon, // 2
  ghost, // 3
  sentinel, // 4
  relay, // 5
  courier, // 6
  anchor, // 7
  drifter, // 8
}

/// Decoded SM_IDENTITY packet (portnum 262).
///
/// Wire format (see docs/firmware/PACKET_TYPES.md):
/// ```
/// [header:1][flags:1][sigilHash:4][trait?:1][encounterCount?:2]
/// ```
class SmIdentity {
  /// Deterministic sigil hash: `mix(nodeNum)`.
  /// Receiver can verify by computing `mix(packet.from)`.
  final int sigilHash;

  /// Node trait, or null if not included.
  final SmNodeTrait? trait;

  /// Encounter count (0-65535), or null if not included.
  final int? encounterCount;

  /// True if this is a response to a request.
  final bool isResponse;

  /// True if this is a request for the peer's identity.
  final bool isRequest;

  const SmIdentity({
    required this.sigilHash,
    this.trait,
    this.encounterCount,
    this.isResponse = false,
    this.isRequest = false,
  });

  /// Compute the expected sigil hash for a node number.
  ///
  /// This is the `mix()` function from the sigil generator,
  /// identical to the hash used in web/sigil.html and
  /// backend/sigil-api/src/sigil-svg.ts.
  static int computeSigilHash(int nodeNum) {
    var h = nodeNum & 0xFFFFFFFF;
    h ^= h >>> 16;
    h = _imul(h, 0x045d9f3b) & 0xFFFFFFFF;
    h ^= h >>> 16;
    h = _imul(h, 0x045d9f3b) & 0xFFFFFFFF;
    h ^= h >>> 16;
    return h & 0xFFFFFFFF; // Ensure unsigned 32-bit
  }

  /// Verify that the sigil hash matches the expected value for a nodeNum.
  static bool verifySigilHash(int sigilHash, int nodeNum) {
    return computeSigilHash(nodeNum) == sigilHash;
  }

  /// 32-bit integer multiplication (matches JavaScript's Math.imul).
  static int _imul(int a, int b) {
    final aHi = (a >>> 16) & 0xFFFF;
    final aLo = a & 0xFFFF;
    final bHi = (b >>> 16) & 0xFFFF;
    final bLo = b & 0xFFFF;
    return ((aLo * bLo) + (((aHi * bLo + aLo * bHi) << 16) & 0xFFFFFFFF)) &
        0xFFFFFFFF;
  }

  /// Encode to binary payload.
  ///
  /// Returns null if both [isRequest] and [isResponse] are true
  /// (invalid per spec).
  Uint8List? encode() {
    // Contradictory flags: spec requires encoders to reject.
    if (isRequest && isResponse) return null;

    final hasTrait = trait != null;
    final hasEncounters = encounterCount != null;

    var size = 2 + 4; // header + flags + sigilHash
    if (hasTrait) size += 1;
    if (hasEncounters) size += 2;

    if (size > SmPayloadLimit.loraMtu) return null;

    final buffer = ByteData(size);
    var offset = 0;

    // Header: version=0, type=3 -> 0x03
    buffer.setUint8(offset++, 0x03);

    // Flags byte.
    var flags = 0;
    if (hasTrait) flags |= 0x01;
    if (hasEncounters) flags |= 0x02;
    if (isResponse) flags |= 0x04;
    if (isRequest) flags |= 0x08;
    buffer.setUint8(offset++, flags);

    // Sigil hash (uint32, big-endian).
    buffer.setUint32(offset, sigilHash, Endian.big);
    offset += 4;

    // Trait.
    if (hasTrait) {
      buffer.setUint8(offset++, trait!.index);
    }

    // Encounter count.
    if (hasEncounters) {
      buffer.setUint16(offset, encounterCount!.clamp(0, 65535), Endian.big);
      offset += 2;
    }

    return buffer.buffer.asUint8List(0, offset);
  }

  /// Decode from binary payload.
  ///
  /// Returns null if the payload is malformed or has an unsupported version.
  static SmIdentity? decode(Uint8List data) {
    if (data.length < 6) return null; // minimum: header + flags + sigilHash

    final buffer = ByteData.sublistView(data);
    var offset = 0;

    // Header byte.
    final header = buffer.getUint8(offset++);
    final version = (header >> 4) & 0x0F;
    if (version > SmVersion.maxSupported) return null;
    final kind = header & 0x0F;
    if (kind != SmPacketKind.identity) return null;

    // Flags byte.
    final flags = buffer.getUint8(offset++);
    final hasTrait = (flags & 0x01) != 0;
    final hasEncounters = (flags & 0x02) != 0;
    final isResponse = (flags & 0x04) != 0;
    final isRequest = (flags & 0x08) != 0;

    // Contradictory flags: spec requires receivers to discard.
    if (isRequest && isResponse) return null;

    // Sigil hash.
    if (offset + 4 > data.length) return null;
    final sigilHash = buffer.getUint32(offset, Endian.big);
    offset += 4;

    // Trait.
    SmNodeTrait? trait;
    if (hasTrait) {
      if (offset >= data.length) return null;
      final traitIndex = buffer.getUint8(offset++);
      trait = traitIndex < SmNodeTrait.values.length
          ? SmNodeTrait.values[traitIndex]
          : SmNodeTrait.unknown;
    }

    // Encounter count.
    int? encounterCount;
    if (hasEncounters) {
      if (offset + 2 > data.length) return null;
      encounterCount = buffer.getUint16(offset, Endian.big);
      offset += 2;
    }

    return SmIdentity(
      sigilHash: sigilHash,
      trait: trait,
      encounterCount: encounterCount,
      isResponse: isResponse,
      isRequest: isRequest,
    );
  }

  @override
  String toString() =>
      'SmIdentity(hash=${sigilHash.toRadixString(16)}, '
      'trait=$trait, encounters=$encounterCount, '
      'isRequest=$isRequest, isResponse=$isResponse)';
}
