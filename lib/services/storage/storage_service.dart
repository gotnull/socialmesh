import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../core/logging.dart';
import '../../models/mesh_models.dart';
import '../../models/canned_response.dart';
import '../../models/tapback.dart';
import '../../utils/text_sanitizer.dart';
import '../../utils/location_privacy.dart';

/// Secure storage service for sensitive data
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService()
    : _storage = const FlutterSecureStorage(
        aOptions: AndroidOptions(encryptedSharedPreferences: true),
      );

  /// Store channel key
  Future<void> storeChannelKey(String name, List<int> key) async {
    try {
      final keyString = base64Encode(key);
      await _storage.write(key: 'channel_$name', value: keyString);
      AppLogging.debug('Stored channel key: $name');
    } catch (e) {
      AppLogging.storage('⚠️ Error storing channel key: $e');
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
      AppLogging.storage('⚠️ Error retrieving channel key: $e');
      return null;
    }
  }

  /// Delete channel key
  Future<void> deleteChannelKey(String name) async {
    try {
      await _storage.delete(key: 'channel_$name');
      AppLogging.debug('Deleted channel key: $name');
    } catch (e) {
      AppLogging.storage('⚠️ Error deleting channel key: $e');
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
      AppLogging.storage('⚠️ Error getting all channel keys: $e');
      return {};
    }
  }

  /// Clear all data
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      AppLogging.storage('Cleared all secure storage');
    } catch (e) {
      AppLogging.storage('⚠️ Error clearing storage: $e');
    }
  }
}

/// Settings storage service
class SettingsService {
  SharedPreferences? _prefs;

  SettingsService();

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

