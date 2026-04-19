// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../core/logging.dart';
import 'stl_envelope.dart';

/// Ed25519 signing service for the Socialmesh Trust Layer (STL).
///
/// Uses the existing SIP keypair infrastructure for Ed25519 operations.
/// This service is stateless — it accepts key material as parameters
/// and does not manage keypair storage.
class StlSigningService {
  final Ed25519 _algorithm;

  StlSigningService({Ed25519? algorithm}) : _algorithm = algorithm ?? Ed25519();

  /// Sign a payload and wrap it in an STL envelope.
  ///
  /// [payload] is the raw payload bytes (cleartext or ciphertext).
  /// [privateKey] is the sender's Ed25519 private key pair.
  /// [senderPubKey] is the sender's 32-byte Ed25519 public key.
  /// [nonce] is required when [encrypted] is true.
  ///
  /// Returns a complete [StlEnvelope] with a valid signature.
  Future<StlEnvelope> signPayload({
    required Uint8List payload,
    required SimpleKeyPair privateKey,
    required Uint8List senderPubKey,
    Uint8List? nonce,
    bool encrypted = false,
  }) async {
    final flags = StlFlags.signed | (encrypted ? StlFlags.encrypted : 0);

    final signedBytes = StlEnvelope.computeSignedBytes(
      version: StlVersion.current,
      flags: flags,
      senderPubKey: senderPubKey,
      nonce: encrypted ? nonce : null,
      payload: payload,
    );

    final signature = await _algorithm.sign(signedBytes, keyPair: privateKey);
    final sigBytes = Uint8List.fromList(signature.bytes);

    AppLogging.spp(
      'STL: signed payload (${payload.length} bytes, '
      'encrypted=$encrypted)',
    );

    return StlEnvelope(
      version: StlVersion.current,
      flags: flags,
      senderPubKey: senderPubKey,
      nonce: encrypted ? nonce : null,
      payload: payload,
      signature: sigBytes,
    );
  }

  /// Verify the signature on an STL envelope.
  ///
  /// Returns true if the Ed25519 signature is valid for the
  /// canonical signed bytes derived from the envelope.
  Future<bool> verifyEnvelope(StlEnvelope envelope) async {
    if (!envelope.isSigned) {
      AppLogging.spp('STL: envelope not signed, verification skipped');
      return false;
    }

    final signedBytes = envelope.signedBytes;

    final sig = Signature(
      envelope.signature,
      publicKey: SimplePublicKey(
        envelope.senderPubKey,
        type: KeyPairType.ed25519,
      ),
    );

    try {
      final valid = await _algorithm.verify(signedBytes, signature: sig);

      if (valid) {
        AppLogging.spp(
          'STL: signature verified '
          '(pubkey=${_hexHint(envelope.senderPubKey)})',
        );
      } else {
        AppLogging.spp(
          'STL: signature INVALID '
          '(pubkey=${_hexHint(envelope.senderPubKey)})',
        );
      }

      return valid;
    } catch (e) {
      AppLogging.spp('STL: signature verification error: $e');
      return false;
    }
  }

  /// First 8 hex chars of a public key for logging (no private data).
  static String _hexHint(Uint8List key) {
    if (key.length < 4) return '???';
    return key
        .sublist(0, 4)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }
}
