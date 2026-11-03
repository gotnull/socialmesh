// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SIP Ed25519 keypair management with persona_id and sigil derivation.
///
/// Generates and persistently stores an Ed25519 keypair in
/// [FlutterSecureStorage]. Derives [personaId] (first 16 bytes of
/// SHA-256 of the public key) and [sigilHash] (Murmur3 finalizer
/// over persona_id bytes) for use in SIP identity claims.
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/logging.dart';
import '../../../core/secure_storage_options.dart';
import '../../../features/nodedex/services/sigil_generator.dart';

/// Secure storage keys for the SIP Ed25519 keypair.
abstract final class _StorageKeys {
  static const String privateKey = 'sip_ed25519_private';
  static const String publicKey = 'sip_ed25519_public';
}

/// Manages a persistent Ed25519 keypair for SIP identity.
///
/// On first access, generates a new keypair and stores it in
/// [FlutterSecureStorage]. Subsequent calls load the existing keypair.
///
/// All derivations (persona_id, sigil_hash) are deterministic from the
/// public key. The private key never leaves secure storage except as
/// an opaque reference during signing operations.
class SipKeypair {
  /// Creates a [SipKeypair] with optional dependency injection.
  ///
  /// [storage] defaults to platform-appropriate secure storage.
  /// [algorithm] defaults to [Ed25519].
  SipKeypair({FlutterSecureStorage? storage, Ed25519? algorithm})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
            aOptions: kSecureStorageAndroidOptions,
          ),
      _algorithm = algorithm ?? Ed25519();

  final FlutterSecureStorage _storage;
  final Ed25519 _algorithm;

  /// Cached key pair (loaded once, kept in memory).
  SimpleKeyPair? _cachedKeyPair;

  /// Cached public key bytes (32 bytes).
  Uint8List? _cachedPublicKeyBytes;

  /// Cached persona_id (16 bytes).
  Uint8List? _cachedPersonaId;

  /// Cached sigil_hash (uint32).
  int? _cachedSigilHash;

  // ---------------------------------------------------------------------------
  // Keypair lifecycle
  // ---------------------------------------------------------------------------

  /// Ensure the keypair is loaded (or generated on first run).
  ///
  /// Call this during app initialization. Subsequent calls are no-ops.
  Future<void> ensureInitialized() async {
    if (_cachedKeyPair != null) return;

    final existingPrivate = await _storage.read(key: _StorageKeys.privateKey);
    final existingPublic = await _storage.read(key: _StorageKeys.publicKey);

    if (existingPrivate != null && existingPublic != null) {
      // Restore from secure storage.
      final privateBytes = _hexToBytes(existingPrivate);
      final publicBytes = _hexToBytes(existingPublic);

      _cachedPublicKeyBytes = publicBytes;
      _cachedKeyPair = SimpleKeyPairData(
        privateBytes,
        publicKey: SimplePublicKey(publicBytes, type: KeyPairType.ed25519),
        type: KeyPairType.ed25519,
      );

      AppLogging.sip(
        'SIP_KEYPAIR: loaded existing keypair, '
        'pubkey_hint=${_bytesToHex(publicBytes.sublist(0, 8))}',
      );
    } else {
      // Generate new keypair.
      final keyPair = await _algorithm.newKeyPair();
      final extracted = await keyPair.extract();
      final publicKey = await keyPair.extractPublicKey();
      final publicBytes = Uint8List.fromList(publicKey.bytes);
      final privateBytes = Uint8List.fromList(
        await extracted.extractPrivateKeyBytes(),
      );

      // Persist to secure storage.
      await _storage.write(
        key: _StorageKeys.privateKey,
        value: _bytesToHex(privateBytes),
      );
      await _storage.write(
        key: _StorageKeys.publicKey,
        value: _bytesToHex(publicBytes),
      );

      _cachedPublicKeyBytes = publicBytes;
      _cachedKeyPair = SimpleKeyPairData(
        privateBytes,
        publicKey: SimplePublicKey(publicBytes, type: KeyPairType.ed25519),
        type: KeyPairType.ed25519,
      );

      AppLogging.sip(
        'SIP_KEYPAIR: no existing keypair, generating Ed25519...\n'
        'SIP_KEYPAIR: keypair stored, '
        'pubkey_hint=${_bytesToHex(publicBytes.sublist(0, 8))}',
      );
    }

    // Derive persona_id and sigil_hash from public key.
    await _deriveIdentity();
  }

  /// Whether the keypair has been loaded/generated.
  bool get isInitialized => _cachedKeyPair != null;

  // ---------------------------------------------------------------------------
  // Public key
  // ---------------------------------------------------------------------------

  /// Returns the 32-byte Ed25519 public key.
  ///
  /// Throws [StateError] if not initialized.
  Uint8List getPublicKeyBytes() {
    if (_cachedPublicKeyBytes == null) {
      throw StateError('SipKeypair not initialized. Call ensureInitialized().');
    }
    return _cachedPublicKeyBytes!;
  }

  /// Returns the first 8 bytes of the public key as a hex hint string.
  String getPublicKeyHint() {
    final bytes = getPublicKeyBytes();
    return _bytesToHex(bytes.sublist(0, 8));
  }

  // ---------------------------------------------------------------------------
  // Signing and verification
  // ---------------------------------------------------------------------------

  /// Sign [data] with the local Ed25519 private key.
  ///
  /// Returns a 64-byte Ed25519 signature.
  Future<Uint8List> sign(Uint8List data) async {
    if (_cachedKeyPair == null) {
      throw StateError('SipKeypair not initialized. Call ensureInitialized().');
    }
    final signature = await _algorithm.sign(data, keyPair: _cachedKeyPair!);
    return Uint8List.fromList(signature.bytes);
  }

  /// Verify a signature against [data] using the given [pubkey].
  ///
  /// Returns true if the signature is valid.
  Future<bool> verify(
    Uint8List data,
    Uint8List signature,
    Uint8List pubkey,
  ) async {
    final sig = Signature(
      signature,
      publicKey: SimplePublicKey(pubkey, type: KeyPairType.ed25519),
    );
    return _algorithm.verify(data, signature: sig);
  }

  // ---------------------------------------------------------------------------
  // Identity derivation
  // ---------------------------------------------------------------------------

  /// Returns the 16-byte persona_id (first 16 bytes of SHA-256 of pubkey).
  Uint8List getPersonaId() {
    if (_cachedPersonaId == null) {
      throw StateError('SipKeypair not initialized. Call ensureInitialized().');
    }
    return _cachedPersonaId!;
  }

  /// Returns the uint32 sigil hash (Murmur3 finalizer over persona_id).
  int getSigilHash() {
    if (_cachedSigilHash == null) {
      throw StateError('SipKeypair not initialized. Call ensureInitialized().');
    }
    return _cachedSigilHash!;
  }

  /// Compute persona_id for an arbitrary public key (static utility).
  ///
  /// Returns the first 16 bytes of SHA-256(pubkeyBytes).
  static Future<Uint8List> computePersonaId(Uint8List pubkeyBytes) async {
    final sha256 = Sha256();
    final hash = await sha256.hash(pubkeyBytes);
    return Uint8List.fromList(hash.bytes.sublist(0, 16));
  }

  /// Compute sigil hash for an arbitrary persona_id (static utility).
  ///
  /// Uses the same Murmur3 finalizer as [SigilGenerator.mix].
  static int computeSigilHash(Uint8List personaId) {
    // Convert first 4 bytes of persona_id to a 32-bit seed.
    int seed = 0;
    for (var i = 0; i < 4 && i < personaId.length; i++) {
      seed |= personaId[i] << (8 * i);
    }
    return SigilGenerator.mix(seed);
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Delete the keypair from secure storage (destructive).
  Future<void> deleteKeypair() async {
    await _storage.delete(key: _StorageKeys.privateKey);
    await _storage.delete(key: _StorageKeys.publicKey);
    _cachedKeyPair = null;
    _cachedPublicKeyBytes = null;
    _cachedPersonaId = null;
    _cachedSigilHash = null;
    AppLogging.sip('SIP_KEYPAIR: keypair deleted from secure storage');
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  Future<void> _deriveIdentity() async {
    final pubkey = _cachedPublicKeyBytes!;
    _cachedPersonaId = await computePersonaId(pubkey);
    _cachedSigilHash = computeSigilHash(_cachedPersonaId!);

    AppLogging.sip(
      'SIP_KEYPAIR: persona_id=${_bytesToHex(_cachedPersonaId!)}\n'
      'SIP_KEYPAIR: sigil_hash=0x${_cachedSigilHash!.toRadixString(16).padLeft(8, '0').toUpperCase()}',
    );
  }

  /// Convert bytes to lowercase hex string.
  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Convert hex string to bytes.
  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}
