// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import '../../core/logging.dart';
import 'stl_envelope.dart';
import 'stl_signing_service.dart';

/// Result of unwrapping an inbound STL envelope.
class StlUnwrapResult {
  /// The inner payload bytes (original SPP packet).
  final Uint8List payload;

  /// Whether the payload was STL-wrapped.
  final bool wasWrapped;

  /// Whether the STL signature was valid (null if not wrapped).
  final bool? signatureValid;

  /// Sender's Ed25519 public key (null if not wrapped).
  final Uint8List? senderPubKey;

  const StlUnwrapResult({
    required this.payload,
    required this.wasWrapped,
    this.signatureValid,
    this.senderPubKey,
  });
}

/// A verified STL payload that has passed signature verification.
///
/// This type exists so downstream handlers can only accept payloads
/// that have been cryptographically verified — it cannot be constructed
/// outside this library, preventing callers from forging verified status.
class VerifiedStlPayload {
  /// The inner payload bytes (after STL envelope was stripped and verified).
  final Uint8List payload;

  /// Sender's Ed25519 public key (32 bytes).
  final Uint8List senderPubKey;

  /// Private constructor — only [StlMiddleware.verifyAndUnwrap] can create.
  const VerifiedStlPayload._({
    required this.payload,
    required this.senderPubKey,
  });
}

/// Callback type for signing data with Ed25519.
typedef StlSignFunction = Future<Uint8List> Function(Uint8List data);

/// Middleware for applying and removing STL envelopes on the file transfer
/// pipeline.
///
/// Outbound: wraps encoded SPP packets with Ed25519 signature.
/// Inbound: detects STL envelopes, verifies signature, extracts inner payload.
///
/// This service is stateless — it delegates to [StlSigningService] for
/// verification and accepts a signing callback for outbound operations.
class StlMiddleware {
  final StlSigningService _signingService;

  StlMiddleware({StlSigningService? signingService})
    : _signingService = signingService ?? StlSigningService();

  /// Wrap an outbound SPP packet with an STL signed envelope.
  ///
  /// [payload] is the encoded SPP packet (offer, chunk, nack, etc.).
  /// [signFn] is a callback that signs data with the sender's Ed25519 key
  ///   (e.g. [SipKeypair.sign]).
  /// [senderPubKey] is the sender's 32-byte Ed25519 public key.
  ///
  /// Returns the STL envelope wire bytes (payload + 98 bytes overhead).
  Future<Uint8List> wrapOutbound({
    required Uint8List payload,
    required StlSignFunction signFn,
    required Uint8List senderPubKey,
  }) async {
    final flags = StlFlags.signed;
    final signedBytes = StlEnvelope.computeSignedBytes(
      version: StlVersion.current,
      flags: flags,
      senderPubKey: senderPubKey,
      payload: payload,
    );

    final signature = await signFn(signedBytes);

    final envelope = StlEnvelope(
      version: StlVersion.current,
      flags: flags,
      senderPubKey: senderPubKey,
      payload: payload,
      signature: signature,
    );

    final encoded = envelope.encode();

    AppLogging.stl(
      'wrapped outbound: ${payload.length} bytes -> '
      '${encoded.length} bytes (+${StlOverhead.signedOnly} overhead)',
    );

    return encoded;
  }

  /// Detect and unwrap an inbound STL envelope.
  ///
  /// If the payload is not STL-wrapped, returns it unchanged with
  /// [StlUnwrapResult.wasWrapped] = false.
  ///
  /// If STL-wrapped, verifies the signature and returns the inner payload.
  /// The caller should check [StlUnwrapResult.signatureValid] and decide
  /// how to handle invalid signatures (log, drop, or proceed with warning).
  Future<StlUnwrapResult> unwrapInbound(Uint8List data) async {
    if (!_isStlWrapped(data)) {
      return StlUnwrapResult(payload: data, wasWrapped: false);
    }

    final envelope = StlEnvelope.decode(data);
    if (envelope == null) {
      AppLogging.stl(
        'STL envelope decode failed, passing raw data through '
        '(${data.length} bytes)',
      );
      return StlUnwrapResult(payload: data, wasWrapped: false);
    }

    final valid = await _signingService.verifyEnvelope(envelope);

    AppLogging.stl(
      'unwrapped inbound: ${data.length} bytes -> '
      '${envelope.payload.length} bytes, '
      'signature=${valid ? "VALID" : "INVALID"}, '
      'pubkey=${_hexHint(envelope.senderPubKey)}',
    );

    return StlUnwrapResult(
      payload: envelope.payload,
      wasWrapped: true,
      signatureValid: valid,
      senderPubKey: envelope.senderPubKey,
    );
  }

  /// Verify and unwrap an inbound STL envelope (fail-closed).
  ///
  /// Returns a [VerifiedStlPayload] if the envelope is valid and the
  /// signature verifies. Returns `null` if:
  /// - the data is not STL-wrapped
  /// - the envelope cannot be decoded
  /// - the Ed25519 signature is invalid
  ///
  /// This is the **only** production API for inbound STL processing.
  /// Unlike [unwrapInbound], it never returns unverified payload bytes.
  Future<VerifiedStlPayload?> verifyAndUnwrap(Uint8List data) async {
    if (!_isStlWrapped(data)) return null;

    final envelope = StlEnvelope.decode(data);
    if (envelope == null) {
      AppLogging.stl(
        'verifyAndUnwrap: envelope decode failed (${data.length} bytes)',
      );
      return null;
    }

    final valid = await _signingService.verifyEnvelope(envelope);
    if (!valid) {
      AppLogging.stl(
        'verifyAndUnwrap: signature INVALID '
        '(pubkey=${_hexHint(envelope.senderPubKey)})',
      );
      return null;
    }

    AppLogging.stl(
      'verifyAndUnwrap: verified ${data.length} -> '
      '${envelope.payload.length} bytes '
      '(pubkey=${_hexHint(envelope.senderPubKey)})',
    );

    return VerifiedStlPayload._(
      payload: envelope.payload,
      senderPubKey: envelope.senderPubKey,
    );
  }

  /// Detect if raw data is an STL envelope vs a regular SPP packet.
  ///
  /// STL envelopes start with version byte 0x01 and are >= 98 bytes.
  /// SPP packets start with header byte (version << 4 | kind), where
  /// version >= 1 produces header >= 0x10, so there's no ambiguity
  /// with STL version byte 0x01.
  bool _isStlWrapped(Uint8List data) {
    if (data.length < StlOverhead.signedOnly) return false;
    // STL version byte is 0x01. SPP header byte for v1 is 0x1X (kind=4..10).
    // So byte[0] == 0x01 means STL, byte[0] >= 0x10 means SPP.
    final firstByte = data[0];
    if (firstByte != StlVersion.current) return false;
    // Extra check: STL flags byte should have at least signed bit set.
    final flagsByte = data[1];
    return (flagsByte & StlFlags.signed) != 0;
  }

  /// First 8 hex chars of a key for logging.
  static String _hexHint(Uint8List key) {
    if (key.length < 4) return '???';
    return key
        .sublist(0, 4)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
