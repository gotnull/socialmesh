// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide Message;
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging.dart';
import '../../core/navigation.dart';
import '../../features/feedback/bug_response_quick_sheet.dart';
import '../../l10n/l10n_utils.dart';
import '../../providers/profile_providers.dart';
import '../../utils/snackbar.dart';

import '../storage/message_database.dart';
import '../messaging/message_utils.dart';

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogging.notifications('🔔 Background message: ${message.messageId}');

  // If this contains a mesh message payload, try to persist it directly so
  // messages received while the app is backgrounded are not lost.
  final data = message.data;
  if (data.containsKey('type') &&
      (data['type'] == 'direct_message' || data['type'] == 'channel_message')) {
    try {
      // Initialize storage service and save the message
      final storage = MessageDatabase();
      await storage.init();

      final parsed = parsePushMessagePayload(data.cast<String, dynamic>());
      if (parsed != null) {
        await storage.saveMessage(parsed);
        AppLogging.messages('🔔 Background persisted message id=${parsed.id}');
      }
    } catch (e) {
      AppLogging.notifications('🔔 Error persisting background message: $e');
    }
  }

  // Background messages are handled automatically by the system, but we try
  // to persist message payloads locally when possible.
}

/// Service for handling Firebase Cloud Messaging (FCM) push notifications.
/// Used for social notifications (follows, likes, comments) that need to
/// reach users even when the app is closed.
class PushNotificationService {
  static final PushNotificationService _instance =
      PushNotificationService._internal();
  factory PushNotificationService() => _instance;
  PushNotificationService._internal();

  /// Lazy-initialized Firebase instances to avoid accessing before Firebase.initializeApp()
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedAppSubscription;
  StreamSubscription<User?>? _authStateSubscription;

  /// SharedPreferences key for persisting the last-saved FCM token so we can
  /// delete the stale Firestore entry when the platform rotates it.
  static const _kPreviousFcmToken = 'previous_fcm_token';
  static const _kMasterToggle = 'notifications_enabled';
  static const _kChannelToggle = 'channel_notifications_enabled';
  static const _kDmToggle = 'dm_notifications_enabled';
  static const _kMutedChannels = 'muted_channel_indices';

  /// Notification channel for Android
  static const AndroidNotificationChannel
  _socialChannel = AndroidNotificationChannel(
    'social_notifications',
    'Social Notifications', // lint-allow: hardcoded-string
    description:
        'Notifications for follows, likes, and comments', // lint-allow: hardcoded-string
    importance: Importance.high,
  );

  /// Android notification channel for admin announcements
  final AndroidNotificationChannel
  _announcementsChannel = const AndroidNotificationChannel(
    'announcements',
    'Announcements',
    description:
        'Important announcements from SocialMesh', // lint-allow: hardcoded-string
    importance: Importance.high,
  );

  /// Initialize the push notification service
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Set up background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      AppLogging.notifications(
        '🔔 Push notification permission: ${settings.authorizationStatus}',
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Create Android notification channels
        if (Platform.isAndroid) {
          final androidPlugin = _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();
          await androidPlugin?.createNotificationChannel(_socialChannel);
          await androidPlugin?.createNotificationChannel(_announcementsChannel);
        }

        // Subscribe to announcements topic for admin broadcasts
        await _subscribeToAnnouncementsTopic();

        // Get and save FCM token for the currently-signed-in user (if any)
        await _saveFcmToken();

        // Listen for token refresh
        _messaging.onTokenRefresh.listen(_onTokenRefresh);

        // Re-save the FCM token whenever a user signs in. initialize() runs
        // at app launch before any sign-in flow, so without this listener a
        // user who signs in after launch would have no token registered
        // until the next app restart. _saveFcmToken() is a no-op when there
        // is no current user, so this is safe across sign-out transitions
        // (cleanup is handled separately by onUserSignOut).
        _authStateSubscription = _auth.authStateChanges().listen((user) {
          if (user != null) {
            unawaited(_saveFcmToken());
          }
        });

        // Handle foreground messages
        _foregroundSubscription = FirebaseMessaging.onMessage.listen(
          _onForegroundMessage,
        );

        // Handle notification tap when app is in background
        _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
          _onMessageOpenedApp,
        );

