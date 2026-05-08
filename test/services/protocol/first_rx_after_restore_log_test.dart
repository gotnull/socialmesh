// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';

class _NoopTransport extends DeviceTransport {
  _NoopTransport();

  final _stateController = StreamController<DeviceConnectionState>.broadcast();
  final _dataController = StreamController<List<int>>.broadcast();

  @override
  TransportType get type => TransportType.network;

  @override
  bool get isConnected => true;

  @override
  DeviceConnectionState get state => DeviceConnectionState.connected;

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

void main() {
  setUpAll(() {
    dotenv.loadFromString(envString: 'TEST=1');
  });

  group('first-RX-after-restore state machine', () {
    test('before bindSessionGeneration: _bindAt is null, flag is false', () {
      final transport = _NoopTransport();
      final protocol = ProtocolService(transport);
      addTearDown(() async {
        await protocol.dispose();
        await transport.dispose();
      });

      expect(protocol.bindAtForTesting, isNull);
      expect(protocol.firstRxAfterBindLoggedForTesting, isFalse);
    });

    test('bindSessionGeneration sets _bindAt and resets the flag', () {
      final transport = _NoopTransport();
      final protocol = ProtocolService(transport);
      addTearDown(() async {
        await protocol.dispose();
        await transport.dispose();
      });

      protocol.bindSessionGeneration(7);

      expect(protocol.bindAtForTesting, isNotNull);
      expect(protocol.firstRxAfterBindLoggedForTesting, isFalse);
      expect(protocol.sessionGeneration, 7);
    });

    test(
      'first inbound packet after bind flips the flag; subsequent packets do '
      'not flip it back',
      () async {
        final transport = _NoopTransport();
        final protocol = ProtocolService(transport);
        addTearDown(() async {
          await protocol.dispose();
          await transport.dispose();
        });

        protocol.bindSessionGeneration(1);
        expect(protocol.firstRxAfterBindLoggedForTesting, isFalse);

        await protocol.handleIncomingPacket(Uint8List.fromList(const <int>[]));
        expect(protocol.firstRxAfterBindLoggedForTesting, isTrue);

        await protocol.handleIncomingPacket(Uint8List.fromList(const <int>[]));
        await protocol.handleIncomingPacket(Uint8List.fromList(const <int>[]));
        expect(
          protocol.firstRxAfterBindLoggedForTesting,
          isTrue,
          reason: 'flag is monotonic within a single bind',
        );
      },
    );

    test('a second bindSessionGeneration re-arms the flag and refreshes the '
        'wall-clock anchor', () async {
      final transport = _NoopTransport();
      final protocol = ProtocolService(transport);
      addTearDown(() async {
        await protocol.dispose();
        await transport.dispose();
      });

      protocol.bindSessionGeneration(1);
      await protocol.handleIncomingPacket(Uint8List.fromList(const <int>[]));
      expect(protocol.firstRxAfterBindLoggedForTesting, isTrue);
      final firstBindAt = protocol.bindAtForTesting;

      // Sleep just enough to make the new wall-clock anchor distinct
      // (DateTime.now() resolution on macOS test runners is sub-ms,
      // so this delay is conservative).
      await Future<void>.delayed(const Duration(milliseconds: 2));

      protocol.bindSessionGeneration(2);
      expect(
        protocol.firstRxAfterBindLoggedForTesting,
        isFalse,
        reason: 'second bind must reset the flag',
      );
      expect(
        protocol.bindAtForTesting,
        isNot(equals(firstBindAt)),
        reason: 'second bind refreshes the wall-clock anchor',
      );
      expect(protocol.sessionGeneration, 2);

      await protocol.handleIncomingPacket(Uint8List.fromList(const <int>[]));
      expect(protocol.firstRxAfterBindLoggedForTesting, isTrue);
    });
  });
}
