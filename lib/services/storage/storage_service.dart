import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'dart:convert';
import '../../models/mesh_models.dart';

/// Secure storage service for sensitive data
class SecureStorageService {
  final FlutterSecureStorage _storage;
  final Logger _logger;

  SecureStorageService({Logger? logger})
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      ),
      _logger = logger ?? Logger();

  /// Store channel key
  Future<void> storeChannelKey(String name, List<int> key) async {
    try {
      final keyString = base64Encode(key);
      await _storage.write(key: 'channel_$name', value: keyString);
      _logger.d('Stored channel key: $name');
    } catch (e) {
      _logger.e('Error storing channel key: $e');
      rethrow;
    }
  }

  /// Retrieve channel key
  Future<List<int>?> getChannelKey(String name) async {
    try {
      final keyString = await _storage.read(key: 'channel_$name');
      if (keyString == null) return null;

      return base64Decode(keyString);
    } catch (e) {
      _logger.e('Error retrieving channel key: $e');
      return null;
    }
  }

  /// Delete channel key
  Future<void> deleteChannelKey(String name) async {
    try {
      await _storage.delete(key: 'channel_$name');
      _logger.d('Deleted channel key: $name');
    } catch (e) {
      _logger.e('Error deleting channel key: $e');
    }
  }

  /// Get all channel keys
  Future<Map<String, List<int>>> getAllChannelKeys() async {
    try {
      final all = await _storage.readAll();
      final keys = <String, List<int>>{};

      for (final entry in all.entries) {
        if (entry.key.startsWith('channel_')) {
          final name = entry.key.substring(8); // Remove 'channel_' prefix
          keys[name] = base64Decode(entry.value);
        }
      }

      return keys;
    } catch (e) {
      _logger.e('Error getting all channel keys: $e');
      return {};
    }
  }

  /// Clear all data
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      _logger.i('Cleared all secure storage');
    } catch (e) {
      _logger.e('Error clearing storage: $e');
    }
  }
}

/// Settings storage service
class SettingsService {
  final Logger _logger;
  SharedPreferences? _prefs;

  SettingsService({Logger? logger}) : _logger = logger ?? Logger();

  /// Initialize the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw Exception('SettingsService not initialized');
    }
    return _prefs!;
  }

  // Last connected device
  Future<void> setLastDevice(String deviceId, String deviceType) async {
    await _preferences.setString('last_device_id', deviceId);
    await _preferences.setString('last_device_type', deviceType);
  }

  String? get lastDeviceId => _preferences.getString('last_device_id');
  String? get lastDeviceType => _preferences.getString('last_device_type');

  // Auto-reconnect
  Future<void> setAutoReconnect(bool enabled) async {
    await _preferences.setBool('auto_reconnect', enabled);
  }

  bool get autoReconnect => _preferences.getBool('auto_reconnect') ?? true;

  // Theme
  Future<void> setDarkMode(bool enabled) async {
    await _preferences.setBool('dark_mode', enabled);
  }

  bool get darkMode => _preferences.getBool('dark_mode') ?? false;

  // Notifications
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _preferences.setBool('notifications_enabled', enabled);
  }

  bool get notificationsEnabled =>
      _preferences.getBool('notifications_enabled') ?? true;

  // Message history limit
  Future<void> setMessageHistoryLimit(int limit) async {
    await _preferences.setInt('message_history_limit', limit);
  }

  int get messageHistoryLimit =>
      _preferences.getInt('message_history_limit') ?? 100;

  // Clear all settings
  Future<void> clearAll() async {
    await _preferences.clear();
    _logger.i('Cleared all settings');
  }

  // Onboarding completion
  Future<void> setOnboardingComplete(bool complete) async {
    await _preferences.setBool('onboarding_complete', complete);
  }

  bool get onboardingComplete =>
      _preferences.getBool('onboarding_complete') ?? false;
}

/// Message storage service - persists messages locally
class MessageStorageService {
  final Logger _logger;
  SharedPreferences? _prefs;
  static const String _messagesKey = 'messages';
  static const int _maxMessages = 500;

  MessageStorageService({Logger? logger}) : _logger = logger ?? Logger();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw Exception('MessageStorageService not initialized');
    }
    return _prefs!;
  }

  /// Save a message to local storage
  Future<void> saveMessage(Message message) async {
    try {
      final messages = await loadMessages();
      messages.add(message);

      // Trim to max messages
      if (messages.length > _maxMessages) {
        messages.removeRange(0, messages.length - _maxMessages);
      }

      final jsonList = messages.map((m) => _messageToJson(m)).toList();
      await _preferences.setString(_messagesKey, jsonEncode(jsonList));
    } catch (e) {
      _logger.e('Error saving message: $e');
    }
  }

  /// Load all messages from local storage
  Future<List<Message>> loadMessages() async {
    try {
      final jsonString = _preferences.getString(_messagesKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((j) => _messageFromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.e('Error loading messages: $e');
      return [];
    }
  }

  /// Clear all messages
  Future<void> clearMessages() async {
    try {
      await _preferences.remove(_messagesKey);
      _logger.i('Cleared all messages');
    } catch (e) {
      _logger.e('Error clearing messages: $e');
    }
  }

  Map<String, dynamic> _messageToJson(Message message) {
    return {
      'id': message.id,
      'from': message.from,
      'to': message.to,
      'text': message.text,
      'timestamp': message.timestamp.millisecondsSinceEpoch,
      'channel': message.channel,
      'sent': message.sent,
      'received': message.received,
      'acked': message.acked,
    };
  }

  Message _messageFromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      from: json['from'] as int,
      to: json['to'] as int,
      text: json['text'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      channel: json['channel'] as int?,
      sent: json['sent'] as bool? ?? false,
      received: json['received'] as bool? ?? false,
      acked: json['acked'] as bool? ?? false,
    );
  }
}
