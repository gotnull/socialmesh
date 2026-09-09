// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

// Every caller latches autoReconnectState to scanning before dispatching a
// network reconnect. When the loop finds the transport already connected
// (a previous loop just finished, or the link never dropped) it has
// nothing to do, and the manager's connected guard only fires on a
// transport state change that already happened. Unless the loop settles
// the state itself, the top banner sits on "Searching for device..."
// over a live link.

final _refProbe = Provider<Ref>((ref) => ref);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'network reconnect against a live link settles scanning back to idle',
    () async {
      final settings = SettingsService();
      await settings.init();

      final container = ProviderContainer(
        overrides: [
          transportProvider.overrideWithValue(_ConnectedNetworkTransport()),
          settingsServiceProvider.overrideWithValue(AsyncValue.data(settings)),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(transportTypeProvider.notifier)
          .setType(TransportType.network);
      container
          .read(autoReconnectStateProvider.notifier)
          .setState(AutoReconnectState.scanning);

      dispatchReconnectForDevice(
        container.read(_refProbe),
        'tcp:10.0.0.5:4403',
      );
      await Future.delayed(const Duration(milliseconds: 50));

      expect(
        container.read(autoReconnectStateProvider),
        AutoReconnectState.idle,
        reason:
            'A reconnect dispatched against an already-connected transport '
            'must not leave the caller-set scanning state behind.',
      );
    },
  );
}

class _ConnectedNetworkTransport implements DeviceTransport {
  final StreamController<DeviceConnectionState> _stateController =
      StreamController<DeviceConnectionState>.broadcast();

  @override
  TransportType get type => TransportType.network;

  @override
  bool get requiresFraming => true;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode =>
      TransportReconnectMode.directEndpoint;

  @override
  DeviceConnectionState get state => DeviceConnectionState.connected;

  @override
  Stream<DeviceConnectionState> get stateStream => _stateController.stream;

  @override
  String? get bleManufacturerName => null;

  @override
  String? get bleModelNumber => null;

  @override
  bool get isConnected => true;

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
  Future<void> enableNotifications() async {}

  @override
  Future<void> refreshNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  Future<void> dispose() async {
    await _stateController.close();
  }
}
