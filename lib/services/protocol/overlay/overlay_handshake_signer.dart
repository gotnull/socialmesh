// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Codec + signer/verifier for the P3 signed `LINK_OPEN` /
/// `LINK_OPEN_OK` payload body.
///
/// Wire layout (`docs/sip/OVERLAY_V0_2.md` §24.1.1):
///
/// ```
/// Offset  Size   Field
/// 0       1      schema_version     0x01
/// 1       1      flags              bit0 capabilityPresent; 1..7 reserved
/// 2       32     sender_ed25519_pub
/// 34      4      capability_bitset  u32 LE
/// 38      8      nonce              random
/// 46      64     signature          Ed25519 over bytes 0..45
/// ```
///
/// Total: 110 bytes. The signature covers bytes 0..45 only (not the
/// MRRP header, not the outer frame) — `linkId` is already bound
/// through the MRRP header on the receive path.
library;

import 'dart:math';
import 'dart:typed_data';

import '../../../core/logging.dart';

/// Signed-body schema version (byte 0).
const int overlayHandshakeSchemaVersion = 0x01;

/// Flag: `capability_bitset` carries meaningful data.
const int overlayHandshakeFlagCapabilityPresent = 0x01;

/// Parsed signed-body payload.
class OverlayHandshakeBody {
  /// Schema version byte. Must be 0x01 in P3.
  final int schemaVersion;

  /// Flags (see [overlayHandshakeFlagCapabilityPresent]).
  final int flags;

  /// 32-byte Ed25519 public key of the signer.
  final Uint8List senderPublicKey;

  /// u32 capability bitset.
  final int capabilityBitset;

  /// 8-byte nonce (signature replay guard).
  final Uint8List nonce;

  /// 64-byte Ed25519 signature.
  final Uint8List signature;

  const OverlayHandshakeBody({
    this.schemaVersion = overlayHandshakeSchemaVersion,
    required this.flags,
    required this.senderPublicKey,
    required this.capabilityBitset,
    required this.nonce,
    required this.signature,
  });

  /// True if the [overlayHandshakeFlagCapabilityPresent] bit is set.
  bool get capabilityPresent =>
      (flags & overlayHandshakeFlagCapabilityPresent) != 0;
}

/// Errors raised by [OverlayHandshakeCodec.decode].
enum OverlayHandshakeDecodeError {
  /// Empty or wrong-length payload.
  badLength,

  /// `schema_version` != 0x01.
  badSchema,

  /// Reserved flag bits are non-zero.
  badFlags,
}

/// Decode result.
class OverlayHandshakeDecodeResult {
  final OverlayHandshakeBody? body;
  final OverlayHandshakeDecodeError? error;
  final String? message;

  const OverlayHandshakeDecodeResult._(this.body, this.error, this.message);

  const OverlayHandshakeDecodeResult.ok(OverlayHandshakeBody body)
    : this._(body, null, null);

  const OverlayHandshakeDecodeResult.fail(
    OverlayHandshakeDecodeError error,
    String message,
  ) : this._(null, error, message);

  bool get isOk => body != null;
}

/// Encode / decode signed handshake bodies.
abstract final class OverlayHandshakeCodec {
  /// Fixed body length in bytes.
  static const int bodyLength = 110;

  /// Offset of the signed region (from start of body).
  static const int signedRegionStart = 0;

  /// Length of the signed region in bytes. Covers schema_version,
  /// flags, sender_ed25519_pub, capability_bitset, and nonce.
  static const int signedRegionLength = 46;

  /// Offset of the 64-byte signature.
  static const int signatureOffset = 46;

  /// Return the bytes that are/were signed, given a full body buffer
  /// (bytes 0..45).
  static Uint8List signedRegion(Uint8List body) {
    return Uint8List.fromList(body.sublist(0, signedRegionLength));
  }

