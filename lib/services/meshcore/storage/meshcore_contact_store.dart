// SPDX-License-Identifier: GPL-3.0-or-later

import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging.dart';
import '../../../models/meshcore_contact.dart';

/// Storage service for MeshCore contacts.
///
/// Persists contacts across app restarts so users don't lose their contact list.
class MeshCoreContactStore {
  static const String _key = 'meshcore_contacts';
  static const String _unreadPrefix = 'meshcore_unread_';

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

  /// Load all saved contacts.
  Future<List<MeshCoreContact>> loadContacts() async {
    await init();
    final jsonStr = _preferences.getString(_key);
    if (jsonStr == null) return [];

    try {
      final jsonList = jsonDecode(jsonStr) as List<dynamic>;
      final contacts = <MeshCoreContact>[];
      for (final entry in jsonList) {
        try {
          final contact = _fromJson(entry as Map<String, dynamic>);
          // Load unread count
          final unread = await getUnreadCount(contact.publicKeyHex);
          contacts.add(contact.copyWith(unreadCount: unread));
        } catch (e) {
          AppLogging.storage('Error parsing contact: $e');
        }
      }
      AppLogging.storage('Loaded ${contacts.length} MeshCore contacts');
      return contacts;
    } catch (e) {
      AppLogging.storage('Error loading MeshCore contacts: $e');
      return [];
    }
  }

  /// Save all contacts.
  Future<void> saveContacts(List<MeshCoreContact> contacts) async {
    await init();
    final jsonList = contacts.map(_toJson).toList();
    await _preferences.setString(_key, jsonEncode(jsonList));
    AppLogging.storage('Saved ${contacts.length} MeshCore contacts');
  }

  /// Save a single contact (upsert).
  Future<void> saveContact(MeshCoreContact contact) async {
    final contacts = await loadContacts();
    final index = contacts.indexWhere(
      (c) => c.publicKeyHex == contact.publicKeyHex,
    );
    if (index >= 0) {
      contacts[index] = contact;
    } else {
      contacts.add(contact);
    }
    await saveContacts(contacts);
  }

  /// Remove a contact.
  Future<void> removeContact(String publicKeyHex) async {
    final contacts = await loadContacts();
    contacts.removeWhere((c) => c.publicKeyHex == publicKeyHex);
    await saveContacts(contacts);
    await clearUnreadCount(publicKeyHex);
  }

  /// Clear all contacts.
  Future<void> clearAll() async {
    await init();
    await _preferences.remove(_key);
    // Clear all unread counts
    final keys = _preferences.getKeys();
    for (final key in keys) {
      if (key.startsWith(_unreadPrefix)) {
        await _preferences.remove(key);
      }
    }
    AppLogging.storage('Cleared all MeshCore contacts');
  }

  /// Get unread count for a contact.
  Future<int> getUnreadCount(String publicKeyHex) async {
    await init();
    return _preferences.getInt('$_unreadPrefix$publicKeyHex') ?? 0;
  }

  /// Set unread count for a contact.
  Future<void> setUnreadCount(String publicKeyHex, int count) async {
    await init();
    if (count <= 0) {
      await _preferences.remove('$_unreadPrefix$publicKeyHex');
    } else {
      await _preferences.setInt('$_unreadPrefix$publicKeyHex', count);
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

  Map<String, dynamic> _toJson(MeshCoreContact contact) {
    return {
      'publicKey': base64Encode(contact.publicKey),
      'name': contact.name,
      'type': contact.type,
      'pathLength': contact.pathLength,
      'path': base64Encode(contact.path),
      'pathOverride': contact.pathOverride,
      'pathOverrideBytes': contact.pathOverrideBytes != null
          ? base64Encode(contact.pathOverrideBytes!)
          : null,
      'latitude': contact.latitude,
      'longitude': contact.longitude,
      'lastSeen': contact.lastSeen.millisecondsSinceEpoch,
      'lastMessageAt': contact.lastMessageAt.millisecondsSinceEpoch,
    };
  }

  MeshCoreContact _fromJson(Map<String, dynamic> json) {
    final lastSeenMs = json['lastSeen'] as int? ?? 0;
    final lastMessageMs = json['lastMessageAt'] as int?;
    return MeshCoreContact(
      publicKey: Uint8List.fromList(base64Decode(json['publicKey'] as String)),
      name: json['name'] as String? ?? 'Unknown',
      type: json['type'] as int? ?? 0,
      pathLength: json['pathLength'] as int? ?? -1,
      path: json['path'] != null
          ? Uint8List.fromList(base64Decode(json['path'] as String))
          : Uint8List(0),
      pathOverride: json['pathOverride'] as int?,
      pathOverrideBytes: json['pathOverrideBytes'] != null
          ? Uint8List.fromList(
              base64Decode(json['pathOverrideBytes'] as String),
            )
          : null,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      lastSeen: DateTime.fromMillisecondsSinceEpoch(lastSeenMs),
      lastMessageAt: lastMessageMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastMessageMs)
          : null,
    );
  }
}
