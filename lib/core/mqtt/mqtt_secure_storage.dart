// SPDX-License-Identifier: GPL-3.0-or-later

/// Secure storage wrapper for Global Layer (MQTT) broker credentials.
///
/// This module isolates all secure storage operations for the Global
/// Layer feature. Broker passwords and other sensitive credentials
/// are stored via [FlutterSecureStorage] and never written to
/// shared preferences or included in JSON serialization.
///
/// The wrapper provides:
/// - Encrypted storage of broker passwords
/// - Atomic save/load of the full [GlobalLayerConfig] (config in
///   shared prefs, password in secure storage)
/// - Safe deletion of all Global Layer credentials
/// - Redacted accessors for diagnostics and logging
library;

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging.dart';
import 'mqtt_config.dart';
import 'mqtt_constants.dart';

/// Manages persistent storage for Global Layer configuration and secrets.
///
/// Configuration data (host, port, topics, privacy toggles) is stored
/// in [SharedPreferences] for fast synchronous reads. The broker
/// password is stored separately in [FlutterSecureStorage] so it is
/// never exposed in plaintext backups or logs.
///
/// Usage:
/// ```dart
/// final storage = GlobalLayerSecureStorage();
/// await storage.saveConfig(config);
/// final loaded = await storage.loadConfig();
/// ```
class GlobalLayerSecureStorage {
  final FlutterSecureStorage _secureStorage;

