// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging.dart';
import '../../core/transport.dart';
import 'background_message_processor.dart';

/// SharedPreferences key tracking whether the battery optimization prompt has
/// been shown to the user. Prevents repeat prompts on every connection.
const String _kBatteryPromptShown = 'bg_battery_prompt_shown';

/// SharedPreferences key for the user-level background BLE toggle.
///
/// Read on Android to gate the foreground service, and on iOS to gate
/// the OS-level pending reconnect that `BleTransport` arms after an
/// unexpected disconnect in the background.
const String kBgBleEnabled = 'bg_ble_enabled';

/// SharedPreferences key for the Android persistent notification style
/// (0 = minimal, 1 = detailed). Owned here so the Riverpod-free service can
/// read the user's choice directly; the settings screen imports this key.
const String kBgNotifStyle = 'bg_notif_style';

/// Manages the Android foreground service that keeps the Dart isolate and BLE
/// connection alive when the app is backgrounded.
///
/// On iOS this class is a no-op -- CoreBluetooth's `bluetooth-central`
/// background mode handles BLE persistence natively.
///
/// Lifecycle:
///   1. [start] after `BleTransport.connect()` succeeds.
///   2. [updateNotification] to reflect the connected device name.
///   3. [stop] on user-initiated disconnect or after auto-reconnect exhaustion.
///
/// This class is intentionally Riverpod-free so it can be used from
/// `BleTransport` without pulling in the provider tree.
class BackgroundBleService {
  BackgroundBleService._();
  static final BackgroundBleService instance = BackgroundBleService._();

  bool _isRunning = false;

  /// Whether the foreground service is currently active.
  bool get isRunning => _isRunning;

  /// Style value for the "detailed" notification (mirrors
  /// `NotificationStyle.detailed.value` in the settings screen).
  static const int _styleDetailed = 1;

  // Notification content state. The persistent notification text is rebuilt
  // from these fields. This service is Riverpod-free, so the provider layer
  // feeds the detailed-style stats via [updateMeshStats] and the settings
  // screen pushes style changes via [setNotificationStyle].
  String _deviceName = '';
  int _notifStyleValue = 0;
  int? _nodeCount;
  DateTime? _lastMessageAt;

  /// The reconnect manager handles exponential-backoff reconnection when BLE
  /// drops while the app is backgrounded.
  final BackgroundReconnectManager reconnectManager =
      BackgroundReconnectManager();

  /// The background message processor decodes incoming BLE packets and
  /// persists text messages without Riverpod.
  final BackgroundMessageProcessor messageProcessor =
      BackgroundMessageProcessor.instance;

  // ---------------------------------------------------------------------------
  // Foreground-task configuration
  // ---------------------------------------------------------------------------

  /// Initialise the foreground task options. Must be called once before [start].
  void init() {
    if (!Platform.isAndroid) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'ble_connection',
        channelName: 'Mesh Connection',
        channelDescription:
            'Keeps the BLE connection to your mesh radio alive', // lint-allow: hardcoded-string
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        // No sound or vibration -- this is a silent status indicator.
        playSound: false,
        enableVibration: false,
        showWhen: false,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        // Keep the isolate alive but don't use the built-in event interval.
        // BLE data arrives via characteristic notifications, not polling.
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    AppLogging.ble('BackgroundBleService: init() complete');
  }

  // ---------------------------------------------------------------------------
  // Start / stop
  // ---------------------------------------------------------------------------

