// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Bluetooth turning on must reconnect the saved radio. Mid-session the
// listener hands off to the auto-reconnect manager. Before the first
// connection of a launch (Bluetooth was off when the app started, so the
// startup reconnect gave up) it re-runs the startup reconnect instead.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

class _FakeDeviceConnectionNotifier extends DeviceConnectionNotifier {
  int startBackgroundCalls = 0;

  @override
  DeviceConnectionState2 build() =>
      const DeviceConnectionState2(state: DevicePairingState.disconnected);

  @override
  Future<void> startBackgroundConnection() async {
    startBackgroundCalls++;
  }
}

class _FakeTransport implements DeviceTransport {
  final StreamController<DeviceConnectionState> _controller =
      StreamController<DeviceConnectionState>.broadcast();

  @override
  DeviceConnectionState get state => DeviceConnectionState.disconnected;

  @override
  Stream<DeviceConnectionState> get stateStream => _controller.stream;

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;

  @override
  bool get isConnected => false;

  @override
  Stream<List<int>> get dataStream => const Stream.empty();

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream.empty();

  @override
  Future<void> connect(DeviceInfo device) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<void> refreshNotifications() async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  String? get bleManufacturerName => null;

  @override
  String? get bleModelNumber => null;

  @override
  Future<void> dispose() async {
    await _controller.close();
  }
}

const _savedDevice = 'AA:BB:CC:DD:EE:FF';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeDeviceConnectionNotifier fake;
  late StreamController<BluetoothAdapterState> adapter;
  late ProviderContainer container;

  void build(FakeAsync async, {String? savedDevice = _savedDevice}) {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'last_device_type': 'ble',
      'auto_reconnect': true,
      'last_device_id': ?savedDevice,
    });
    // A fresh instance per test: settingsServiceProvider caches the first
    // one it builds for the life of the isolate.
    final settings = SettingsService();
    settings.init();
    async.flushMicrotasks();
    fake = _FakeDeviceConnectionNotifier();
    adapter = StreamController<BluetoothAdapterState>();
    container = ProviderContainer(
      overrides: [
        settingsServiceProvider.overrideWithValue(AsyncValue.data(settings)),
        deviceConnectionProvider.overrideWith(() => fake),
        transportProvider.overrideWithValue(_FakeTransport()),
        bluetoothStateProvider.overrideWith((ref) => adapter.stream),
      ],
    );
    // main.dart watches these; an unlistened provider is paused.
    container.listen(bluetoothStateListenerProvider, (_, _) {});
  }

  void emit(FakeAsync async, BluetoothAdapterState s) {
    adapter.add(s);
    async.flushMicrotasks();
  }

  void finish(FakeAsync async) {
    // Let any reconnect the listener started run to its first exit so
    // nothing reads the container after it is disposed.
    container.read(userDisconnectedProvider.notifier).setUserDisconnected(true);
    async.elapse(const Duration(seconds: 15));
    container.dispose();
    adapter.close();
    async.flushMicrotasks();
  }

  test('Bluetooth on after a launch with it off retries the startup '
      'reconnect', () {
    fakeAsync((async) {
      build(async);
      emit(async, BluetoothAdapterState.unknown);
      emit(async, BluetoothAdapterState.off);
      emit(async, BluetoothAdapterState.on);

      async.elapse(const Duration(milliseconds: 1900));
      expect(fake.startBackgroundCalls, 0, reason: 'waits 2s to settle');

      async.elapse(const Duration(milliseconds: 200));
      expect(fake.startBackgroundCalls, 1);
      expect(
        container.read(autoReconnectStateProvider),
        AutoReconnectState.idle,
        reason:
            'startBackgroundConnection refuses to run while the state is '
            'scanning, so the listener must leave it alone',
      );
      finish(async);
    });
  });

  test('Bluetooth on with no saved device does nothing', () {
    fakeAsync((async) {
      build(async, savedDevice: null);
      emit(async, BluetoothAdapterState.off);
      emit(async, BluetoothAdapterState.on);
      async.elapse(const Duration(seconds: 3));

      expect(fake.startBackgroundCalls, 0);
      expect(
        container.read(autoReconnectStateProvider),
        AutoReconnectState.idle,
      );
      finish(async);
    });
  });

  test('a normal launch with Bluetooth already on does nothing', () {
    fakeAsync((async) {
      build(async);
      emit(async, BluetoothAdapterState.unknown);
      emit(async, BluetoothAdapterState.on);
      async.elapse(const Duration(seconds: 3));

      expect(fake.startBackgroundCalls, 0);
      finish(async);
    });
  });

  test('Bluetooth on after a user disconnect does nothing', () {
    fakeAsync((async) {
      build(async);
      container
          .read(userDisconnectedProvider.notifier)
          .setUserDisconnected(true);
      emit(async, BluetoothAdapterState.off);
      emit(async, BluetoothAdapterState.on);
      async.elapse(const Duration(seconds: 3));

      expect(fake.startBackgroundCalls, 0);
      finish(async);
    });
  });

  test('Bluetooth on mid-session still hands off to the auto-reconnect '
      'manager', () {
    fakeAsync((async) {
      build(async);
      // The manager records the device of this launch's first connection.
      container.listen(autoReconnectManagerProvider, (_, _) {});
      container
          .read(connectedDeviceProvider.notifier)
          .setState(
            DeviceInfo(
              id: _savedDevice,
              name: 'Radio',
              type: TransportType.ble,
            ),
          );
      container.read(connectedDeviceProvider.notifier).setState(null);
      // Clear any reconnect the manager started for that drop, so only the
      // Bluetooth listener can set the state below.
      emit(async, BluetoothAdapterState.on);
      container
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.idle);
      async.flushMicrotasks();

      emit(async, BluetoothAdapterState.off);
      emit(async, BluetoothAdapterState.on);
      async.elapse(const Duration(milliseconds: 2100));

      expect(fake.startBackgroundCalls, 0);
      expect(
        container.read(autoReconnectStateProvider),
        AutoReconnectState.scanning,
        reason: 'the manager path marks the reconnect as scanning',
      );
      finish(async);
    });
  });
}
