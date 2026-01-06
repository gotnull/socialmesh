import '../../core/logging.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../models/mesh_models.dart';

/// Represents a pending message notification for batching
class PendingMessageNotification {
  final String senderName;
  final String? senderShortName;
  final String message;
  final int fromNodeNum;
  final int? channelIndex;
  final String? channelName;
  final DateTime timestamp;

  PendingMessageNotification({
    required this.senderName,
    this.senderShortName,
    required this.message,
    required this.fromNodeNum,
    this.channelIndex,
    this.channelName,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isChannelMessage => channelIndex != null && channelIndex! > 0;
}

/// Represents a pending node notification for batching
class PendingNodeNotification {
  final MeshNode node;
  final DateTime timestamp;

  PendingNodeNotification({required this.node, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}

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
        AppLogging.notifications(
          '🔔 iOS notification permissions granted: $granted',
        );
      }
    }

    // Request permissions on Android 13+
    if (Platform.isAndroid) {
      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final granted = await androidPlugin?.requestNotificationsPermission();
      AppLogging.notifications(
        '🔔 Android notification permissions granted: $granted',
      );
    }

    _initialized = true;
    AppLogging.notifications('🔔 NotificationService initialized successfully');
  }

  /// Handle notification tap or action
  void _onNotificationResponse(NotificationResponse response) {
    AppLogging.notifications(
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
      AppLogging.notifications('🔔 Notification tapped with payload: $payload');
      // Could navigate to nodes screen, message thread, etc.
    }
  }

  /// Handle a reaction action from notification
  void _handleReactionAction(String? payload, String emoji) {
    if (payload == null) {
      AppLogging.notifications('🔔 Reaction action without payload, ignoring');
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
      AppLogging.notifications(
        '🔔 Could not parse node number from payload: $payload',
      );
      return;
    }

    AppLogging.notifications('🔔 Sending $emoji reaction to node $nodeNum');

    // Call the reaction callback if set
    if (onReactionSelected != null) {
      onReactionSelected!(nodeNum, emoji);
    } else {
      AppLogging.notifications(
        '🔔 No reaction callback set, cannot send reaction',
      );
    }
  }