  /// Start the foreground service with a persistent notification showing the
  /// connected device name.
  ///
  /// When [transport] is provided, the background message processor is also
  /// started so incoming text messages are persisted while the app is
  /// backgrounded.
  ///
  /// No-op on iOS or if already running.
  Future<void> start({
    required String deviceName,
    DeviceTransport? transport,
  }) async {
    if (!Platform.isAndroid) return;
    if (_isRunning) {
      AppLogging.ble(
        'BackgroundBleService: already running, updating notification',
      );
      await updateNotification(deviceName: deviceName);
      return;
    }

    AppLogging.ble(
      'BackgroundBleService: starting foreground service for "$deviceName"',
    );

    // Initialise and start the background message processor before the
    // foreground service so messages are captured as soon as the OS grants
    // the service permission.
    if (transport != null) {
      await messageProcessor.init();
      messageProcessor.start(transport);
    }

    _deviceName = deviceName;
    await _loadNotifStyle();

    final result = await FlutterForegroundTask.startService(
      notificationTitle: _notificationTitle(),
      notificationText: _notificationBody(),
      serviceId: 500,
      callback: _foregroundTaskCallback,
    );

    if (result is ServiceRequestSuccess) {
      _isRunning = true;
      AppLogging.ble('BackgroundBleService: foreground service started');
    } else {
      AppLogging.ble(
        'BackgroundBleService: failed to start foreground service: $result',
      );
    }
  }

  /// Update the persistent notification content (e.g. after reconnect to a
  /// different device).
  Future<void> updateNotification({required String deviceName}) async {
    if (!Platform.isAndroid || !_isRunning) return;
    _deviceName = deviceName;
    await _applyNotification();
  }

  /// Update the cached notification style (0 = minimal, 1 = detailed) and
  /// re-render the live notification immediately. Called by the settings
  /// screen when the user picks Minimal / Detailed.
  Future<void> setNotificationStyle(int styleValue) async {
    _notifStyleValue = styleValue;
    await _applyNotification();
  }

  /// Feed the latest mesh stats consumed by the "detailed" notification style.
  /// Re-renders only when the detailed style is active (the minimal text is
  /// static). Called by the provider layer as node / message state changes.
  Future<void> updateMeshStats({
    int? nodeCount,
    DateTime? lastMessageAt,
  }) async {
    _nodeCount = nodeCount;
    _lastMessageAt = lastMessageAt;
    if (_notifStyleValue != _styleDetailed) return;
    await _applyNotification();
  }