  /// Reload preferences from disk to avoid stale reads.
  Future<void> reload() async {
    await _preferences.reload();
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

  /// Remove all saved device identifiers so we forget the pairing.
  Future<void> clearLastDevice() async {
    await _preferences.remove('last_device_id');
    await _preferences.remove('last_device_type');
    await _preferences.remove('last_device_name');
  }

  String? get lastDeviceId => _preferences.getString('last_device_id');
  String? get lastDeviceType => _preferences.getString('last_device_type');
  String? get lastDeviceName => _preferences.getString('last_device_name');

  // Last connected myNodeNum - used to detect device changes and clear stale data
  Future<void> setLastMyNodeNum(int? nodeNum) async {
    if (nodeNum != null) {
      await _preferences.setInt('last_my_node_num', nodeNum);
    } else {
      await _preferences.remove('last_my_node_num');
    }
  }

  int? get lastMyNodeNum => _preferences.getInt('last_my_node_num');

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

  // Theme Mode (0 = system, 1 = light, 2 = dark)
  Future<void> setThemeMode(int modeIndex) async {
    await _preferences.setInt('theme_mode', modeIndex);
  }

  int get themeMode => _preferences.getInt('theme_mode') ?? 2; // Default dark

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

  // Shake to report bug
  Future<void> setShakeToReportEnabled(bool enabled) async {
    await _preferences.setBool('shake_to_report_enabled', enabled);
  }

  bool get shakeToReportEnabled =>
      _preferences.getBool('shake_to_report_enabled') ?? true;

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

  // Debug: Mesh-only mode for signals (no cloud features)
  Future<void> setMeshOnlyDebugMode(bool enabled) async {
    await _preferences.setBool('mesh_only_debug_mode', enabled);
  }

  bool get meshOnlyDebugMode =>
      _preferences.getBool('mesh_only_debug_mode') ?? false;

  // Privacy: Signal location approximation radius (meters)
  Future<void> setSignalLocationRadiusMeters(int meters) async {
    final normalized = LocationPrivacy.normalizeRadiusMeters(meters);
    await _preferences.setInt('signal_location_radius_meters', normalized);
  }

  int get signalLocationRadiusMeters =>
      _preferences.getInt('signal_location_radius_meters') ??
      kDefaultSignalLocationRadiusMeters;

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

  // Map tile style (index in MapTileStyle enum)
  Future<void> setMapTileStyleIndex(int index) async {
    await _preferences.setInt('map_tile_style_index', index);
  }

  int get mapTileStyleIndex =>
      _preferences.getInt('map_tile_style_index') ?? 0;

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
    AppLogging.storage('Cleared all settings');
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
      AppLogging.storage('⚠️ Error parsing canned responses: $e');
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

  // Tapback configuration
  Future<void> setTapbackConfigs(List<TapbackConfig> configs) async {
    final jsonList = configs.map((c) => c.toJson()).toList();
    await _preferences.setString('tapback_configs', jsonEncode(jsonList));
  }

  List<TapbackConfig> get tapbackConfigs {
    final jsonString = _preferences.getString('tapback_configs');
    if (jsonString == null) {
      return DefaultTapbacks.all;
    }
    try {
      final jsonList = jsonDecode(jsonString) as List;
      final configs = jsonList.map((j) => TapbackConfig.fromJson(j)).toList();
      configs.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      return configs;
    } catch (e) {
      AppLogging.storage('⚠️ Error parsing tapback configs: $e');
      return DefaultTapbacks.all;
    }
  }

  /// Get only enabled tapbacks
  List<TapbackConfig> get enabledTapbacks =>
      tapbackConfigs.where((c) => c.enabled).toList();

  Future<void> updateTapbackConfig(TapbackConfig config) async {
    final configs = tapbackConfigs;
    final index = configs.indexWhere((c) => c.id == config.id);
    if (index >= 0) {
      configs[index] = config;
      await setTapbackConfigs(configs);
    }
  }

  Future<void> reorderTapbacks(int oldIndex, int newIndex) async {
    final configs = tapbackConfigs;
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = configs.removeAt(oldIndex);
    configs.insert(newIndex, item);
    // Update sort orders
    for (int i = 0; i < configs.length; i++) {
      configs[i] = configs[i].copyWith(sortOrder: i);
    }
    await setTapbackConfigs(configs);
  }

  Future<void> resetTapbacksToDefaults() async {
    await _preferences.remove('tapback_configs');
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
    required bool useAccelerometer,
    required double accelerometerSensitivity,
    required double accelerometerFriction,
    String physicsMode = 'momentum',
    bool enableTouch = true,
    bool enablePullToStretch = false,
    double touchIntensity = 0.5,
    double stretchIntensity = 0.3,
  }) async {
    await _preferences.setDouble('splash_mesh_size', size);
    await _preferences.setString('splash_mesh_animation_type', animationType);
    await _preferences.setDouble('splash_mesh_glow_intensity', glowIntensity);
    await _preferences.setDouble('splash_mesh_line_thickness', lineThickness);
    await _preferences.setDouble('splash_mesh_node_size', nodeSize);
    // Color is now controlled by accent color in Theme settings
    await _preferences.setBool(
      'splash_mesh_use_accelerometer',
      useAccelerometer,
    );
    await _preferences.setDouble(
      'splash_mesh_accel_sensitivity',
      accelerometerSensitivity,
    );
    await _preferences.setDouble(
      'splash_mesh_accel_friction',
      accelerometerFriction,
    );
    await _preferences.setString('splash_mesh_physics_mode', physicsMode);
    await _preferences.setBool('splash_mesh_enable_touch', enableTouch);
    await _preferences.setBool(
      'splash_mesh_enable_pull_to_stretch',
      enablePullToStretch,
    );
    await _preferences.setDouble('splash_mesh_touch_intensity', touchIntensity);
    await _preferences.setDouble(
      'splash_mesh_stretch_intensity',
      stretchIntensity,
    );
  }

  double get splashMeshSize =>
      _preferences.getDouble('splash_mesh_size') ?? 600;
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
      _preferences.getDouble('splash_mesh_accel_sensitivity') ?? 0.5;
  double get splashMeshAccelFriction =>
      _preferences.getDouble('splash_mesh_accel_friction') ?? 0.97;
  String get splashMeshPhysicsMode =>
      _preferences.getString('splash_mesh_physics_mode') ?? 'momentum';
  bool get splashMeshEnableTouch =>
      _preferences.getBool('splash_mesh_enable_touch') ?? true;
  bool get splashMeshEnablePullToStretch =>
      _preferences.getBool('splash_mesh_enable_pull_to_stretch') ?? false;
  double get splashMeshTouchIntensity =>
      _preferences.getDouble('splash_mesh_touch_intensity') ?? 0.5;
  double get splashMeshStretchIntensity =>
      _preferences.getDouble('splash_mesh_stretch_intensity') ?? 0.3;

