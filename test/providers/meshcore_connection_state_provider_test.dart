// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// The MeshCore screens decide connected or disconnected from
// linkStatusProvider, which follows meshCoreConnectionStateProvider. A
// state change the coordinator announces just after that provider is built
// must still reach them.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/models/mesh_device.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/connection_coordinator.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

class _SwitchableCoordinator implements ConnectionCoordinator {
  final _states = StreamController<MeshConnectionState>.broadcast();
  bool _connected = false;

  void announceConnected() {
    _connected = true;
    _states.add(MeshConnectionState.connected);
  }

  Future<void> close() => _states.close();

  @override
  bool get isConnected => _connected;

  @override
  bool get isConnecting => false;

  @override
  MeshDeviceInfo? get deviceInfo => _connected
      ? MeshDeviceInfo(
          protocolType: MeshProtocolType.meshcore,
          displayName: 'WisMeshCore',
          nodeId: '96458BE0',
        )
      : null;

  @override
  Stream<MeshConnectionState> get stateStream => _states.stream;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Future<(ProviderContainer, _SwitchableCoordinator)> _boot() async {
  SharedPreferences.setMockInitialValues({'last_device_protocol': 'meshcore'});
  final settings = SettingsService();
  await settings.init();
  final coordinator = _SwitchableCoordinator();
  addTearDown(coordinator.close);
  final container = ProviderContainer(
    overrides: [
      settingsServiceProvider.overrideWithValue(AsyncValue.data(settings)),
      connectionCoordinatorProvider.overrideWithValue(coordinator),
    ],
  );
  addTearDown(container.dispose);
  container.listen(linkStatusProvider, (_, _) {});
  return (container, coordinator);
}

Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a connect announced right after the provider is built reaches '
      'the link status', () async {
    final (container, coordinator) = await _boot();
    expect(container.read(linkStatusProvider).isConnected, isFalse);

    // Same turn as the build: before any microtask has run.
    coordinator.announceConnected();
    await _settle();

    expect(
      container.read(meshCoreConnectionStateProvider).value,
      MeshConnectionState.connected,
    );
    expect(container.read(linkStatusProvider).isConnected, isTrue);
  });

  test('a connect announced later reaches the link status', () async {
    final (container, coordinator) = await _boot();
    await _settle();
    expect(container.read(linkStatusProvider).isConnected, isFalse);

    coordinator.announceConnected();
    await _settle();

    expect(container.read(linkStatusProvider).isConnected, isTrue);
  });
}
