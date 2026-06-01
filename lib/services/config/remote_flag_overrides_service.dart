// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging.dart';

/// Remote override layer for boolean env flags that AppFeatureFlags and
/// AppLogging already read from `dotenv.env`.
///
/// Design intent: do NOT introduce a new feature-flag framework. Keep
/// existing call sites unchanged. We overlay remote boolean values into
/// `dotenv.env` so the existing getters keep working, and we invalidate
/// AppLogging's lazy caches whenever the overlay changes.
///
/// Firestore document path: `app_config/remote_flags`
/// Expected document shape (flat map of allowlisted env keys to bool):
/// ```json
/// {
///   "HANDSHAKE_ENABLED": true,
///   "MESHCORE_ENABLED": false,
///   "BLE_LOGGING_ENABLED": true
/// }
/// ```
///
/// Unknown keys are ignored with a log. Non-bool values are ignored
/// with a log. Removing a key from the doc restores its original
/// boot-time `.env` value.
class RemoteFlagOverridesService {
  RemoteFlagOverridesService._internal();

  static final RemoteFlagOverridesService instance =
      RemoteFlagOverridesService._internal();

  /// Allowlist of env-var names this service is willing to mutate. Any
  /// key not in this set is rejected (both inbound from Firestore and
  /// outbound from admin writes). Add a new entry here whenever an
  /// existing `*_ENABLED` / `*_LOGGING_ENABLED` env key should become
  /// remote-flippable.
  static const Set<String> allowedKeys = <String>{
    // AppFeatureFlags (lib/core/constants.dart)
    'VOICE_MESSAGES_ENABLED',
    'MESSAGE_TIMELINE_ENABLED',
    'FILE_TRANSFER_ENABLED',
    'MESHCORE_ENABLED',
    'MESHCORE_REPLIES_ENABLED',
    'MAPBOX_ENABLED',
    'AETHER_ENABLED',
    'OPERATIONS_ENABLED',
    'TAK_GATEWAY_ENABLED',
    'TAK_MESH_BRIDGE_ENABLED',
    'TAK_PUBLISH_ENABLED',
    'TAK_VIDEO_ENABLED',
    'NODEDEX_CONSTELLATION_ENABLED',
    'SOCIAL_ENABLED',
    'APPLE_WALLET_ENABLED',
    'HANDSHAKE_ENABLED',
    'SIP_ENABLED',
    'MRRP_ENABLED',
    'MRRP_HARNESS_ENABLED',
    'MESH_INCIDENTS_ENABLED',
    'MESH_EXPLORER_ENABLED',
    'MESH_SERVICES_ENABLED',
    'NODEBOARD_ENABLED',
    'PET_ENABLED',
    'MESH_FEED_ENABLED',
    'MESH_FEED_RF_ENABLED',
    'OPPORTUNISTIC_SYNC_ENABLED',
    'RETICULUM_TUNNEL_ENABLED',
    'TRANSLATION_ENABLED',
    'STRIPE_PURCHASES_ENABLED',
    'BMC_PURCHASE_ENABLED',
    // SmFeatureFlag (lib/services/protocol/socialmesh/sm_feature_flag.dart)
    'BLE_RX_STALL_RECOVERY_RECONNECT',
    // AppLogging (lib/core/logging.dart)
    'BLE_LOGGING_ENABLED',
    'MAP_LOGGING_ENABLED',
    'PROTOCOL_LOGGING_ENABLED',
    'WIDGET_BUILDER_LOGGING_ENABLED',
    'LIVE_ACTIVITY_LOGGING_ENABLED',
    'AUTOMATIONS_LOGGING_ENABLED',
    'MESSAGES_LOGGING_ENABLED',
    'IFTTT_LOGGING_ENABLED',
    'TELEMETRY_LOGGING_ENABLED',
    'CONNECTION_LOGGING_ENABLED',
    'NODES_LOGGING_ENABLED',
    'CHANNELS_LOGGING_ENABLED',
    'APP_LOGGING_ENABLED',
    'SUBSCRIPTIONS_LOGGING_ENABLED',
    'PURCHASE_LOGGING_ENABLED',
    'NOTIFICATIONS_LOGGING_ENABLED',
    'AUDIO_LOGGING_ENABLED',
    'MAPS_LOGGING_ENABLED',
    'FIRMWARE_LOGGING_ENABLED',
    'SETTINGS_LOGGING_ENABLED',
    'DEBUG_LOGGING_ENABLED',
    'AUTH_LOGGING_ENABLED',
    'SOCIAL_LOGGING_ENABLED',
    'STORAGE_LOGGING_ENABLED',
    'PERMISSIONS_LOGGING_ENABLED',
    'MARKETPLACE_LOGGING_ENABLED',
    'QR_LOGGING_ENABLED',
    'BUG_REPORT_LOGGING_ENABLED',
    'SHOP_LOGGING_ENABLED',
    'NODEDEX_LOGGING_ENABLED',
    'NODEBOARD_LOGGING_ENABLED',
    'PET_LOGGING_ENABLED',
    'MFA_LOGGING_ENABLED',
    'AETHER_LOGGING_ENABLED',
    'TAK_LOGGING_ENABLED',
    'CLAIMS_LOGGING_ENABLED',
    'UI_GATES_LOGGING_ENABLED',
    'SYNC_LOGGING_ENABLED',
    'INCIDENTS_LOGGING_ENABLED',
    'INCIDENT_SYNC_LOGGING_ENABLED',
    'INCIDENT_UI_LOGGING_ENABLED',
    'TASKS_LOGGING_ENABLED',
    'TASK_SYNC_LOGGING_ENABLED',
    'OPERATIONS_LOGGING_ENABLED',
    'ADMIN_DIAG_LOGGING_ENABLED',
    'FILE_TRANSFER_LOGGING_ENABLED',
    'HANDSHAKE_LOGGING_ENABLED',
    'SIP_LOGGING_ENABLED',
    'SIP_INK_LOGGING_ENABLED',
    'SIP_PLAY_LOGGING_ENABLED',
    'SIP_SIGNAL_LOGGING_ENABLED',
    'RETICULUM_LOGGING_ENABLED',
    'MRRP_DEBUG',
    'MRRP_HARNESS_DEBUG',
    'MESH_EXPLORER_DEBUG',
    'MESH_CAPACITY_LOGGING_ENABLED',
    'VOICE_LOGGING_ENABLED',
    'CODEC2_LOGGING_ENABLED',
    'SPP_LOGGING_ENABLED',
    'SPP_NEGOTIATION_LOGGING_ENABLED',
    'STL_LOGGING_ENABLED',
    'OVERLAY_LOGGING_ENABLED',
    'MESH_FEED_LOGGING_ENABLED',
    'MESH_GAMES_LOGGING_ENABLED',
    'MESH_GAME_TRANSPORT_LOGGING_ENABLED',
    'MESH_GAME_SESSION_LOGGING_ENABLED',
    'MESH_GAME_UI_LOGGING_ENABLED',
    'MQTT_PROXY_LOGGING_ENABLED',
    'MESHCORE_LOGGING_ENABLED',
    'MESHCORE_LOGGING_LOCATION_ENABLED',
    'PLATFORM_LOGGING_ENABLED',
  };

