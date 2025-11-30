import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../models/mesh_models.dart';

/// Notification action identifiers
class NotificationActions {
  static const String thumbsUp = 'THUMBS_UP';
  static const String thumbsDown = 'THUMBS_DOWN';
  static const String messageCategory = 'MESSAGE_CATEGORY';
}

/// Callback type for sending reaction messages
typedef ReactionCallback = Future<void> Function(int toNodeNum, String emoji);

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

  /// Callback to send reaction messages back to senders
  ReactionCallback? onReactionSelected;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;

    // Define notification actions for iOS
    final thumbsUpAction = DarwinNotificationAction.plain(
      NotificationActions.thumbsUp,
      '👍',
      options: <DarwinNotificationActionOption>{
        DarwinNotificationActionOption.foreground,
      },
    );

    final thumbsDownAction = DarwinNotificationAction.plain(
      NotificationActions.thumbsDown,
      '👎',
      options: <DarwinNotificationActionOption>{
        DarwinNotificationActionOption.foreground,
      },
    );

    // Define the message category with reaction actions
    final messageCategory = DarwinNotificationCategory(
      NotificationActions.messageCategory,
      actions: <DarwinNotificationAction>[thumbsUpAction, thumbsDownAction],
      options: <DarwinNotificationCategoryOption>{
        DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
      },
    );

    // Android settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS settings - request permissions and enable foreground presentation
    final iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      // Enable foreground notifications on iOS 10+
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
      notificationCategories: <DarwinNotificationCategory>[messageCategory],
    );

    // macOS settings
    final macOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
      notificationCategories: <DarwinNotificationCategory>[messageCategory],
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      macOS: macOSSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
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

  /// Handle notification tap or action
  void _onNotificationResponse(NotificationResponse response) {
    debugPrint(
      '🔔 Notification response: action=${response.actionId}, payload=${response.payload}',
    );

    final actionId = response.actionId;
    final payload = response.payload;

    // Handle reaction actions
    if (actionId == NotificationActions.thumbsUp ||
        actionId == NotificationActions.thumbsDown) {
      final emoji = actionId == NotificationActions.thumbsUp ? '👍' : '👎';
      _handleReactionAction(payload, emoji);
      return;
    }

    // Handle regular notification tap - could navigate to specific screen
    if (payload != null) {
      debugPrint('🔔 Notification tapped with payload: $payload');
      // Could navigate to nodes screen, message thread, etc.
    }
  }

  /// Handle a reaction action from notification
  void _handleReactionAction(String? payload, String emoji) {
    if (payload == null) {
      debugPrint('🔔 Reaction action without payload, ignoring');
      return;
    }

    // Parse payload to get node number
    // Payload format: "dm:nodeNum" or "channel:channelIndex:nodeNum"
    int? nodeNum;

    if (payload.startsWith('dm:')) {
      nodeNum = int.tryParse(payload.substring(3));
    } else if (payload.startsWith('channel:')) {
      // For channel messages, payload is "channel:index:nodeNum"
      final parts = payload.split(':');
      if (parts.length >= 3) {
        nodeNum = int.tryParse(parts[2]);
      }
    }

    if (nodeNum == null) {
      debugPrint('🔔 Could not parse node number from payload: $payload');
      return;
    }

    debugPrint('🔔 Sending $emoji reaction to node $nodeNum');

    // Call the reaction callback if set
    if (onReactionSelected != null) {
      onReactionSelected!(nodeNum, emoji);
    } else {
      debugPrint('🔔 No reaction callback set, cannot send reaction');
    }
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
    // Use short name (4-char code) if available, otherwise last 4 hex digits
    final shortCode =
        node.shortName ??
        node.nodeNum
            .toRadixString(16)
            .substring(node.nodeNum.toRadixString(16).length - 4)
            .toUpperCase();

    // Use modulo to keep ID within 32-bit signed int range
    final notificationId = (node.nodeNum % 1000000).toInt();

    await _notifications.show(
      notificationId,
      'New Node Discovered',
      '$nodeName ($shortCode) joined the mesh',
      notificationDetails,
      payload: 'node:${node.nodeNum}',
    );

    debugPrint('🔔 Showed notification for node: $nodeName');
  }

  /// Show notification for new message
  Future<void> showNewMessageNotification({
    required String senderName,
    required String? senderShortName,
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
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          NotificationActions.thumbsUp,
          '👍',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          NotificationActions.thumbsDown,
          '👎',
          showsUserInterface: true,
        ),
      ],
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
      categoryIdentifier: NotificationActions.messageCategory,
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

      // Use short name (4-char code) if available, otherwise last 4 hex digits
      final shortCode =
          senderShortName ??
          fromNodeNum
              .toRadixString(16)
              .substring(fromNodeNum.toRadixString(16).length - 4)
              .toUpperCase();

      await _notifications.show(
        notificationId,
        'Message from $senderName ($shortCode)',
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
    required String? senderShortName,
    required String channelName,
    required String message,
    required int channelIndex,
    required int fromNodeNum,
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
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          NotificationActions.thumbsUp,
          '👍',
          showsUserInterface: true,
        ),
        const AndroidNotificationAction(
          NotificationActions.thumbsDown,
          '👎',
          showsUserInterface: true,
        ),
      ],
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
      categoryIdentifier: NotificationActions.messageCategory,
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

    // Use short name (4-char code) if available, otherwise last 4 hex digits
    final shortCode =
        senderShortName ??
        fromNodeNum
            .toRadixString(16)
            .substring(fromNodeNum.toRadixString(16).length - 4)
            .toUpperCase();

    await _notifications.show(
      channelIndex + 2000000, // Channel indices are small, this is safe
      '$senderName ($shortCode) in $channelName',
      truncatedMessage,
      notificationDetails,
      payload: 'channel:$channelIndex:$fromNodeNum',
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