  /// Build the byte range that a signer signs over — given the
  /// pre-signature components. Deterministic; tests use this to
  /// build golden vectors.
  static Uint8List buildSignedRegion({
    required int flags,
    required Uint8List senderPublicKey,
    required int capabilityBitset,
    required Uint8List nonce,
    int schemaVersion = overlayHandshakeSchemaVersion,
  }) {
    if (senderPublicKey.length != 32) {
      throw ArgumentError.value(
        senderPublicKey.length,
        'senderPublicKey.length',
        'must be 32 bytes (Ed25519)',
      );
    }
    if (nonce.length != 8) {
      throw ArgumentError.value(
        nonce.length,
        'nonce.length',
        'must be 8 bytes',
      );
    }
    final out = Uint8List(signedRegionLength);
    out[0] = schemaVersion;
    out[1] = flags;
    out.setRange(2, 34, senderPublicKey);
    final bd = ByteData.view(out.buffer);
    bd.setUint32(34, capabilityBitset, Endian.little);
    out.setRange(38, 46, nonce);
    return out;
  }

  /// Assemble the full 110-byte signed body from the signed region
  /// bytes and the attached signature.
  static Uint8List encode({
    required Uint8List signedRegion,
    required Uint8List signature,
  }) {
    if (signedRegion.length != signedRegionLength) {
      throw ArgumentError.value(
        signedRegion.length,
        'signedRegion.length',
        'must be $signedRegionLength',
      );
    }
    if (signature.length != 64) {
      throw ArgumentError.value(
        signature.length,
        'signature.length',
        'must be 64 bytes (Ed25519)',
      );
    }
    final out = Uint8List(bodyLength);
    out.setRange(0, signedRegionLength, signedRegion);
    out.setRange(signatureOffset, bodyLength, signature);
    return out;
  }

  /// Decode a 110-byte signed body into its fields. Returns a typed
  /// error on malformed input; the caller verifies the signature
  /// separately via [OverlayIdentityKeypair.verify].
  static OverlayHandshakeDecodeResult decode(Uint8List body) {
    if (body.length != bodyLength) {
      return OverlayHandshakeDecodeResult.fail(
        OverlayHandshakeDecodeError.badLength,
        'body length ${body.length} != $bodyLength',
      );
    }
    final schemaVersion = body[0];
    if (schemaVersion != overlayHandshakeSchemaVersion) {
      return OverlayHandshakeDecodeResult.fail(
        OverlayHandshakeDecodeError.badSchema,
        'schema_version=0x${schemaVersion.toRadixString(16)} != 0x'
        '${overlayHandshakeSchemaVersion.toRadixString(16)}',
      );
    }
    final flags = body[1];
    // Reserved bits must be zero.
    if ((flags & ~overlayHandshakeFlagCapabilityPresent) != 0) {
      return OverlayHandshakeDecodeResult.fail(
        OverlayHandshakeDecodeError.badFlags,
        'reserved flag bits set: 0x${flags.toRadixString(16)}',
      );
    }
    final senderPk = Uint8List.fromList(body.sublist(2, 34));
    final bd = ByteData.view(body.buffer, body.offsetInBytes, body.length);
    final capability = bd.getUint32(34, Endian.little);
    final nonce = Uint8List.fromList(body.sublist(38, 46));
    final signature = Uint8List.fromList(body.sublist(46, 110));
    return OverlayHandshakeDecodeResult.ok(
      OverlayHandshakeBody(
        schemaVersion: schemaVersion,
        flags: flags,
        senderPublicKey: senderPk,
        capabilityBitset: capability,
        nonce: nonce,
        signature: signature,
      ),
    );
  }

  /// Generate an 8-byte nonce suitable for the signed body. Uses
  /// [Random.secure] unless [randomSource] is supplied (tests).
  static Uint8List generateNonce({Random? randomSource}) {
    final r = randomSource ?? Random.secure();
    final out = Uint8List(8);
    for (var i = 0; i < 8; i++) {
      out[i] = r.nextInt(256);
    }
    return out;
  }

  /// Log a decode failure at the overlay scope.
  static void logDecodeFailure(OverlayHandshakeDecodeResult result) {
    AppLogging.overlay(
      'handshake decode failed: '
      '${result.error?.name} ${result.message}',
    );
  }
}
