// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../core/transport.dart';
import '../core/navigation.dart';
import '../core/widgets/app_bottom_sheet.dart';
import '../features/feedback/report_bug_sheet.dart';
import '../models/mesh_models.dart';
import '../providers/app_providers.dart';
import '../providers/connection_providers.dart';
import '../providers/connectivity_providers.dart';

class BugReportService with WidgetsBindingObserver {
  BugReportService(this.ref);

  final Ref ref;
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  bool _enabled = true;
  bool _appActive = true;
  bool _isShowing = false;
  int _shakeCount = 0;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _resetTimer;

  static const double _shakeThresholdG = 2.7;
  static const int _requiredShakeCount = 2;
  static const Duration _shakeWindow = Duration(milliseconds: 600);

  Future<void> initialize() async {
    final settings = await ref.read(settingsServiceProvider.future);
    _enabled = settings.shakeToReportEnabled;
    WidgetsBinding.instance.addObserver(this);
    AppLogging.bugReport('Initialized (enabled=$_enabled)');
    if (_enabled) {
      _startListening();
    }
  }

  /// Whether the accelerometer subscription is currently live.
  @visibleForTesting
  bool get isListening => _accelerometerSub != null;

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accelerometerSub?.cancel();
    _resetTimer?.cancel();
  }

  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;
    final settings = await ref.read(settingsServiceProvider.future);
    await settings.setShakeToReportEnabled(enabled);
    AppLogging.bugReport('Shake toggle set to $enabled');
    if (enabled) {
      if (_appActive) {
        _startListening();
      }
    } else {
      await _accelerometerSub?.cancel();
      _accelerometerSub = null;
    }
  }

  void _startListening() {
    _accelerometerSub?.cancel();
    _accelerometerSub = accelerometerEventStream(
      samplingPeriod: const Duration(milliseconds: 20),
    ).listen(_handleAccel);
  }

  void _handleAccel(AccelerometerEvent event) {
    if (!_enabled || _isShowing || !_appActive) return;
    final gX = event.x / 9.81;
    final gY = event.y / 9.81;
    final gZ = event.z / 9.81;
    final gForce = sqrt(gX * gX + gY * gY + gZ * gZ);

    if (gForce < _shakeThresholdG) return;
    final now = DateTime.now();

    if (now.difference(_lastShake) > _shakeWindow) {
      _shakeCount = 0;
    }
    _lastShake = now;
    _shakeCount++;

    _resetTimer?.cancel();
    _resetTimer = Timer(_shakeWindow, () => _shakeCount = 0);

    if (_shakeCount >= _requiredShakeCount) {
      _shakeCount = 0;
      AppLogging.bugReport('Shake detected - opening report flow');
      _triggerReport();
    }
  }

  Future<void> _triggerReport() async {
    final context = navigatorKey.currentContext;
    if (context == null) return;
    _isShowing = true;

    Uint8List? screenshotBytes;
    try {
      // Wait for frame to settle before capture.
      await SchedulerBinding.instance.endOfFrame;
      screenshotBytes = await _captureScreenshot();
      AppLogging.bugReport(
        'Captured screenshot: ${screenshotBytes?.length ?? 0} bytes',
      );
    } catch (e) {
      AppLogging.app('BugReport: screenshot capture failed: $e');
    }

    if (!context.mounted) {
      _isShowing = false;
      return;
    }

    final rootContext = context;
    final proceed = await AppBottomSheet.showRaw<bool>(
      context: context,
      builder: (sheetContext) {
        return ReportBugPromptSheet(
          onToggleShake: setEnabled,
          isShakeEnabled: _enabled,
        );
      },
    );

    if (proceed != true) {
      AppLogging.bugReport('Prompt dismissed');
      _isShowing = false;
      return;
    }

    if (!rootContext.mounted) {
      _isShowing = false;
      return;
    }

    final settings = await ref.read(settingsServiceProvider.future);
    final initialDraft = settings.bugReportDraft;

    if (!rootContext.mounted) {
      _isShowing = false;
      return;
    }

    await AppBottomSheet.showRaw<void>(
      context: rootContext,
      builder: (sheetContext) {
        return ReportBugSheet(
          initialScreenshot: screenshotBytes,
          initialDescription: initialDraft,
          onDescriptionChanged: (value) {
            settings.setBugReportDraft(value);
          },
          onSubmit: _submitReport,
          onToggleShake: setEnabled,
          isShakeEnabled: _enabled,
        );
      },
    );

    _isShowing = false;
    AppLogging.bugReport('Report flow closed');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isActive = state == AppLifecycleState.resumed;
    if (_appActive == isActive) return;
    _appActive = isActive;
    if (!isActive) {
      // Stop sensor delivery whenever the app leaves the foreground.
      // sensors_plus queues CoreMotion callbacks onto the main dispatch
      // queue; a block that executes after the Flutter engine stops throws
      // a fatal NSInternalInconsistencyException.
      _accelerometerSub?.cancel();
      _accelerometerSub = null;
      _shakeCount = 0;
      _lastShake = DateTime.fromMillisecondsSinceEpoch(0);
      _resetTimer?.cancel();
      AppLogging.bugReport('Shake listener paused (app inactive)');
    } else {
      if (_enabled && _accelerometerSub == null) {
        _startListening();
      }
      AppLogging.bugReport('Shake listener resumed');
    }
  }

  Future<Uint8List?> _captureScreenshot() async {
    final context = appRepaintBoundaryKey.currentContext;
    final boundary = context?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final pixelRatio = MediaQuery.of(context!).devicePixelRatio;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<String?> _uploadScreenshot(Uint8List bytes) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      // Use 'anonymous' folder for non-authenticated users
      final uid = user?.uid ?? 'anonymous';
      AppLogging.bugReport(
        'User state: ${user == null ? "not logged in" : "logged in as $uid"}',
      );

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final refPath = 'bug_reports/$uid/$timestamp.png';
      AppLogging.bugReport(
        'Uploading screenshot to $refPath (${bytes.length} bytes)',
      );

      final ref = FirebaseStorage.instance.ref(refPath);
      AppLogging.bugReport('Storage ref created, attempting upload...');

      await ref.putData(bytes, SettableMetadata(contentType: 'image/png'));
      AppLogging.bugReport('Upload successful, getting download URL...');

      final url = await ref.getDownloadURL();
      AppLogging.bugReport('Screenshot uploaded successfully: $url');
      return url;
    } catch (e, stackTrace) {
      AppLogging.bugReport('❌ Screenshot upload failed: $e');
      AppLogging.bugReport('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _submitReport({
    required String description,
    required bool includeScreenshot,
    Uint8List? screenshotBytes,
  }) async {
    // Bug reports require network for Storage upload + Cloud Function call
    final isOnline = ref.read(isOnlineProvider);
    if (!isOnline) {
      throw Exception(
        'Bug reports require an internet connection. '
        'Please try again when you are online.',
      );
    }

    String? screenshotUrl;
    if (includeScreenshot && screenshotBytes != null) {
      screenshotUrl = await _uploadScreenshot(screenshotBytes);
    }

    final package = await PackageInfo.fromPlatform();
    final user = FirebaseAuth.instance.currentUser;
    final functions = FirebaseFunctions.instance;
    final callable = functions.httpsCallable('reportBug');

    // Collect device model and OS version
    final deviceInfoPlugin = DeviceInfoPlugin();
    String? deviceModel;
    String? osVersion;
    if (Platform.isIOS) {
      final iosInfo = await deviceInfoPlugin.iosInfo;
      deviceModel = iosInfo.utsname.machine; // e.g. "iPhone16,1"
      osVersion = '${iosInfo.systemName} ${iosInfo.systemVersion}';
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfoPlugin.androidInfo;
      deviceModel = '${androidInfo.manufacturer} ${androidInfo.model}';
      osVersion =
          'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})'; // lint-allow: hardcoded-string
    }

    // Collect comprehensive app state for better bug context
    final appContext = await _collectAppContext();

    AppLogging.bugReport('Submitting report (screenshot=$includeScreenshot)');
    final result = await callable.call({
      'description': description,
      'screenshotUrl': screenshotUrl,
      'appVersion': package.version,
      'buildNumber': package.buildNumber,
      'platform': Platform.operatingSystem,
      'platformVersion': Platform.operatingSystemVersion,
      'deviceModel': deviceModel,
      'osVersion': osVersion,
      'uid': _hashUid(user?.uid),
      'email': _maskEmail(user?.email),
      'displayName': _maskDisplayName(user?.displayName),
      'isAnonymous': user?.isAnonymous,
      'createdAt': user?.metadata.creationTime?.toIso8601String(),
      'lastSignIn': user?.metadata.lastSignInTime?.toIso8601String(),
      // Include comprehensive app context
      ...appContext,
    });

    // Validate server response
    final Map<String, dynamic>? data = result.data as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Invalid server response');
    }
    if (data['success'] != true) {
      throw Exception(
        data['error'] ?? 'Failed to submit bug report',
      ); // lint-allow: hardcoded-string
    }

    AppLogging.bugReport('Report submitted');
    return data;
  }

  /// Collects comprehensive app context for bug reports
  Future<Map<String, dynamic>> _collectAppContext() async {
    final context = <String, dynamic>{};

    try {
      // Settings and preferences
      final settings = await ref.read(settingsServiceProvider.future);
      context['settings'] = {
        'autoReconnect': settings.autoReconnect,
        'lastDeviceId': settings.lastDeviceId,
        'lastDeviceName': settings.lastDeviceName,
        'lastDeviceProtocol': settings.lastDeviceProtocol,
        'notificationsEnabled': settings.notificationsEnabled,
        'darkMode': settings.darkMode,
        'themeMode': settings.themeMode,
        'shakeToReportEnabled': settings.shakeToReportEnabled,
      };

      // Connection state
      final autoReconnectState = ref.read(autoReconnectStateProvider);
      final userDisconnected = ref.read(userDisconnectedProvider);
      context['connectionState'] = {
        'autoReconnectState': autoReconnectState.name,
        'userDisconnected': userDisconnected,
      };

      // Try to get device connection state if available
      try {
        final deviceConnection = ref.read(deviceConnectionProvider);
        context['deviceConnection'] = {
          'state': deviceConnection.state.name,
          'reason': deviceConnection.reason.name,
          'deviceId': deviceConnection.device?.id,
          'deviceName': deviceConnection.device?.name,
          'myNodeNum': deviceConnection.myNodeNum,
          'reconnectAttempts': deviceConnection.reconnectAttempts,
          'lastConnectedAt': deviceConnection.lastConnectedAt
              ?.toIso8601String(),
        };

        context['connectedMeshDevice'] = _buildConnectedMeshDeviceContext(
          settingsLastDeviceId: settings.lastDeviceId,
          settingsLastDeviceName: settings.lastDeviceName,
          settingsLastDeviceProtocol: settings.lastDeviceProtocol,
        );
      } catch (e) {
        context['deviceConnection'] = {'error': e.toString()};
      }

      // Bluetooth state
      try {
        final btStateAsync = ref.read(bluetoothStateProvider);
        btStateAsync.whenData((btState) {
          context['bluetoothState'] = btState.name;
        });
      } catch (e) {
        context['bluetoothState'] = 'unknown';
      }
    } catch (e) {
      context['contextError'] = e.toString();
    }

    return context;
  }

  Map<String, dynamic> _buildConnectedMeshDeviceContext({
    required String? settingsLastDeviceId,
    required String? settingsLastDeviceName,
    required String? settingsLastDeviceProtocol,
  }) {
    final deviceConnection = ref.read(deviceConnectionProvider);
    final connectedDevice = ref.read(connectedDeviceProvider);
    final myNodeNum = ref.read(myNodeNumProvider);
    final nodes = ref.read(nodesProvider);

    final MeshNode? myNode = myNodeNum != null ? nodes[myNodeNum] : null;
    final DeviceInfo? activeDevice = connectedDevice ?? deviceConnection.device;

    return {
      'capturedAt': DateTime.now().toUtc().toIso8601String(),
      'isConnected': deviceConnection.isConnected,
      'connectionState': deviceConnection.state.name,
      'disconnectReason': deviceConnection.reason.name,
      'transport':
          settingsLastDeviceProtocol ?? activeDevice?.type.name ?? 'unknown',
      'deviceId': activeDevice?.id ?? settingsLastDeviceId,
      'deviceName': activeDevice?.name ?? settingsLastDeviceName,
      'myNodeNum': myNodeNum,
      'myNodeHex': myNodeNum?.toRadixString(16).toUpperCase(),
      'nodeLongName': myNode?.longName,
      'nodeShortName': myNode?.shortName,
      'userId': myNode?.userId,
      'hardwareModel': myNode?.hardwareModel,
      'hardwareModelId': myNode?.hwModelId,
      'role': myNode?.role,
      'firmwareVersion': myNode?.firmwareVersion,
      'batteryLevel': myNode?.batteryLevel,
      'hasBluetooth': myNode?.hasBluetooth,
      'hasWifi': myNode?.hasWifi,
      'channelUtilization': myNode?.channelUtilization,
      'airUtilTx': myNode?.airUtilTx,
      'uptimeSeconds': myNode?.uptimeSeconds,
      'lastHeard': myNode?.lastHeard?.toIso8601String(),
      'lastConnectedAt': deviceConnection.lastConnectedAt?.toIso8601String(),
      'reconnectAttempts': deviceConnection.reconnectAttempts,
    };
  }

  // ---------------------------------------------------------------------------
  // PII masking helpers
  // ---------------------------------------------------------------------------

  /// Hash UID to SHA-256 truncated to 16 hex chars for correlation without
  /// exposing the raw Firebase UID.
  static String? _hashUid(String? uid) {
    if (uid == null) return null;
    final bytes = utf8.encode(uid);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// Mask email: "alice@example.com" -> "a***@example.com"
  static String? _maskEmail(String? email) {
    if (email == null) return null;
    final parts = email.split('@');
    if (parts.length != 2 || parts[0].isEmpty) return '***@***';
    return '${parts[0][0]}***@${parts[1]}';
  }

  /// Mask display name: keep first character only.
  static String? _maskDisplayName(String? name) {
    if (name == null || name.isEmpty) return null;
    return '${name[0]}***';
  }
}
