// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/services/transport/ble_transport.dart';

// Guard matrix for the iOS OS-level pending reconnect armed after an
// unexpected BLE disconnect in the background. The predicate is pure so
// this matrix pins every gate without the Bluetooth stack.
void main() {
  // Baseline arguments that satisfy every gate; each test flips one.
  bool arm({
    TargetPlatform platform = TargetPlatform.iOS,
    AppLifecycleState? lifecycleState = AppLifecycleState.paused,
    bool hasDevice = true,
    bool registrationExists = false,
    DeviceConnectionState transportState = DeviceConnectionState.disconnected,
  }) {
    return BleTransport.shouldArmOsPendingReconnect(
      platform: platform,
      lifecycleState: lifecycleState,
      hasDevice: hasDevice,
      registrationExists: registrationExists,
      transportState: transportState,
    );
  }

  group('shouldArmOsPendingReconnect', () {
    test('arms on iOS when backgrounded with a device and no registration', () {
      expect(arm(), isTrue);
    });

    test('never arms off iOS - Android owns background reconnect via the '
        'foreground service', () {
      for (final platform in TargetPlatform.values) {
        if (platform == TargetPlatform.iOS) continue;
        expect(
          arm(platform: platform),
          isFalse,
          reason: 'must not arm on $platform',
        );
      }
    });

    test('never arms in the foreground - the scan pipeline owns recovery', () {
      expect(arm(lifecycleState: AppLifecycleState.resumed), isFalse);
    });

    test('arms in every non-resumed lifecycle state', () {
      for (final state in AppLifecycleState.values) {
        if (state == AppLifecycleState.resumed) continue;
        expect(
          arm(lifecycleState: state),
          isTrue,
          reason: 'must arm in $state',
        );
      }
    });

    test('null lifecycle state counts as background', () {
      expect(arm(lifecycleState: null), isTrue);
    });

    test('never arms without a device handle', () {
      expect(arm(hasDevice: false), isFalse);
    });

    test('never arms when the flutter_blue_plus registration already '
        'exists - the plugin re-issues the pending connect itself', () {
      expect(arm(registrationExists: true), isFalse);
    });

    test('only arms from the disconnected transport state', () {
      for (final state in DeviceConnectionState.values) {
        expect(
          arm(transportState: state),
          state == DeviceConnectionState.disconnected,
          reason: 'unexpected verdict for $state',
        );
      }
    });
  });
}
