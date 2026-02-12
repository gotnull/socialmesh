// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';

/// A Logger that outputs nothing
class _NoOpOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    // Do nothing
  }
}

/// Helper to safely read env vars (returns null if dotenv not initialized)
String? _safeGetEnv(String key) {
  try {
    return dotenv.env[key];
  } catch (_) {
    // dotenv not initialized (e.g. in tests)
    return null;
  }
}

/// Centralized logging configuration
class AppLogging {
  static bool? _bleLoggingEnabled;
  static bool? _mapLoggingEnabled;
  static bool? _protocolLoggingEnabled;
  static bool? _widgetsLoggingEnabled;
  static bool? _liveActivityLoggingEnabled;
  static bool? _automationsLoggingEnabled;
  static bool? _messagesLoggingEnabled;
  static bool? _iftttLoggingEnabled;
  static bool? _telemetryLoggingEnabled;
  static bool? _connectionLoggingEnabled;
  static bool? _nodesLoggingEnabled;
  static bool? _channelsLoggingEnabled;
  static bool? _appLoggingEnabled;
  static bool? _subscriptionsLoggingEnabled;
  static bool? _notificationsLoggingEnabled;
  static bool? _audioLoggingEnabled;
  static bool? _mapsLoggingEnabled;
  static bool? _firmwareLoggingEnabled;
  static bool? _settingsLoggingEnabled;
  static bool? _debugLoggingEnabled;
  static bool? _authLoggingEnabled;
  static bool? _socialLoggingEnabled;
  static bool? _storageLoggingEnabled;
  static bool? _permissionsLoggingEnabled;
  static bool? _marketplaceLoggingEnabled;
  static bool? _qrLoggingEnabled;
  static bool? _bugReportLoggingEnabled;
  static bool? _shopLoggingEnabled;
  static bool? _nodeDexLoggingEnabled;
  static bool? _syncLoggingEnabled;
  static bool? _mfaLoggingEnabled;
  static bool? _forceEmptyStates;
  static Logger? _bleLogger;
  static Logger? _mapLogger;
  static Logger? _noOpLogger;

