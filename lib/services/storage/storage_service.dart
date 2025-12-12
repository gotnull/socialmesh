import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'dart:convert';
import '../../models/mesh_models.dart';
import '../../models/canned_response.dart';

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
  Future<void> setLastDevice(
    String deviceId,
    String deviceType, {
    String? deviceName,
  }) async {
    await _preferences.setString('last_device_id', deviceId);
    await _preferences.setString('last_device_type', deviceType);
    if (deviceName != null) {
      await _preferences.setString('last_device_name', deviceName);
    }
  }

  String? get lastDeviceId => _preferences.getString('last_device_id');
  String? get lastDeviceType => _preferences.getString('last_device_type');
  String? get lastDeviceName => _preferences.getString('last_device_name');

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

  // Accent Color
  Future<void> setAccentColor(int colorValue) async {
    await _preferences.setInt('accent_color', colorValue);
  }

  int get accentColor =>
      _preferences.getInt('accent_color') ?? 0xFFE91E8C; // Default magenta

  // Notifications - Master toggle
  Future<void> setNotificationsEnabled(bool enabled) async {
    await _preferences.setBool('notifications_enabled', enabled);
  }

  bool get notificationsEnabled =>
      _preferences.getBool('notifications_enabled') ?? true;

  // Notification: New Nodes
  Future<void> setNewNodeNotificationsEnabled(bool enabled) async {
    await _preferences.setBool('new_node_notifications_enabled', enabled);
  }

  bool get newNodeNotificationsEnabled =>
      _preferences.getBool('new_node_notifications_enabled') ?? true;

  // Notification: Direct Messages
  Future<void> setDirectMessageNotificationsEnabled(bool enabled) async {
    await _preferences.setBool('dm_notifications_enabled', enabled);
  }

  bool get directMessageNotificationsEnabled =>
      _preferences.getBool('dm_notifications_enabled') ?? true;

  // Notification: Channel Messages
  Future<void> setChannelMessageNotificationsEnabled(bool enabled) async {
    await _preferences.setBool('channel_notifications_enabled', enabled);
  }

  bool get channelMessageNotificationsEnabled =>
      _preferences.getBool('channel_notifications_enabled') ?? true;

  // Notification: Sound
  Future<void> setNotificationSoundEnabled(bool enabled) async {
    await _preferences.setBool('notification_sound_enabled', enabled);
  }

  bool get notificationSoundEnabled =>
      _preferences.getBool('notification_sound_enabled') ?? true;

  // Notification: Vibration
  Future<void> setNotificationVibrationEnabled(bool enabled) async {
    await _preferences.setBool('notification_vibration_enabled', enabled);
  }

  bool get notificationVibrationEnabled =>
      _preferences.getBool('notification_vibration_enabled') ?? true;

  // Haptic Feedback Settings
  Future<void> setHapticFeedbackEnabled(bool enabled) async {
    await _preferences.setBool('haptic_feedback_enabled', enabled);
  }

  bool get hapticFeedbackEnabled =>
      _preferences.getBool('haptic_feedback_enabled') ?? true;

  // Haptic Feedback Intensity: 0 = light, 1 = medium, 2 = heavy
  Future<void> setHapticIntensity(int intensity) async {
    await _preferences.setInt('haptic_intensity', intensity.clamp(0, 2));
  }

  int get hapticIntensity => _preferences.getInt('haptic_intensity') ?? 1;

  // Animations Enabled
  Future<void> setAnimationsEnabled(bool enabled) async {
    await _preferences.setBool('animations_enabled', enabled);
  }

  bool get animationsEnabled =>
      _preferences.getBool('animations_enabled') ?? true;

  // 3D Animations Enabled
  Future<void> setAnimations3DEnabled(bool enabled) async {
    await _preferences.setBool('animations_3d_enabled', enabled);
  }

  bool get animations3DEnabled =>
      _preferences.getBool('animations_3d_enabled') ?? true;

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

  // Region configuration (tracks if region has ever been set)
  Future<void> setRegionConfigured(bool configured) async {
    await _preferences.setBool('region_configured', configured);
  }

  bool get regionConfigured =>
      _preferences.getBool('region_configured') ?? false;

  // Canned responses
  Future<void> setCannedResponses(List<CannedResponse> responses) async {
    final jsonList = responses.map((r) => r.toJson()).toList();
    await _preferences.setString('canned_responses', jsonEncode(jsonList));
  }

  List<CannedResponse> get cannedResponses {
    final jsonString = _preferences.getString('canned_responses');
    if (jsonString == null) {
      return DefaultCannedResponses.all;
    }
    try {
      final jsonList = jsonDecode(jsonString) as List;
      final responses = jsonList
          .map((j) => CannedResponse.fromJson(j))
          .toList();
      responses.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return responses;
    } catch (e) {
      _logger.e('Error parsing canned responses: $e');
      return DefaultCannedResponses.all;
    }
  }

  Future<void> addCannedResponse(CannedResponse response) async {
    final responses = cannedResponses;
    final newResponse = response.copyWith(sortOrder: responses.length);
    responses.add(newResponse);
    await setCannedResponses(responses);
  }

  Future<void> updateCannedResponse(CannedResponse response) async {
    final responses = cannedResponses;
    final index = responses.indexWhere((r) => r.id == response.id);
    if (index >= 0) {
      responses[index] = response;
      await setCannedResponses(responses);
    }
  }

  Future<void> deleteCannedResponse(String id) async {
    final responses = cannedResponses;
    responses.removeWhere((r) => r.id == id);
    // Reorder
    for (int i = 0; i < responses.length; i++) {
      responses[i] = responses[i].copyWith(sortOrder: i);
    }
    await setCannedResponses(responses);
  }

  Future<void> reorderCannedResponses(int oldIndex, int newIndex) async {
    final responses = cannedResponses;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = responses.removeAt(oldIndex);
    responses.insert(newIndex, item);
    // Update sort orders
    for (int i = 0; i < responses.length; i++) {
      responses[i] = responses[i].copyWith(sortOrder: i);
    }
    await setCannedResponses(responses);
  }

  Future<void> resetCannedResponsesToDefaults() async {
    await _preferences.remove('canned_responses');
  }

  // Ringtone settings
  Future<void> setSelectedRingtone({
    required String rtttl,
    required String name,
    String? description,
    String? source,
  }) async {
    await _preferences.setString('ringtone_rtttl', rtttl);
    await _preferences.setString('ringtone_name', name);
    if (description != null) {
      await _preferences.setString('ringtone_description', description);
    } else {
      await _preferences.remove('ringtone_description');
    }
    if (source != null) {
      await _preferences.setString('ringtone_source', source);
    } else {
      await _preferences.remove('ringtone_source');
    }
  }

  String? get selectedRingtoneRtttl => _preferences.getString('ringtone_rtttl');
  String? get selectedRingtoneName => _preferences.getString('ringtone_name');
  String? get selectedRingtoneDescription =>
      _preferences.getString('ringtone_description');
  String? get selectedRingtoneSource =>
      _preferences.getString('ringtone_source');

  Future<void> clearSelectedRingtone() async {
    await _preferences.remove('ringtone_rtttl');
    await _preferences.remove('ringtone_name');
    await _preferences.remove('ringtone_description');
    await _preferences.remove('ringtone_source');
  }

  // Splash Mesh Node Configuration
  Future<void> setSplashMeshConfig({
    required double size,
    required String animationType,
    required double glowIntensity,
    required double lineThickness,
    required double nodeSize,
    required int colorPreset,
    required bool useAccelerometer,
    required double accelerometerSensitivity,
    required double accelerometerSmoothing,
  }) async {
    await _preferences.setDouble('splash_mesh_size', size);
    await _preferences.setString('splash_mesh_animation_type', animationType);
    await _preferences.setDouble('splash_mesh_glow_intensity', glowIntensity);
    await _preferences.setDouble('splash_mesh_line_thickness', lineThickness);
    await _preferences.setDouble('splash_mesh_node_size', nodeSize);
    await _preferences.setInt('splash_mesh_color_preset', colorPreset);
    await _preferences.setBool(
      'splash_mesh_use_accelerometer',
      useAccelerometer,
    );
    await _preferences.setDouble(
      'splash_mesh_accel_sensitivity',
      accelerometerSensitivity,
    );
    await _preferences.setDouble(
      'splash_mesh_accel_smoothing',
      accelerometerSmoothing,
    );
  }

  double get splashMeshSize =>
      _preferences.getDouble('splash_mesh_size') ?? 300;
  String get splashMeshAnimationType =>
      _preferences.getString('splash_mesh_animation_type') ?? 'tumble';
  double get splashMeshGlowIntensity =>
      _preferences.getDouble('splash_mesh_glow_intensity') ?? 0.5;
  double get splashMeshLineThickness =>
      _preferences.getDouble('splash_mesh_line_thickness') ?? 0.5;
  double get splashMeshNodeSize =>
      _preferences.getDouble('splash_mesh_node_size') ?? 0.8;
  int get splashMeshColorPreset =>
      _preferences.getInt('splash_mesh_color_preset') ?? 0;
  bool get splashMeshUseAccelerometer =>
      _preferences.getBool('splash_mesh_use_accelerometer') ?? true;
  double get splashMeshAccelSensitivity =>
      _preferences.getDouble('splash_mesh_accel_sensitivity') ?? 1.0;
  double get splashMeshAccelSmoothing =>
      _preferences.getDouble('splash_mesh_accel_smoothing') ?? 0.8;

  Future<void> resetSplashMeshConfig() async {
    await _preferences.remove('splash_mesh_size');
    await _preferences.remove('splash_mesh_animation_type');
    await _preferences.remove('splash_mesh_glow_intensity');
    await _preferences.remove('splash_mesh_line_thickness');
    await _preferences.remove('splash_mesh_node_size');
    await _preferences.remove('splash_mesh_color_preset');
    await _preferences.remove('splash_mesh_use_accelerometer');
    await _preferences.remove('splash_mesh_accel_sensitivity');
    await _preferences.remove('splash_mesh_accel_smoothing');
  }
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
      'source': message.source.name,
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
      source: _parseMessageSource(json['source'] as String?),
    );
  }

  MessageSource _parseMessageSource(String? name) {
    if (name == null) return MessageSource.unknown;
    return MessageSource.values.firstWhere(
      (e) => e.name == name,
      orElse: () => MessageSource.unknown,
    );
  }
}

