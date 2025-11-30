import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../models/mesh_models.dart';

/// Service for handling local push notifications
/// Local notifications do NOT require APNs (Apple Push Notification service)
/// They are generated and displayed entirely on-device
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Android settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS settings - request permissions and enable foreground presentation
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      // Enable foreground notifications on iOS 10+
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    // macOS settings
    const macOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macOSSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Request permissions on iOS/macOS
    if (Platform.isIOS || Platform.isMacOS) {
      final iosPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        debugPrint('🔔 iOS notification permissions granted: $granted');
      }
    }

    // Request permissions on Android 13+
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await androidPlugin?.requestNotificationsPermission();
      debugPrint('🔔 Android notification permissions granted: $granted');
    }

    _initialized = true;
    debugPrint('🔔 NotificationService initialized successfully');
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Notification tapped: ${response.payload}');
    // Could navigate to nodes screen or specific node detail
  }

  /// Show notification for new node discovery
  Future<void> showNewNodeNotification(
    MeshNode node, {
    bool playSound = true,
    bool vibrate = true,
  }) async {
    if (!_initialized) {
      debugPrint(
        '🔔 NotificationService not initialized, skipping notification',
      );
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'new_nodes',
      'New Nodes',
      channelDescription: 'Notifications for newly discovered mesh nodes',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      groupKey: 'mesh_nodes',
      playSound: playSound,
      enableVibration: vibrate,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    final nodeName = node.displayName;
    final nodeId = node.userId ?? '!${node.nodeNum.toRadixString(16)}';

    // Use modulo to keep ID within 32-bit signed int range
    final notificationId = (node.nodeNum % 1000000).toInt();

    await _notifications.show(
      notificationId,
      'New Node Discovered',
      '$nodeName ($nodeId) joined the mesh',
      notificationDetails,
      payload: 'node:${node.nodeNum}',
    );

    debugPrint('🔔 Showed notification for node: $nodeName');
  }

  /// Show notification for new message
  Future<void> showNewMessageNotification({
    required String senderName,
    required String message,
    required int fromNodeNum,
    bool playSound = true,
    bool vibrate = true,
  }) async {
    debugPrint(
      '🔔 showNewMessageNotification called - initialized: $_initialized',
    );
    if (!_initialized) {
      debugPrint(
        '🔔 NotificationService not initialized, skipping DM notification',
      );
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'direct_messages',
      'Direct Messages',
      channelDescription: 'Notifications for direct mesh messages',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      groupKey: 'mesh_direct_messages',
      playSound: playSound,
      enableVibration: vibrate,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    // Truncate message if too long
    final truncatedMessage = message.length > 100
        ? '${message.substring(0, 100)}...'
        : message;

    debugPrint('🔔 Calling _notifications.show() for DM from $senderName');
    try {
      // Use modulo to keep ID within 32-bit signed int range
      // Offset by 1000000 to avoid collision with node notifications
      final notificationId = (fromNodeNum % 1000000) + 1000000;

      await _notifications.show(
        notificationId,
        'Message from $senderName',
        truncatedMessage,
        notificationDetails,
        payload: 'dm:$fromNodeNum',
      );
      debugPrint('🔔 Successfully showed DM notification from: $senderName');
    } catch (e) {
      debugPrint('🔔 Error showing DM notification: $e');
      rethrow;
    }
  }

  /// Show notification for channel message
  Future<void> showChannelMessageNotification({
    required String senderName,
    required String channelName,
    required String message,
    required int channelIndex,
    bool playSound = true,
    bool vibrate = true,
  }) async {
    if (!_initialized) return;

    final androidDetails = AndroidNotificationDetails(
      'channel_messages',
      'Channel Messages',
      channelDescription: 'Notifications for channel mesh messages',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      groupKey: 'mesh_channel_messages',
      playSound: playSound,
      enableVibration: vibrate,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    // Truncate message if too long
    final truncatedMessage = message.length > 100
        ? '${message.substring(0, 100)}...'
        : message;

    await _notifications.show(
      channelIndex + 2000000, // Channel indices are small, this is safe
      '$senderName in $channelName',
      truncatedMessage,
      notificationDetails,
      payload: 'channel:$channelIndex',
    );

    debugPrint('🔔 Showed channel notification: $senderName in $channelName');
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Cancel notification by ID
  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }
}
