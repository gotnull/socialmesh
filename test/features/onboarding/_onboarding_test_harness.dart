// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Shared test scaffolding for the [MeshtasticOnboardingFlow]
/// coordinator. Builds a ProviderContainer with all the dependency
/// overrides needed to exercise the state machine end-to-end without
/// touching real BLE / Firestore / SharedPreferences.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/features/onboarding/meshtastic_onboarding_flow.dart';
import 'package:socialmesh/features/onboarding/onboarding_flow_flag.dart';
import 'package:socialmesh/generated/meshtastic/config.pb.dart' as config_pb;
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart'
    as config_pbenum;
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

/// Convenience targeting the same DeviceInfo across phases of a test.
DeviceInfo testDevice({String id = 'device-alpha', String name = 'Test'}) {
  return DeviceInfo(id: id, name: name, type: TransportType.ble);
}

/// Stand-in protocol service. Drives readiness + region stream. The
/// production `setRegion` does an actual wire-write; here we just
/// record the call and let the test simulate the post-reboot
/// readiness/region emissions.
class FakeOnboardingProtocolService extends ProtocolService {
  final StreamController<config_pbenum.Config_LoRaConfig_RegionCode>
  _regionController = StreamController.broadcast();
  final StreamController<config_pb.Config_LoRaConfig> _loraController =
      StreamController.broadcast();

  config_pbenum.Config_LoRaConfig_RegionCode? _currentRegion;
  bool setRegionShouldThrow = false;
  int setRegionCallCount = 0;

  FakeOnboardingProtocolService({
    config_pbenum.Config_LoRaConfig_RegionCode? initialRegion,
  }) : _currentRegion = initialRegion,
       super(_SilentTransport(), dedupeStore: _SilentDedupeStore());

  @override
  config_pbenum.Config_LoRaConfig_RegionCode? get currentRegion =>
      _currentRegion;

  @override
  Stream<config_pbenum.Config_LoRaConfig_RegionCode> get regionStream =>
      _regionController.stream;

  @override
  Stream<config_pb.Config_LoRaConfig> get loraConfigStream =>
      _loraController.stream;

  @override
  Future<void> setRegion(
    config_pbenum.Config_LoRaConfig_RegionCode region,
  ) async {
    setRegionCallCount += 1;
    if (setRegionShouldThrow) {
      throw StateError('setRegion failed (test)');
    }
  }

  void emitRegion(config_pbenum.Config_LoRaConfig_RegionCode region) {
    _currentRegion = region;
    if (!_regionController.isClosed) {
      _regionController.add(region);
    }
    if (!_loraController.isClosed) {
      _loraController.add(config_pb.Config_LoRaConfig()..region = region);
    }
  }
}

class _SilentDedupeStore extends MeshPacketDedupeStore {
  @override
  Future<void> cleanup({Duration? ttl}) async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> hasSeen(MeshPacketKey key, {Duration? ttl}) async => false;

  @override
  Future<void> init() async {}

  @override
  Future<void> markSeen(MeshPacketKey key, {Duration? ttl}) async {}
}

class _SilentTransport implements DeviceTransport {
  final StreamController<DeviceConnectionState> _stateController =
      StreamController<DeviceConnectionState>.broadcast();
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();
  final DeviceConnectionState _state = DeviceConnectionState.disconnected;

  @override
  TransportType get type => TransportType.ble;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;

  @override
  DeviceConnectionState get state => _state;

  @override
  Stream<DeviceConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<List<int>> get dataStream => _dataController.stream;

  @override
  bool get isConnected => _state == DeviceConnectionState.connected;

  @override
  String? get bleModelNumber => null;

  @override
  String? get bleManufacturerName => null;

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
  Future<void> dispose() async {
    await _stateController.close();
    await _dataController.close();
  }
}

/// Build a ProviderContainer set up for the onboarding-flow tests.
ProviderContainer buildOnboardingTestContainer({
  required FakeOnboardingProtocolService protocol,
  bool flowEnabled = true,
  OnboardingFlowTimeouts? timeouts,
}) {
  SharedPreferences.setMockInitialValues({});
  final container = ProviderContainer(
    overrides: [
      protocolServiceProvider.overrideWithValue(protocol),
      meshtasticOnboardingFlowFlagsProvider.overrideWithValue(
        flowEnabled
            ? MeshtasticOnboardingFlowFlags.enabledForTests
            : MeshtasticOnboardingFlowFlags.disabled,
      ),
    ],
  );
  if (timeouts != null) {
    container
        .read(meshtasticOnboardingFlowProvider.notifier)
        .debugSetTimeoutsForTesting(timeouts);
  }
  // Eager-read so the notifier's build() runs and attaches its
  // listeners synchronously. Without this, the first state change
  // would happen before the coordinator subscribed.
  container.read(meshtasticOnboardingFlowProvider);
  return container;
}

/// Helper to drive the device-connection notifier into a given
/// state without going through the BLE transport pipeline.
void setConnectionState(
  ProviderContainer container, {
  required DevicePairingState state,
  DeviceInfo? device,
  int sessionId = 1,
  bool isInvalidated = false,
}) {
  final pairingState = isInvalidated
      ? DevicePairingState.pairedDeviceInvalidated
      : state;
  container
      .read(deviceConnectionProvider.notifier)
      .setTestState(
        DeviceConnectionState2(
          state: pairingState,
          device: device,
          connectionSessionId: sessionId,
          lastConnectedAt: DateTime.now(),
        ),
      );
}

/// Helper that yields micro-tasks so listener callbacks fire
/// before the test makes its assertions.
Future<void> pumpMicrotasks([int rounds = 3]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