  /// Creates a new instance with platform-appropriate secure storage options.
  GlobalLayerSecureStorage()
    : _secureStorage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
        iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
      );

  /// Creates an instance with a custom [FlutterSecureStorage] for testing.
  GlobalLayerSecureStorage.withStorage(this._secureStorage);

  // ---------------------------------------------------------------------------
  // Password storage
  // ---------------------------------------------------------------------------

  /// Stores the broker password securely.
  ///
  /// If [password] is empty, any previously stored password is deleted.
  Future<void> savePassword(String password) async {
    try {
      if (password.isEmpty) {
        await _secureStorage.delete(
          key: GlobalLayerConstants.passwordStorageKey,
        );
        AppLogging.settings('GlobalLayer: cleared stored password');
      } else {
        await _secureStorage.write(
          key: GlobalLayerConstants.passwordStorageKey,
          value: password,
        );
        AppLogging.settings('GlobalLayer: stored broker password');
      }
    } catch (e) {
      AppLogging.settings('GlobalLayer: failed to save password: $e');
      rethrow;
    }
  }

  /// Retrieves the stored broker password.
  ///
  /// Returns an empty string if no password is stored or if the read fails.
  Future<String> loadPassword() async {
    try {
      final password = await _secureStorage.read(
        key: GlobalLayerConstants.passwordStorageKey,
      );
      return password ?? '';
    } catch (e) {
      AppLogging.settings('GlobalLayer: failed to load password: $e');
      return '';
    }
  }

  /// Deletes the stored broker password.
  Future<void> deletePassword() async {
    try {
      await _secureStorage.delete(key: GlobalLayerConstants.passwordStorageKey);
      AppLogging.settings('GlobalLayer: deleted stored password');
    } catch (e) {
      AppLogging.settings('GlobalLayer: failed to delete password: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Full config persistence
  // ---------------------------------------------------------------------------

  /// Saves the complete [GlobalLayerConfig] to storage.
  ///
  /// The password is extracted and stored in secure storage.
  /// The remaining config (without password) is stored in shared preferences.
  Future<void> saveConfig(GlobalLayerConfig config) async {
    try {
      // Store password separately in secure storage
      await savePassword(config.password);

      // Store the rest in shared preferences (password excluded by toJson)
      final prefs = await SharedPreferences.getInstance();
      final jsonString = config.toJsonString();
      await prefs.setString(GlobalLayerConstants.configPrefsKey, jsonString);

      AppLogging.settings(
        'GlobalLayer: saved config (host: ${config.host}, '
        'enabled: ${config.enabled}, '
        'topics: ${config.subscriptions.length})',
      );
    } catch (e) {
      AppLogging.settings('GlobalLayer: failed to save config: $e');
      rethrow;
    }
  }

  /// Loads the complete [GlobalLayerConfig] from storage.
  ///
  /// Reads the config from shared preferences and the password from
  /// secure storage, then combines them into a single config object.
  ///
  /// Returns [GlobalLayerConfig.initial] if no config is stored or
  /// if loading fails.
  Future<GlobalLayerConfig> loadConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(GlobalLayerConstants.configPrefsKey);

      if (jsonString == null || jsonString.isEmpty) {
        AppLogging.settings('GlobalLayer: no stored config found');
        return GlobalLayerConfig.initial;
      }

      // Load password from secure storage
      final password = await loadPassword();

      // Combine config + password
      final config = GlobalLayerConfig.fromJsonString(
        jsonString,
        password: password,
      );

      AppLogging.settings(
        'GlobalLayer: loaded config (host: ${config.host}, '
        'enabled: ${config.enabled}, '
        'setupComplete: ${config.setupComplete})',
      );

      return config;
    } catch (e) {
      AppLogging.settings('GlobalLayer: failed to load config: $e');
      return GlobalLayerConfig.initial;
    }
  }

  /// Deletes all Global Layer configuration and credentials.
  ///
  /// This is a destructive operation that cannot be undone. Used when
  /// the user explicitly resets the Global Layer feature or clears
  /// all app data.
  Future<void> clearAll() async {
    try {
      // Delete password from secure storage
      await deletePassword();

      // Delete config from shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(GlobalLayerConstants.configPrefsKey);
      await prefs.remove(GlobalLayerConstants.setupCompleteKey);
      await prefs.remove(GlobalLayerConstants.firstViewedKey);

      AppLogging.settings('GlobalLayer: cleared all stored data');
    } catch (e) {
      AppLogging.settings('GlobalLayer: failed to clear all data: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Setup completion flag
  // ---------------------------------------------------------------------------

  /// Marks the setup wizard as completed.
  Future<void> markSetupComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(GlobalLayerConstants.setupCompleteKey, true);
      AppLogging.settings('GlobalLayer: marked setup as complete');
    } catch (e) {
      AppLogging.settings('GlobalLayer: failed to mark setup complete: $e');
    }
  }

  /// Whether the setup wizard has been completed.
  Future<bool> isSetupComplete() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(GlobalLayerConstants.setupCompleteKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // First-viewed flag (for NEW badge in drawer)
  // ---------------------------------------------------------------------------

  /// Marks the Global Layer feature as viewed (hides the NEW badge).
  Future<void> markFirstViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(GlobalLayerConstants.firstViewedKey, true);
      AppLogging.settings('GlobalLayer: marked as first viewed');
    } catch (e) {
      AppLogging.settings('GlobalLayer: failed to mark first viewed: $e');
    }
  }

  /// Whether the user has viewed the Global Layer feature at least once.
  Future<bool> hasBeenViewed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(GlobalLayerConstants.firstViewedKey) ?? false;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Diagnostics helpers
  // ---------------------------------------------------------------------------

  /// Returns a redacted summary of what is stored, suitable for
  /// inclusion in diagnostics exports and bug reports.
  ///
  /// No actual secret values are included. Only presence/absence
  /// and metadata are reported.
  Future<Map<String, dynamic>> getStorageDiagnostics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasConfig = prefs.containsKey(GlobalLayerConstants.configPrefsKey);
      final hasSetupFlag = prefs.containsKey(
        GlobalLayerConstants.setupCompleteKey,
      );
      final hasViewedFlag = prefs.containsKey(
        GlobalLayerConstants.firstViewedKey,
      );

      // Check if password exists without reading its value
      bool hasPassword;
      try {
        final pw = await _secureStorage.read(
          key: GlobalLayerConstants.passwordStorageKey,
        );
        hasPassword = pw != null && pw.isNotEmpty;
      } catch (_) {
        hasPassword = false;
      }

      // Get config size if present
      int? configSizeBytes;
      if (hasConfig) {
        final jsonString = prefs.getString(GlobalLayerConstants.configPrefsKey);
        configSizeBytes = jsonString?.length;
      }

      return {
        'hasConfig': hasConfig,
        'hasPassword': hasPassword,
        'hasSetupCompleteFlag': hasSetupFlag,
        'hasViewedFlag': hasViewedFlag,
        'configSizeBytes': configSizeBytes,
        'setupComplete':
            prefs.getBool(GlobalLayerConstants.setupCompleteKey) ?? false,
        'hasBeenViewed':
            prefs.getBool(GlobalLayerConstants.firstViewedKey) ?? false,
      };
    } catch (e) {
      return {'error': 'Failed to read storage diagnostics: $e'};
    }
  }

  /// Returns a full diagnostics string combining config and storage
  /// metadata, with all secrets redacted.
  ///
  /// This is the recommended method for the "Copy diagnostics summary"
  /// button in the diagnostics UI.
  Future<String> getRedactedDiagnosticsString() async {
    final storageDiag = await getStorageDiagnostics();
    GlobalLayerConfig? config;
    try {
      config = await loadConfig();
    } catch (_) {
      // If config load fails, we still want storage diagnostics
    }

    final combined = <String, dynamic>{
      'storage': storageDiag,
      if (config != null) 'config': config.toRedactedJson(),
    };

    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(combined);
  }
}
