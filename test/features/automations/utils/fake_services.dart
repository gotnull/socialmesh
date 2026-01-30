import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Fake RTTTL player for testing sound actions
class FakeRtttlPlayer {
  final List<String> playedSounds = [];
  bool shouldFail = false;
  String? failureMessage;

  Future<void> play(String rtttl) async {
    if (shouldFail) {
      throw Exception(failureMessage ?? 'Fake player error');
    }
    playedSounds.add(rtttl);
  }

  Future<void> dispose() async {
    // No-op for testing
  }

  void reset() {
    playedSounds.clear();
    shouldFail = false;
    failureMessage = null;
  }
}

/// Fake URL launcher for testing shortcut actions
class FakeUrlLauncher {
  final List<Uri> launchedUrls = [];
  bool shouldFail = false;
  bool launchResult = true;

  Future<bool> launchUrl(Uri url, {LaunchMode? mode}) async {
    if (shouldFail) {
      throw Exception('Fake launcher error');
    }
    launchedUrls.add(url);
    return launchResult;
  }

  void reset() {
    launchedUrls.clear();
    shouldFail = false;
    launchResult = true;
  }
}

/// Mock launch mode enum for testing
enum LaunchMode { externalApplication, platformDefault }

/// Fake GlyphService for testing Nothing Phone glyph patterns
class FakeGlyphService {
  final List<String> shownPatterns = [];
  bool isSupported = true;
  bool shouldFail = false;
  String? failureMessage;

  Future<void> showPattern(String pattern) async {
    if (!isSupported) {
      throw Exception('Glyph interface not available');
    }
    if (shouldFail) {
      throw Exception(failureMessage ?? 'Fake glyph error');
    }
    shownPatterns.add(pattern);
  }

  Future<void> showConnected() => showPattern('connected');
  Future<void> showDisconnected() => showPattern('disconnected');
  Future<void> showMessageReceived({bool isDM = false}) =>
      showPattern(isDM ? 'dm' : 'message');
  Future<void> showMessageSent() => showPattern('sent');
  Future<void> showNodeOnline() => showPattern('node_online');
  Future<void> showNodeOffline() => showPattern('node_offline');
  Future<void> showSignalNearby() => showPattern('signal_nearby');
  Future<void> showLowBattery() => showPattern('low_battery');
  Future<void> showError() => showPattern('error');
  Future<void> showSuccess() => showPattern('success');
  Future<void> showSyncing() => showPattern('syncing');
  Future<void> showAutomationTriggered() => showPattern('pulse');

  void reset() {
    shownPatterns.clear();
    isSupported = true;
    shouldFail = false;
    failureMessage = null;
  }
}

/// Fake notification plugin for testing push notifications
class FakeNotificationsPlugin {
  final List<FakeNotification> shownNotifications = [];
  bool shouldFail = false;

  Future<void> show(
    int id,
    String? title,
    String? body,
    dynamic details,
  ) async {
    if (shouldFail) {
      throw Exception('Notification failed');
    }
    shownNotifications.add(FakeNotification(id: id, title: title, body: body));
  }

  void reset() {
    shownNotifications.clear();
    shouldFail = false;
  }
}

/// Represents a notification that was shown
class FakeNotification {
  final int id;
  final String? title;
  final String? body;

  FakeNotification({required this.id, this.title, this.body});
}

/// Fake clock for deterministic time-based testing
class FakeClock {
  DateTime _now;

  FakeClock([DateTime? initial])
    : _now = initial ?? DateTime(2025, 1, 30, 12, 0, 0);

  DateTime get now => _now;

  void setTime(DateTime time) => _now = time;

  void advance(Duration duration) => _now = _now.add(duration);

  void advanceMinutes(int minutes) => advance(Duration(minutes: minutes));

  void advanceHours(int hours) => advance(Duration(hours: hours));

  void advanceDays(int days) => advance(Duration(days: days));

  /// Set to a specific time of day while keeping the date
  void setTimeOfDay(int hour, int minute, [int second = 0]) {
    _now = DateTime(_now.year, _now.month, _now.day, hour, minute, second);
  }

  /// Set to a specific weekday (1=Monday, 7=Sunday)
  void setWeekday(int weekday) {
    final currentWeekday = _now.weekday;
    final diff = weekday - currentWeekday;
    _now = _now.add(Duration(days: diff));
  }
}

/// Captures haptic feedback calls for testing vibrate action
class FakeHapticFeedback {
  static final List<String> calls = [];
  static bool shouldFail = false;

  static void reset() {
    calls.clear();
    shouldFail = false;
  }

  static Future<void> heavyImpact() async {
    if (shouldFail) {
      throw PlatformException(code: 'HAPTIC_FAILED');
    }
    calls.add('heavyImpact');
  }
}

/// Test helper to capture all side effects
class SideEffectCapture {
  final List<(int, String)> sentMessages = [];
  final List<(int, String)> sentChannelMessages = [];
  final FakeRtttlPlayer rtttlPlayer = FakeRtttlPlayer();
  final FakeGlyphService glyphService = FakeGlyphService();
  final FakeNotificationsPlugin notificationsPlugin = FakeNotificationsPlugin();
  final FakeUrlLauncher urlLauncher = FakeUrlLauncher();

  Future<bool> onSendMessage(int nodeNum, String message) async {
    sentMessages.add((nodeNum, message));
    return true;
  }

  Future<bool> onSendToChannel(int channelIndex, String message) async {
    sentChannelMessages.add((channelIndex, message));
    return true;
  }

  void reset() {
    sentMessages.clear();
    sentChannelMessages.clear();
    rtttlPlayer.reset();
    glyphService.reset();
    notificationsPlugin.reset();
    urlLauncher.reset();
    FakeHapticFeedback.reset();
  }

  /// Assert no side effects occurred
  void assertNoSideEffects() {
    expect(sentMessages, isEmpty, reason: 'Expected no messages sent');
    expect(
      sentChannelMessages,
      isEmpty,
      reason: 'Expected no channel messages sent',
    );
    expect(
      rtttlPlayer.playedSounds,
      isEmpty,
      reason: 'Expected no sounds played',
    );
    expect(
      glyphService.shownPatterns,
      isEmpty,
      reason: 'Expected no glyph patterns',
    );
    expect(
      notificationsPlugin.shownNotifications,
      isEmpty,
      reason: 'Expected no notifications',
    );
    expect(
      urlLauncher.launchedUrls,
      isEmpty,
      reason: 'Expected no URLs launched',
    );
  }
}
