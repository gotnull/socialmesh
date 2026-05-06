// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import '../../core/logging.dart';

/// STL (SocialMesh Trust Layer) envelope version.
abstract final class StlVersion {
  static const int v1 = 1;
  static const int current = v1;
}

/// STL flag bits in the flags byte.
abstract final class StlFlags {
  /// Payload is signed (Ed25519).
  static const int signed = 0x01;

  /// Payload is encrypted (ChaCha20-Poly1305).
  static const int encrypted = 0x02;
}

/// STL wire format overhead sizes.
abstract final class StlOverhead {
  /// Version field: 1 byte.
  static const int version = 1;

  /// Flags field: 1 byte.
  static const int flags = 1;

  /// Ed25519 public key: 32 bytes.
  static const int senderPubKey = 32;

  /// Nonce: 12 bytes (only present when encrypted).
  static const int nonce = 12;

  /// Ed25519 signature: 64 bytes (only present when signed).
  static const int signature = 64;

  /// Minimum overhead (signed only, no encryption):
  /// version(1) + flags(1) + pubkey(32) + signature(64) = 98 bytes.
  static const int signedOnly = version + flags + senderPubKey + signature;

  /// Full overhead (signed + encrypted):
  /// version(1) + flags(1) + pubkey(32) + nonce(12) + signature(64) = 110 bytes.
  /// Note: this is the *envelope* overhead only. Encryption also adds a
  /// 16-byte Poly1305 auth tag to the payload (see [poly1305Tag]).
  static const int signedAndEncrypted =
      version + flags + senderPubKey + nonce + signature;

  /// Poly1305 authentication tag appended to ciphertext by AEAD encryption.
  /// This is part of the payload field in the wire format, not a separate
  /// envelope field, but it reduces usable plaintext capacity.
  static const int poly1305Tag = 16;

  /// Total wire overhead for signed-only STL (bytes added beyond plaintext).
  static const int wireOverheadSignedOnly = signedOnly;

  /// Total wire overhead for signed+encrypted STL (bytes added beyond
  /// plaintext). Includes envelope fields (110) + Poly1305 tag (16) = 126.
  static const int wireOverheadEncrypted = signedAndEncrypted + poly1305Tag;

  /// Returns the total STL wire overhead for the given mode.
  ///
  /// This is the **single authoritative source** of STL overhead for all
  /// chunk-sizing and MTU calculations. Do not duplicate this math elsewhere.
  static int wireOverhead({bool encrypted = false}) =>
      encrypted ? wireOverheadEncrypted : wireOverheadSignedOnly;
}

/// Computes effective chunk payload size accounting for all wire overhead.
///
/// This is the **single authoritative API** for chunk-size decisions.
/// All callers that need to determine chunk payload size MUST use this
/// instead of inline arithmetic.
///
/// Returns the maximum plaintext bytes per chunk that will fit within
/// [mtu] after adding [sppHeaderOverhead] and STL overhead.
///
/// Throws [ArgumentError] if the overhead leaves no usable payload capacity.
int computeStlAwareChunkSize({
  required int mtu,
  required int sppHeaderOverhead,
  bool stlEnabled = false,
  bool stlEncrypted = false,
}) {
  final stlOverhead = stlEnabled
      ? StlOverhead.wireOverhead(encrypted: stlEncrypted)
      : 0;
  final effective = mtu - sppHeaderOverhead - stlOverhead;
  assert(
    effective > 0,
    'STL + SPP overhead ($sppHeaderOverhead + $stlOverhead) '
    'exceeds MTU ($mtu). No usable payload capacity.',
  );
  if (effective <= 0) {
    throw ArgumentError(
      'STL + SPP overhead ($sppHeaderOverhead + $stlOverhead) '
      'exceeds MTU ($mtu). No usable payload capacity.',
    );
  }
  return effective;
}

///
/// Wire format (signed only):
/// ```
/// [version:1][flags:1][senderPubKey:32][payload:N][signature:64]
/// ```
///
/// Wire format (signed + encrypted):
/// ```
/// [version:1][flags:1][senderPubKey:32][nonce:12][payload:N][signature:64]
/// ```
///
/// The signature covers: version + flags + senderPubKey + nonce (if present) + payload.
/// When encrypted, the payload bytes are the ciphertext (with Poly1305 tag appended by AEAD).
class StlEnvelope {
  /// Protocol version.
  final int version;

  /// Flags byte.
  final int flags;

  /// Sender's Ed25519 public key (32 bytes).
  final Uint8List senderPubKey;

  /// Nonce (12 bytes, only present when encrypted).
  final Uint8List? nonce;

  /// Payload bytes (cleartext or ciphertext depending on flags).
  final Uint8List payload;

  /// Ed25519 signature (64 bytes).
  final Uint8List signature;

  const StlEnvelope({
    required this.version,
    required this.flags,
    required this.senderPubKey,
    this.nonce,
    required this.payload,
    required this.signature,
  });

  /// Whether this envelope has the signed flag set.
  bool get isSigned => (flags & StlFlags.signed) != 0;

  /// Whether this envelope has the encrypted flag set.
  bool get isEncrypted => (flags & StlFlags.encrypted) != 0;

