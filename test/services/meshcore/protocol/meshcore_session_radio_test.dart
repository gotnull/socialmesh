// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Tests for MeshCoreSession.setRadioParams and setRadioTxPower.
//
// The session helpers wrap CMD_SET_RADIO_PARAMS (0x0B) and
// CMD_SET_RADIO_TX_POWER (0x0C). Wire format mirrors upstream
// MyMesh.cpp: freq is u32 LE in kHz, bw is u32 LE in Hz, sf and cr are
// u8, tx power is int8.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

class _RecordingTransport implements MeshCoreTransport {
  final StreamController<Uint8List> _rx =
      StreamController<Uint8List>.broadcast();
  final List<Uint8List> sent = [];
  bool connected = true;

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    sent.add(Uint8List.fromList(data));
  }

  @override
  bool get isConnected => connected;

  void simulateOk() {
    final ok = MeshCoreFrame(
      command: MeshCoreResponses.ok,
      payload: Uint8List(0),
    );
    _rx.add(ok.toBytes());
  }

  void simulateErr() {
    final err = MeshCoreFrame(
      command: MeshCoreResponses.err,
      payload: Uint8List.fromList([0x01]),
    );
    _rx.add(err.toBytes());
  }

  Future<void> dispose() async {
    await _rx.close();
  }
}

void main() {
  group('MeshCoreSession.setRadioParams', () {
    test('encodes freq + bw + sf + cr in canonical wire format', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);

      // Schedule the OK ack on the next microtask so the helper sees it.
      Future.microtask(() => transport.simulateOk());

      final ok = await session.setRadioParams(
        freqKhz: 869618, // 869.618 MHz
        bandwidthHz: 62500, // 62.5 kHz
        spreadingFactor: 8,
        codingRate: 5,
      );

      expect(ok, isTrue);
      expect(transport.sent, hasLength(1));
      final wire = transport.sent.single;
      // [cmd][freq:u32 LE][bw:u32 LE][sf][cr]
      expect(wire.length, 11);
      expect(wire[0], MeshCoreCommands.setRadioParams);

      final freqBytes = ByteData.sublistView(wire, 1, 5);
      expect(freqBytes.getUint32(0, Endian.little), 869618);
      final bwBytes = ByteData.sublistView(wire, 5, 9);
      expect(bwBytes.getUint32(0, Endian.little), 62500);
      expect(wire[9], 8); // sf
      expect(wire[10], 5); // cr

      await session.dispose();
      await transport.dispose();
    });

    test('returns false on firmware ERR response', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);

      // sendAndWait waits for OK (0x00). Sim an ERR: no OK ever arrives,
      // so the call times out. Use a short timeout so the test stays fast.
      final ok = await session.setRadioParams(
        freqKhz: 869618,
        bandwidthHz: 62500,
        spreadingFactor: 8,
        codingRate: 5,
        timeout: const Duration(milliseconds: 100),
      );

      expect(ok, isFalse);

      await session.dispose();
      await transport.dispose();
    });

    test('rejects out-of-range freq', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);

      expect(
        () => session.setRadioParams(
          freqKhz: 100000, // < 150_000
          bandwidthHz: 62500,
          spreadingFactor: 8,
          codingRate: 5,
        ),
        throwsArgumentError,
      );
      expect(
        () => session.setRadioParams(
          freqKhz: 3000000, // > 2_500_000
          bandwidthHz: 62500,
          spreadingFactor: 8,
          codingRate: 5,
        ),
        throwsArgumentError,
      );

      await session.dispose();
      await transport.dispose();
    });

    test('rejects out-of-range bandwidth', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);

      expect(
        () => session.setRadioParams(
          freqKhz: 869618,
          bandwidthHz: 5000, // < 7_000
          spreadingFactor: 8,
          codingRate: 5,
        ),
        throwsArgumentError,
      );
      expect(
        () => session.setRadioParams(
          freqKhz: 869618,
          bandwidthHz: 600000, // > 500_000
          spreadingFactor: 8,
          codingRate: 5,
        ),
        throwsArgumentError,
      );

      await session.dispose();
      await transport.dispose();
    });

    test('rejects out-of-range SF and CR', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);

      expect(
        () => session.setRadioParams(
          freqKhz: 869618,
          bandwidthHz: 62500,
          spreadingFactor: 4, // < 5
          codingRate: 5,
        ),
        throwsArgumentError,
      );
      expect(
        () => session.setRadioParams(
          freqKhz: 869618,
          bandwidthHz: 62500,
          spreadingFactor: 13, // > 12
          codingRate: 5,
        ),
        throwsArgumentError,
      );
      expect(
        () => session.setRadioParams(
          freqKhz: 869618,
          bandwidthHz: 62500,
          spreadingFactor: 8,
          codingRate: 4, // < 5
        ),
        throwsArgumentError,
      );
      expect(
        () => session.setRadioParams(
          freqKhz: 869618,
          bandwidthHz: 62500,
          spreadingFactor: 8,
          codingRate: 9, // > 8
        ),
        throwsArgumentError,
      );

      await session.dispose();
      await transport.dispose();
    });
  });

  group('MeshCoreSession.setRadioTxPower', () {
    test('encodes int8 power byte and returns true on OK', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);

      Future.microtask(() => transport.simulateOk());

      final ok = await session.setRadioTxPower(powerDbm: 22);
      expect(ok, isTrue);

      expect(transport.sent, hasLength(1));
      final wire = transport.sent.single;
      expect(wire.length, 2);
      expect(wire[0], MeshCoreCommands.setRadioTxPower);
      expect(wire[1], 22);

      await session.dispose();
      await transport.dispose();
    });

    test('encodes negative power as two\'s-complement byte', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);

      Future.microtask(() => transport.simulateOk());

      final ok = await session.setRadioTxPower(powerDbm: -5);
      expect(ok, isTrue);
      expect(transport.sent.single[1], 0xFB); // -5 as int8 = 0xFB

      await session.dispose();
      await transport.dispose();
    });

    test('rejects out-of-range TX power', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);

      expect(() => session.setRadioTxPower(powerDbm: -10), throwsArgumentError);
      expect(() => session.setRadioTxPower(powerDbm: 31), throwsArgumentError);

      await session.dispose();
      await transport.dispose();
    });

    test('returns false on timeout (no ack)', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);

      final ok = await session.setRadioTxPower(
        powerDbm: 22,
        timeout: const Duration(milliseconds: 100),
      );

      expect(ok, isFalse);

      await session.dispose();
      await transport.dispose();
    });
  });
}