/// Node storage service - persists nodes and positions locally
class NodeStorageService {
  final Logger _logger;
  SharedPreferences? _prefs;
  static const String _nodesKey = 'nodes';

  NodeStorageService({Logger? logger}) : _logger = logger ?? Logger();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw Exception('NodeStorageService not initialized');
    }
    return _prefs!;
  }

  /// Save a node to local storage
  Future<void> saveNode(MeshNode node) async {
    try {
      final nodes = await loadNodes();
      // Update existing node or add new
      final index = nodes.indexWhere((n) => n.nodeNum == node.nodeNum);
      if (index >= 0) {
        // Preserve position if new node doesn't have one
        if (!node.hasPosition && nodes[index].hasPosition) {
          node = node.copyWith(
            latitude: nodes[index].latitude,
            longitude: nodes[index].longitude,
            altitude: nodes[index].altitude,
          );
        }
        nodes[index] = node;
      } else {
        nodes.add(node);
      }

      final jsonList = nodes.map((n) => _nodeToJson(n)).toList();
      await _preferences.setString(_nodesKey, jsonEncode(jsonList));
      _logger.d('Saved node ${node.nodeNum} to storage');
    } catch (e) {
      _logger.e('Error saving node: $e');
    }
  }

  /// Save multiple nodes to local storage
  Future<void> saveNodes(List<MeshNode> nodesToSave) async {
    try {
      final existingNodes = await loadNodes();
      final nodeMap = <int, MeshNode>{};

      // Start with existing nodes
      for (final node in existingNodes) {
        nodeMap[node.nodeNum] = node;
      }

      // Update with new nodes, preserving positions when needed
      for (var node in nodesToSave) {
        final existing = nodeMap[node.nodeNum];
        if (existing != null && !node.hasPosition && existing.hasPosition) {
          node = node.copyWith(
            latitude: existing.latitude,
            longitude: existing.longitude,
            altitude: existing.altitude,
          );
        }
        nodeMap[node.nodeNum] = node;
      }

      final jsonList = nodeMap.values.map((n) => _nodeToJson(n)).toList();
      await _preferences.setString(_nodesKey, jsonEncode(jsonList));
      _logger.d('Saved ${nodesToSave.length} nodes to storage');
    } catch (e) {
      _logger.e('Error saving nodes: $e');
    }
  }

  /// Load all nodes from local storage
  Future<List<MeshNode>> loadNodes() async {
    try {
      final jsonString = _preferences.getString(_nodesKey);
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final jsonList = jsonDecode(jsonString) as List;
      return jsonList
          .map((j) => _nodeFromJson(j as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _logger.e('Error loading nodes: $e');
      return [];
    }
  }

  /// Get a specific node from storage
  Future<MeshNode?> getNode(int nodeNum) async {
    try {
      final nodes = await loadNodes();
      return nodes.where((n) => n.nodeNum == nodeNum).firstOrNull;
    } catch (e) {
      _logger.e('Error getting node: $e');
      return null;
    }
  }

  /// Clear all nodes
  Future<void> clearNodes() async {
    try {
      await _preferences.remove(_nodesKey);
      _logger.i('Cleared all nodes');
    } catch (e) {
      _logger.e('Error clearing nodes: $e');
    }
  }

  Map<String, dynamic> _nodeToJson(MeshNode node) {
    return {
      'nodeNum': node.nodeNum,
      'longName': node.longName,
      'shortName': node.shortName,
      'userId': node.userId,
      'hardwareModel': node.hardwareModel,
      'latitude': node.latitude,
      'longitude': node.longitude,
      'altitude': node.altitude,
      'batteryLevel': node.batteryLevel,
      'snr': node.snr,
      'rssi': node.rssi,
      'firmwareVersion': node.firmwareVersion,
      'lastHeard': node.lastHeard?.millisecondsSinceEpoch,
      'isOnline': node.isOnline,
      'avatarColor': node.avatarColor,
      'role': node.role,
      'isFavorite': node.isFavorite,
      'distance': node.distance,
      'hasPublicKey': node.hasPublicKey,
    };
  }

  MeshNode _nodeFromJson(Map<String, dynamic> json) {
    return MeshNode(
      nodeNum: json['nodeNum'] as int,
      longName: json['longName'] as String?,
      shortName: json['shortName'] as String?,
      userId: json['userId'] as String?,
      hardwareModel: json['hardwareModel'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      altitude: json['altitude'] as int?,
      batteryLevel: json['batteryLevel'] as int?,
      snr: json['snr'] as int?,
      rssi: json['rssi'] as int?,
      firmwareVersion: json['firmwareVersion'] as String?,
      lastHeard: json['lastHeard'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['lastHeard'] as int)
          : null,
      isOnline: json['isOnline'] as bool? ?? false,
      avatarColor: json['avatarColor'] as int? ?? 0xFF1976D2,
      role: json['role'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      distance: (json['distance'] as num?)?.toDouble(),
      hasPublicKey: json['hasPublicKey'] as bool? ?? false,
    );
  }
}