  /// Re-render the persistent notification from the current cached state.
  Future<void> _applyNotification() async {
    if (!Platform.isAndroid || !_isRunning) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: _notificationTitle(),
      notificationText: _notificationBody(),
    );
  }

  /// Load the persisted notification style into the cache. Defaults to
  /// minimal (0) when the user has not chosen one.
  Future<void> _loadNotifStyle() async {
    final prefs = await SharedPreferences.getInstance();
    _notifStyleValue = prefs.getInt(kBgNotifStyle) ?? 0;
  }

  String _notificationTitle() =>
      'Connected to $_deviceName'; // lint-allow: hardcoded-string

  String _notificationBody() => buildNotificationBody(
    styleValue: _notifStyleValue,
    nodeCount: _nodeCount,
    lastMessageAt: _lastMessageAt,
    now: DateTime.now(),
  );

  /// Build the notification body for the given style and stats. Detailed
  /// shows node count and last-message age; it falls back to the minimal text
  /// until the provider layer has fed at least one stat. Pure and clock-
  /// injectable so the format is unit-testable without the platform plugin.
  @visibleForTesting
  static String buildNotificationBody({
    required int styleValue,
    required int? nodeCount,
    required DateTime? lastMessageAt,
    required DateTime now,
  }) {
    const minimal =
        'Mesh radio connection active'; // lint-allow: hardcoded-string
    if (styleValue != _styleDetailed) return minimal;

    final parts = <String>[];
    if (nodeCount != null) {
      parts.add(
        nodeCount == 1
            ? '1 node heard' // lint-allow: hardcoded-string
            : '$nodeCount nodes heard', // lint-allow: hardcoded-string
      );
    }
    if (lastMessageAt != null) {
      // lint-allow: hardcoded-string
      parts.add('last message ${_relativeAgo(lastMessageAt, now)}');
    }
    return parts.isEmpty ? minimal : parts.join(', ');
  }

  /// Compact "time ago" label for the detailed notification (e.g. "3m ago").
  static String _relativeAgo(DateTime time, DateTime now) {
    final seconds = now.difference(time).inSeconds;
    if (seconds < 5) return 'just now'; // lint-allow: hardcoded-string
    if (seconds < 60) return '${seconds}s ago'; // lint-allow: hardcoded-string
    if (seconds < 3600) {
      return '${seconds ~/ 60}m ago'; // lint-allow: hardcoded-string
    }
    if (seconds < 86400) {
      return '${seconds ~/ 3600}h ago'; // lint-allow: hardcoded-string
    }
    return '${seconds ~/ 86400}d ago'; // lint-allow: hardcoded-string
  }

  /// Show a "Disconnected" notification after auto-reconnect exhaustion.
  Future<void> showDisconnectedNotification({
    required String deviceName,
  }) async {
    if (!Platform.isAndroid || !_isRunning) return;

    await FlutterForegroundTask.updateService(
      notificationTitle:
          'Disconnected from $deviceName', // lint-allow: hardcoded-string
      notificationText:
          'Auto-reconnect failed. Tap to reopen.', // lint-allow: hardcoded-string
    );
  }

  /// Stop the foreground service. Safe to call even if not running.
  ///
  /// Also fully disposes the background reconnect manager (cancels retries
  /// and tears down the transport state subscription) and stops the message
  /// processor.
  Future<void> stop() async {
    reconnectManager.dispose();
    messageProcessor.stop();

    if (!Platform.isAndroid) return;
    if (!_isRunning) {
      AppLogging.ble('BackgroundBleService: stop() called but not running');
      return;
    }

    AppLogging.ble('BackgroundBleService: stopping foreground service');

    final result = await FlutterForegroundTask.stopService();
    if (result is ServiceRequestSuccess) {
      _isRunning = false;
      AppLogging.ble('BackgroundBleService: foreground service stopped');
    } else {
      // Force-clear the flag even if the stop call reports failure; the OS may
      // have already killed the service.
      _isRunning = false;
      AppLogging.ble(
        'BackgroundBleService: stop returned $result, flag cleared anyway',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Battery optimization
  // ---------------------------------------------------------------------------

  /// Check and optionally prompt the user to disable battery optimization.
  ///
  /// Only shows the prompt once per install (tracked via SharedPreferences).
  /// Returns `true` if the device is already ignoring battery optimizations.
  Future<bool> promptBatteryOptimizationIfNeeded() async {
    if (!Platform.isAndroid) return true;

    final prefs = await SharedPreferences.getInstance();
    final alreadyPrompted = prefs.getBool(_kBatteryPromptShown) ?? false;

    final isIgnoring =
        await FlutterForegroundTask.isIgnoringBatteryOptimizations;

    if (isIgnoring) {
      AppLogging.ble(
        'BackgroundBleService: battery optimization already disabled',
      );
      return true;
    }

    if (alreadyPrompted) {
      AppLogging.ble(
        'BackgroundBleService: battery prompt already shown, skipping',
      );
      return false;
    }

    AppLogging.ble(
      'BackgroundBleService: requesting battery optimization exemption',
    );

    final granted =
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();

    // Mark as shown regardless of outcome so we don't prompt again.
    await prefs.setBool(_kBatteryPromptShown, true);

    AppLogging.ble(
      'BackgroundBleService: battery optimization exemption granted=$granted',
    );
    return granted;
  }

  /// Whether the user-level "background BLE" toggle is enabled.
  ///
  /// Defaults to `true` when no preference has been set.
  static Future<bool> isBackgroundBleEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kBgBleEnabled) ?? true;
  }
}

// =============================================================================
// Background Reconnect Manager
// =============================================================================

/// Callback that attempts a BLE reconnection to the last-known device.
///
/// Returns `true` if the reconnection succeeded, `false` otherwise.
typedef ReconnectCallback = Future<bool> Function();

/// Callback that checks whether the user explicitly disconnected.
typedef UserDisconnectedCheck = bool Function();

