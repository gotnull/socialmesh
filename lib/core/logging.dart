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
  static bool? _protocolLoggingEnabled;
  static bool? _widgetBuilderLoggingEnabled;
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
  static Logger? _bleLogger;
  static Logger? _noOpLogger;

  static bool get bleLoggingEnabled {
    _bleLoggingEnabled ??=
        _safeGetEnv('BLE_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _bleLoggingEnabled!;
  }

  static bool get protocolLoggingEnabled {
    _protocolLoggingEnabled ??=
        _safeGetEnv('PROTOCOL_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _protocolLoggingEnabled!;
  }

  static bool get widgetBuilderLoggingEnabled {
    _widgetBuilderLoggingEnabled ??=
        _safeGetEnv('WIDGET_BUILDER_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _widgetBuilderLoggingEnabled!;
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

  static void protocol(String message) {
    if (protocolLoggingEnabled) debugPrint('📦 Protocol: $message');
  }

  static void widgetBuilder(String message) {
    if (widgetBuilderLoggingEnabled) debugPrint('�� WidgetBuilder: $message');
  }

  static void liveActivity(String message) {
    if (liveActivityLoggingEnabled) debugPrint('📱 LiveActivity: $message');
  }

  static void automations(String message) {
    if (automationsLoggingEnabled) debugPrint('🤖 $message');
  }

  static void messages(String message) {
    if (messagesLoggingEnabled) debugPrint('📨 $message');
  }

  static void ifttt(String message) {
    if (iftttLoggingEnabled) debugPrint('🔗 IFTTT: $message');
  }

  static void telemetry(String message) {
    if (telemetryLoggingEnabled) debugPrint('📊 Telemetry: $message');
  }

  static void connection(String message) {
    if (connectionLoggingEnabled) debugPrint('🔄 $message');
  }

  static void nodes(String message) {
    if (nodesLoggingEnabled) debugPrint('📍 $message');
  }

  static void channels(String message) {
    if (channelsLoggingEnabled) debugPrint('📡 $message');
  }

  static void app(String message) {
    if (appLoggingEnabled) debugPrint('🔵 $message');
  }

  static void subscriptions(String message) {
    if (subscriptionsLoggingEnabled) debugPrint('💳 $message');
  }

  static void notifications(String message) {
    if (notificationsLoggingEnabled) debugPrint('🔔 $message');
  }

  static void audio(String message) {
    if (audioLoggingEnabled) debugPrint('🔊 $message');
  }

  static void maps(String message) {
    if (mapsLoggingEnabled) debugPrint('🗺️ $message');
  }

  static void firmware(String message) {
    if (firmwareLoggingEnabled) debugPrint('📲 $message');
  }

  static void settings(String message) {
    if (settingsLoggingEnabled) debugPrint('⚙️ $message');
  }

  static void debug(String message) {
    if (debugLoggingEnabled) debugPrint('🐛 $message');
  }

  static void auth(String message) {
    if (authLoggingEnabled) debugPrint('🔐 Auth: $message');
  }

  static void reset() {
    _bleLoggingEnabled = null;
    _protocolLoggingEnabled = null;
    _widgetBuilderLoggingEnabled = null;
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
    _bleLogger = null;
    _noOpLogger = null;
  }
}