  /// Show notification for new node discovery
  Future<void> showNewNodeNotification(
    MeshNode node, {
    bool playSound = true,
    bool vibrate = true,
  }) async {
    if (!_initialized) {
      AppLogging.notifications(
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

    AppLogging.notifications('🔔 Showed notification for node: $nodeName');
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
    AppLogging.notifications(
      '🔔 showNewMessageNotification called - initialized: $_initialized',
    );
    if (!_initialized) {
      AppLogging.notifications(
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

    AppLogging.notifications(
      '🔔 Calling _notifications.show() for DM from $senderName',
    );
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
      AppLogging.notifications(
        '🔔 Successfully showed DM notification from: $senderName',
      );
    } catch (e) {
      AppLogging.notifications('🔔 Error showing DM notification: $e');
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

    AppLogging.notifications(
      '🔔 Showed channel notification: $senderName in $channelName',
    );
  }

  /// Cancel all notifications
  Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }

  /// Cancel notification by ID
  Future<void> cancel(int id) async {
    await _notifications.cancel(id);
  }

  // ============================================================
  // BATCHED NOTIFICATIONS - For handling notification floods
  // ============================================================

  /// Show a batched summary for multiple messages
  /// Groups by sender for DMs, or by channel for channel messages
  Future<void> showBatchedMessagesNotification({
    required List<PendingMessageNotification> messages,
    bool playSound = true,
    bool vibrate = true,
  }) async {
    if (!_initialized || messages.isEmpty) return;

    // Separate DMs and channel messages
    final dms = messages.where((m) => !m.isChannelMessage).toList();
    final channelMsgs = messages.where((m) => m.isChannelMessage).toList();

    // Show DM summary if any
    if (dms.isNotEmpty) {
      await _showBatchedDMNotification(dms, playSound, vibrate);
    }

    // Show channel message summary if any
    if (channelMsgs.isNotEmpty) {
      await _showBatchedChannelNotification(channelMsgs, playSound, vibrate);
    }
  }

  Future<void> _showBatchedDMNotification(
    List<PendingMessageNotification> dms,
    bool playSound,
    bool vibrate,
  ) async {
    // Group by sender
    final bySender = <int, List<PendingMessageNotification>>{};
    for (final dm in dms) {
      bySender.putIfAbsent(dm.fromNodeNum, () => []).add(dm);
    }

    final senderCount = bySender.length;
    final messageCount = dms.length;

    String title;
    String body;

    if (senderCount == 1) {
      // All from one person
      final sender = dms.first;
      title = '$messageCount messages from ${sender.senderName}';
      body = dms.map((m) => m.message).take(3).join(' • ');
      if (messageCount > 3) body += ' ...';
    } else {
      // Multiple senders
      title = '$messageCount new messages';
      body =
          'From $senderCount people: ${bySender.values.map((msgs) => msgs.first.senderName).take(3).join(', ')}';
      if (senderCount > 3) body += '...';
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

    await _notifications.show(
      3000001, // Fixed ID for batched DM notifications
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      ),
      payload: 'batched_dm',
    );

    AppLogging.notifications(
      '🔔 Showed batched DM notification: $messageCount messages from $senderCount senders',
    );
  }

  Future<void> _showBatchedChannelNotification(
    List<PendingMessageNotification> channelMsgs,
    bool playSound,
    bool vibrate,
  ) async {
    // Group by channel
    final byChannel = <int, List<PendingMessageNotification>>{};
    for (final msg in channelMsgs) {
      byChannel.putIfAbsent(msg.channelIndex!, () => []).add(msg);
    }

    final channelCount = byChannel.length;
    final messageCount = channelMsgs.length;

    String title;
    String body;

    if (channelCount == 1) {
      // All from one channel
      final first = channelMsgs.first;
      title = '$messageCount messages in ${first.channelName ?? 'Channel'}';
      // Group by sender within channel
      final bySender = <int, List<PendingMessageNotification>>{};
      for (final msg in channelMsgs) {
        bySender.putIfAbsent(msg.fromNodeNum, () => []).add(msg);
      }
      body = 'From ${bySender.length} people';
    } else {
      // Multiple channels
      title = '$messageCount new channel messages';
      final channelNames = byChannel.values
          .map(
            (msgs) =>
                msgs.first.channelName ?? 'Channel ${msgs.first.channelIndex}',
          )
          .take(3)
          .join(', ');
      body = 'In $channelCount channels: $channelNames';
      if (channelCount > 3) body += '...';
    }

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

    await _notifications.show(
      3000002, // Fixed ID for batched channel notifications
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      ),
      payload: 'batched_channel',
    );

    AppLogging.notifications(
      '🔔 Showed batched channel notification: $messageCount messages in $channelCount channels',
    );
  }

  /// Show a batched summary for multiple new nodes
  Future<void> showBatchedNodesNotification({
    required List<PendingNodeNotification> nodes,
    bool playSound = true,
    bool vibrate = true,
  }) async {
    if (!_initialized || nodes.isEmpty) return;

    final nodeCount = nodes.length;

    String title;
    String body;

    if (nodeCount == 1) {
      // Single node - show regular notification
      await showNewNodeNotification(
        nodes.first.node,
        playSound: playSound,
        vibrate: vibrate,
      );
      return;
    }

    // Multiple nodes - show summary
    title = '$nodeCount new nodes discovered';
    final nodeNames = nodes.take(3).map((n) => n.node.displayName).join(', ');
    body = nodeNames + (nodeCount > 3 ? '...' : '');

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

    await _notifications.show(
      3000003, // Fixed ID for batched node notifications
      title,
      body,
      NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
        macOS: iosDetails,
      ),
      payload: 'batched_nodes',
    );

    AppLogging.notifications(
      '🔔 Showed batched node notification: $nodeCount nodes',
    );
  }
}
