// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/providers/app_providers.dart'
    show bugReportServiceProvider, settingsServiceProvider;
import 'package:socialmesh/services/bug_report_service.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

// The shake listener must release its accelerometer subscription whenever
// the app leaves the foreground: sensors_plus queues CoreMotion callbacks
// onto the iOS main dispatch queue, and a block that executes after the
// Flutter engine stops throws a fatal NSInternalInconsistencyException.

Future<SettingsService> _settingsWithMocks(Map<String, Object> seed) async {
  SharedPreferences.setMockInitialValues(seed);
  final s = SettingsService();
  await s.init();
  return s;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel(
    'dev.fluttercommunity.plus/sensors/method',
  );
  const accelerometerChannel = EventChannel(
    'dev.fluttercommunity.plus/sensors/accelerometer',
  );

  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(methodChannel, (call) async => null);
    messenger.setMockStreamHandler(
      accelerometerChannel,
      MockStreamHandler.inline(onListen: (arguments, events) {}),
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockStreamHandler(accelerometerChannel, null);
  });

  Future<BugReportService> buildService({required bool shakeEnabled}) async {
    final settings = await _settingsWithMocks({
      'shake_to_report_enabled': shakeEnabled,
    });
    final container = ProviderContainer(
      overrides: [
        settingsServiceProvider.overrideWith((ref) async => settings),
      ],
    );
    addTearDown(container.dispose);
    final service = container.read(bugReportServiceProvider);
    await service.initialize();
    return service;
  }

  test('does not subscribe when shake-to-report is disabled', () async {
    final service = await buildService(shakeEnabled: false);
    expect(service.isListening, isFalse);
  });

  test('subscribes when shake-to-report is enabled', () async {
    final service = await buildService(shakeEnabled: true);
    expect(service.isListening, isTrue);
  });

  test('cancels the subscription when the app is paused', () async {
    final service = await buildService(shakeEnabled: true);
    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(service.isListening, isFalse);
  });

  test('cancels the subscription when the app becomes inactive', () async {
    final service = await buildService(shakeEnabled: true);
    service.didChangeAppLifecycleState(AppLifecycleState.inactive);
    expect(service.isListening, isFalse);
  });

  test('resubscribes when the app resumes', () async {
    final service = await buildService(shakeEnabled: true);
    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    expect(service.isListening, isFalse);
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(service.isListening, isTrue);
  });

  test('does not resubscribe on resume when disabled', () async {
    final service = await buildService(shakeEnabled: false);
    service.didChangeAppLifecycleState(AppLifecycleState.paused);
    service.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(service.isListening, isFalse);
  });

  test(
    'enabling while backgrounded defers the subscription to resume',
    () async {
      final service = await buildService(shakeEnabled: false);
      service.didChangeAppLifecycleState(AppLifecycleState.paused);
      await service.setEnabled(true);
      expect(service.isListening, isFalse);
      service.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(service.isListening, isTrue);
    },
  );
}
