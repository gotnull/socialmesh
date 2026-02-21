// SPDX-License-Identifier: GPL-3.0-or-later
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
import '../core/navigation.dart';
import '../features/feedback/report_bug_sheet.dart';
import '../providers/app_providers.dart';
import '../providers/connection_providers.dart';
import '../providers/connectivity_providers.dart';
import '../utils/snackbar.dart';

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
    _startListening();
  }

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
      _startListening();
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

    // Require authentication — anonymous reports can never receive replies
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (context.mounted) {
        showGlobalErrorSnackBar(
          'Sign in to report bugs. Anonymous reports cannot receive replies.',
        );
      }
      _isShowing = false;
      return;
    }

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
    final proceed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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

    await showModalBottomSheet<void>(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ReportBugSheet(
          initialScreenshot: screenshotBytes,
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
      _shakeCount = 0;
      _lastShake = DateTime.fromMillisecondsSinceEpoch(0);
      _resetTimer?.cancel();
      AppLogging.bugReport('Shake listener paused (app inactive)');
    } else {
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
          'Android ${androidInfo.version.release} (SDK ${androidInfo.version.sdkInt})';
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
      throw Exception(data['error'] ?? 'Failed to submit bug report');
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
