// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging.dart';
import '../../../core/radio_scope.dart';

/// Unread counts for MeshCore DM threads and channels. The contact roster
/// itself lives on the radio.
class MeshCoreContactStore {
  // Contact list written by older builds; now only ever cleared.
  static const String _key = 'meshcore_contacts';
  static const String _unreadPrefix = 'meshcore_unread_';

  /// D38-A: per-channel unread count keyspace.
  ///
  /// Shape: `meshcore_channel_unread_<devicePubKeyPrefix>_<idx>`.
  /// Device-scoped because the firmware slot index is positional -
  /// two radios share `slot 0 = "Public"`, so without the device
  /// prefix the unread count would bleed across radios.
  ///
  /// Key by channel **slot index** only. Never by channel name (user-
  /// editable), PSK (secret), or channel code (carries the PSK). This
  /// mirrors the D37-A/B/C prefs-store keying discipline.
  static const String _channelUnreadPrefix = 'meshcore_channel_unread_';

  SharedPreferences? _prefs;

  MeshCoreContactStore();

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw StateError('MeshCoreContactStore not initialized');
    }
    return _prefs!;
  }

  /// Clear the legacy contact list key and every unread count.
  Future<void> clearAll() async {
    await init();
    await _preferences.remove(_key);
    // Clear all unread counts (contacts + D38-A channel-unread keys).
    final scopedUnread = RadioScope.instance.prefsKey(_unreadPrefix);
    final keys = _preferences.getKeys().toList();
    for (final key in keys) {
      if (key.startsWith(_unreadPrefix) ||
          key.startsWith(scopedUnread) ||
          key.startsWith(_channelUnreadPrefix)) {
        await _preferences.remove(key);
      }
    }
    AppLogging.storage('Cleared MeshCore unread counts');
  }

  /// Get unread count for a contact.
  Future<int> getUnreadCount(String publicKeyHex) async {
    await init();
    return RadioScope.instance.readScoped(
          '$_unreadPrefix$publicKeyHex',
          _preferences.getInt,
        ) ??
        0;
  }

  /// Set unread count for a contact, under the connected radio's scope.
  Future<void> setUnreadCount(String publicKeyHex, int count) async {
    await init();
    final key = RadioScope.instance.prefsKey('$_unreadPrefix$publicKeyHex');
    if (count <= 0) {
      await _preferences.remove(key);
    } else {
      await _preferences.setInt(key, count);
    }
  }

  /// Moves per-contact unread counts kept before they were radio-scoped
  /// into the current scope, unless the scope already has a count for that
  /// contact. Call once a MeshCore radio has identified.
  Future<void> adoptUnscopedUnreadCounts() async {
    await init();
    for (final key in _preferences.getKeys().toList()) {
      if (!key.startsWith(_unreadPrefix)) continue;
      final value = _preferences.get(key);
      final scoped = RadioScope.instance.prefsKey(key);
      if (value is int && !_preferences.containsKey(scoped)) {
        await _preferences.setInt(scoped, value);
      }
      await _preferences.remove(key);
    }
  }

  /// Increment unread count for a contact.
  Future<int> incrementUnreadCount(String publicKeyHex) async {
    final current = await getUnreadCount(publicKeyHex);
    final updated = current + 1;
    await setUnreadCount(publicKeyHex, updated);
    return updated;
  }

  /// Clear unread count for a contact.
  Future<void> clearUnreadCount(String publicKeyHex) async {
    await setUnreadCount(publicKeyHex, 0);
  }

  /// D38-A: build the SharedPreferences key for a per-channel unread
  /// counter. Empty [devicePubKeyPrefix] yields an empty string so
  /// the caller can fast-path away from any read/write before
  /// touching the keyspace.
  String _channelUnreadKey(String devicePubKeyPrefix, int channelIndex) {
    if (devicePubKeyPrefix.isEmpty) return '';
    return '$_channelUnreadPrefix${devicePubKeyPrefix.toLowerCase()}_'
        '$channelIndex';
  }

  /// D38-A: load the persisted unread count for channel slot
  /// [channelIndex] on the device identified by [devicePubKeyPrefix].
  /// Returns 0 on missing key, empty prefix, or corrupt value.
  Future<int> getChannelUnreadCount(
    String devicePubKeyPrefix,
    int channelIndex,
  ) async {
    if (devicePubKeyPrefix.isEmpty) return 0;
    await init();
    final key = _channelUnreadKey(devicePubKeyPrefix, channelIndex);
    try {
      return _preferences.getInt(key) ?? 0;
    } catch (_) {
      // SharedPreferences stores the wrong type at this key (e.g. a
      // string written by an older build). Treat as zero rather than
      // throw - the user must never lose channel access because of a
      // stale serialised value.
      return 0;
    }
  }

  /// D38-A: set the persisted unread count for channel slot
  /// [channelIndex]. Writing 0 (or any non-positive value) removes the
  /// key so the SharedPreferences keyspace stays compact.
  Future<void> setChannelUnreadCount(
    String devicePubKeyPrefix,
    int channelIndex,
    int count,
  ) async {
    if (devicePubKeyPrefix.isEmpty) return;
    await init();
    final key = _channelUnreadKey(devicePubKeyPrefix, channelIndex);
    if (count <= 0) {
      await _preferences.remove(key);
    } else {
      await _preferences.setInt(key, count);
    }
  }

  /// D38-A: increment the persisted unread count by 1 and return the
  /// new value. No-op on empty prefix.
  Future<int> incrementChannelUnreadCount(
    String devicePubKeyPrefix,
    int channelIndex,
  ) async {
    if (devicePubKeyPrefix.isEmpty) return 0;
    final current = await getChannelUnreadCount(
      devicePubKeyPrefix,
      channelIndex,
    );
    final updated = current + 1;
    await setChannelUnreadCount(devicePubKeyPrefix, channelIndex, updated);
    return updated;
  }

  /// D38-A: clear the persisted unread count for channel slot
  /// [channelIndex].
  Future<void> clearChannelUnreadCount(
    String devicePubKeyPrefix,
    int channelIndex,
  ) async {
    await setChannelUnreadCount(devicePubKeyPrefix, channelIndex, 0);
  }
}