        // Check if app was opened from a notification
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _onMessageOpenedApp(initialMessage);
        }

        _initialized = true;
        AppLogging.notifications('🔔 PushNotificationService initialized');
      } else {
        AppLogging.notifications(
          '🔔 Push notifications not authorized: ${settings.authorizationStatus}',
        );
      }
    } catch (e) {
      AppLogging.notifications('🔔 Error initializing push notifications: $e');
    }
  }

  /// Subscribe to the announcements FCM topic for admin broadcasts.
  ///
  /// Subscribes to both the general `announcements` topic (for broadcasts
  /// targeting all platforms) and the platform-specific topic
  /// (`announcements_android` or `announcements_ios`) so admins can send
  /// platform-targeted push notifications.
  Future<void> _subscribeToAnnouncementsTopic() async {
    try {
      await _messaging.subscribeToTopic('announcements');
      AppLogging.notifications('🔔 Subscribed to announcements topic');

      // Subscribe to platform-specific topic for targeted broadcasts
      final platformTopic = Platform.isAndroid
          ? 'announcements_android'
          : 'announcements_ios';
      await _messaging.subscribeToTopic(platformTopic);
      AppLogging.notifications('🔔 Subscribed to $platformTopic topic');
    } catch (e) {
      AppLogging.notifications(
        '🔔 Error subscribing to announcements topic: $e',
      );
    }
  }

  /// Save the FCM token to Firestore for the current user
  Future<void> _saveFcmToken() async {
    final user = _auth.currentUser;
    if (user == null) {
      AppLogging.notifications('🔔 No user signed in, skipping FCM token save');
      return;
    }

    try {
      final token = await _messaging.getToken();
      if (token == null) {
        AppLogging.notifications('🔔 Could not get FCM token');
        return;
      }

      final packageInfo = await PackageInfo.fromPlatform();

      // Store token in user's profile with device info. appVersion/buildNumber
      // are read by the purchaseNotification trigger to surface "version at
      // time of purchase" in the instant alert email.
      await _firestore.collection('users').doc(user.uid).set({
        'fcmTokens': {
          token: {
            'platform': Platform.operatingSystem,
            'appVersion': packageInfo.version,
            'buildNumber': packageInfo.buildNumber,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        },
      }, SetOptions(merge: true));

      // Persist token locally so _onTokenRefresh can delete it later
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPreviousFcmToken, token);

      AppLogging.notifications('🔔 FCM token saved for user ${user.uid}');
    } catch (e) {
      AppLogging.notifications('🔔 Error saving FCM token: $e');
    }
  }

  /// Handle FCM token refresh — delete stale token before writing the new one.
  Future<void> _onTokenRefresh(String newToken) async {
    AppLogging.notifications('🔔 FCM token refreshed');

    final user = _auth.currentUser;
    if (user == null) {
      AppLogging.notifications(
        '🔔 _onTokenRefresh - No user signed in, skipping',
      );
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final previousToken = prefs.getString(_kPreviousFcmToken);

      // If the token actually changed, remove the stale entry from Firestore
      if (previousToken != null && previousToken != newToken) {
        AppLogging.notifications(
          '🔔 Deleting stale FCM token for user ${user.uid}',
        );
        await _firestore.collection('users').doc(user.uid).update({
          'fcmTokens.$previousToken': FieldValue.delete(),
        });
      }
    } catch (e) {
      // Best-effort — don't block the new token write
      AppLogging.notifications('🔔 Error removing stale FCM token: $e');
    }

    // Write the new token (also persists it to SharedPreferences)
    await _saveFcmToken();
  }

  /// Handle foreground messages - show local notification
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    AppLogging.notifications(
      '🔔 Foreground message: ${message.notification?.title}',
    );

    // Redact PII before logging — text and sender names replaced with [redacted]
    final redactedData = Map<String, dynamic>.from(message.data);
    for (final key in const [
      'text',
      'senderLongName',
      'senderShortName',
      'body',
      'message',
    ]) {
      if (redactedData.containsKey(key)) {
        redactedData[key] = '[redacted]';
      }
    }
    AppLogging.notifications('🔔 Foreground message data: $redactedData');

    // Emit content refresh event for screens currently visible
    _emitContentRefreshEvent(message);

    // Surface a localised in-app snackbar for founder bug-report responses
    // when the app is in the foreground. The system local-notification
    // banner is suppressed in this case (return below) to avoid a double
    // banner — the snackbar's "View" action navigates to the report and is
    // the in-app equivalent of tapping the system banner.
    if (message.data['type'] == 'bug_report_response') {
      _showBugReportResponseSnackBar(message);
      return;
    }

    // If push contains message payload for mesh DM/channel, log and persist via event
    final data = message.data;
    if (data.containsKey('type') &&
        (data['type'] == 'direct_message' ||
            data['type'] == 'channel_message')) {
      AppLogging.messages(
        '🔔 Push message received: type=${data['type']}, keys=${data.keys.toList()}',
      );
    }

    final notification = message.notification;
    if (notification == null) return;

    // Respect user notification preferences for mesh message types.
    // The content refresh event above has already been emitted so the
    // message is persisted regardless — we only suppress the visible
    // notification here.
    final pushType = message.data['type'] as String?;
    if (pushType == 'channel_message' || pushType == 'direct_message') {
      final prefs = await SharedPreferences.getInstance();
      final masterEnabled = prefs.getBool(_kMasterToggle) ?? true;
      if (!masterEnabled) return;

      // Respect per-channel mute preference.
      // This check runs before the channel/DM type split because the
      // primary channel (index 0) may arrive as either push type
      // depending on server classification.  Without this early gate,
      // muting channel 0 has no effect for push notifications.
      final channelStr = message.data['channel'] as String?;
      final channelIndex = channelStr != null ? int.tryParse(channelStr) : null;
      if (channelIndex != null) {
        final mutedRaw = prefs.getStringList(_kMutedChannels);
        if (mutedRaw != null) {
          final mutedSet = mutedRaw
              .map((s) => int.tryParse(s))
              .whereType<int>()
              .toSet();
          if (mutedSet.contains(channelIndex)) return;
        }
      }

      if (pushType == 'channel_message') {
        if (!(prefs.getBool(_kChannelToggle) ?? true)) return;
      } else {
        if (!(prefs.getBool(_kDmToggle) ?? true)) return;
      }
    }

    // Try to get image URL from data payload
    final imageUrl = message.data['imageUrl'] as String?;
    final notificationType = message.data['type'] as String?;
    final isAnnouncement = notificationType == 'announcement';
    AppLogging.notifications(
      '🔔 Foreground message imageUrl: $imageUrl, type: $notificationType',
    );

    // Download image for attachment if available
    String? imagePath;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      imagePath = await _downloadImage(imageUrl);
      AppLogging.notifications('🔔 Downloaded image to: $imagePath');
    }

    // Select the appropriate channel — announcements get their own channel
    // so users can independently control notification preferences.
    final channel = isAnnouncement ? _announcementsChannel : _socialChannel;

    // Build Android notification details.
    // Broadcast announcements use the branded icon as largeIcon only (the
    // small coloured square beside the text). BigPictureStyle is skipped
    // because the 512x512 icon should not be expanded full-width.
    // Social notifications keep BigPictureStyle for photos/avatars.
    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      icon: '@mipmap/ic_launcher',
      importance: Importance.high,
      priority: Priority.high,
      largeIcon: imagePath != null ? FilePathAndroidBitmap(imagePath) : null,
      styleInformation: imagePath != null && !isAnnouncement
          ? BigPictureStyleInformation(
              FilePathAndroidBitmap(imagePath),
              hideExpandedLargeIcon: false,
            )
          : null,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      attachments: imagePath != null
          ? [DarwinNotificationAttachment(imagePath)]
          : null,
    );

    // Show local notification for foreground messages
    // Encode type and deepLink into payload for navigation on tap
    final payloadType = message.data['type'] as String? ?? '';
    final payloadDeepLink = message.data['deepLink'] as String?;
    final payloadString = payloadDeepLink != null && payloadDeepLink.isNotEmpty
        ? '$payloadType|$payloadDeepLink'
        : payloadType;

    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: payloadString,
    );
  }

  /// Show an in-app snackbar with a "View" action for a foreground
  /// bug-report response push. Falls back to a localised default message
  /// when the FCM payload omits a notification body. Suppressed entirely
  /// if the user has set [UserPreferences.bugResponseSnackbarsDisabled]
  /// (push and local notifications still fire).
  void _showBugReportResponseSnackBar(RemoteMessage message) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;

    // Respect the user's opt-out: if they've silenced these in-app
    // snackbars, return early — push/local notifications still fire
    // because they're dispatched by the OS layer above this helper.
    final container = ProviderScope.containerOf(ctx, listen: false);
    final profile = container.read(userProfileProvider).value;
    final disabled =
        profile?.preferences?.bugResponseSnackbarsDisabled ?? false;
    if (disabled) {
      AppLogging.notifications(
        'Bug-response snackbar suppressed (user opt-out)',
      );
      return;
    }

    final l10n = safeL10n();
    final body = message.notification?.body;
    final snackMessage = (body != null && body.isNotEmpty)
        ? body
        : l10n.feedbackResponseToastDefault;
    final targetId = message.data['targetId'] as String?;
    if (targetId == null || targetId.isEmpty) {
      AppLogging.notifications(
        'Bug-response snackbar skipped: missing targetId',
      );
      return;
    }

    showGlobalActionSnackBar(
      snackMessage,
      actionLabel: l10n.feedbackResponseToastAction,
      onAction: () {
        final sheetCtx = navigatorKey.currentContext;
        if (sheetCtx == null) return;
        BugResponseQuickSheet.show(context: sheetCtx, reportId: targetId);
      },
      type: SnackBarType.bug,
      duration: const Duration(seconds: 6),
    );
  }

  /// Download an image from URL and save to temp directory.
  /// The file extension is derived from the Content-Type header or the URL
  /// path so that iOS DarwinNotificationAttachment infers the correct type.
  Future<String?> _downloadImage(String imageUrl) async {
    try {
      final response = await http
          .get(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final tempDir = await getTemporaryDirectory();
        final ext = _imageExtension(response.headers['content-type'], imageUrl);
        final fileName =
            'notification_${DateTime.now().millisecondsSinceEpoch}$ext';
        final file = File('${tempDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);
        return file.path;
      }
    } catch (e) {
      AppLogging.notifications('🔔 Error downloading notification image: $e');
    }
    return null;
  }

  /// Return a file extension (with leading dot) from Content-Type or URL path.
  static String _imageExtension(String? contentType, String url) {
    if (contentType != null) {
      final mime = contentType.split(';').first.trim().toLowerCase();
      switch (mime) {
        case 'image/png':
          return '.png';
        case 'image/gif':
          return '.gif';
        case 'image/webp':
          return '.webp';
        case 'image/jpeg':
          return '.jpg';
      }
    }
    final path = Uri.tryParse(url)?.path ?? '';
    if (path.endsWith('.png')) return '.png';
    if (path.endsWith('.gif')) return '.gif';
    if (path.endsWith('.webp')) return '.webp';
    return '.jpg';
  }

  /// Emit content refresh events based on notification type
  void _emitContentRefreshEvent(RemoteMessage message) {
    final type = message.data['type'] as String?;
    final targetId = message.data['targetId'] as String?;

    AppLogging.notifications(
      '🔔 _emitContentRefreshEvent: type=$type, targetId=$targetId',
    );

    if (type == null) return;

    switch (type) {
      case 'signal_comment':
      case 'signal_reply':
      case 'signal_vote':
        // When someone comments on a signal
        _contentRefreshController.add(
          ContentRefreshEvent(
            contentType: 'signal_response',
            targetId: targetId,
          ),
        );
        AppLogging.notifications(
          '🔔 Emitted signal_response refresh for signal: $targetId',
        );
        break;
      case 'new_comment':
        // When someone comments on a post
        _contentRefreshController.add(
          ContentRefreshEvent(contentType: 'post_comment', targetId: targetId),
        );
        AppLogging.notifications(
          '🔔 Emitted post_comment refresh for post: $targetId',
        );
        break;
      case 'signal_like':
        // When someone likes a signal
        _contentRefreshController.add(
          ContentRefreshEvent(contentType: 'signal_like', targetId: targetId),
        );
        AppLogging.notifications(
          '🔔 Emitted signal_like refresh for signal: $targetId',
        );
        break;
      case 'new_like':
        // When someone likes a post
        _contentRefreshController.add(
          ContentRefreshEvent(contentType: 'post_like', targetId: targetId),
        );
        break;
      case 'direct_message':
      case 'channel_message':
        // Forward message payloads to the app so they can be persisted and shown
        _contentRefreshController.add(
          ContentRefreshEvent(
            contentType: type,
            targetId: targetId,
            payload: message.data.cast<String, dynamic>(),
          ),
        );
        AppLogging.notifications(
          '🔔 Emitted $type refresh with payload keys: ${message.data.keys.toList()}',
        );
        break;
      case 'bug_report_response':
        // When the founder responds to a bug report
        _contentRefreshController.add(
          ContentRefreshEvent(
            contentType: 'bug_report_response',
            targetId: targetId,
          ),
        );
        AppLogging.notifications(
          '🔔 Emitted bug_report_response refresh for report: $targetId',
        );
        break;
      case 'new_signal':
        // When a new signal is created and pushed via FCM. The targetId
        // is the Firestore UUID. Emit so signal_service can bind sm-
        // signals to the UUID when the legacy JSON packet never arrives.
        if (targetId != null) {
          _contentRefreshController.add(
            ContentRefreshEvent(contentType: 'new_signal', targetId: targetId),
          );
          AppLogging.notifications(
            '🔔 Emitted new_signal refresh for signal: $targetId',
          );
        }
        break;
    }
  }

  /// Handle notification tap when app is opened from background
  Future<void> _onMessageOpenedApp(RemoteMessage message) async {
    AppLogging.notifications('🔔 Notification opened app: ${message.data}');

    final type = message.data['type'] as String?;
    final targetId = message.data['targetId'] as String?;

    // Navigate based on notification type
    // This will be handled by the app's navigation system
    if (type != null) {
      // If this is a message payload, try to persist it locally so the UI
      // can show it after navigation.
      if ((type == 'direct_message' || type == 'channel_message') &&
          message.data.isNotEmpty) {
        try {
          final payload = message.data.cast<String, dynamic>();
          final parsed = parsePushMessagePayload(payload);
          if (parsed != null) {
            final storage = MessageDatabase();
            await storage.init();
            await storage.saveMessage(parsed);
            AppLogging.notifications(
              '🔔 Persisted message from notification open: id=${parsed.id}',
            );
            // Also emit content refresh event so UI refreshes
            _contentRefreshController.add(
              ContentRefreshEvent(
                contentType: type,
                targetId: targetId,
                payload: payload,
              ),
            );
          }
        } catch (e) {
          AppLogging.notifications(
            '🔔 Error persisting notification-open message: $e',
          );
        }
      }

      _handleNotificationNavigation(
        type,
        targetId,
        deepLink: message.data['deepLink'] as String?,
      );
    }
  }

  /// Handle navigation based on notification type
  void _handleNotificationNavigation(
    String type,
    String? targetId, {
    String? deepLink,
  }) {
    // Navigation will be handled via a stream that the app listens to
    _notificationNavigationController.add(
      NotificationNavigation(
        type: type,
        targetId: targetId,
        deepLink: deepLink,
      ),
    );
  }

  /// Stream of notification navigation events
  final _notificationNavigationController =
      StreamController<NotificationNavigation>.broadcast();

  Stream<NotificationNavigation> get onNotificationNavigation =>
      _notificationNavigationController.stream;

  /// Stream of content refresh events for screens to listen to
  final _contentRefreshController =
      StreamController<ContentRefreshEvent>.broadcast();

  Stream<ContentRefreshEvent> get onContentRefresh =>
      _contentRefreshController.stream;

  /// Update FCM token when user signs in
  Future<void> onUserSignIn() async {
    AppLogging.notifications('🔔 onUserSignIn - Updating FCM token...');
    if (!_initialized) {
      AppLogging.notifications('🔔 onUserSignIn - Not initialized, skipping');
      return;
    }
    await _saveFcmToken();
    AppLogging.notifications('🔔 onUserSignIn - FCM token updated');
  }

  /// Remove FCM token when user signs out
  Future<void> onUserSignOut() async {
    AppLogging.notifications('🔔 onUserSignOut - START');
    final user = _auth.currentUser;
    if (user == null) {
      AppLogging.notifications('🔔 onUserSignOut - No current user, skipping');
      return;
    }

    try {
      final token = await _messaging.getToken();
      if (token == null) {
        AppLogging.notifications('🔔 onUserSignOut - No FCM token, skipping');
        return;
      }

      // Remove this token from user's profile
      AppLogging.notifications(
        '🔔 onUserSignOut - Removing FCM token for user ${user.uid}',
      );
      await _firestore.collection('users').doc(user.uid).update({
        'fcmTokens.$token': FieldValue.delete(),
      });

      // Clear persisted token so it is not orphaned on next sign-in
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPreviousFcmToken);

      AppLogging.notifications('🔔 onUserSignOut - ✅ FCM token removed');
    } catch (e) {
      AppLogging.notifications('🔔 onUserSignOut - ❌ Error: $e');
    }
  }

  /// Update notification settings in Firestore
  /// These settings are read by Cloud Functions to determine whether to send pushes
  Future<void> updateNotificationSettings({
    bool? followNotifications,
    bool? likeNotifications,
    bool? commentNotifications,
    bool? signalNotifications,
    bool? voteNotifications,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final updates = <String, dynamic>{};
      if (followNotifications != null) {
        updates['notificationSettings.follows'] = followNotifications;
      }
      if (likeNotifications != null) {
        updates['notificationSettings.likes'] = likeNotifications;
      }
      if (commentNotifications != null) {
        updates['notificationSettings.comments'] = commentNotifications;
      }
      if (signalNotifications != null) {
        updates['notificationSettings.signals'] = signalNotifications;
      }
      if (voteNotifications != null) {
        updates['notificationSettings.votes'] = voteNotifications;
      }

      if (updates.isNotEmpty) {
        await _firestore.collection('users').doc(user.uid).update(updates);
        AppLogging.notifications('🔔 Notification settings updated');
      }
    } catch (e) {
      AppLogging.notifications('🔔 Error updating notification settings: $e');
    }
  }

  /// Get current notification settings from Firestore
  Future<Map<String, bool>> getNotificationSettings() async {
    final user = _auth.currentUser;
    if (user == null) {
      return {
        'follows': true,
        'likes': true,
        'comments': true,
        'signals': true,
        'votes': true,
      };
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        return {
          'follows': true,
          'likes': true,
          'comments': true,
          'signals': true,
          'votes': true,
        };
      }

      final data = doc.data();
      final settings = data?['notificationSettings'] as Map<String, dynamic>?;

      return {
        'follows': settings?['follows'] ?? true,
        'likes': settings?['likes'] ?? true,
        'comments': settings?['comments'] ?? true,
        'signals': settings?['signals'] ?? true,
        'votes': settings?['votes'] ?? true,
      };
    } catch (e) {
      AppLogging.notifications('🔔 Error getting notification settings: $e');
      return {
        'follows': true,
        'likes': true,
        'comments': true,
        'signals': true,
        'votes': true,
      };
    }
  }

  /// Clean up resources
  void dispose() {
    _foregroundSubscription?.cancel();
    _openedAppSubscription?.cancel();
    _authStateSubscription?.cancel();
    _notificationNavigationController.close();
    _contentRefreshController.close();
  }
}

/// Navigation event from a notification
class NotificationNavigation {
  final String type;
  final String? targetId;
  final String? deepLink;

  const NotificationNavigation({
    required this.type,
    this.targetId,
    this.deepLink,
  });
}

/// Event for content refresh triggered by push notification
/// Used to notify screens that their content may have changed
class ContentRefreshEvent {
  /// Type of content: 'signal_response', 'post_comment', 'post_like', etc.
  final String contentType;

  /// ID of the content that was updated (e.g., signal ID, post ID)
  final String? targetId;

  /// Optional payload (for example, message fields coming from FCM)
  final Map<String, dynamic>? payload;

  const ContentRefreshEvent({
    required this.contentType,
    this.targetId,
    this.payload,
  });
}
