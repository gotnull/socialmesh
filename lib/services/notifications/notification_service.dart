// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import '../../core/logging.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import '../../models/mesh_models.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/l10n/l10n_utils.dart';

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

  /// Resolve [AppLocalizations] from the platform locale.
  /// Usable without [BuildContext] for background notifications.
  AppLocalizations get _l10n => safeL10n();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  /// Callback to send reaction messages back to senders
  ReactionCallback? onReactionSelected;

  /// Stream of push notification navigation payloads (type|deepLink format)
  final _pushTapController = StreamController<String>.broadcast();

  /// Stream that emits when a push-originated local notification is tapped.
  /// The payload format is 'type' or 'type|deepLink'.
  Stream<String> get onPushNotificationTap => _pushTapController.stream;

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
      '@mipmap/ic_launcher', // lint-allow: hardcoded-string
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
      settings: initSettings,
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
    if (payload != null && payload.isNotEmpty) {
      AppLogging.notifications('🔔 Notification tapped with payload: $payload');
      // Push notification payloads use 'type' or 'type|deepLink' format
      // Emit on the stream so the app can navigate
      _pushTapController.add(payload);
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
      'New Nodes', // lint-allow: hardcoded-string
      channelDescription: _l10n.notificationChannelNodeDiscovery,
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
      id: notificationId,
      title: _l10n.notificationNewNodeTitle,
      body: _l10n.notificationNewNodeBody(nodeName, shortCode),
      notificationDetails: notificationDetails,
      payload: 'node:${node.nodeNum}',
    );

    AppLogging.notifications('🔔 Showed notification for node: $nodeName');
  }

  /// Show notification when a mesh node matches an active Aether flight.
  ///
  /// Alerts the user that a node in their mesh is currently airborne on
  /// a known flight so they can report their reception.
  Future<void> showAetherFlightDetectedNotification({
    required String flightNumber,
    required String departure,
    required String arrival,
    required String nodeName,
    bool playSound = true,
    bool vibrate = true,
  }) async {
    if (!_initialized) {
      AppLogging.notifications(
        '🔔 NotificationService not initialized, skipping Aether notification',
      );
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'aether_flights',
      'Aether Flights', // lint-allow: hardcoded-string
      channelDescription: _l10n.notificationChannelAetherFlights,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      groupKey: 'aether_flights',
      playSound: playSound,
      enableVibration: vibrate,
      color: const Color(0xFF29B6F6), // lightBlue.shade400
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
      threadIdentifier: 'aether_flights',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch % 100000000;
    final route = '$departure → $arrival';

    await _notifications.show(
      id: notificationId,
      title: _l10n.notificationAetherFlightTitle,
      body:
          '$nodeName is airborne on $flightNumber ($route) — report your reception!',
      notificationDetails: notificationDetails,
      payload: 'aether:$flightNumber',
    );

    AppLogging.notifications(
      '🔔 Showed Aether flight notification: $flightNumber ($route)',
    );
  }

  /// Show notification for firmware alert (errors, warnings from device)
  /// These are important notifications that should be shown even when app is in background
  Future<void> showFirmwareNotification({
    required String title,
    required String message,
    required String level,
    bool playSound = true,
    bool vibrate = true,
  }) async {
    if (!_initialized) {
      AppLogging.notifications(
        '🔔 NotificationService not initialized, skipping firmware notification',
      );
      return;
    }

    // Determine urgency based on level
    final isError = level == 'ERROR' || level == 'CRITICAL';
    final isWarning = level == 'WARNING';

    final androidDetails = AndroidNotificationDetails(
      'firmware_alerts',
      'Firmware Alerts', // lint-allow: hardcoded-string
      channelDescription: _l10n.notificationChannelDeviceAlerts,
      importance: isError ? Importance.max : Importance.high,
      priority: isError ? Priority.max : Priority.high,
      icon: '@mipmap/ic_launcher',
      groupKey: 'firmware_alerts',
      playSound: playSound,
      enableVibration: vibrate,
      // Use different colors for different severity levels
      color: isError
          ? const Color(0xFFE53935) // Red for errors
          : isWarning
          ? const Color(0xFFFFA000) // Amber for warnings
          : AccentColors.blue, // Blue for info
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
      // Add threadIdentifier for grouping
      threadIdentifier: 'firmware_alerts',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    // Use timestamp-based ID to avoid collision
    final notificationId = DateTime.now().millisecondsSinceEpoch % 100000000;

    await _notifications.show(
      id: notificationId,
      title: title,
      body: message,
      notificationDetails: notificationDetails,
      payload: 'firmware:$level',
    );

    AppLogging.notifications(
      '🔔 Showed firmware notification: [$level] $message',
    );
  }

  /// Show notification for detection sensor event
  Future<void> showDetectionSensorNotification({
    required String sensorName,
    required bool detected,
    required int nodeNum,
    String? nodeName,
    bool playSound = true,
    bool vibrate = true,
  }) async {
    if (!_initialized) {
      AppLogging.notifications(
        '🔔 NotificationService not initialized, skipping detection notification',
      );
      return;
    }

    final displayName = nodeName ?? '!${nodeNum.toRadixString(16)}';
    final state = detected ? 'Triggered' : 'Clear';

    final androidDetails = AndroidNotificationDetails(
      'detection_sensor',
      'Detection Sensors', // lint-allow: hardcoded-string
      channelDescription: _l10n.notificationChannelDetectionSensor,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      groupKey: 'detection_sensors',
      playSound: playSound,
      enableVibration: vibrate,
      color: detected ? AccentColors.coral : const Color(0xFF4ECB71),
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
      threadIdentifier: 'detection_sensors',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    // Use combination of node and timestamp for unique ID
    final notificationId =
        (nodeNum + DateTime.now().millisecondsSinceEpoch) % 100000000;

    await _notifications.show(
      id: notificationId,
      title: _l10n.notificationDetectionSensorTitle(sensorName, state),
      body: _l10n.notificationDetectionSensorBody(displayName),
      notificationDetails: notificationDetails,
      payload: 'detection:$nodeNum:$detected',
    );

    AppLogging.notifications(
      '🔔 Showed detection sensor notification: $sensorName = $state',
    );
  }

  /// Show notification when a tracked TAK entity goes stale.
  Future<void> showTakStaleNotification({
    required String uid,
    required String callsign,
    required double lat,
    required double lon,
    required String timeAgo,
    bool playSound = true,
    bool vibrate = true,
  }) async {
    if (!_initialized) {
      AppLogging.notifications(
        '🔔 NotificationService not initialized, skipping TAK stale notification',
      );
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'tak_entity',
      'TAK Entities', // lint-allow: hardcoded-string
      channelDescription: _l10n.notificationChannelTakStale,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      groupKey: 'tak_entities',
      playSound: playSound,
      enableVibration: vibrate,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
      threadIdentifier: 'tak_entities',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    final notificationId = uid.hashCode.abs() % 100000000;

    await _notifications.show(
      id: notificationId,
      title: _l10n.notificationEntityStaleTitle(callsign),
      body:
          'Last position: ${lat.toStringAsFixed(4)}, ' // lint-allow: hardcoded-string
          '${lon.toStringAsFixed(4)} — $timeAgo',
      notificationDetails: notificationDetails,
      payload: 'tak:$uid',
    );

    AppLogging.notifications(
      '🔔 Showed TAK stale notification for $callsign ($uid)',
    );
  }

  /// Show notification when a hostile/unknown TAK entity enters the proximity
  /// radius.
  Future<void> showTakProximityNotification({
    required String uid,
    required String callsign,
    required String body,
    bool playSound = true,
    bool vibrate = true,
  }) async {
    if (!_initialized) {
      AppLogging.notifications(
        '🔔 NotificationService not initialized, skipping TAK proximity notification',
      );
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'tak_entity',
      'TAK Entities', // lint-allow: hardcoded-string
      channelDescription: _l10n.notificationChannelTakProximity,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      groupKey: 'tak_entities',
      playSound: playSound,
      enableVibration: vibrate,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
      threadIdentifier: 'tak_entities',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    // Use a distinct ID range from stale notifications.
    final notificationId = (uid.hashCode.abs() + 50000000) % 100000000;

    await _notifications.show(
      id: notificationId,
      title: _l10n.notificationProximityAlertTitle(callsign),
      body: body,
      notificationDetails: notificationDetails,
      payload: 'tak:$uid',
    );

    AppLogging.notifications(
      '🔔 Showed TAK proximity notification for $callsign ($uid)',
    );
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
      'Direct Messages', // lint-allow: hardcoded-string
      channelDescription: _l10n.notificationChannelDirectMessages,
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
        ? '${message.substring(0, 100)}…'
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
        id: notificationId,
        title: _l10n.notificationDirectMessageTitle(senderName, shortCode),
        body: truncatedMessage,
        notificationDetails: notificationDetails,
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
      'Channel Messages', // lint-allow: hardcoded-string
      channelDescription: _l10n.notificationChannelMessages,
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
        ? '${message.substring(0, 100)}…'
        : message;

    // Use short name (4-char code) if available, otherwise last 4 hex digits
    final shortCode =
        senderShortName ??
        fromNodeNum
            .toRadixString(16)
            .substring(fromNodeNum.toRadixString(16).length - 4)
            .toUpperCase();

    await _notifications.show(
      id: channelIndex + 2000000, // Channel indices are small, this is safe
      title: _l10n.notificationChannelMessageTitle(
        senderName,
        shortCode,
        channelName,
      ),
      body: truncatedMessage,
      notificationDetails: notificationDetails,
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

  /// Native method channel used to reset the iOS/macOS app icon badge count.
  ///
  /// [flutter_local_notifications]' [cancelAll] removes delivered notifications
  /// from the notification centre but does NOT reset
  /// [UIApplication.applicationIconBadgeNumber] (iOS) or the dock-tile badge
  /// (macOS). Setting the badge to 0 requires an explicit native call, which
  /// is wired up in AppDelegate.swift on both platforms.
  static const _badgeChannel = MethodChannel('socialmesh/badge');

  /// Clear the app icon badge.
  ///
  /// Cancels all delivered local notifications (removing them from the system
  /// tray) and then calls the native [_badgeChannel] to set the badge count
  /// to 0. The native call is necessary because [UIApplication
  /// .applicationIconBadgeNumber] is a separate counter from the notification
  /// centre — [cancelAll] alone does not reset it.
  Future<void> clearBadge() async {
    if (!_initialized) return;
    await _notifications.cancelAll();
    if (Platform.isIOS || Platform.isMacOS) {
      try {
        await _badgeChannel.invokeMethod<void>('clearBadge');
      } catch (e) {
        AppLogging.notifications('🔔 clearBadge channel error: $e');
      }
    }
    AppLogging.notifications('🔔 Badge cleared');
  }

  /// Cancel notification by ID
  Future<void> cancel(int id) async {
    await _notifications.cancel(id: id);
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
      body = dms.map((m) => m.message).take(3).join(', ');
      if (messageCount > 3) body += ' …';
    } else {
      // Multiple senders
      title = '$messageCount new messages';
      body =
          'From $senderCount people: ${bySender.values.map((msgs) => msgs.first.senderName).take(3).join(', ')}';
      if (senderCount > 3) body += '…';
    }

    final androidDetails = AndroidNotificationDetails(
      'direct_messages',
      'Direct Messages', // lint-allow: hardcoded-string
      channelDescription: _l10n.notificationChannelDirectMessages,
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
      id: 3000001, // Fixed ID for batched DM notifications
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
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
                msgs.first.channelName ??
                'Channel ${msgs.first.channelIndex}', // lint-allow: hardcoded-string
          )
          .take(3)
          .join(', ');
      body = 'In $channelCount channels: $channelNames';
      if (channelCount > 3) body += '…';
    }

    final androidDetails = AndroidNotificationDetails(
      'channel_messages',
      'Channel Messages', // lint-allow: hardcoded-string
      channelDescription: _l10n.notificationChannelMessages,
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
      id: 3000002, // Fixed ID for batched channel notifications
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
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
    title = _l10n.notificationBatchedNodesTitle(nodeCount);
    final nodeNames = nodes.take(3).map((n) => n.node.displayName).join(', ');
    body = nodeNames + (nodeCount > 3 ? '…' : '');

    final androidDetails = AndroidNotificationDetails(
      'new_nodes',
      'New Nodes', // lint-allow: hardcoded-string
      channelDescription: _l10n.notificationChannelNodeDiscovery,
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

    try {
      await _notifications.show(
        id: 3000003, // Fixed ID for batched node notifications
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
          macOS: iosDetails,
        ),
        payload: 'batched_nodes',
      );

      AppLogging.notifications(
        '🔔 Showed batched node notification: $nodeCount nodes',
      );
    } catch (e) {
      AppLogging.notifications(
        '🔔 Failed to show batched node notification: $e',
      );
    }
  }

  /// Fixed notification ID for admin bug report notifications
  static const int _bugReportNotificationId = 3000004;

  /// Show notification for a new bug report (admin only)
  Future<void> showNewBugReportNotification({
    required String reportId,
    required String description,
    String? email,
    bool playSound = true,
    bool vibrate = true,
  }) async {
    if (!_initialized) {
      AppLogging.notifications(
        '🔔 NotificationService not initialized, skipping bug report notification',
      );
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      'admin_bug_reports',
      'Bug Reports', // lint-allow: hardcoded-string
      channelDescription:
          'Notifications for new user bug reports (admin only)', // lint-allow: hardcoded-string
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      groupKey: 'admin_bug_reports',
      playSound: playSound,
      enableVibration: vibrate,
      color: const Color(0xFFE91E63),
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

    // Truncate description for notification body
    final truncated = description.length > 120
        ? '${description.substring(0, 120)}…'
        : description;

    final subtitle = email != null && email.isNotEmpty
        ? 'From: $email' // lint-allow: hardcoded-string
        : 'Anonymous report';

    await _notifications.show(
      id: _bugReportNotificationId,
      title: '🐛 New Bug Report', // lint-allow: hardcoded-string
      body: '$subtitle\n$truncated', // lint-allow: hardcoded-string
      notificationDetails: notificationDetails,
      payload: 'bug_report|$reportId',
    );

    AppLogging.notifications(
      '🔔 Showed bug report notification for report: $reportId',
    );
  }

  // ============================================================
  // SIP (Socialmesh Interchange Protocol) NOTIFICATIONS
  // ============================================================

  /// Show notification for an incoming SIP ephemeral DM message.
  Future<void> showSipDmNotification({
    required String peerName,
    required String message,
    required int sessionTag,
    bool playSound = true,
    bool vibrate = true,
  }) async {
    if (!_initialized) return;

    final androidDetails = AndroidNotificationDetails(
      'sip_messages',
      'SIP Ephemeral Messages', // lint-allow: hardcoded-string
      channelDescription: _l10n.notificationChannelSipMessages,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      groupKey: 'sip_dm_messages',
      playSound: playSound,
      enableVibration: vibrate,
      color: AccentColors.green,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
      threadIdentifier: 'sip_dm_messages',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    // Truncate message if too long
    final truncatedMessage = message.length > 100
        ? '${message.substring(0, 100)}…'
        : message;

    // Use session tag modulo to keep ID within 32-bit signed int range.
    // Offset by 4000000 to avoid collision with other notification IDs.
    final notificationId = (sessionTag.abs() % 1000000) + 4000000;

    await _notifications.show(
      id: notificationId,
      title: _l10n.notificationSipDmTitle(peerName),
      body: truncatedMessage,
      notificationDetails: notificationDetails,
      payload: 'sip_dm:$sessionTag',
    );

    AppLogging.notifications('🔔 Showed SIP DM notification from: $peerName');
  }

  /// Show notification when a SIP handshake completes and a DM session
  /// is established.
  Future<void> showSipHandshakeCompleteNotification({
    required String peerName,
    required int peerNodeId,
    bool playSound = true,
    bool vibrate = true,
  }) async {
    if (!_initialized) return;

    final androidDetails = AndroidNotificationDetails(
      'sip_handshakes',
      'SIP Handshakes', // lint-allow: hardcoded-string
      channelDescription: _l10n.notificationChannelSipHandshake,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      groupKey: 'sip_handshakes',
      playSound: playSound,
      enableVibration: vibrate,
      color: AccentColors.green,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
      threadIdentifier: 'sip_handshakes',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    final notificationId = (peerNodeId.abs() % 1000000) + 5000000;

    await _notifications.show(
      id: notificationId,
      title: _l10n.notificationSipHandshakeTitle,
      body: _l10n.notificationSipHandshakeBody(peerName),
      notificationDetails: notificationDetails,
      payload: 'sip_handshake:$peerNodeId',
    );

    AppLogging.notifications(
      '🔔 Showed SIP handshake notification for: $peerName',
    );
  }

  /// Show notification when an incoming SIP handshake request (HS_HELLO)
  /// is received from a remote peer.
  Future<void> showSipHandshakeRequestNotification({
    required String peerName,
    required int peerNodeId,
    bool playSound = true,
    bool vibrate = true,
  }) async {
    if (!_initialized) return;

    final androidDetails = AndroidNotificationDetails(
      'sip_handshakes',
      'SIP Handshakes', // lint-allow: hardcoded-string
      channelDescription: _l10n.notificationChannelSipHandshake,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      groupKey: 'sip_handshakes',
      playSound: playSound,
      enableVibration: vibrate,
      color: AccentColors.green,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
      threadIdentifier: 'sip_handshakes',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    final notificationId = (peerNodeId.abs() % 1000000) + 6000000;

    await _notifications.show(
      id: notificationId,
      title: _l10n.notificationSipHandshakeRequestTitle,
      body: _l10n.notificationSipHandshakeRequestBody(peerName),
      notificationDetails: notificationDetails,
      payload: 'sip_handshake_request:$peerNodeId',
    );

    AppLogging.notifications(
      '🔔 Showed SIP handshake request notification from: $peerName',
    );
  }

  /// Show notification when a peer declines our SIP handshake request.
  Future<void> showSipHandshakeDeclinedNotification({
    required String peerName,
    required int peerNodeId,
  }) async {
    if (!_initialized) return;

    final androidDetails = AndroidNotificationDetails(
      'sip_handshakes',
      'SIP Handshakes', // lint-allow: hardcoded-string
      channelDescription: _l10n.notificationChannelSipHandshake,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      icon: '@mipmap/ic_launcher',
      groupKey: 'sip_handshakes',
      playSound: false,
      enableVibration: false,
      color: AccentColors.red,
    );

    final iosDetails = const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
      threadIdentifier: 'sip_handshakes',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    final notificationId = (peerNodeId.abs() % 1000000) + 7000000;

    await _notifications.show(
      id: notificationId,
      title: _l10n.notificationSipHandshakeDeclinedTitle,
      body: _l10n.notificationSipHandshakeDeclinedBody(peerName),
      notificationDetails: notificationDetails,
      payload: 'sip_handshake_declined:$peerNodeId',
    );

    AppLogging.notifications(
      '🔔 Showed SIP handshake declined notification from: $peerName',
    );
  }

  /// Show notification when a new SIP peer is discovered nearby.
  ///
  /// Fires on the `sip_discovery` channel. Intended to run in the background
  /// so the user knows to open Mesh Explorer and connect.
  Future<void> showSipPeerFoundNotification({required int peerNodeId}) async {
    if (!_initialized) return;

    final androidDetails = AndroidNotificationDetails(
      'sip_discovery',
      'Peer Discovery', // lint-allow: hardcoded-string
      channelDescription: _l10n.notificationChannelSipDiscovery,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      groupKey: 'sip_discovery',
      playSound: false,
      enableVibration: false,
      color: AccentColors.teal,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: false,
      threadIdentifier: 'sip_discovery',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      macOS: iosDetails,
    );

    final notificationId = (peerNodeId.abs() % 1000000) + 7000000;

    await _notifications.show(
      id: notificationId,
      title: _l10n.notificationSipPeerFoundTitle,
      body: _l10n.notificationSipPeerFoundBody,
      notificationDetails: notificationDetails,
      payload: 'sip_peer_found:$peerNodeId',
    );

    AppLogging.notifications(
      '🔔 Showed SIP peer found notification for: $peerNodeId',
    );
  }
}
