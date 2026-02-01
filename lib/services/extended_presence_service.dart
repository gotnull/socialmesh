// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging.dart';
import '../models/presence_confidence.dart';

/// Service for managing extended presence info (intent + short status).
/// Piggybacks on existing signal broadcast channel with rate limiting.
class ExtendedPresenceService {
  static const String _prefsKeyMyIntent = 'extended_presence_my_intent';
  static const String _prefsKeyMyStatus = 'extended_presence_my_status';
  static const String _prefsKeyLastBroadcast =
      'extended_presence_last_broadcast';
  static const String _prefsKeyRemoteCache = 'extended_presence_remote_cache';

  /// Minimum interval between broadcasts (15 minutes)
  static const Duration minBroadcastInterval = Duration(minutes: 15);

  SharedPreferences? _prefs;
  DateTime? _lastBroadcastTime;
  ExtendedPresenceInfo? _lastBroadcastInfo;

  /// Cache of remote node extended presence info
  final Map<int, ExtendedPresenceInfo> _remoteCache = {};

  /// Stream controller for remote presence updates
  final _remoteUpdatesController =
      StreamController<(int nodeNum, ExtendedPresenceInfo info)>.broadcast();

  Stream<(int nodeNum, ExtendedPresenceInfo info)> get remoteUpdates =>
      _remoteUpdatesController.stream;

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _loadLastBroadcastTime();
    _loadRemoteCache();
    _initialized = true;
  }

  void _loadLastBroadcastTime() {
    final timestampMs = _prefs?.getInt(_prefsKeyLastBroadcast);
    if (timestampMs != null) {
      _lastBroadcastTime = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    }
  }

  void _loadRemoteCache() {
    final cacheJson = _prefs?.getString(_prefsKeyRemoteCache);
    if (cacheJson == null) return;
    try {
      final decoded = jsonDecode(cacheJson) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        final nodeNum = int.tryParse(entry.key);
        if (nodeNum == null) continue;
        final info = ExtendedPresenceInfo.fromJson(
          entry.value as Map<String, dynamic>?,
        );
        if (info.hasData) {
          _remoteCache[nodeNum] = info;
        }
      }
      AppLogging.protocol(
        'ExtendedPresence: Loaded ${_remoteCache.length} cached remote entries',
      );
    } catch (e) {
      AppLogging.protocol('ExtendedPresence: Failed to load remote cache: $e');
    }
  }

  Future<void> _saveRemoteCache() async {
    if (_prefs == null) return;
    final cacheMap = <String, dynamic>{};
    for (final entry in _remoteCache.entries) {
      if (entry.value.hasData) {
        cacheMap[entry.key.toString()] = entry.value.toJson();
      }
    }
    await _prefs!.setString(_prefsKeyRemoteCache, jsonEncode(cacheMap));
  }

  /// Get my current extended presence info from local storage.
  Future<ExtendedPresenceInfo> getMyPresenceInfo() async {
    _prefs ??= await SharedPreferences.getInstance();
    final intentValue = _prefs!.getInt(_prefsKeyMyIntent);
    final status = _prefs!.getString(_prefsKeyMyStatus);
    return ExtendedPresenceInfo(
      intent: PresenceIntent.fromValue(intentValue),
      shortStatus: status,
    );
  }

  /// Set my intent. Returns true if value changed.
  Future<bool> setMyIntent(PresenceIntent intent) async {
    _prefs ??= await SharedPreferences.getInstance();
    final current = _prefs!.getInt(_prefsKeyMyIntent);
    if (current == intent.value) return false;
    await _prefs!.setInt(_prefsKeyMyIntent, intent.value);
    return true;
  }

  /// Set my short status. Returns true if value changed.
  Future<bool> setMyStatus(String? status) async {
    _prefs ??= await SharedPreferences.getInstance();
    final current = _prefs!.getString(_prefsKeyMyStatus);
    final trimmed = status?.trim();
    final normalized = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
    if (current == normalized) return false;
    if (normalized == null) {
      await _prefs!.remove(_prefsKeyMyStatus);
    } else {
      final clamped = normalized.length > ExtendedPresenceInfo.maxStatusLength
          ? normalized.substring(0, ExtendedPresenceInfo.maxStatusLength)
          : normalized;
      await _prefs!.setString(_prefsKeyMyStatus, clamped);
    }
    return true;
  }

  /// Check if we should broadcast (rate limiting).
  /// Returns true if enough time has passed since last broadcast
  /// or if the info has changed.
  bool shouldBroadcast(ExtendedPresenceInfo info) {
    // Always allow if no data to broadcast
    if (!info.hasData) return false;

    // Allow if info changed
    if (_lastBroadcastInfo != info) return true;

    // Rate limit: only broadcast every minBroadcastInterval
    if (_lastBroadcastTime == null) return true;
    final elapsed = DateTime.now().difference(_lastBroadcastTime!);
    return elapsed >= minBroadcastInterval;
  }

  /// Record that we broadcast presence info.
  Future<void> recordBroadcast(ExtendedPresenceInfo info) async {
    _lastBroadcastTime = DateTime.now();
    _lastBroadcastInfo = info;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(
      _prefsKeyLastBroadcast,
      _lastBroadcastTime!.millisecondsSinceEpoch,
    );
  }

  /// Handle received extended presence info from another node.
  void handleRemotePresence(int nodeNum, ExtendedPresenceInfo info) {
    if (!info.hasData) {
      _remoteCache.remove(nodeNum);
    } else {
      final existing = _remoteCache[nodeNum];
      if (existing == info) return; // No change
      _remoteCache[nodeNum] = info;
    }
    _remoteUpdatesController.add((nodeNum, info));
    // Debounced save
    _scheduleCacheSave();
  }

  Timer? _cacheSaveTimer;
  void _scheduleCacheSave() {
    _cacheSaveTimer?.cancel();
    _cacheSaveTimer = Timer(const Duration(seconds: 5), () {
      _saveRemoteCache();
    });
  }

  /// Get cached extended presence info for a node.
  ExtendedPresenceInfo? getRemotePresence(int nodeNum) {
    return _remoteCache[nodeNum];
  }

  /// Get all cached remote presence info.
  Map<int, ExtendedPresenceInfo> get allRemotePresence =>
      Map.unmodifiable(_remoteCache);

  void dispose() {
    _cacheSaveTimer?.cancel();
    _remoteUpdatesController.close();
  }
}
