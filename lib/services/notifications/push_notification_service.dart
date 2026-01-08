import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../core/logging.dart';

/// Background message handler - must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  AppLogging.notifications('🔔 Background message: ${message.messageId}');
  // Background messages are handled automatically by the system
  // We don't need to show a notification manually - FCM does it
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

  /// Notification channel for Android
  static const AndroidNotificationChannel _socialChannel =
      AndroidNotificationChannel(
        'social_notifications',
        'Social Notifications',
        description: 'Notifications for follows, likes, and comments',
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
        // Create Android notification channel
        if (Platform.isAndroid) {
          await _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.createNotificationChannel(_socialChannel);
        }

        // Get and save FCM token
        await _saveFcmToken();

        // Listen for token refresh
        _messaging.onTokenRefresh.listen(_onTokenRefresh);

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

      // Store token in user's profile with device info
      await _firestore.collection('users').doc(user.uid).set({
        'fcmTokens': {
          token: {
            'platform': Platform.operatingSystem,
            'updatedAt': FieldValue.serverTimestamp(),
          },
        },
      }, SetOptions(merge: true));

      AppLogging.notifications('🔔 FCM token saved for user ${user.uid}');
    } catch (e) {
      AppLogging.notifications('🔔 Error saving FCM token: $e');
    }
  }

  /// Handle FCM token refresh
  void _onTokenRefresh(String token) {
    AppLogging.notifications('🔔 FCM token refreshed');
    _saveFcmToken();
  }

  /// Handle foreground messages - show local notification
  Future<void> _onForegroundMessage(RemoteMessage message) async {
    AppLogging.notifications(
      '🔔 Foreground message: ${message.notification?.title}',
    );

    final notification = message.notification;
    if (notification == null) return;

    // Show local notification for foreground messages
    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _socialChannel.id,
          _socialChannel.name,
          channelDescription: _socialChannel.description,
          icon: '@mipmap/ic_launcher',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['type'],
    );
  }

  /// Handle notification tap when app is opened from background
  void _onMessageOpenedApp(RemoteMessage message) {
    AppLogging.notifications('🔔 Notification opened app: ${message.data}');

    final type = message.data['type'] as String?;
    final targetId = message.data['targetId'] as String?;

    // Navigate based on notification type
    // This will be handled by the app's navigation system
    if (type != null) {
      _handleNotificationNavigation(type, targetId);
    }
  }

  /// Handle navigation based on notification type
  void _handleNotificationNavigation(String type, String? targetId) {
    // Navigation will be handled via a stream that the app listens to
    _notificationNavigationController.add(
      NotificationNavigation(type: type, targetId: targetId),
    );
  }

  /// Stream of notification navigation events
  final _notificationNavigationController =
      StreamController<NotificationNavigation>.broadcast();

  Stream<NotificationNavigation> get onNotificationNavigation =>
      _notificationNavigationController.stream;

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
      return {'follows': true, 'likes': true, 'comments': true};
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (!doc.exists) {
        return {'follows': true, 'likes': true, 'comments': true};
      }

      final data = doc.data();
      final settings = data?['notificationSettings'] as Map<String, dynamic>?;

      return {
        'follows': settings?['follows'] ?? true,
        'likes': settings?['likes'] ?? true,
        'comments': settings?['comments'] ?? true,
      };
    } catch (e) {
      AppLogging.notifications('🔔 Error getting notification settings: $e');
      return {'follows': true, 'likes': true, 'comments': true};
    }
  }

  /// Clean up resources
  void dispose() {
    _foregroundSubscription?.cancel();
    _openedAppSubscription?.cancel();
    _notificationNavigationController.close();
  }
}

/// Navigation event from a notification
class NotificationNavigation {
  final String type;
  final String? targetId;

  const NotificationNavigation({required this.type, this.targetId});
}
