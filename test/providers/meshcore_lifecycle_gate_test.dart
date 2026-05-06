// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D27 - MeshCore reconnect gate tests.
//
// Pin the lifecycle predicate `evaluateMeshCoreReconnectGate` that
// `meshCoreLifecycleProvider.maybeReconnect` consults before firing a
// reconnect. The predicate gates on:
//
// - cooldown window (5s after a previous dispatch)
// - last device protocol matches `meshcore`
// - last device id present
// - auto-reconnect enabled in settings
// - user did not manually disconnect
// - coordinator is not already connected/connecting
// - auto-reconnect manager is not already mid-flight
//
// Each test exercises one negative case in isolation, plus the positive
// case where every gate passes.

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/providers/meshcore_lifecycle_provider.dart';

MeshCoreReconnectGateOutcome _evaluate({
  bool withinCooldown = false,
  String? lastDeviceProtocol = 'meshcore',
  String? lastDeviceId = 'meshcore-tcp:192.168.1.100:5000',
  bool autoReconnectEnabled = true,
  bool userDisconnected = false,
  bool coordinatorConnected = false,
  bool coordinatorConnecting = false,
  bool autoReconnectInProgress = false,
}) => evaluateMeshCoreReconnectGate(
  withinCooldown: withinCooldown,
  lastDeviceProtocol: lastDeviceProtocol,
  lastDeviceId: lastDeviceId,
  autoReconnectEnabled: autoReconnectEnabled,
  userDisconnected: userDisconnected,
  coordinatorConnected: coordinatorConnected,
  coordinatorConnecting: coordinatorConnecting,
  autoReconnectInProgress: autoReconnectInProgress,
);

void main() {
  group('evaluateMeshCoreReconnectGate', () {
    test(
      'proceeds when every gate passes (TCP MeshCore, idle, foreground)',
      () {
        final outcome = _evaluate();
        expect(outcome.proceed, isTrue);
        expect(outcome.skipReason, isNull);
      },
    );

    test('proceeds for BLE MeshCore peer with everything else green', () {
      final outcome = _evaluate(lastDeviceId: 'AA:BB:CC:DD:EE:FF');
      expect(outcome.proceed, isTrue);
    });

    test('skips with cooldown when within the dispatch cooldown window', () {
      final outcome = _evaluate(withinCooldown: true);
      expect(outcome.proceed, isFalse);
      expect(outcome.skipReason, 'cooldown');
    });

    test('skips with not_meshcore for Meshtastic peers', () {
      final outcome = _evaluate(lastDeviceProtocol: 'meshtastic');
      expect(outcome.proceed, isFalse);
      expect(outcome.skipReason, 'not_meshcore');
    });

    test('skips with not_meshcore when no protocol persisted', () {
      final outcome = _evaluate(lastDeviceProtocol: null);
      expect(outcome.proceed, isFalse);
      expect(outcome.skipReason, 'not_meshcore');
    });

    test('skips with no_saved_device when lastDeviceId is null', () {
      final outcome = _evaluate(lastDeviceId: null);
      expect(outcome.proceed, isFalse);
      expect(outcome.skipReason, 'no_saved_device');
    });

    test('skips with auto_reconnect_disabled when setting is off', () {
      final outcome = _evaluate(autoReconnectEnabled: false);
      expect(outcome.proceed, isFalse);
      expect(outcome.skipReason, 'auto_reconnect_disabled');
    });

    test('skips with user_disconnected after a manual cancel', () {
      final outcome = _evaluate(userDisconnected: true);
      expect(outcome.proceed, isFalse);
      expect(outcome.skipReason, 'user_disconnected');
    });

    test('skips with already_active when coordinator is connected', () {
      final outcome = _evaluate(coordinatorConnected: true);
      expect(outcome.proceed, isFalse);
      expect(outcome.skipReason, 'already_active');
    });

    test('skips with already_active when coordinator is connecting', () {
      final outcome = _evaluate(coordinatorConnecting: true);
      expect(outcome.proceed, isFalse);
      expect(outcome.skipReason, 'already_active');
    });

    test(
      'skips with already_reconnecting when auto-reconnect is mid-flight',
      () {
        final outcome = _evaluate(autoReconnectInProgress: true);
        expect(outcome.proceed, isFalse);
        expect(outcome.skipReason, 'already_reconnecting');
      },
    );
  });

  group('evaluateMeshCoreReconnectGate - check ordering', () {
    // The order of skip reasons matters for telemetry: when multiple
    // gates would block, the FIRST one wins so the field-test logs
    // pinpoint the earliest cause. These tests pin the order against
    // accidental reshuffling.

    test('cooldown wins over not_meshcore', () {
      final outcome = _evaluate(
        withinCooldown: true,
        lastDeviceProtocol: 'meshtastic',
      );
      expect(outcome.skipReason, 'cooldown');
    });

    test('not_meshcore wins over no_saved_device', () {
      final outcome = _evaluate(
        lastDeviceProtocol: 'meshtastic',
        lastDeviceId: null,
      );
      expect(outcome.skipReason, 'not_meshcore');
    });

    test('no_saved_device wins over auto_reconnect_disabled', () {
      final outcome = _evaluate(
        lastDeviceId: null,
        autoReconnectEnabled: false,
      );
      expect(outcome.skipReason, 'no_saved_device');
    });

    test('auto_reconnect_disabled wins over user_disconnected', () {
      final outcome = _evaluate(
        autoReconnectEnabled: false,
        userDisconnected: true,
      );
      expect(outcome.skipReason, 'auto_reconnect_disabled');
    });

    test('user_disconnected wins over already_active', () {
      final outcome = _evaluate(
        userDisconnected: true,
        coordinatorConnected: true,
      );
      expect(outcome.skipReason, 'user_disconnected');
    });

    test('already_active wins over already_reconnecting', () {
      final outcome = _evaluate(
        coordinatorConnecting: true,
        autoReconnectInProgress: true,
      );
      expect(outcome.skipReason, 'already_active');
    });
  });

  group('MeshCoreReconnectGateOutcome', () {
    test('proceed factory carries no skip reason', () {
      final o = MeshCoreReconnectGateOutcome.proceed();
      expect(o.proceed, isTrue);
      expect(o.skipReason, isNull);
    });

    test('skip factory carries the reason', () {
      final o = MeshCoreReconnectGateOutcome.skip('user_disconnected');
      expect(o.proceed, isFalse);
      expect(o.skipReason, 'user_disconnected');
    });
  });
}
