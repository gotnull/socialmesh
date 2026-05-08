// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

class _FakeTransport extends DeviceTransport {
  _FakeTransport({required this.connected});

  final bool connected;
  final _stateController = StreamController<DeviceConnectionState>.broadcast();
  final _dataController = StreamController<List<int>>.broadcast();

  @override
  TransportType get type => TransportType.network;

  @override
  bool get isConnected => connected;

  @override
  DeviceConnectionState get state => connected
      ? DeviceConnectionState.connected
      : DeviceConnectionState.disconnected;

  @override
  Stream<DeviceConnectionState> get stateStream => _stateController.stream;

  @override
  Stream<List<int>> get dataStream => _dataController.stream;

  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream<DeviceInfo>.empty();

  @override
  Future<void> connect(DeviceInfo device) async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> send(List<int> data) async {}

  @override
  Future<void> enableNotifications() async {}

  @override
  Future<void> pollOnce() async {}

  @override
  Future<int?> readRssi() async => null;

  @override
  bool get requiresFraming => false;

  @override
  bool get requiresWakeSequence => false;

  @override
  String? get bleModelNumber => null;

  @override
  String? get bleManufacturerName => null;

  @override
  Future<void> dispose() async {
    await _stateController.close();
    await _dataController.close();
  }
}

class _StubProtocol implements ProtocolService {
  final _readinessController = StreamController<OperationalReadiness>.broadcast(
    sync: true,
  );

  @override
  Stream<OperationalReadiness> get readinessStream =>
      _readinessController.stream;

  Future<void> emit(OperationalReadiness state) async {
    _readinessController.add(state);
    // Let the StreamProvider pump.
    await Future<void>.delayed(Duration.zero);
  }

  @override
  Future<void> dispose() async {
    await _readinessController.close();
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProviderContainer _makeContainer({
  required _FakeTransport transport,
  required _StubProtocol protocol,
}) {
  return ProviderContainer(
    overrides: [
      transportProvider.overrideWithValue(transport),
      protocolServiceProvider.overrideWithValue(protocol),
    ],
  );
}

void main() {
  group('meshtasticBannerStateProvider', () {
    test('passthrough before any readiness event has been delivered', () async {
      final transport = _FakeTransport(connected: true);
      final protocol = _StubProtocol();
      final container = _makeContainer(
        transport: transport,
        protocol: protocol,
      );
      addTearDown(() async {
        container.dispose();
        await transport.dispose();
        await protocol.dispose();
      });

      // Subscribe so the StreamProvider initialises.
      container.listen(meshtasticBannerStateProvider, (_, _) {});

      expect(
        container.read(meshtasticBannerStateProvider),
        MeshtasticBannerState.passthrough,
      );
    });

    test(
      'configuring for linkConnected / handshakePhase1 / handshakePhase2',
      () async {
        final transport = _FakeTransport(connected: true);
        final protocol = _StubProtocol();
        final container = _makeContainer(
          transport: transport,
          protocol: protocol,
        );
        addTearDown(() async {
          container.dispose();
          await transport.dispose();
          await protocol.dispose();
        });

        container.listen(meshtasticBannerStateProvider, (_, _) {});

        for (final state in [
          OperationalReadiness.linkConnected,
          OperationalReadiness.handshakePhase1,
          OperationalReadiness.handshakePhase2,
        ]) {
          await protocol.emit(state);
          expect(
            container.read(meshtasticBannerStateProvider),
            MeshtasticBannerState.configuring,
            reason: '$state should map to configuring',
          );
        }
      },
    );

    test('passthrough when ready', () async {
      final transport = _FakeTransport(connected: true);
      final protocol = _StubProtocol();
      final container = _makeContainer(
        transport: transport,
        protocol: protocol,
      );
      addTearDown(() async {
        container.dispose();
        await transport.dispose();
        await protocol.dispose();
      });

      container.listen(meshtasticBannerStateProvider, (_, _) {});

      await protocol.emit(OperationalReadiness.ready);
      expect(
        container.read(meshtasticBannerStateProvider),
        MeshtasticBannerState.passthrough,
      );
    });

    test('recovering for degraded', () async {
      final transport = _FakeTransport(connected: true);
      final protocol = _StubProtocol();
      final container = _makeContainer(
        transport: transport,
        protocol: protocol,
      );
      addTearDown(() async {
        container.dispose();
        await transport.dispose();
        await protocol.dispose();
      });

      container.listen(meshtasticBannerStateProvider, (_, _) {});

      await protocol.emit(OperationalReadiness.degraded);
      expect(
        container.read(meshtasticBannerStateProvider),
        MeshtasticBannerState.recovering,
      );
    });

    test(
      'idle while transport is connected -> configuring (no disconnect flash '
      'during active restore)',
      () async {
        final transport = _FakeTransport(connected: true);
        final protocol = _StubProtocol();
        final container = _makeContainer(
          transport: transport,
          protocol: protocol,
        );
        addTearDown(() async {
          container.dispose();
          await transport.dispose();
          await protocol.dispose();
        });

        container.listen(meshtasticBannerStateProvider, (_, _) {});

        // Simulate the brief `ready -> idle -> linkConnected` window
        // during a restoreSession: protocol.stop() set readiness=idle
        // but the BLE link is still up.
        await protocol.emit(OperationalReadiness.ready);
        await protocol.emit(OperationalReadiness.idle);

        expect(
          container.read(meshtasticBannerStateProvider),
          MeshtasticBannerState.configuring,
          reason:
              'idle + transport.isConnected must be treated as configuring '
              'so the banner does not flash Disconnected during a restore',
        );
      },
    );

    test('idle when transport is disconnected -> passthrough', () async {
      final transport = _FakeTransport(connected: false);
      final protocol = _StubProtocol();
      final container = _makeContainer(
        transport: transport,
        protocol: protocol,
      );
      addTearDown(() async {
        container.dispose();
        await transport.dispose();
        await protocol.dispose();
      });

      container.listen(meshtasticBannerStateProvider, (_, _) {});

      await protocol.emit(OperationalReadiness.idle);
      expect(
        container.read(meshtasticBannerStateProvider),
        MeshtasticBannerState.passthrough,
      );
    });
  });
}