/// Callback that checks whether a device reboot is currently expected (e.g.
/// the app just wrote a config change to the local node and the radio is
/// rebooting). Drives tighter retry timing in the post-reboot reconnect
/// window.
typedef RebootExpectedCheck = bool Function();

/// Manages exponential-backoff reconnection attempts when the BLE connection
/// drops while the app is backgrounded.
///
/// The manager is Riverpod-free. The [ReconnectCallback],
/// [UserDisconnectedCheck], and [RebootExpectedCheck] are injected by the
/// provider layer when the foreground service starts.
class BackgroundReconnectManager {
  Timer? _retryTimer;
  int _attempt = 0;
  bool _active = false;
  List<Duration> _activeDelays = _backoffDelaysDefault;

  /// Default backoff delays (unknown disconnect cause): 5 s, 15 s, 45 s.
  static const List<Duration> _backoffDelaysDefault = [
    Duration(seconds: 5),
    Duration(seconds: 15),
    Duration(seconds: 45),
  ];

  /// Backoff delays when a device reboot is expected (e.g. region apply,
  /// node-db reset, factory reset). Initial wait gives the Meshtastic
  /// radio time to finish booting and re-advertise (~8-15 s); subsequent
  /// retries fire faster because the device is known to be coming back,
  /// and FlutterBluePlus's connect() blocks for 15 s on a non-advertising
  /// peripheral so a missed first attempt should retry sooner, not later.
  static const List<Duration> _backoffDelaysRebootExpected = [
    Duration(seconds: 8),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
    Duration(seconds: 5),
  ];

  /// Maximum number of reconnect attempts in the longer (reboot-aware)
  /// schedule. Used by callers that need a stable upper bound regardless
  /// of the schedule that ends up active at runtime.
  static int get maxAttempts => _backoffDelaysRebootExpected.length;

  /// Current attempt index (0-based). Useful for logging/UI.
  int get attempt => _attempt;

  /// Whether a reconnect cycle is currently in progress.
  bool get isActive => _active;

  StreamSubscription<DeviceConnectionState>? _stateSubscription;
  ReconnectCallback? _reconnect;
  UserDisconnectedCheck? _isUserDisconnected;
  RebootExpectedCheck? _isRebootExpected;
  String _deviceName = '';

  /// Begin observing [transportStateStream] for unexpected disconnects.
  ///
  /// When a disconnect is detected (and the user did not manually disconnect),
  /// the manager will attempt reconnection with exponential backoff.
  ///
  /// [isRebootExpected] selects the tighter backoff schedule when the
  /// disconnect was triggered by a known impending device reboot (region
  /// apply, factory reset, node-db reset, any config write). Optional;
  /// when omitted, the default backoff is used for every disconnect.
  ///
  /// Call [dispose] or [cancel] to stop listening.
  void observe({
    required Stream<DeviceConnectionState> transportStateStream,
    required ReconnectCallback reconnect,
    required UserDisconnectedCheck isUserDisconnected,
    required String deviceName,
    RebootExpectedCheck? isRebootExpected,
  }) {
    // Tear down any previous observer.
    _stateSubscription?.cancel();
    _reconnect = reconnect;
    _isUserDisconnected = isUserDisconnected;
    _isRebootExpected = isRebootExpected;
    _deviceName = deviceName;

    _stateSubscription = transportStateStream.listen((state) {
      if (state == DeviceConnectionState.disconnected) {
        _onDisconnect();
      } else if (state == DeviceConnectionState.connected) {
        // Connection restored (either by us or the foreground path).
        _onReconnected();
      }
    });

    AppLogging.ble(
      'BackgroundReconnectManager: observing transport for "$deviceName"',
    );
  }

