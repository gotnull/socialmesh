import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../core/navigation.dart';
import '../features/feedback/report_bug_sheet.dart';
import '../providers/app_providers.dart';

class BugReportService {
  BugReportService(this.ref);

  final Ref ref;
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  bool _enabled = true;
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
    AppLogging.bugReport('Initialized (enabled=$_enabled)');
    _startListening();
  }

  void dispose() {
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
    if (!_enabled || _isShowing) return;
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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final uid = user.uid;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final refPath = 'bug_reports/$uid/$timestamp.png';
    AppLogging.bugReport('Uploading screenshot to $refPath');
    final ref = FirebaseStorage.instance.ref(refPath);
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/png'),
    );
    final url = await ref.getDownloadURL();
    AppLogging.bugReport('Screenshot uploaded');
    return url;
  }

  Future<void> _submitReport({
    required String description,
    required bool includeScreenshot,
    Uint8List? screenshotBytes,
  }) async {
    String? screenshotUrl;
    if (includeScreenshot && screenshotBytes != null) {
      screenshotUrl = await _uploadScreenshot(screenshotBytes);
    }

    final package = await PackageInfo.fromPlatform();
    final user = FirebaseAuth.instance.currentUser;
    final functions = FirebaseFunctions.instance;
    final callable = functions.httpsCallable('reportBug');

    AppLogging.bugReport('Submitting report (screenshot=$includeScreenshot)');
    final result = await callable.call({
      'description': description,
      'screenshotUrl': screenshotUrl,
      'appVersion': package.version,
      'buildNumber': package.buildNumber,
      'platform': Platform.operatingSystem,
      'platformVersion': Platform.operatingSystemVersion,
      'uid': user?.uid,
      'email': user?.email,
    });

    // Validate server response and surface any email errors to the UI
    final Map<String, dynamic>? data = result.data as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Invalid server response');
    }
    if (data['success'] != true) {
      throw Exception(data['error'] ?? 'Failed to submit bug report');
    }
    if (data['emailSent'] == false) {
      throw Exception(data['emailError'] ?? 'Bug report saved but email notification failed');
    }

    AppLogging.bugReport('Report submitted');
  }
}