  static bool get bleLoggingEnabled {
    _bleLoggingEnabled ??=
        _safeGetEnv('BLE_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _bleLoggingEnabled!;
  }

  static bool get mapLoggingEnabled {
    _mapLoggingEnabled ??=
        _safeGetEnv('MAP_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _mapLoggingEnabled!;
  }

  static bool get protocolLoggingEnabled {
    _protocolLoggingEnabled ??=
        _safeGetEnv('PROTOCOL_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _protocolLoggingEnabled!;
  }

  static bool get widgetsLoggingEnabled {
    _widgetsLoggingEnabled ??=
        _safeGetEnv('WIDGET_BUILDER_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _widgetsLoggingEnabled!;
  }

  static bool get liveActivityLoggingEnabled {
    _liveActivityLoggingEnabled ??=
        _safeGetEnv('LIVE_ACTIVITY_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _liveActivityLoggingEnabled!;
  }

  static bool get automationsLoggingEnabled {
    _automationsLoggingEnabled ??=
        _safeGetEnv('AUTOMATIONS_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _automationsLoggingEnabled!;
  }

  static bool get messagesLoggingEnabled {
    _messagesLoggingEnabled ??=
        _safeGetEnv('MESSAGES_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _messagesLoggingEnabled!;
  }

  static bool get iftttLoggingEnabled {
    _iftttLoggingEnabled ??=
        _safeGetEnv('IFTTT_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _iftttLoggingEnabled!;
  }

  static bool get telemetryLoggingEnabled {
    _telemetryLoggingEnabled ??=
        _safeGetEnv('TELEMETRY_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _telemetryLoggingEnabled!;
  }

  static bool get connectionLoggingEnabled {
    _connectionLoggingEnabled ??=
        _safeGetEnv('CONNECTION_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _connectionLoggingEnabled!;
  }

  static bool get nodesLoggingEnabled {
    _nodesLoggingEnabled ??=
        _safeGetEnv('NODES_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _nodesLoggingEnabled!;
  }

  static bool get channelsLoggingEnabled {
    _channelsLoggingEnabled ??=
        _safeGetEnv('CHANNELS_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _channelsLoggingEnabled!;
  }

  static bool get appLoggingEnabled {
    _appLoggingEnabled ??=
        _safeGetEnv('APP_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _appLoggingEnabled!;
  }

  static bool get subscriptionsLoggingEnabled {
    _subscriptionsLoggingEnabled ??=
        _safeGetEnv('SUBSCRIPTIONS_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _subscriptionsLoggingEnabled!;
  }

  static bool get notificationsLoggingEnabled {
    _notificationsLoggingEnabled ??=
        _safeGetEnv('NOTIFICATIONS_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _notificationsLoggingEnabled!;
  }

  static bool get audioLoggingEnabled {
    _audioLoggingEnabled ??=
        _safeGetEnv('AUDIO_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _audioLoggingEnabled!;
  }

  static bool get mapsLoggingEnabled {
    _mapsLoggingEnabled ??=
        _safeGetEnv('MAPS_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _mapsLoggingEnabled!;
  }

  static bool get firmwareLoggingEnabled {
    _firmwareLoggingEnabled ??=
        _safeGetEnv('FIRMWARE_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _firmwareLoggingEnabled!;
  }

  static bool get settingsLoggingEnabled {
    _settingsLoggingEnabled ??=
        _safeGetEnv('SETTINGS_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _settingsLoggingEnabled!;
  }

  static bool get debugLoggingEnabled {
    _debugLoggingEnabled ??=
        _safeGetEnv('DEBUG_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _debugLoggingEnabled!;
  }

  static bool get authLoggingEnabled {
    _authLoggingEnabled ??=
        _safeGetEnv('AUTH_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _authLoggingEnabled!;
  }

  static bool get socialLoggingEnabled {
    _socialLoggingEnabled ??=
        _safeGetEnv('SOCIAL_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _socialLoggingEnabled!;
  }

  static bool get storageLoggingEnabled {
    _storageLoggingEnabled ??=
        _safeGetEnv('STORAGE_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _storageLoggingEnabled!;
  }

  static bool get permissionsLoggingEnabled {
    _permissionsLoggingEnabled ??=
        _safeGetEnv('PERMISSIONS_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _permissionsLoggingEnabled!;
  }

  static bool get marketplaceLoggingEnabled {
    _marketplaceLoggingEnabled ??=
        _safeGetEnv('MARKETPLACE_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _marketplaceLoggingEnabled!;
  }

  static bool get qrLoggingEnabled {
    _qrLoggingEnabled ??=
        _safeGetEnv('QR_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _qrLoggingEnabled!;
  }

  static bool get bugReportLoggingEnabled {
    _bugReportLoggingEnabled ??=
        _safeGetEnv('BUG_REPORT_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _bugReportLoggingEnabled!;
  }

  static bool get shopLoggingEnabled {
    _shopLoggingEnabled ??=
        _safeGetEnv('SHOP_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _shopLoggingEnabled!;
  }

  static bool get nodeDexLoggingEnabled {
    _nodeDexLoggingEnabled ??=
        _safeGetEnv('NODEDEX_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _nodeDexLoggingEnabled!;
  }

  static bool get mfaLoggingEnabled {
    _mfaLoggingEnabled ??=
        _safeGetEnv('MFA_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _mfaLoggingEnabled!;
  }

  /// Cloud Sync logging — always enabled by default for debugging sync issues.
  /// Disable with SYNC_LOGGING_ENABLED=false if needed.
  static bool get syncLoggingEnabled {
    _syncLoggingEnabled ??=
        _safeGetEnv('SYNC_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _syncLoggingEnabled!;
  }

  /// Force empty states to show for testing animated empty state widgets.
  /// Enable with DEBUG_EMPTY_STATES=true in .env file.
  /// Defaults to false (opt-in).
  static bool get forceEmptyStates {
    _forceEmptyStates ??=
        _safeGetEnv('DEBUG_EMPTY_STATES')?.toLowerCase() == 'true';
    return _forceEmptyStates!;
  }

  static Logger get bleLogger {
    if (bleLoggingEnabled) {
      _bleLogger ??= Logger(
        printer: PrettyPrinter(methodCount: 0, printEmojis: false),
      );
      return _bleLogger!;
    } else {
      _noOpLogger ??= Logger(output: _NoOpOutput());
      return _noOpLogger!;
    }
  }

  static void ble(String message) {
    if (bleLoggingEnabled) debugPrint('📱 BLE: $message');
  }

  static Logger get mapLogger {
    if (mapLoggingEnabled) {
      _mapLogger ??= Logger(
        printer: PrettyPrinter(methodCount: 0, printEmojis: false),
      );
      return _mapLogger!;
    } else {
      _noOpLogger ??= Logger(output: _NoOpOutput());
      return _noOpLogger!;
    }
  }

  static void map(String message) {
    if (mapLoggingEnabled) debugPrint('MAP: $message');
  }

  static void protocol(String message) {
    if (protocolLoggingEnabled) debugPrint('Protocol: $message');
  }

  static void widgets(String message) {
    if (widgetsLoggingEnabled) debugPrint('Widgets: $message');
  }

  static void liveActivity(String message) {
    if (liveActivityLoggingEnabled) debugPrint('LiveActivity: $message');
  }

  static void automations(String message) {
    if (automationsLoggingEnabled) debugPrint('Automations: $message');
  }

  static void messages(String message) {
    if (messagesLoggingEnabled) debugPrint('Messages: $message');
  }

  static void ifttt(String message) {
    if (iftttLoggingEnabled) debugPrint('IFTTT: $message');
  }

  static void telemetry(String message) {
    if (telemetryLoggingEnabled) debugPrint('Telemetry: $message');
  }

  static void connection(String message) {
    if (connectionLoggingEnabled) debugPrint('Connection: $message');
  }

  static void nodes(String message) {
    if (nodesLoggingEnabled) debugPrint('Nodes: $message');
  }

  static void channels(String message) {
    if (channelsLoggingEnabled) debugPrint('Channels: $message');
  }

  static void app(String message) {
    if (appLoggingEnabled) debugPrint('App: $message');
  }

  static void subscriptions(String message) {
    if (subscriptionsLoggingEnabled) debugPrint('Subscriptions: $message');
  }

  static void notifications(String message) {
    if (notificationsLoggingEnabled) debugPrint('🔔 $message');
  }

  static void audio(String message) {
    if (audioLoggingEnabled) debugPrint('Audio: $message');
  }

  static void maps(String message) {
    if (mapsLoggingEnabled) debugPrint('Maps: $message');
  }

  static void firmware(String message) {
    if (firmwareLoggingEnabled) debugPrint('Firmware: $message');
  }

  static void settings(String message) {
    if (settingsLoggingEnabled) debugPrint('Settings: $message');
  }

  static void debug(String message) {
    if (debugLoggingEnabled) debugPrint('Debug: $message');
  }

  static void auth(String message) {
    if (authLoggingEnabled) debugPrint('Auth: $message');
  }

  static void social(String message) {
    if (socialLoggingEnabled) debugPrint('Social: $message');
  }

  static void storage(String message) {
    if (storageLoggingEnabled) debugPrint('Storage: $message');
  }

  static void permissions(String message) {
    if (permissionsLoggingEnabled) debugPrint('Permissions: $message');
  }

  static void marketplace(String message) {
    if (marketplaceLoggingEnabled) debugPrint('Marketplace: $message');
  }

  static void qr(String message) {
    if (qrLoggingEnabled) debugPrint('QR: $message');
  }

  static void bugReport(String message) {
    if (bugReportLoggingEnabled) debugPrint('BugReport: $message');
  }

  static void shop(String message) {
    if (shopLoggingEnabled) debugPrint('Shop: $message');
  }

  static void nodeDex(String message) {
    if (nodeDexLoggingEnabled) debugPrint('NodeDex: $message');
  }

  /// Always-on Cloud Sync logging channel.
  ///
  /// Use this for sync pipeline instrumentation so sync issues
  /// are always visible in device logs regardless of other logging flags.
  /// Grep with: `adb logcat | grep "SYNC:"` or filter for "SYNC:" in Xcode.
  static void sync(String message) {
    if (syncLoggingEnabled) debugPrint('SYNC: $message');
  }

  static void mfa(String message) {
    if (mfaLoggingEnabled) debugPrint('MFA: $message');
  }

  static void reset() {
    _bleLoggingEnabled = null;
    _protocolLoggingEnabled = null;
    _widgetsLoggingEnabled = null;
    _liveActivityLoggingEnabled = null;
    _automationsLoggingEnabled = null;
    _messagesLoggingEnabled = null;
    _iftttLoggingEnabled = null;
    _telemetryLoggingEnabled = null;
    _connectionLoggingEnabled = null;
    _nodesLoggingEnabled = null;
    _channelsLoggingEnabled = null;
    _appLoggingEnabled = null;
    _subscriptionsLoggingEnabled = null;
    _notificationsLoggingEnabled = null;
    _audioLoggingEnabled = null;
    _mapsLoggingEnabled = null;
    _firmwareLoggingEnabled = null;
    _settingsLoggingEnabled = null;
    _debugLoggingEnabled = null;
    _authLoggingEnabled = null;
    _socialLoggingEnabled = null;
    _storageLoggingEnabled = null;
    _permissionsLoggingEnabled = null;
    _marketplaceLoggingEnabled = null;
    _qrLoggingEnabled = null;
    _bugReportLoggingEnabled = null;
    _shopLoggingEnabled = null;
    _nodeDexLoggingEnabled = null;
    _syncLoggingEnabled = null;
    _mfaLoggingEnabled = null;
    _bleLogger = null;
    _noOpLogger = null;
  }
}