  void _onDisconnect() {
    if (_isUserDisconnected?.call() ?? false) {
      AppLogging.ble(
        'BackgroundReconnectManager: disconnect detected but user-initiated, '
        'skipping reconnect',
      );
      return;
    }

    if (_active) {
      AppLogging.ble(
        'BackgroundReconnectManager: disconnect detected but reconnect '
        'already active, ignoring',
      );
      return;
    }

    final rebootExpected = _isRebootExpected?.call() ?? false;
    _activeDelays = rebootExpected
        ? _backoffDelaysRebootExpected
        : _backoffDelaysDefault;
    AppLogging.ble(
      'BackgroundReconnectManager: unexpected disconnect, '
      'starting reconnect cycle (rebootExpected=$rebootExpected, '
      'schedule=${_activeDelays.map((d) => '${d.inSeconds}s').join('/')})',
    );
    _attempt = 0;
    _active = true;
    _scheduleNextAttempt();
  }

  void _onReconnected() {
    if (!_active) return;
    AppLogging.ble(
      'BackgroundReconnectManager: connection restored after '
      '$_attempt attempt(s)',
    );
    _retryTimer?.cancel();
    _active = false;
    _attempt = 0;

    // Update the persistent notification back to "Connected".
    BackgroundBleService.instance.updateNotification(deviceName: _deviceName);
  }

  void _scheduleNextAttempt() {
    if (_attempt >= _activeDelays.length) {
      _onReconnectExhausted();
      return;
    }

    final delay = _activeDelays[_attempt];
    AppLogging.ble(
      'BackgroundReconnectManager: attempt ${_attempt + 1}/${_activeDelays.length} '
      'in ${delay.inSeconds}s',
    );

    _retryTimer?.cancel();
    _retryTimer = Timer(delay, _performAttempt);
  }

  Future<void> _performAttempt() async {
    if (!_active) return;
    if (_isUserDisconnected?.call() ?? false) {
      AppLogging.ble(
        'BackgroundReconnectManager: user disconnected during backoff, aborting',
      );
      cancel();
      return;
    }

    AppLogging.ble(
      'BackgroundReconnectManager: attempting reconnect '
      '(attempt ${_attempt + 1}/${_activeDelays.length})',
    );

    final success = await (_reconnect?.call() ?? Future.value(false));
    if (success) {
      // _onReconnected will be called by the stateStream listener when
      // the transport transitions to connected.
      AppLogging.ble('BackgroundReconnectManager: reconnect call succeeded');
    } else {
      AppLogging.ble('BackgroundReconnectManager: reconnect call failed');
      _attempt++;
      _scheduleNextAttempt();
    }
  }

  void _onReconnectExhausted() {
    AppLogging.ble(
      'BackgroundReconnectManager: all ${_activeDelays.length} attempts '
      'exhausted, stopping service',
    );
    _active = false;
    _attempt = 0;

    // Show "Disconnected" notification, then stop the foreground service.
    final service = BackgroundBleService.instance;
    service.showDisconnectedNotification(deviceName: _deviceName).then((_) {
      // Give the user a moment to see the notification before stopping.
      Future.delayed(const Duration(seconds: 2), service.stop);
    });
  }

  /// Cancel any in-progress reconnect cycle and stop observing.
  void cancel() {
    _retryTimer?.cancel();
    _active = false;
    _attempt = 0;
  }

  /// Fully tear down: cancel reconnect and stop listening to transport.
  void dispose() {
    cancel();
    _stateSubscription?.cancel();
    _stateSubscription = null;
    _reconnect = null;
    _isUserDisconnected = null;
  }
}

// ---------------------------------------------------------------------------
// Foreground task callback (runs in a separate Dart isolate on Android)
// ---------------------------------------------------------------------------

/// Top-level callback required by `flutter_foreground_task`.
///
/// The actual BLE data processing happens on the _main_ isolate where
/// `BleTransport` characteristics are subscribed. This callback simply keeps
/// the isolate alive; no additional work is needed here for Phase 1.
@pragma('vm:entry-point')
void _foregroundTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_BleTaskHandler());
}

/// Minimal task handler. The foreground service's sole purpose at this stage
/// is to prevent the OS from killing the Dart isolate. BLE data flows through
/// the main isolate's characteristic subscriptions, not through this handler.
class _BleTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Service started.
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Not used -- eventAction is set to nothing().
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    // Service destroyed by OS or explicit stop.
  }
}
