// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
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
  /// Optional callback that receives structured log events for the in-app
  /// log viewer. Set once during app initialization to bridge console
  /// logging into the in-memory [AppLogger] ring buffer.
  ///
  /// Signature: (int level, String source, String message)
  /// Levels: 0=debug, 1=info, 2=warning, 3=error
  static void Function(int level, String source, String message)? _appLogSink;

  /// Registers the in-app log sink. Call once during app startup.
  static void setAppLogSink(
    void Function(int level, String source, String message) sink,
  ) {
    _appLogSink = sink;
  }

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
  static bool? _nodeBoardLoggingEnabled;
  static bool? _petLoggingEnabled;
  static bool? _syncLoggingEnabled;
  static bool? _mfaLoggingEnabled;
  static bool? _aetherLoggingEnabled;
  static bool? _takLoggingEnabled;
  static bool? _claimsLoggingEnabled;
  static bool? _uiGatesLoggingEnabled;
  static bool? _incidentsLoggingEnabled;
  static bool? _incidentSyncLoggingEnabled;
  static bool? _incidentUILoggingEnabled;
  static bool? _adminDiagLoggingEnabled;
  static bool? _tasksLoggingEnabled;
  static bool? _taskSyncLoggingEnabled;
  static bool? _fileTransferLoggingEnabled;
  static bool? _sipLoggingEnabled;
  static bool? _sipInkLoggingEnabled;
  static bool? _sipPlayLoggingEnabled;
  static bool? _sipSignalLoggingEnabled;
  static bool? _mrrpDebugEnabled;
  static bool? _mrrpHarnessDebugEnabled;
  static bool? _meshExplorerDebugEnabled;
  static bool? _voiceLoggingEnabled;
  static bool? _codec2LoggingEnabled;
  static bool? _sppLoggingEnabled;
  static bool? _sppNegotiationLoggingEnabled;
  static bool? _stlLoggingEnabled;
  static bool? _overlayLoggingEnabled;
  static bool? _reticulumLoggingEnabled;
  static bool? _meshFeedLoggingEnabled;
  static bool? _meshGamesLoggingEnabled;
  static bool? _meshGameTransportLoggingEnabled;
  static bool? _meshGameSessionLoggingEnabled;
  static bool? _meshGameUiLoggingEnabled;
  static bool? _mqttProxyLoggingEnabled;
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

  static bool get nodeBoardLoggingEnabled {
    _nodeBoardLoggingEnabled ??=
        _safeGetEnv('NODEBOARD_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _nodeBoardLoggingEnabled!;
  }

  static bool get petLoggingEnabled {
    _petLoggingEnabled ??=
        _safeGetEnv('PET_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _petLoggingEnabled!;
  }

  static bool get mfaLoggingEnabled {
    _mfaLoggingEnabled ??=
        _safeGetEnv('MFA_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _mfaLoggingEnabled!;
  }

  static bool get aetherLoggingEnabled {
    _aetherLoggingEnabled ??=
        _safeGetEnv('AETHER_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _aetherLoggingEnabled!;
  }

  static bool get takLoggingEnabled {
    _takLoggingEnabled ??=
        _safeGetEnv('TAK_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _takLoggingEnabled!;
  }

  /// Org claims caching and refresh logging.
  /// Enable with CLAIMS_LOGGING_ENABLED=true in .env file.
  static bool get claimsLoggingEnabled {
    _claimsLoggingEnabled ??=
        _safeGetEnv('CLAIMS_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _claimsLoggingEnabled!;
  }

  /// RBAC UI gate visibility logging.
  /// Enable with UI_GATES_LOGGING_ENABLED=true in .env file.
  static bool get uiGatesLoggingEnabled {
    _uiGatesLoggingEnabled ??=
        _safeGetEnv('UI_GATES_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _uiGatesLoggingEnabled!;
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

  /// Severity-2 BLE warning. Forwarded to the app log sink (in-app log
  /// viewer / Crashlytics bridge) at warning level so support telemetry
  /// can surface receive-pipeline stalls and recovery failures even
  /// when verbose BLE logging is disabled at the device.
  static void bleWarning(String message) {
    if (bleLoggingEnabled) debugPrint('📱 BLE: $message');
    _appLogSink?.call(2, 'ble', message);
  }

  /// Short fingerprint for a PSK / public-key byte string suitable for
  /// log lines.
  ///
  /// Format: `<len>B:aabbccdd…eeff0011` — the byte length, a colon, and
  /// the first 4 + last 4 bytes in lowercase hex. Empty/null PSKs
  /// render as `0B:none`. Single-byte PSKs (the canonical default
  /// LongFast `AQ==`) render as `1B:01`.
  ///
  /// Never log the full PSK — channel keys are user secrets. The
  /// fingerprint is enough to spot mismatches between sent / saved /
  /// re-read keys without leaking the encryption material.
  static String pskFingerprint(List<int>? psk) {
    if (psk == null || psk.isEmpty) return '0B:none';
    final hex = psk.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    if (psk.length <= 8) {
      return '${psk.length}B:$hex';
    }
    final head = hex.substring(0, 8);
    final tail = hex.substring(hex.length - 8);
    return '${psk.length}B:$head…$tail';
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
    if (appLoggingEnabled) {
      debugPrint('App: $message');
      _appLogSink?.call(1, 'app', message); // lint-allow: hardcoded-string
    }
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

  static void nodeBoard(String message) {
    if (nodeBoardLoggingEnabled) debugPrint('NodeBoard: $message');
  }

  static void pet(String message) {
    if (petLoggingEnabled) debugPrint('Pet: $message');
  }

  /// Always-on Cloud Sync logging channel.
  ///
  /// Use this for sync pipeline instrumentation so sync issues
  /// are always visible in device logs regardless of other logging flags.
  /// Grep with: `adb logcat | grep "SYNC:"` or filter for "SYNC:" in Xcode.
  static void sync(String message) {
    if (syncLoggingEnabled) debugPrint('Sync: $message');
  }

  static void mfa(String message) {
    if (mfaLoggingEnabled) debugPrint('MFA: $message');
  }

  static void aether(String message) {
    if (aetherLoggingEnabled) debugPrint('Aether: $message');
  }

  static void tak(String message) {
    if (takLoggingEnabled) debugPrint('TAK: $message');
  }

  static void claims(String message) {
    if (claimsLoggingEnabled) debugPrint(message);
  }

  static void uiGates(String message) {
    if (uiGatesLoggingEnabled) debugPrint('Gate: $message');
  }

  /// Incident lifecycle logging.
  /// Enable with INCIDENTS_LOGGING_ENABLED=true in .env file.
  static bool get incidentsLoggingEnabled {
    _incidentsLoggingEnabled ??=
        _safeGetEnv('INCIDENTS_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _incidentsLoggingEnabled!;
  }

  static void incidents(String message) {
    if (incidentsLoggingEnabled) debugPrint('Incidents: $message');
  }

  /// Incident sync conflict resolution logging.
  /// Enable with INCIDENT_SYNC_LOGGING_ENABLED=true in .env file.
  static bool get incidentSyncLoggingEnabled {
    _incidentSyncLoggingEnabled ??=
        _safeGetEnv('INCIDENT_SYNC_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _incidentSyncLoggingEnabled!;
  }

  static void incidentSync(String message) {
    if (incidentSyncLoggingEnabled) debugPrint('IncidentSync: $message');
  }

  /// Incident UI screen logging.
  /// Enable with INCIDENT_UI_LOGGING_ENABLED=true in .env file.
  static bool get incidentUILoggingEnabled {
    _incidentUILoggingEnabled ??=
        _safeGetEnv('INCIDENT_UI_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _incidentUILoggingEnabled!;
  }

  static void incidentUI(String message) {
    if (incidentUILoggingEnabled) debugPrint('IncidentUI: $message');
  }

  /// Task system logging.
  /// Enable with TASKS_LOGGING_ENABLED=true in .env file.
  static bool get tasksLoggingEnabled {
    _tasksLoggingEnabled ??=
        _safeGetEnv('TASKS_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _tasksLoggingEnabled!;
  }

  static void tasks(String message) {
    if (tasksLoggingEnabled) debugPrint('Tasks: $message');
  }

  /// Task sync conflict resolution logging.
  /// Enable with TASK_SYNC_LOGGING_ENABLED=true in .env file.
  static bool get taskSyncLoggingEnabled {
    _taskSyncLoggingEnabled ??=
        _safeGetEnv('TASK_SYNC_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _taskSyncLoggingEnabled!;
  }

  static void taskSync(String message) {
    if (taskSyncLoggingEnabled) debugPrint('TaskSync: $message');
  }

  /// Admin diagnostic harness logging.
  /// Always enabled — diagnostic sessions are explicit user actions.
  static bool get adminDiagLoggingEnabled {
    _adminDiagLoggingEnabled ??=
        _safeGetEnv('ADMIN_DIAG_LOGGING_ENABLED')?.toLowerCase() != 'false';
    return _adminDiagLoggingEnabled!;
  }

  static void adminDiag(String message) {
    if (adminDiagLoggingEnabled) debugPrint('AdminDiag: $message');
  }

  /// File transfer engine logging.
  /// Enable with FILE_TRANSFER_LOGGING_ENABLED=true in .env file.
  static bool get fileTransferLoggingEnabled {
    _fileTransferLoggingEnabled ??=
        _safeGetEnv('FILE_TRANSFER_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _fileTransferLoggingEnabled!;
  }

  static void fileTransfer(String message) {
    if (fileTransferLoggingEnabled) debugPrint('FileTransfer: $message');
  }

  static bool get sipLoggingEnabled {
    _sipLoggingEnabled ??=
        _safeGetEnv('SIP_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _sipLoggingEnabled!;
  }

  static void sip(String message) {
    if (sipLoggingEnabled) debugPrint('SIP: $message');
  }

  /// SIP Ink (sketch) observability logging.
  /// Enable with SIP_INK_LOGGING_ENABLED=true in .env file.
  static bool get sipInkLoggingEnabled {
    _sipInkLoggingEnabled ??=
        _safeGetEnv('SIP_INK_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _sipInkLoggingEnabled!;
  }

  static void sipInk(String message) {
    if (sipInkLoggingEnabled) debugPrint('SIP_INK: $message');
  }

  /// SIP Play turn-based mini-game observability logging.
  /// Enable with SIP_PLAY_LOGGING_ENABLED=true in .env file.
  static bool get sipPlayLoggingEnabled {
    _sipPlayLoggingEnabled ??=
        _safeGetEnv('SIP_PLAY_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _sipPlayLoggingEnabled!;
  }

  static void sipPlay(String message) {
    if (sipPlayLoggingEnabled) debugPrint('SIP_PLAY: $message');
  }

  /// SIP Signal (musical phrase + Morse) observability logging.
  /// Enable with SIP_SIGNAL_LOGGING_ENABLED=true in .env file.
  /// Never log waveform samples — only structural events (compose,
  /// encode size, send attempts, dedupe drops, decode failures).
  static bool get sipSignalLoggingEnabled {
    _sipSignalLoggingEnabled ??=
        _safeGetEnv('SIP_SIGNAL_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _sipSignalLoggingEnabled!;
  }

  static void sipSignal(String message) {
    if (sipSignalLoggingEnabled) debugPrint('SIP_SIGNAL: $message');
  }

  /// Reticulum tunnel (Meshtastic portnum 76) observability logging.
  /// Enable with RETICULUM_LOGGING_ENABLED=true in .env file.
  static bool get reticulumLoggingEnabled {
    _reticulumLoggingEnabled ??=
        _safeGetEnv('RETICULUM_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _reticulumLoggingEnabled!;
  }

  static void reticulum(String message) {
    if (reticulumLoggingEnabled) debugPrint('Reticulum: $message');
  }

  /// MRRP protocol debug logging.
  /// Enable with MRRP_DEBUG=true in .env file.
  static bool get mrrpDebugEnabled {
    _mrrpDebugEnabled ??= _safeGetEnv('MRRP_DEBUG')?.toLowerCase() == 'true';
    return _mrrpDebugEnabled!;
  }

  static void mrrp(String message) {
    if (mrrpDebugEnabled) debugPrint('MRRP: $message');
  }

  /// MRRP harness debug logging.
  /// Enable with MRRP_HARNESS_DEBUG=true in .env file.
  static bool get mrrpHarnessDebugEnabled {
    _mrrpHarnessDebugEnabled ??=
        _safeGetEnv('MRRP_HARNESS_DEBUG')?.toLowerCase() == 'true';
    return _mrrpHarnessDebugEnabled!;
  }

  static void mrrpHarness(String message) {
    if (mrrpHarnessDebugEnabled) debugPrint('MRRP_HARNESS: $message');
  }

  /// Mesh Explorer debug logging.
  /// Enable with MESH_EXPLORER_DEBUG=true in .env file.
  static bool get meshExplorerDebugEnabled {
    _meshExplorerDebugEnabled ??=
        _safeGetEnv('MESH_EXPLORER_DEBUG')?.toLowerCase() == 'true';
    return _meshExplorerDebugEnabled!;
  }

  static void meshExplorer(String message) {
    if (meshExplorerDebugEnabled) debugPrint('MESH_EXPLORER: $message');
  }

  /// Mesh Capacity Advisor logging — snapshot generation, recommendation
  /// changes, and card lifecycle (shown / dismissed / explanation opened /
  /// radio settings opened from advisor). Enable with
  /// MESH_CAPACITY_LOGGING_ENABLED=true in .env file.
  static bool? _meshCapacityLoggingEnabled;
  static bool get meshCapacityLoggingEnabled {
    _meshCapacityLoggingEnabled ??=
        _safeGetEnv('MESH_CAPACITY_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _meshCapacityLoggingEnabled!;
  }

  static void meshCapacity(String message) {
    if (meshCapacityLoggingEnabled) debugPrint('MeshCapacity: $message');
  }

  /// Voice message pipeline logging.
  /// Enable with VOICE_LOGGING_ENABLED=true in .env file.
  static bool get voiceLoggingEnabled {
    _voiceLoggingEnabled ??=
        _safeGetEnv('VOICE_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _voiceLoggingEnabled!;
  }

  static void voice(String message) {
    if (voiceLoggingEnabled) debugPrint('Voice: $message');
  }

  /// Codec2 FFI encode/decode logging.
  /// Enable with CODEC2_LOGGING_ENABLED=true in .env file.
  static bool get codec2LoggingEnabled {
    _codec2LoggingEnabled ??=
        _safeGetEnv('CODEC2_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _codec2LoggingEnabled!;
  }

  static void codec2(String message) {
    if (codec2LoggingEnabled) debugPrint('Codec2: $message');
  }

  /// SPP payload transfer logging.
  /// Enable with SPP_LOGGING_ENABLED=true in .env file.
  static bool get sppLoggingEnabled {
    _sppLoggingEnabled ??=
        _safeGetEnv('SPP_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _sppLoggingEnabled!;
  }

  static void spp(String message) {
    if (sppLoggingEnabled) debugPrint('SPP: $message');
  }

  /// SPP negotiation logging.
  /// Enable with SPP_NEGOTIATION_LOGGING_ENABLED=true in .env file.
  static bool get sppNegotiationLoggingEnabled {
    _sppNegotiationLoggingEnabled ??=
        _safeGetEnv('SPP_NEGOTIATION_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _sppNegotiationLoggingEnabled!;
  }

  static void sppNegotiation(String message) {
    if (sppNegotiationLoggingEnabled) debugPrint('SPP_NEG: $message');
  }

  /// STL (Socialmesh Trust Layer) logging.
  /// Enable with STL_LOGGING_ENABLED=true in .env file.
  static bool get stlLoggingEnabled {
    _stlLoggingEnabled ??=
        _safeGetEnv('STL_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _stlLoggingEnabled!;
  }

  static void stl(String message) {
    if (stlLoggingEnabled) debugPrint('STL: $message');
  }

  /// Socialmesh Overlay v0.2 logging — link state, resource transfer,
  /// persistence, capability negotiation. Enable with
  /// `OVERLAY_LOGGING_ENABLED=true` in the .env file.
  static bool get overlayLoggingEnabled {
    _overlayLoggingEnabled ??=
        _safeGetEnv('OVERLAY_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _overlayLoggingEnabled!;
  }

  static void overlay(String message) {
    if (overlayLoggingEnabled) debugPrint('Overlay: $message');
  }

  /// Mesh Feed logging — ingest, replay protection, propagation, sync.
  /// Enable with MESH_FEED_LOGGING_ENABLED=true in .env file.
  static bool get meshFeedLoggingEnabled {
    _meshFeedLoggingEnabled ??=
        _safeGetEnv('MESH_FEED_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _meshFeedLoggingEnabled!;
  }

  static void meshFeed(String message) {
    if (meshFeedLoggingEnabled) debugPrint('MeshFeed: $message');
  }

  /// Mesh Games logging — session lifecycle (create/join/complete/abandon).
  /// Enable with MESH_GAMES_LOGGING_ENABLED=true in .env file.
  static bool get meshGamesLoggingEnabled {
    _meshGamesLoggingEnabled ??=
        _safeGetEnv('MESH_GAMES_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _meshGamesLoggingEnabled!;
  }

  static void meshGames(String message) {
    if (meshGamesLoggingEnabled) debugPrint('MeshGames: $message');
  }

  /// Mesh Games transport logging — encode/decode of game wire frames.
  static bool get meshGameTransportLoggingEnabled {
    _meshGameTransportLoggingEnabled ??=
        _safeGetEnv('MESH_GAME_TRANSPORT_LOGGING_ENABLED')?.toLowerCase() ==
        'true';
    return _meshGameTransportLoggingEnabled!;
  }

  static void meshGameTransport(String message) {
    if (meshGameTransportLoggingEnabled) {
      debugPrint('MeshGameTransport: $message');
    }
  }

  /// Mesh Games session logging — persistence + state transitions.
  static bool get meshGameSessionLoggingEnabled {
    _meshGameSessionLoggingEnabled ??=
        _safeGetEnv('MESH_GAME_SESSION_LOGGING_ENABLED')?.toLowerCase() ==
        'true';
    return _meshGameSessionLoggingEnabled!;
  }

  static void meshGameSession(String message) {
    if (meshGameSessionLoggingEnabled) {
      debugPrint('MeshGameSession: $message');
    }
  }

  /// Mesh Games UI logging — user actions + screen transitions.
  static bool get meshGameUiLoggingEnabled {
    _meshGameUiLoggingEnabled ??=
        _safeGetEnv('MESH_GAME_UI_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _meshGameUiLoggingEnabled!;
  }

  static void meshGameUi(String message) {
    if (meshGameUiLoggingEnabled) debugPrint('MeshGameUi: $message');
  }

  /// MQTT client proxy logging.
  /// Enable with MQTT_PROXY_LOGGING_ENABLED=true in .env file.
  static bool get mqttProxyLoggingEnabled {
    _mqttProxyLoggingEnabled ??=
        _safeGetEnv('MQTT_PROXY_LOGGING_ENABLED')?.toLowerCase() == 'true';
    return _mqttProxyLoggingEnabled!;
  }

  static void mqttProxy(String message) {
    if (mqttProxyLoggingEnabled) debugPrint('MQTT_PROXY: $message');
    // Always forward to in-app log viewer for support visibility
    _appLogSink?.call(1, 'mqtt_proxy', message); // lint-allow: hardcoded-string
  }

  /// Logs an MQTT proxy error to both console and in-app log viewer.
  static void mqttProxyError(String message) {
    if (mqttProxyLoggingEnabled) debugPrint('MQTT_PROXY: $message');
    _appLogSink?.call(3, 'mqtt_proxy', message); // lint-allow: hardcoded-string
  }

  /// Logs an MQTT proxy warning to both console and in-app log viewer.
  static void mqttProxyWarning(String message) {
    if (mqttProxyLoggingEnabled) debugPrint('MQTT_PROXY: $message');
    _appLogSink?.call(2, 'mqtt_proxy', message); // lint-allow: hardcoded-string
  }

  static void reset() {
    _appLogSink = null;
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
    _nodeBoardLoggingEnabled = null;
    _petLoggingEnabled = null;
    _syncLoggingEnabled = null;
    _mfaLoggingEnabled = null;
    _aetherLoggingEnabled = null;
    _takLoggingEnabled = null;
    _claimsLoggingEnabled = null;
    _uiGatesLoggingEnabled = null;
    _incidentsLoggingEnabled = null;
    _incidentSyncLoggingEnabled = null;
    _incidentUILoggingEnabled = null;
    _adminDiagLoggingEnabled = null;
    _tasksLoggingEnabled = null;
    _taskSyncLoggingEnabled = null;
    _fileTransferLoggingEnabled = null;
    _sipLoggingEnabled = null;
    _sipInkLoggingEnabled = null;
    _sipPlayLoggingEnabled = null;
    _sipSignalLoggingEnabled = null;
    _mrrpDebugEnabled = null;
    _mrrpHarnessDebugEnabled = null;
    _meshExplorerDebugEnabled = null;
    _voiceLoggingEnabled = null;
    _codec2LoggingEnabled = null;
    _sppLoggingEnabled = null;
    _sppNegotiationLoggingEnabled = null;
    _stlLoggingEnabled = null;
    _meshFeedLoggingEnabled = null;
    _meshCapacityLoggingEnabled = null;
    _mqttProxyLoggingEnabled = null;
    _bleLogger = null;
    _noOpLogger = null;
  }
}