  /// Subset of [allowedKeys] whose code-level default is `true` when no
  /// remote override and no `.env` value is present (opt-out flags).
  /// The matching getter in AppFeatureFlags must agree — keep in sync.
  /// Without this set the admin sheet would render an unset opt-out flag
  /// as OFF and its kill-switch would read backwards.
  static const Set<String> defaultTrueKeys = <String>{
    'STRIPE_PURCHASES_ENABLED',
  };

  static const String _firestoreCollection = 'app_config';
  static const String _firestoreDocument = 'remote_flags';
  static const String _prefsCacheKey = 'remote_flag_overrides_cache_v1';

  bool _initialised = false;

  /// Snapshot of `dotenv.env` for allowlisted keys captured at first
  /// init. Used to restore original values when an override is removed.
  /// `null` here means the key was not present in `.env` at boot.
  final Map<String, String?> _originalEnv = <String, String?>{};

  /// Currently applied overrides (already written into `dotenv.env`).
  final Map<String, bool> _currentOverrides = <String, bool>{};

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _firestoreSubscription;

  /// Increments on every applied change so UI surfaces (the admin
  /// sheet) can rebuild via ValueListenableBuilder without depending
  /// on a Riverpod provider.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  Map<String, bool> get currentOverrides => Map.unmodifiable(_currentOverrides);