  /// Encode to wire format.
  Uint8List encode() {
    final hasNonce = isEncrypted && nonce != null;
    final totalSize =
        StlOverhead.version +
        StlOverhead.flags +
        StlOverhead.senderPubKey +
        (hasNonce ? StlOverhead.nonce : 0) +
        payload.length +
        StlOverhead.signature;

    final buffer = Uint8List(totalSize);
    var offset = 0;

    buffer[offset] = version;
    offset += 1;

    buffer[offset] = flags;
    offset += 1;

    buffer.setRange(offset, offset + 32, senderPubKey);
    offset += 32;

    if (hasNonce) {
      buffer.setRange(offset, offset + 12, nonce!);
      offset += 12;
    }

    buffer.setRange(offset, offset + payload.length, payload);
    offset += payload.length;

    buffer.setRange(offset, offset + 64, signature);

    return buffer;
  }

  /// Decode from wire format.
  ///
  /// Returns null if the data is too short or has an unsupported version.
  static StlEnvelope? decode(Uint8List data) {
    // Minimum: version(1) + flags(1) + pubkey(32) + signature(64) = 98
    if (data.length < StlOverhead.signedOnly) {
      AppLogging.spp('STL decode: data too short (${data.length} bytes)');
      return null;
    }

    final version = data[0];
    if (version > StlVersion.current) {
      AppLogging.spp('STL decode: unsupported version $version');
      return null;
    }

    final flags = data[1];
    final senderPubKey = Uint8List.fromList(data.sublist(2, 34));

    final isEncrypted = (flags & StlFlags.encrypted) != 0;
    var offset = 34;

    Uint8List? nonce;
    if (isEncrypted) {
      if (data.length < StlOverhead.signedAndEncrypted) {
        AppLogging.spp(
          'STL decode: encrypted but too short (${data.length} bytes)',
        );
        return null;
      }
      nonce = Uint8List.fromList(data.sublist(offset, offset + 12));
      offset += 12;
    }

    // Signature is always the last 64 bytes
    if (data.length < offset + 64) {
      AppLogging.spp('STL decode: no room for signature');
      return null;
    }

    final signatureStart = data.length - 64;
    final payload = Uint8List.fromList(data.sublist(offset, signatureStart));
    final signature = Uint8List.fromList(data.sublist(signatureStart));

    return StlEnvelope(
      version: version,
      flags: flags,
      senderPubKey: senderPubKey,
      nonce: nonce,
      payload: payload,
      signature: signature,
    );
  }

  /// Build the canonical bytes that are signed.
  ///
  /// The signed data is: version + flags + senderPubKey + nonce (if encrypted) + payload.
  /// This must match between sign and verify.
  Uint8List get signedBytes {
    final hasNonce = isEncrypted && nonce != null;
    final size =
        StlOverhead.version +
        StlOverhead.flags +
        StlOverhead.senderPubKey +
        (hasNonce ? StlOverhead.nonce : 0) +
        payload.length;

    final buffer = Uint8List(size);
    var offset = 0;

    buffer[offset] = version;
    offset += 1;

    buffer[offset] = flags;
    offset += 1;

    buffer.setRange(offset, offset + 32, senderPubKey);
    offset += 32;

    if (hasNonce) {
      buffer.setRange(offset, offset + 12, nonce!);
      offset += 12;
    }

    buffer.setRange(offset, offset + payload.length, payload);

    return buffer;
  }

  /// Compute the canonical bytes from components (for signing before
  /// the signature is known).
  static Uint8List computeSignedBytes({
    required int version,
    required int flags,
    required Uint8List senderPubKey,
    Uint8List? nonce,
    required Uint8List payload,
  }) {
    final isEnc = (flags & StlFlags.encrypted) != 0;
    final hasNonce = isEnc && nonce != null;
    final size =
        StlOverhead.version +
        StlOverhead.flags +
        StlOverhead.senderPubKey +
        (hasNonce ? StlOverhead.nonce : 0) +
        payload.length;

    final buffer = Uint8List(size);
    var offset = 0;

    buffer[offset] = version;
    offset += 1;

    buffer[offset] = flags;
    offset += 1;

    buffer.setRange(offset, offset + 32, senderPubKey);
    offset += 32;

    if (nonce != null && hasNonce) {
      buffer.setRange(offset, offset + 12, nonce);
      offset += 12;
    }

    buffer.setRange(offset, offset + payload.length, payload);

    return buffer;
  }

  /// Check if raw data looks like an STL envelope.
  ///
  /// Quick check: version byte is valid and minimum size met.
  static bool isStlPayload(Uint8List data) {
    if (data.length < StlOverhead.signedOnly) return false;
    final version = data[0];
    return version >= 1 && version <= StlVersion.current;
  }

  /// Stricter check that distinguishes STL envelopes from SPP packets.
  ///
  /// STL envelopes start with [0x01][flags] where flags has signed bit set.
  /// SPP packets start with [(version<<4)|kind] where version >= 1 gives
  /// byte values >= 0x10 — no collision with STL version 0x01.
  static bool isStlWrapped(Uint8List data) {
    if (data.length < StlOverhead.signedOnly) return false;
    final firstByte = data[0];
    if (firstByte != StlVersion.current) return false;
    final flagsByte = data[1];
    return (flagsByte & StlFlags.signed) != 0;
  }

  /// Synchronously strip the STL envelope and return the inner payload.
  ///
  /// **WARNING**: Does NOT verify the signature. Use
  /// [StlMiddleware.verifyAndUnwrap] for production inbound paths.
  ///
  /// Retained only for test-level inspection of envelope contents.
  /// The codebase audit test blocks production use of `stripEnvelope`.
  static Uint8List? stripEnvelopeForTestsOnly(Uint8List data) {
    if (!isStlWrapped(data)) return null;
    final envelope = decode(data);
    return envelope?.payload;
  }
}
