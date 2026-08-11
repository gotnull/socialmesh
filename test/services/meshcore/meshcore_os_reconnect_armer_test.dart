// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCore OS-level pending-reconnect armer tests.
//
// Two surfaces:
//
// 1. `shouldArmMeshCoreOsReconnect` - the pure gate the lifecycle
//    provider consults before routing a background BLE drop into an
//    OS-level pending reconnect instead of the immediate direct-connect
//    dispatch. Each negative case is pinned in isolation plus the
//    positive case.
//
// 2. `MeshCoreOsReconnectArmer` - arm/callback/cancel behaviour against
//    a fake BluetoothDevice injected through the `deviceFactory` seam:
//    registration with `autoConnect: true`, at-most-once callback on the
//    connected event, registration release semantics on cancel, and
//    idempotent re-arm guards.

import 'dart:async';

import 'package:flutter/foundation.dart' show TargetPlatform;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/meshcore_os_reconnect_armer.dart';

bool _shouldArm({
  TargetPlatform platform = TargetPlatform.iOS,
  bool isForeground = false,
  bool isTcpDevice = false,
  bool coordinatorConnected = false,
  bool coordinatorConnecting = false,
  bool alreadyArmed = false,
  bool backgroundBleEnabled = true,
}) => shouldArmMeshCoreOsReconnect(
  platform: platform,
  isForeground: isForeground,
  isTcpDevice: isTcpDevice,
  coordinatorConnected: coordinatorConnected,
  coordinatorConnecting: coordinatorConnecting,
  alreadyArmed: alreadyArmed,
  backgroundBleEnabled: backgroundBleEnabled,
);

// Fake fbp device: records connect/disconnect calls and lets tests drive
// the connectionState stream. Unrelated BluetoothDevice members are
// unimplemented on purpose - the armer must never touch them.
class _FakeBluetoothDevice implements BluetoothDevice {
  final _stateController =
      StreamController<BluetoothConnectionState>.broadcast();

  int connectCalls = 0;
  int disconnectCalls = 0;
  bool? lastAutoConnect;
  int? lastMtu;
  Object? connectError;

  @override
  Stream<BluetoothConnectionState> get connectionState =>
      _stateController.stream;

  @override
  Future<void> connect({
    required License license,
    Duration timeout = const Duration(seconds: 35),
    int? mtu = 512,
    bool autoConnect = false,
  }) async {
    connectCalls++;
    lastAutoConnect = autoConnect;
    lastMtu = mtu;
    final error = connectError;
    if (error != null) throw error;
  }

  @override
  Future<void> disconnect({
    int timeout = 35,
    bool queue = true,
    int androidDelay = 2000,
  }) async {
    disconnectCalls++;
  }

  void emit(BluetoothConnectionState state) => _stateController.add(state);

  Future<void> close() => _stateController.close();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('shouldArmMeshCoreOsReconnect', () {
    test('arms for backgrounded iOS BLE peer with idle coordinator', () {
      expect(_shouldArm(), isTrue);
    });

    test('skips on Android', () {
      expect(_shouldArm(platform: TargetPlatform.android), isFalse);
    });

    test('skips in the foreground', () {
      expect(_shouldArm(isForeground: true), isFalse);
    });

    test('skips for TCP peers', () {
      expect(_shouldArm(isTcpDevice: true), isFalse);
    });

    test('skips while the coordinator is connected', () {
      expect(_shouldArm(coordinatorConnected: true), isFalse);
    });

    test('skips while the coordinator is connecting', () {
      expect(_shouldArm(coordinatorConnecting: true), isFalse);
    });

    test('skips when a registration is already armed', () {
      expect(_shouldArm(alreadyArmed: true), isFalse);
    });

    test('skips when the background-connection toggle is off', () {
      expect(_shouldArm(backgroundBleEnabled: false), isFalse);
    });
  });

