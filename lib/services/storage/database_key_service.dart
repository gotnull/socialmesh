// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/logging.dart';

/// Thrown when the database encryption key cannot be read or written because
/// the platform keystore is unavailable (e.g. the device is locked before the
/// first post-boot unlock).
///
/// [DatabaseKeyService.getOrCreateKey] has already exhausted its retry ladder
/// by the time this surfaces, and it clears the memoised load, so the next
/// open attempt reads the keystore again rather than reusing the failure.
/// What a caller must never do is fall back to generating a fresh key: that
/// orphans the existing encrypted databases for good.
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

  /// Backoff between keystore attempts, one entry per retry. The failure this
  /// recovers from is a cold start racing a keystore that is a moment from
  /// ready, so the whole ladder is under a second; a device that is genuinely
  /// locked before its first unlock is not waited out here, it is reported.
  static const _defaultRetryBackoff = <Duration>[
    Duration(milliseconds: 200),
    Duration(milliseconds: 600),
  ];

  final FlutterSecureStorage _storage;
  final List<Duration> _retryBackoff;

  Future<String>? _pending;
  bool _keyGeneratedThisLaunch = false;

  DatabaseKeyService({
    FlutterSecureStorage? storage,
    List<Duration>? retryBackoff,
  }) : _storage =
           storage ??
           const FlutterSecureStorage(
             aOptions: AndroidOptions(encryptedSharedPreferences: true),
             iOptions: IOSOptions(
               accessibility: KeychainAccessibility.first_unlock,
             ),
           ),
       _retryBackoff = retryBackoff ?? _defaultRetryBackoff;

  /// Whether the key handed out this launch was freshly generated rather than
  /// read back from the keystore. A fresh key against a database file that
  /// already exists is the signature of an orphaned file, so the database
  /// open path reports this alongside a failure.
  bool get keyGeneratedThisLaunch => _keyGeneratedThisLaunch;

  /// Process-wide default instance used by [openEncryptedDatabase].
  static final DatabaseKeyService instance = DatabaseKeyService();

  /// Returns the database passphrase, generating and persisting one on first
  /// use. Concurrent callers share a single in-flight load so the key is never
  /// generated twice.
  ///
  /// A locked keystore is retried on the backoff ladder before it is given up
  /// on. Throws [DatabaseKeyUnavailableException] once the ladder is spent.
  /// The in-flight future is cleared on failure so a later call can retry.
  Future<String> getOrCreateKey() {
    return _pending ??= _loadWithRetry();
  }

  Future<String> _loadWithRetry() async {
    final attempts = _retryBackoff.length + 1;
    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        return await _load();
      } on DatabaseKeyUnavailableException catch (e) {
        AppLogging.storage(
          'DatabaseKeyService: keystore unavailable on attempt '
          '$attempt of $attempts ($e)',
        );
        if (attempt == attempts) {
          _pending = null;
          rethrow;
        }
        await Future<void>.delayed(_retryBackoff[attempt - 1]);
      }
    }
    // Unreachable: the loop either returns a key or rethrows on its last pass.
    throw StateError('key retry loop fell through');
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
      // the key would make it permanently unreadable. Surface it; the retry
      // ladder above owns whether to try again, and owns clearing the memo so
      // concurrent callers keep sharing this one in-flight load.
      AppLogging.storage(
        'DatabaseKeyService: read failed (${e.code}: ${e.message})',
      );
      throw DatabaseKeyUnavailableException(e.code, e.message);
    }

    // Genuinely absent (read succeeded, returned null): generate and persist.
    final generated = _generateKey();
    try {
      await _storage.write(key: _storageKey, value: generated);
      _keyGeneratedThisLaunch = true;
      AppLogging.storage('DatabaseKeyService: generated and stored new key');
    } on PlatformException catch (e) {
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
