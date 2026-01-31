// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for Firebase Analytics instance (nullable until Firebase is initialized)
final analyticsProvider = Provider<FirebaseAnalytics?>((ref) {
  // Check if Firebase is initialized before accessing Analytics
  try {
    Firebase.app();
    return FirebaseAnalytics.instance;
  } catch (_) {
    // Firebase not initialized yet
    return null;
  }
});

/// Provider for Firebase Analytics Observer (for navigation tracking)
/// Returns null if Firebase is not yet initialized
final analyticsObserverProvider = Provider<FirebaseAnalyticsObserver?>((ref) {
  final analytics = ref.watch(analyticsProvider);
  if (analytics == null) return null;
  return FirebaseAnalyticsObserver(analytics: analytics);
});

/// Helper class for logging analytics events
/// All methods are safe to call even if Firebase is not initialized
class AnalyticsEvents {
  static FirebaseAnalytics? get _analytics {
    try {
      Firebase.app();
      return FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  // App events
  static Future<void> appOpened() async {
    await _analytics?.logAppOpen();
  }

  // Connection events
  static Future<void> deviceConnected({
    required String connectionType,
    String? deviceName,
  }) async {
    await _analytics?.logEvent(
      name: 'device_connected',
      parameters: {
        'connection_type': connectionType,
        if (deviceName != null) 'device_name': deviceName,
      },
    );
  }

  static Future<void> deviceDisconnected() async {
    await _analytics?.logEvent(name: 'device_disconnected');
  }

  // Messaging events
  static Future<void> messageSent({
    required String channelType,
    bool hasAttachment = false,
  }) async {
    await _analytics?.logEvent(
      name: 'message_sent',
      parameters: {
        'channel_type': channelType,
        'has_attachment': hasAttachment.toString(),
      },
    );
  }

  // Feature usage
  static Future<void> featureUsed(String featureName) async {
    await _analytics?.logEvent(
      name: 'feature_used',
      parameters: {'feature_name': featureName},
    );
  }

  // Screen tracking (automatic with observer, but manual option)
  static Future<void> screenView(String screenName) async {
    await _analytics?.logScreenView(screenName: screenName);
  }

  // Node interactions
  static Future<void> nodeShared() async {
    await _analytics?.logEvent(name: 'node_shared');
  }

  static Future<void> nodeViewed() async {
    await _analytics?.logEvent(name: 'node_viewed');
  }

  // Settings
  static Future<void> settingsChanged(String settingName) async {
    await _analytics?.logEvent(
      name: 'settings_changed',
      parameters: {'setting_name': settingName},
    );
  }

  // Subscription events
  static Future<void> subscriptionStarted(String productId) async {
    await _analytics?.logEvent(
      name: 'subscription_started',
      parameters: {'product_id': productId},
    );
  }

  // Widget marketplace
  static Future<void> widgetDownloaded(String widgetId) async {
    await _analytics?.logEvent(
      name: 'widget_downloaded',
      parameters: {'widget_id': widgetId},
    );
  }

  // Automations
  static Future<void> automationCreated(String triggerType) async {
    await _analytics?.logEvent(
      name: 'automation_created',
      parameters: {'trigger_type': triggerType},
    );
  }

  static Future<void> automationTriggered(String triggerType) async {
    await _analytics?.logEvent(
      name: 'automation_triggered',
      parameters: {'trigger_type': triggerType},
    );
  }
}