  group('MeshCoreOsReconnectArmer', () {
    late _FakeBluetoothDevice device;
    late MeshCoreOsReconnectArmer armer;

    setUp(() {
      device = _FakeBluetoothDevice();
      armer = MeshCoreOsReconnectArmer();
      armer.deviceFactory = (_) => device;
    });

    tearDown(() async {
      armer.dispose();
      await device.close();
    });

    test(
      'arm registers an OS pending connect (autoConnect, null mtu)',
      () async {
        await armer.arm(
          deviceId: 'AA:BB:CC:DD:EE:FF',
          onLinkReestablished: (_) async {},
        );
        expect(armer.isArmed, isTrue);
        expect(armer.armedDeviceId, 'AA:BB:CC:DD:EE:FF');
        expect(device.connectCalls, 1);
        expect(device.lastAutoConnect, isTrue);
        expect(device.lastMtu, isNull);
      },
    );

    test('second arm while armed is a no-op', () async {
      await armer.arm(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        onLinkReestablished: (_) async {},
      );
      await armer.arm(
        deviceId: '11:22:33:44:55:66',
        onLinkReestablished: (_) async {},
      );
      expect(device.connectCalls, 1);
      expect(armer.armedDeviceId, 'AA:BB:CC:DD:EE:FF');
    });

    test('connected event disarms then fires the callback once', () async {
      final callbackIds = <String>[];
      await armer.arm(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        onLinkReestablished: (id) async => callbackIds.add(id),
      );

      device.emit(BluetoothConnectionState.connected);
      await Future<void>.delayed(Duration.zero);

      expect(callbackIds, ['AA:BB:CC:DD:EE:FF']);
      expect(armer.isArmed, isFalse);
      // Registration ownership passes to the session bring-up: the armer
      // must not release the link it just recovered.
      expect(device.disconnectCalls, 0);

      // A second event after disarm must not re-fire.
      device.emit(BluetoothConnectionState.connected);
      await Future<void>.delayed(Duration.zero);
      expect(callbackIds.length, 1);
    });

    test('disconnected events are ignored while armed', () async {
      var fired = false;
      await armer.arm(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        onLinkReestablished: (_) async => fired = true,
      );

      device.emit(BluetoothConnectionState.disconnected);
      await Future<void>.delayed(Duration.zero);

      expect(fired, isFalse);
      expect(armer.isArmed, isTrue);
    });

    test('cancel with releaseRegistration drops the OS registration', () async {
      await armer.arm(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        onLinkReestablished: (_) async {},
      );
      await armer.cancel(releaseRegistration: true);

      expect(armer.isArmed, isFalse);
      expect(device.disconnectCalls, 1);

      // Late link event after cancel must not fire the callback.
      device.emit(BluetoothConnectionState.connected);
      await Future<void>.delayed(Duration.zero);
      expect(armer.isArmed, isFalse);
    });

    test('cancel without releaseRegistration keeps the registration', () async {
      await armer.arm(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        onLinkReestablished: (_) async {},
      );
      await armer.cancel(releaseRegistration: false);

      expect(armer.isArmed, isFalse);
      expect(device.disconnectCalls, 0);
    });

    test('cancel while idle is a no-op', () async {
      await armer.cancel(releaseRegistration: true);
      expect(device.disconnectCalls, 0);
    });

    test('arm failure disarms so a later attempt can retry', () async {
      device.connectError = Exception('bt off');
      await armer.arm(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        onLinkReestablished: (_) async {},
      );
      expect(armer.isArmed, isFalse);

      device.connectError = null;
      await armer.arm(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        onLinkReestablished: (_) async {},
      );
      expect(armer.isArmed, isTrue);
      expect(device.connectCalls, 2);
    });

    test('re-arm after a completed cycle registers again', () async {
      await armer.arm(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        onLinkReestablished: (_) async {},
      );
      device.emit(BluetoothConnectionState.connected);
      await Future<void>.delayed(Duration.zero);
      expect(armer.isArmed, isFalse);

      await armer.arm(
        deviceId: 'AA:BB:CC:DD:EE:FF',
        onLinkReestablished: (_) async {},
      );
      expect(armer.isArmed, isTrue);
      expect(device.connectCalls, 2);
    });
  });
}
