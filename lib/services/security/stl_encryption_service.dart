// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../../core/logging.dart';

/// X25519 + ChaCha20-Poly1305 encryption service for the STL.
///
/// Provides optional end-to-end encryption of payload data using
/// X25519 key agreement and ChaCha20-Poly1305 AEAD.
///
/// Key exchange:
/// 1. Sender has an X25519 keypair (derived from Ed25519 or separate)
/// 2. Receiver's X25519 public key is known (from SIP handshake or NodeDex)
/// 3. Shared secret = X25519(senderPrivate, receiverPublic)
/// 4. Session key = HKDF-SHA256(sharedSecret, nonce, "stl-v1")
/// 5. Encrypt: ChaCha20-Poly1305(sessionKey, nonce, payload)
class StlEncryptionService {
  final X25519 _keyExchange;

  StlEncryptionService({X25519? keyExchange})
    : _keyExchange = keyExchange ?? X25519();

  /// Encrypt payload using X25519 key agreement + ChaCha20-Poly1305.
  ///
  /// [payload] is the raw cleartext bytes.
  /// [senderKeyPair] is the sender's X25519 keypair.
  /// [receiverPubKey] is the receiver's X25519 public key (32 bytes).
  /// [nonce] is a 12-byte random nonce (must be unique per message).
  ///
  /// Returns the ciphertext (payload + 16-byte Poly1305 tag).
  Future<Uint8List> encrypt({
    required Uint8List payload,
    required SimpleKeyPair senderKeyPair,
    required Uint8List receiverPubKey,
    required Uint8List nonce,
  }) async {
    // X25519 key agreement
    final sharedSecret = await _keyExchange.sharedSecretKey(
      keyPair: senderKeyPair,
      remotePublicKey: SimplePublicKey(
        receiverPubKey,
        type: KeyPairType.x25519,
      ),
    );

    // Derive session key via HKDF
    final sessionKey = await _deriveSessionKey(sharedSecret, nonce);

    // Encrypt with ChaCha20-Poly1305
    final algorithm = Chacha20.poly1305Aead();
    final secretBox = await algorithm.encrypt(
      payload,
      secretKey: sessionKey,
      nonce: nonce,
    );

    // Concatenate ciphertext + MAC (Poly1305 tag)
    final result = Uint8List(
      secretBox.cipherText.length + secretBox.mac.bytes.length,
    );
    result.setRange(0, secretBox.cipherText.length, secretBox.cipherText);
    result.setRange(
      secretBox.cipherText.length,
      result.length,
      secretBox.mac.bytes,
    );

    AppLogging.spp(
      'STL: encrypted ${payload.length} bytes -> ${result.length} bytes',
    );

    return result;
  }

  /// Decrypt ciphertext using X25519 key agreement + ChaCha20-Poly1305.
  ///
  /// [ciphertext] includes the 16-byte Poly1305 tag at the end.
  /// [receiverKeyPair] is the receiver's X25519 keypair.
  /// [senderPubKey] is the sender's X25519 public key (32 bytes).
  /// [nonce] is the 12-byte nonce from the STL envelope.
  ///
  /// Returns the decrypted payload, or null if decryption fails.
  Future<Uint8List?> decrypt({
    required Uint8List ciphertext,
    required SimpleKeyPair receiverKeyPair,
    required Uint8List senderPubKey,
    required Uint8List nonce,
  }) async {
    if (ciphertext.length < 16) {
      AppLogging.spp('STL: ciphertext too short for MAC tag');
      return null;
    }

    // X25519 key agreement (reverse direction)
    final sharedSecret = await _keyExchange.sharedSecretKey(
      keyPair: receiverKeyPair,
      remotePublicKey: SimplePublicKey(senderPubKey, type: KeyPairType.x25519),
    );

    // Derive session key via HKDF
    final sessionKey = await _deriveSessionKey(sharedSecret, nonce);

    // Split ciphertext and MAC
    final macStart = ciphertext.length - 16;
    final ct = ciphertext.sublist(0, macStart);
    final mac = Mac(ciphertext.sublist(macStart));

    // Decrypt with ChaCha20-Poly1305
    final algorithm = Chacha20.poly1305Aead();
    try {
      final cleartext = await algorithm.decrypt(
        SecretBox(ct, nonce: nonce, mac: mac),
        secretKey: sessionKey,
      );

      AppLogging.spp(
        'STL: decrypted ${ciphertext.length} bytes -> '
        '${cleartext.length} bytes',
      );

      return Uint8List.fromList(cleartext);
    } catch (e) {
      AppLogging.spp('STL: decryption failed: $e');
      return null;
    }
  }

  /// Derive a session key from shared secret + nonce using HKDF-SHA256.
  Future<SecretKey> _deriveSessionKey(
    SecretKey sharedSecret,
    Uint8List nonce,
  ) async {
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

    // info = "stl-v1" as bytes (protocol binding)
    // lint-allow: hardcoded-string
    const info = [0x73, 0x74, 0x6c, 0x2d, 0x76, 0x31]; // "stl-v1"

    return hkdf.deriveKey(secretKey: sharedSecret, nonce: nonce, info: info);
  }
}
