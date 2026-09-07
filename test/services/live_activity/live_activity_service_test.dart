// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/live_activity/live_activity_service.dart';

class _IosService extends LiveActivityService {
  @override
  bool get isSupported => true;
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('live_activities');
  late _IosService service;
  String? nativeState;
  bool failQuery = false;

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    nativeState = 'active';
    failQuery = false;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      switch (call.method) {
        case 'areActivitiesEnabled':
          return true;
        case 'createActivity':
          return 'native-id';
        case 'getActivityState':
          if (failQuery) throw PlatformException(code: 'temporary');
          return nativeState;
        default:
          return null;
      }
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('live_activities/activity_status'),
      (_) async => null,
    );
    service = _IosService();
    expect(
      await service.startMeshActivity(
        deviceName: 'Radio',
        shortName: 'RAD',
        nodeNum: 1,
      ),
      isTrue,
    );
  });

  tearDown(() async {
    await service.endActivity();
    service.dispose();
    debugDefaultTargetPlatformOverride = null;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  for (final state in ['active', 'stale']) {
    test('keeps a $state activity', () async {
      nativeState = state;
      expect(await service.hasRunningActivity(), isTrue);
      expect(service.isActive, isTrue);
    });
  }
  for (final state in ['ended', 'dismissed', null]) {
    test('forgets an activity with native state $state', () async {
      nativeState = state;
      expect(await service.hasRunningActivity(), isFalse);
      expect(service.isActive, isFalse);
    });
  }
  test('does not replace an activity on a transient bridge failure', () async {
    failQuery = true;
    expect(await service.hasRunningActivity(), isTrue);
  });
}