  Future<void> resetSplashMeshConfig() async {
    await _preferences.remove('splash_mesh_size');
    await _preferences.remove('splash_mesh_animation_type');
    await _preferences.remove('splash_mesh_glow_intensity');
    await _preferences.remove('splash_mesh_line_thickness');
    await _preferences.remove('splash_mesh_node_size');
    await _preferences.remove('splash_mesh_color_preset');
    await _preferences.remove('splash_mesh_use_accelerometer');
    await _preferences.remove('splash_mesh_accel_sensitivity');
    await _preferences.remove('splash_mesh_accel_friction');
    await _preferences.remove('splash_mesh_physics_mode');
    await _preferences.remove('splash_mesh_enable_touch');
    await _preferences.remove('splash_mesh_enable_pull_to_stretch');
    await _preferences.remove('splash_mesh_touch_intensity');
    await _preferences.remove('splash_mesh_stretch_intensity');
  }
}

/// Device favorites storage service - persists favorite node numbers
/// independently of node data so favorites survive device reconnects/clears
class DeviceFavoritesService {
  SharedPreferences? _prefs;
  static const String _favoritesKey = 'device_favorites';
  static const String _ignoredKey = 'device_ignored';

  DeviceFavoritesService();

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw Exception('DeviceFavoritesService not initialized');
    }
    return _prefs!;
  }

  /// Get all favorite node numbers
  Set<int> get favorites {
    final list = _preferences.getStringList(_favoritesKey) ?? [];
    return list.map((s) => int.parse(s)).toSet();
  }

  /// Check if a node is favorite
  bool isFavorite(int nodeNum) => favorites.contains(nodeNum);

  /// Add a node to favorites
  Future<void> addFavorite(int nodeNum) async {
    final set = favorites;
    set.add(nodeNum);
    await _preferences.setStringList(
      _favoritesKey,
      set.map((n) => n.toString()).toList(),
    );
    AppLogging.debug('Added node $nodeNum to favorites');
  }

  /// Remove a node from favorites
  Future<void> removeFavorite(int nodeNum) async {
    final set = favorites;
    set.remove(nodeNum);
    await _preferences.setStringList(
      _favoritesKey,
      set.map((n) => n.toString()).toList(),
    );
    AppLogging.debug('Removed node $nodeNum from favorites');
  }

  /// Get all ignored node numbers
  Set<int> get ignored {
    final list = _preferences.getStringList(_ignoredKey) ?? [];
    return list.map((s) => int.parse(s)).toSet();
  }

  /// Check if a node is ignored
  bool isIgnored(int nodeNum) => ignored.contains(nodeNum);

  /// Add a node to ignored list
  Future<void> addIgnored(int nodeNum) async {
    final set = ignored;
    set.add(nodeNum);
    await _preferences.setStringList(
      _ignoredKey,
      set.map((n) => n.toString()).toList(),
    );
    AppLogging.debug('Added node $nodeNum to ignored');
  }

  /// Remove a node from ignored list
  Future<void> removeIgnored(int nodeNum) async {
    final set = ignored;
    set.remove(nodeNum);
    await _preferences.setStringList(
      _ignoredKey,
      set.map((n) => n.toString()).toList(),
    );
    AppLogging.debug('Removed node $nodeNum from ignored');
  }

  /// Clear all favorites (used when switching devices)
  Future<void> clearAll() async {
    await _preferences.remove(_favoritesKey);
    await _preferences.remove(_ignoredKey);
    AppLogging.storage('Cleared all device favorites and ignored');
  }
}

/// Message storage service - persists messages locally
class MessageStorageService {
  SharedPreferences? _prefs;
  static const String _messagesKey = 'messages';
  static const int _maxMessages = 500;

  MessageStorageService();

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

      // Check for existing message with same ID to prevent duplicates
      final existingIndex = messages.indexWhere((m) => m.id == message.id);
      if (existingIndex >= 0) {
        // Update existing message instead of adding duplicate
        messages[existingIndex] = message;
        AppLogging.storage(
          'Saved message (updated): ${message.id}, from=${message.from}, to=${message.to}',
        );
      } else {
        messages.add(message);
        AppLogging.storage(
          'Saved message (new): ${message.id}, from=${message.from}, to=${message.to}',
        );
      }

