// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/logging.dart';

/// Thrown when the database encryption key cannot be read or written because
/// the platform keystore is unavailable (e.g. the device is locked before the
/// first post-boot unlock). Callers should defer the database open and retry —
/// they must NOT fall back to generating a fresh key, which would orphan the
/// existing encrypted databases.
class DatabaseKeyUnavailableException implements Exception {
  final String code;
  final String? message;

  const DatabaseKeyUnavailableException(this.code, this.message);

  @override
  String toString() =>
      'DatabaseKeyUnavailableException($code: ${message ?? 'unknown'})';
}

/// Owns the single 256-bit passphrase used to encrypt the sensitive SQLite
/// databases (messages, signals, routes, waypoints, peer_safety, nodedex).
///
/// The key is generated once with a cryptographically secure RNG and stored in
/// the platform keystore via [FlutterSecureStorage] — iOS Keychain / Android
/// Keystore-backed encrypted shared preferences. iOS accessibility is
/// [KeychainAccessibility.first_unlock] (NOT `whenUnlocked`) so background
/// writes (the foreground BLE service / notification handlers persisting an
/// inbound DM) can still read the key while the screen is locked.
///
/// The key is memoised after the first successful read so repeated database
/// opens do not round-trip to the keystore.
class DatabaseKeyService {
  static const _storageKey = 'db_master_key_v1';
  static const _keyLengthBytes = 32; // 256-bit

  final FlutterSecureStorage _storage;

  Future<String>? _pending;

  DatabaseKeyService({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  /// Process-wide default instance used by [openEncryptedDatabase].
  static final DatabaseKeyService instance = DatabaseKeyService();

  /// Returns the database passphrase, generating and persisting one on first
  /// use. Concurrent callers share a single in-flight load so the key is never
  /// generated twice.
  ///
  /// Throws [DatabaseKeyUnavailableException] when the keystore is locked. The
  /// in-flight future is cleared on failure so a later call can retry.
  Future<String> getOrCreateKey() {
    return _pending ??= _load();
  }

  Future<String> _load() async {
    try {
      final existing = await _storage.read(key: _storageKey);
      if (existing != null && existing.isNotEmpty) {
        AppLogging.storage('DatabaseKeyService: loaded existing key');
        return existing;
      }
    } on PlatformException catch (e) {
      // Keystore locked (iOS -25308). Do NOT generate — an encrypted database
      // keyed with the real passphrase may already exist on disk; clobbering
      // the key would make it permanently unreadable. Surface and let the
      // caller retry after the next unlock.
      _pending = null;
      AppLogging.storage(
        'DatabaseKeyService: read failed (${e.code}: ${e.message})',
      );
      throw DatabaseKeyUnavailableException(e.code, e.message);
    }

    // Genuinely absent (read succeeded, returned null): generate and persist.
    final generated = _generateKey();
    try {
      await _storage.write(key: _storageKey, value: generated);
      AppLogging.storage('DatabaseKeyService: generated and stored new key');
    } on PlatformException catch (e) {
      _pending = null;
      AppLogging.storage(
        'DatabaseKeyService: write failed (${e.code}: ${e.message})',
      );
      throw DatabaseKeyUnavailableException(e.code, e.message);
    }
    return generated;
  }

  static String _generateKey() {
    final rng = Random.secure();
    final bytes = Uint8List(_keyLengthBytes);
    for (var i = 0; i < _keyLengthBytes; i++) {
      bytes[i] = rng.nextInt(256);
    }
    return base64Encode(bytes);
  }

  /// Visible-for-testing: the keystore entry name.
  static String get storageKey => _storageKey;
}