  bool? getRemoteOverride(String key) => _currentOverrides[key];

  /// What `dotenv.env[key]` resolves to right now (override or original).
  /// Empty string when neither is set. Useful for the admin UI.
  String effectiveValueFor(String key) {
    try {
      return dotenv.env[key] ?? '';
    } catch (_) {
      return '';
    }
  }

  /// The resolved boolean the app actually sees for [key]: the remote
  /// override if set, else the `.env` value, else the code-level default
  /// (`true` for [defaultTrueKeys], `false` otherwise). Mirrors the
  /// AppFeatureFlags / AppLogging getter semantics so the admin sheet's
  /// switch reflects reality for both opt-in and opt-out flags.
  bool effectiveBoolFor(String key) {
    final raw = effectiveValueFor(key).trim().toLowerCase();
    if (raw.isEmpty) return defaultTrueKeys.contains(key);
    if (defaultTrueKeys.contains(key)) return raw != 'false';
    return raw == 'true' || raw == '1';
  }

  /// One-time initialisation. Idempotent. Must not throw or block.
  ///
  ///   1. Snapshot original `.env` for allowlisted keys.
  ///   2. Load cached overrides from SharedPreferences and apply.
  ///   3. Fire-and-forget Firestore listener for live updates.
  Future<void> initialise() async {
    if (_initialised) return;
    _initialised = true;
    AppLogging.settings('RemoteFlagOverrides: init');

    _captureOriginalEnv();

    await _loadCachedOverrides();

    // Don't await — Firestore listening must never block app startup.
    unawaited(_startFirestoreListener());
  }

  void _captureOriginalEnv() {
    for (final key in allowedKeys) {
      try {
        _originalEnv[key] = dotenv.env[key];
      } catch (_) {
        _originalEnv[key] = null;
      }
    }
  }