      // Trim to max messages
      if (messages.length > _maxMessages) {
        messages.removeRange(0, messages.length - _maxMessages);
      }

      final jsonList = messages.map((m) => _messageToJson(m)).toList();
      await _preferences.setString(_messagesKey, jsonEncode(jsonList));
    } catch (e) {
      AppLogging.storage('⚠️ Error saving message: $e');
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
      final messages = jsonList
          .map((j) => _messageFromJson(j as Map<String, dynamic>))
          .toList();

      // Deduplicate by ID (handles legacy duplicates in storage)
      final seen = <String>{};
      final deduped = <Message>[];
      for (final msg in messages) {
        if (!seen.contains(msg.id)) {
          seen.add(msg.id);
          deduped.add(msg);
        }
      }

      // If duplicates were found, save the cleaned list
      if (deduped.length < messages.length) {
        AppLogging.storage(
          'Removed ${messages.length - deduped.length} duplicate messages',
        );
        final jsonList = deduped.map((m) => _messageToJson(m)).toList();
        await _preferences.setString(_messagesKey, jsonEncode(jsonList));
      }

      return deduped;
    } catch (e) {
      AppLogging.storage('⚠️ Error loading messages: $e');
      return [];
    }
  }

  /// Count messages for a given node (either from or to the node)
  Future<int> countMessagesForNode(int nodeNum, {int? sinceMillis}) async {
    final messages = await loadMessages();
    final cutoff = sinceMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(sinceMillis)
        : null;
    return messages.where((m) {
      final inScope = m.from == nodeNum || m.to == nodeNum;
      final after = cutoff == null ? true : m.timestamp.isAfter(cutoff);
      return inScope && after;
    }).length;
  }

  /// Load messages for a given node (from or to the node), optionally since a timestamp
  Future<List<Message>> loadMessagesForNode(
    int nodeNum, {
    int? sinceMillis,
  }) async {
    final messages = await loadMessages();
    final cutoff = sinceMillis != null
        ? DateTime.fromMillisecondsSinceEpoch(sinceMillis)
        : null;
    return messages.where((m) {
      final inScope = m.from == nodeNum || m.to == nodeNum;
      final after = cutoff == null ? true : m.timestamp.isAfter(cutoff);
      return inScope && after;
    }).toList();
  }

  /// Delete a specific message by ID
  Future<void> deleteMessage(String messageId) async {
    try {
      final messages = await loadMessages();
      messages.removeWhere((m) => m.id == messageId);
      final jsonList = messages.map((m) => _messageToJson(m)).toList();
      await _preferences.setString(_messagesKey, jsonEncode(jsonList));
      AppLogging.storage('Deleted message: $messageId');
    } catch (e) {
      AppLogging.storage('⚠️ Error deleting message: $e');
    }
  }

  /// Clear all messages
  Future<void> clearMessages() async {
    try {
      await _preferences.remove(_messagesKey);
      AppLogging.storage('Cleared all messages');
    } catch (e) {
      AppLogging.storage('⚠️ Error clearing messages: $e');
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
      // Sender info cache
      'senderLongName': message.senderLongName,
      'senderShortName': message.senderShortName,
      'senderAvatarColor': message.senderAvatarColor,
    };
  }

  Message _messageFromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      from: json['from'] as int,
      to: json['to'] as int,
      text: sanitizeUtf16(json['text'] as String),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      channel: json['channel'] as int?,
      sent: json['sent'] as bool? ?? false,
      received: json['received'] as bool? ?? false,
      acked: json['acked'] as bool? ?? false,
      source: _parseMessageSource(json['source'] as String?),
      // Sender info cache
      senderLongName: json['senderLongName'] != null
          ? sanitizeUtf16(json['senderLongName'] as String)
          : null,
      senderShortName: json['senderShortName'] != null
          ? sanitizeUtf16(json['senderShortName'] as String)
          : null,
      senderAvatarColor: json['senderAvatarColor'] as int?,
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
  SharedPreferences? _prefs;
  static const String _nodesKey = 'nodes';

  NodeStorageService();

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
        // Preserve firstHeard from existing node
        if (nodes[index].firstHeard != null && node.firstHeard == null) {
          node = node.copyWith(firstHeard: nodes[index].firstHeard);
        }
        nodes[index] = node;
      } else {
        // New node - set firstHeard to now if not already set
        if (node.firstHeard == null) {
          node = node.copyWith(firstHeard: DateTime.now());
        }
        nodes.add(node);
      }

      final jsonList = nodes.map((n) => _nodeToJson(n)).toList();
      await _preferences.setString(_nodesKey, jsonEncode(jsonList));
      AppLogging.debug('Saved node ${node.nodeNum} to storage');
    } catch (e) {
      AppLogging.storage('⚠️ Error saving node: $e');
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

      // Update with new nodes, preserving positions and firstHeard when needed
      for (var node in nodesToSave) {
        final existing = nodeMap[node.nodeNum];
        if (existing != null) {
          // Preserve position if new node doesn't have one
          if (!node.hasPosition && existing.hasPosition) {
            node = node.copyWith(
              latitude: existing.latitude,
              longitude: existing.longitude,
              altitude: existing.altitude,
            );
          }
          // Preserve firstHeard from existing node
          if (existing.firstHeard != null && node.firstHeard == null) {
            node = node.copyWith(firstHeard: existing.firstHeard);
          }
        } else {
          // New node - set firstHeard to now if not already set
          if (node.firstHeard == null) {
            node = node.copyWith(firstHeard: DateTime.now());
          }
        }
        nodeMap[node.nodeNum] = node;
      }

      final jsonList = nodeMap.values.map((n) => _nodeToJson(n)).toList();
      await _preferences.setString(_nodesKey, jsonEncode(jsonList));
      AppLogging.debug('Saved ${nodesToSave.length} nodes to storage');
    } catch (e) {
      AppLogging.storage('⚠️ Error saving nodes: $e');
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
      AppLogging.storage('⚠️ Error loading nodes: $e');
      return [];
    }
  }

  /// Get a specific node from storage
  Future<MeshNode?> getNode(int nodeNum) async {
    try {
      final nodes = await loadNodes();
      return nodes.where((n) => n.nodeNum == nodeNum).firstOrNull;
    } catch (e) {
      AppLogging.storage('⚠️ Error getting node: $e');
      return null;
    }
  }

  /// Clear all nodes
  Future<void> clearNodes() async {
    try {
      await _preferences.remove(_nodesKey);
      AppLogging.storage('Cleared all nodes');
    } catch (e) {
      AppLogging.storage('⚠️ Error clearing nodes: $e');
    }
  }

  /// Delete a specific node from storage
  Future<void> deleteNode(int nodeNum) async {
    try {
      final nodes = await loadNodes();
      nodes.removeWhere((n) => n.nodeNum == nodeNum);
      final jsonList = nodes.map((n) => _nodeToJson(n)).toList();
      await _preferences.setString(_nodesKey, jsonEncode(jsonList));
      AppLogging.storage('Deleted node $nodeNum from storage');
    } catch (e) {
      AppLogging.storage('⚠️ Error deleting node $nodeNum: $e');
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
      'firstHeard': node.firstHeard?.millisecondsSinceEpoch,
      'avatarColor': node.avatarColor,
      'role': node.role,
      'isFavorite': node.isFavorite,
      'isIgnored': node.isIgnored,
      'distance': node.distance,
      'hasPublicKey': node.hasPublicKey,
    };
  }

  MeshNode _nodeFromJson(Map<String, dynamic> json) {
    // Sanitize string fields to prevent UTF-16 crashes when rendering text
    final rawLongName = json['longName'] as String?;
    final rawShortName = json['shortName'] as String?;

    return MeshNode(
      nodeNum: json['nodeNum'] as int,
      longName: rawLongName != null ? sanitizeUtf16(rawLongName) : null,
      shortName: rawShortName != null ? sanitizeUtf16(rawShortName) : null,
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
      firstHeard: json['firstHeard'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['firstHeard'] as int)
          : null,
      avatarColor: json['avatarColor'] as int? ?? 0xFF1976D2,
      role: json['role'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      isIgnored: json['isIgnored'] as bool? ?? false,
      distance: (json['distance'] as num?)?.toDouble(),
      hasPublicKey: json['hasPublicKey'] as bool? ?? false,
    );
  }
}
