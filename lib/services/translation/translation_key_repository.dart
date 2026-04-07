// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/logging.dart';

/// Secure local-only store for BYO translation provider API keys.
///
/// Keys are stored exclusively on-device via [FlutterSecureStorage].
/// They are never sent to Socialmesh servers, logged, or included in
/// crash reports.
class TranslationKeyRepository {
  static const String _keyPrefix = 'translation_byo_key';

  final FlutterSecureStorage _storage;

  TranslationKeyRepository({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  /// Store a BYO API key securely.
  Future<void> storeKey(String apiKey) async {
    try {
      await _storage.write(key: _keyPrefix, value: apiKey);
      AppLogging.app('TranslationKeyRepository: key stored');
    } catch (e) {
      AppLogging.app('TranslationKeyRepository: failed to store key');
      rethrow;
    }
  }

  /// Read the stored BYO API key (null if not set).
  Future<String?> readKey() async {
    try {
      return await _storage.read(key: _keyPrefix);
    } catch (e) {
      AppLogging.app('TranslationKeyRepository: failed to read key');
      return null;
    }
  }

  /// Delete the stored BYO API key.
  Future<void> deleteKey() async {
    try {
      await _storage.delete(key: _keyPrefix);
      AppLogging.app('TranslationKeyRepository: key deleted');
    } catch (e) {
      AppLogging.app('TranslationKeyRepository: failed to delete key');
    }
  }

  /// Check if a BYO key is stored.
  Future<bool> hasKey() async {
    final key = await readKey();
    return key != null && key.isNotEmpty;
  }

  /// Returns a masked version for display (e.g. "AIza...xY9z").
  Future<String?> maskedKey() async {
    final key = await readKey();
    if (key == null || key.length < 8) return null;
    return '${key.substring(0, 4)}...${key.substring(key.length - 4)}';
  }
}