  Future<void> _loadCachedOverrides() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsCacheKey);
      if (raw == null || raw.isEmpty) {
        AppLogging.settings('RemoteFlagOverrides: no cached overrides');
        return;
      }
      final decoded = json.decode(raw);
      if (decoded is! Map) return;
      final next = _filterValidOverrides(decoded);
      _applyOverrides(next, reason: 'cache');
    } catch (e) {
      AppLogging.settings(
        'RemoteFlagOverrides: failed to load cached overrides: $e',
      );
    }
  }

  Future<void> _persistCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsCacheKey, json.encode(_currentOverrides));
    } catch (e) {
      AppLogging.settings('RemoteFlagOverrides: failed to persist cache: $e');
    }
  }

  Future<void> _startFirestoreListener() async {
    final firestore = _firestoreOrNull();
    if (firestore == null) {
      AppLogging.settings(
        'RemoteFlagOverrides: firestore unavailable, '
        'staying on cached overrides only',
      );
      return;
    }
    try {
      final doc = firestore
          .collection(_firestoreCollection)
          .doc(_firestoreDocument);
      _firestoreSubscription = doc.snapshots().listen(
        (snapshot) {
          try {
            final data = snapshot.data();
            if (!snapshot.exists || data == null) {
              AppLogging.settings(
                'RemoteFlagOverrides: firestore doc missing, '
                'clearing remote overrides',
              );
              _applyOverrides(const <String, bool>{}, reason: 'remote-empty');
              unawaited(_persistCache());
              return;
            }
            final next = _filterValidOverrides(data);
            _applyOverrides(next, reason: 'remote');
            unawaited(_persistCache());
          } catch (e) {
            AppLogging.settings(
              'RemoteFlagOverrides: failed to apply remote update: $e',
            );
          }
        },
        onError: (Object e) {
          AppLogging.settings(
            'RemoteFlagOverrides: firestore stream error: $e',
          );
        },
      );
      AppLogging.settings('RemoteFlagOverrides: firestore listener active');
    } catch (e) {
      AppLogging.settings(
        'RemoteFlagOverrides: failed to start firestore listener: $e',
      );
    }
  }

  /// Inbound validation: keep only allowlisted keys with bool values.
  /// Anything else gets logged and dropped.
  Map<String, bool> _filterValidOverrides(Map<dynamic, dynamic> raw) {
    final out = <String, bool>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString();
      if (!allowedKeys.contains(key)) {
        AppLogging.settings('RemoteFlagOverrides: ignoring unknown key "$key"');
        continue;
      }
      final value = entry.value;
      if (value is bool) {
        out[key] = value;
      } else {
        AppLogging.settings(
          'RemoteFlagOverrides: ignoring non-bool value for "$key": '
          '${value.runtimeType}',
        );
      }
    }
    return out;
  }

  /// Apply [next] as the new full set of overrides. Diff against
  /// current state, mutate `dotenv.env`, restore originals for removed
  /// keys, and invalidate AppLogging caches.
  void _applyOverrides(Map<String, bool> next, {required String reason}) {
    final changed = <String>[];

    // Apply new / changed values.
    for (final entry in next.entries) {
      final prev = _currentOverrides[entry.key];
      if (prev == entry.value) continue;
      _writeEnv(entry.key, entry.value ? 'true' : 'false');
      _currentOverrides[entry.key] = entry.value;
      changed.add('${entry.key}=${entry.value}');
    }

    // Restore originals for keys no longer overridden.
    final removed = _currentOverrides.keys
        .where((k) => !next.containsKey(k))
        .toList(growable: false);
    for (final key in removed) {
      _restoreOriginal(key);
      _currentOverrides.remove(key);
      changed.add('$key=<restored>');
    }

    if (changed.isEmpty) {
      AppLogging.settings('RemoteFlagOverrides: no changes from $reason');
      return;
    }

    AppLogging.invalidateCaches();
    revision.value++;
    AppLogging.settings(
      'RemoteFlagOverrides: applied $reason: ${changed.join(', ')}',
    );
  }

  void _writeEnv(String key, String value) {
    try {
      dotenv.env[key] = value;
    } catch (e) {
      AppLogging.settings(
        'RemoteFlagOverrides: failed to write env "$key": $e',
      );
    }
  }

  void _restoreOriginal(String key) {
    try {
      final original = _originalEnv[key];
      if (original == null) {
        dotenv.env.remove(key);
      } else {
        dotenv.env[key] = original;
      }
    } catch (e) {
      AppLogging.settings(
        'RemoteFlagOverrides: failed to restore env "$key": $e',
      );
    }
  }

  /// Admin writes one override up to Firestore. The Firestore listener
  /// will mirror the change back into local state on the next snapshot.
  Future<void> setRemoteFlag(String key, bool value) async {
    if (!allowedKeys.contains(key)) {
      AppLogging.settings(
        'RemoteFlagOverrides: refusing to write unknown key "$key"',
      );
      return;
    }
    final firestore = _firestoreOrNull();
    if (firestore == null) {
      AppLogging.settings(
        'RemoteFlagOverrides: write skipped, firestore unavailable',
      );
      return;
    }
    try {
      await firestore
          .collection(_firestoreCollection)
          .doc(_firestoreDocument)
          .set(<String, dynamic>{key: value}, SetOptions(merge: true));
      AppLogging.settings(
        'RemoteFlagOverrides: wrote $key=$value to firestore',
      );
    } catch (e) {
      AppLogging.settings('RemoteFlagOverrides: write failed for "$key": $e');
    }
  }

  /// Admin clears an override (restores the boot-time `.env` value).
  Future<void> removeRemoteFlag(String key) async {
    if (!allowedKeys.contains(key)) {
      AppLogging.settings(
        'RemoteFlagOverrides: refusing to delete unknown key "$key"',
      );
      return;
    }
    final firestore = _firestoreOrNull();
    if (firestore == null) {
      AppLogging.settings(
        'RemoteFlagOverrides: delete skipped, firestore unavailable',
      );
      return;
    }
    try {
      await firestore
          .collection(_firestoreCollection)
          .doc(_firestoreDocument)
          .update(<String, dynamic>{key: FieldValue.delete()});
      AppLogging.settings('RemoteFlagOverrides: deleted $key from firestore');
    } catch (e) {
      AppLogging.settings('RemoteFlagOverrides: delete failed for "$key": $e');
    }
  }

  /// The original (boot-time) `.env` value for a key, or null if it was
  /// unset at boot. Useful for the admin UI's "original value" column.
  String? originalEnvValueFor(String key) => _originalEnv[key];

  FirebaseFirestore? _firestoreOrNull() {
    try {
      if (Firebase.apps.isEmpty) return null;
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    await _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
  }
}
