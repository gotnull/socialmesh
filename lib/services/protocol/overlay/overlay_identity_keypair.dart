// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Persistent Ed25519 identity for the SocialMesh Overlay v0.2 stack.
///
/// A **separate** keypair from `SipKeypair` — per the P3 locked
/// principle that user identity, transport identity, and overlay
/// endpoint identity must not be commingled. The private key lives in
/// [FlutterSecureStorage] and never touches SQLite. Storage keys are
/// prefixed `overlay_ed25519_*` to avoid any collision with the SIP
/// keypair (`sip_ed25519_*`).
///
/// One stable key per install; rotation is explicitly out of scope for
/// v0.2 per the P3 conservative key-lifecycle rule. A fresh generation
/// happens only on first access (when secure storage is empty), and
/// the resulting public bytes are the sole authoritative identity for
/// this device in the overlay layer.
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/logging.dart';

/// Storage keys for the overlay Ed25519 keypair. Intentionally
/// separate namespace from `SipKeypair`.
abstract final class _OverlayStorageKeys {
  static const String privateKey = 'overlay_ed25519_private';
  static const String publicKey = 'overlay_ed25519_public';
}

/// Manages a persistent Ed25519 keypair for overlay identity.
///
/// Thread safety: [ensureInitialized] is idempotent and safe to call
/// concurrently; the first call wins and subsequent callers wait on
/// the same in-flight Future.
class OverlayIdentityKeypair {
  /// Construct with optional DI overrides. Tests supply an in-memory
  /// [storage] to avoid touching platform keychains.
  OverlayIdentityKeypair({FlutterSecureStorage? storage, Ed25519? algorithm})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          ),
      _algorithm = algorithm ?? Ed25519();

  final FlutterSecureStorage _storage;
  final Ed25519 _algorithm;

  SimpleKeyPair? _cachedKeyPair;
  Uint8List? _cachedPublicKey;
  Future<void>? _inFlight;

  /// Ensure the keypair is loaded (or generated on first run). Safe
  /// to call many times; concurrent callers share the same in-flight
  /// init.
  Future<void> ensureInitialized() {
    if (_cachedKeyPair != null) return Future<void>.value();
    return _inFlight ??= _loadOrGenerate();
  }

  Future<void> _loadOrGenerate() async {
    try {
      final priv = await _storage.read(key: _OverlayStorageKeys.privateKey);
      final pub = await _storage.read(key: _OverlayStorageKeys.publicKey);

      if (priv != null && pub != null) {
        final privBytes = _hexToBytes(priv);
        final pubBytes = _hexToBytes(pub);
        _cachedPublicKey = pubBytes;
        _cachedKeyPair = SimpleKeyPairData(
          privBytes,
          publicKey: SimplePublicKey(pubBytes, type: KeyPairType.ed25519),
          type: KeyPairType.ed25519,
        );
        AppLogging.overlay(
          'identity loaded hint=${_hex(pubBytes.sublist(0, 8))}',
        );
        return;
      }

      final keyPair = await _algorithm.newKeyPair();
      final extracted = await keyPair.extract();
      final publicKey = await keyPair.extractPublicKey();
      final pubBytes = Uint8List.fromList(publicKey.bytes);
      final privBytes = Uint8List.fromList(
        await extracted.extractPrivateKeyBytes(),
      );

      await _storage.write(
        key: _OverlayStorageKeys.privateKey,
        value: _hex(privBytes),
      );
      await _storage.write(
        key: _OverlayStorageKeys.publicKey,
        value: _hex(pubBytes),
      );

      _cachedPublicKey = pubBytes;
      _cachedKeyPair = SimpleKeyPairData(
        privBytes,
        publicKey: SimplePublicKey(pubBytes, type: KeyPairType.ed25519),
        type: KeyPairType.ed25519,
      );
      AppLogging.overlay(
        'identity generated hint=${_hex(pubBytes.sublist(0, 8))}',
      );
    } finally {
      _inFlight = null;
    }
  }

  /// True once [ensureInitialized] has completed successfully.
  bool get isInitialized => _cachedKeyPair != null;

  /// 32-byte Ed25519 public key. Throws if not initialised.
  Uint8List publicKey() {
    final pk = _cachedPublicKey;
    if (pk == null) {
      throw StateError(
        'OverlayIdentityKeypair not initialized — call ensureInitialized()',
      );
    }
    return pk;
  }

  /// First 8 bytes of the public key, matching the persona-hint shape
  /// used elsewhere in SocialMesh.
  Uint8List publicKeyHint() => Uint8List.fromList(publicKey().sublist(0, 8));

  /// Sign [data] with the local private key. Returns a 64-byte
  /// Ed25519 signature.
  Future<Uint8List> sign(Uint8List data) async {
    final kp = _cachedKeyPair;
    if (kp == null) {
      throw StateError(
        'OverlayIdentityKeypair not initialized — call ensureInitialized()',
      );
    }
    final sig = await _algorithm.sign(data, keyPair: kp);
    return Uint8List.fromList(sig.bytes);
  }

  /// Verify that [signature] is a valid Ed25519 signature over [data]
  /// by [publicKey]. Returns false (never throws) on any failure.
  Future<bool> verify(
    Uint8List data,
    Uint8List signature,
    Uint8List publicKey,
  ) async {
    try {
      if (signature.length != 64) return false;
      if (publicKey.length != 32) return false;
      final sig = Signature(
        signature,
        publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
      );
      return await _algorithm.verify(data, signature: sig);
    } catch (e) {
      AppLogging.overlay('verify error: $e');
      return false;
    }
  }

  /// DANGEROUS: wipe the persisted keypair. Test-only helper; never
  /// call in production code paths.
  Future<void> debugWipeForTest() async {
    await _storage.delete(key: _OverlayStorageKeys.privateKey);
    await _storage.delete(key: _OverlayStorageKeys.publicKey);
    _cachedKeyPair = null;
    _cachedPublicKey = null;
  }

  static String _hex(Uint8List bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      sb.write(b.toRadixString(16).padLeft(2, '0'));
    }
    return sb.toString();
  }

  static Uint8List _hexToBytes(String hex) {
    if (hex.length.isOdd) {
      throw FormatException('odd hex string length ${hex.length}');
    }
    final out = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }
}
