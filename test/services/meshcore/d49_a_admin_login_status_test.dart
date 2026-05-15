// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-A: `MeshCoreSession.sendLogin` + `sendStatusRequest`
// + `MeshCoreRepeaterStatus.parse` pins.
//
// Pinned invariants:
//
// CMD_SEND_LOGIN 0x1A:
//   - outbound bytes are `[0x1A][pubkey:32][password utf-8][0x00]`.
//   - multi-byte password UTF-8 encodes correctly.
//   - 0x85 (admin=1) with matching prefix => delivered + admin=true.
//   - 0x85 (admin=0) with matching prefix => delivered + admin=false.
//   - 0x86 with matching prefix => delivered=false.
//   - mismatched prefix on 0x85/0x86 is ignored => timeout.
//   - timeout => MeshCoreLoginResult(delivered=false).
//
// CMD_SEND_STATUS_REQ 0x1B:
//   - outbound bytes are `[0x1B][pubkey:32]`.
//   - 0x87 with matching prefix + valid 52-byte stats body =>
//     parsed status.
//   - mismatched prefix on 0x87 is ignored => null.
//   - short 0x87 payload returns null.
//   - rejects non-32-byte pubKey with ArgumentError.
//
// MeshCoreRepeaterStatus.parse:
//   - golden 52-byte hex blob decodes every field.
//   - payload < 59 bytes => null.
//   - lastSnrDb = lastSnrQuarter / 4.0.
//   - batteryVolts = batteryMv / 1000.0 (null when batteryMv == 0).

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

class _RecordingTransport implements MeshCoreTransport {
  final StreamController<Uint8List> _rx =
      StreamController<Uint8List>.broadcast();
  final List<Uint8List> sent = [];
  bool _connected = true;

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    sent.add(Uint8List.fromList(data));
  }

  @override
  bool get isConnected => _connected;

  void inject(Uint8List bytes) {
    _rx.add(bytes);
  }

  Future<void> dispose() async {
    _connected = false;
    await _rx.close();
  }
}

final _repeaterPubKey = Uint8List.fromList(
  List<int>.generate(32, (i) => 0x10 + i),
);

Uint8List _loginSuccessFrame(Uint8List pubKey, {required bool admin}) {
  final payload = Uint8List(7);
  payload[0] = admin ? 1 : 0;
  for (var i = 0; i < 6; i++) {
    payload[1 + i] = pubKey[i];
  }
  return MeshCoreFrame(
    command: MeshCorePushCodes.loginSuccess,
    payload: payload,
  ).toBytes();
}

Uint8List _loginFailFrame(Uint8List pubKey) {
  final payload = Uint8List(7);
  for (var i = 0; i < 6; i++) {
    payload[1 + i] = pubKey[i];
  }
  return MeshCoreFrame(
    command: MeshCorePushCodes.loginFail,
    payload: payload,
  ).toBytes();
}

Uint8List _statusBody({
  required int batteryMv,
  required int queueLen,
  required int noise,
  required int rssi,
  required int packetsRecv,
  required int packetsSent,
  required int txSecs,
  required int uptimeSecs,
  required int floodTx,
  required int directTx,
  required int floodRx,
  required int directRx,
  required int errEvents,
  required int snrQuarter,
  required int directDups,
  required int floodDups,
  required int rxSecs,
}) {
  final body = Uint8List(52);
  final bd = ByteData.sublistView(body);
  bd.setUint16(0, batteryMv, Endian.little);
  bd.setUint16(2, queueLen, Endian.little);
  bd.setInt16(4, noise, Endian.little);
  bd.setInt16(6, rssi, Endian.little);
  bd.setUint32(8, packetsRecv, Endian.little);
  bd.setUint32(12, packetsSent, Endian.little);
  bd.setUint32(16, txSecs, Endian.little);
  bd.setUint32(20, uptimeSecs, Endian.little);
  bd.setUint32(24, floodTx, Endian.little);
  bd.setUint32(28, directTx, Endian.little);
  bd.setUint32(32, floodRx, Endian.little);
  bd.setUint32(36, directRx, Endian.little);
  bd.setUint16(40, errEvents, Endian.little);
  bd.setInt16(42, snrQuarter, Endian.little);
  bd.setUint16(44, directDups, Endian.little);
  bd.setUint16(46, floodDups, Endian.little);
  bd.setUint32(48, rxSecs, Endian.little);
  return body;
}

Uint8List _statusResponseFrame(Uint8List pubKey, Uint8List body) {
  final payload = Uint8List(7 + body.length);
  for (var i = 0; i < 6; i++) {
    payload[1 + i] = pubKey[i];
  }
  payload.setRange(7, payload.length, body);
  return MeshCoreFrame(
    command: MeshCorePushCodes.statusResponse,
    payload: payload,
  ).toBytes();
}

void main() {
  group('CMD_SEND_LOGIN 0x1A - D49-A', () {
    test('outbound bytes are [0x1A][pubkey:32][password][0x00]', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.sendLogin(
        pubKey: _repeaterPubKey,
        password: 'admin123',
        timeout: const Duration(milliseconds: 100),
      );
      await Future<void>.delayed(Duration.zero);

      expect(tx.sent, hasLength(1));
      final sent = MeshCoreFrame.fromBytes(tx.sent.single);
      expect(sent.command, MeshCoreCommands.sendLogin);
      expect(sent.payload.sublist(0, 32), equals(_repeaterPubKey));
      expect(sent.payload.sublist(32, 40), equals(utf8.encode('admin123')));
      expect(sent.payload.last, 0); // C-string NUL

      await fut; // timeout
    });

    test('multi-byte password UTF-8 encodes correctly', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.sendLogin(
        pubKey: _repeaterPubKey,
        password: 'pässwörd-éé',
        timeout: const Duration(milliseconds: 100),
      );
      await Future<void>.delayed(Duration.zero);

      final sent = MeshCoreFrame.fromBytes(tx.sent.single);
      final passwordBytes = sent.payload.sublist(32, sent.payload.length - 1);
      expect(passwordBytes, equals(utf8.encode('pässwörd-éé')));
      await fut;
    });

    test('0x85 (admin=1) matching prefix => delivered + admin=true', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.sendLogin(pubKey: _repeaterPubKey, password: 'x');
      await Future<void>.delayed(Duration.zero);
      tx.inject(_loginSuccessFrame(_repeaterPubKey, admin: true));

      final result = await fut;
      expect(result.delivered, isTrue);
      expect(result.isAdmin, isTrue);
    });

    test('0x85 (admin=0) matching prefix => delivered + admin=false', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.sendLogin(pubKey: _repeaterPubKey, password: 'x');
      await Future<void>.delayed(Duration.zero);
      tx.inject(_loginSuccessFrame(_repeaterPubKey, admin: false));

      final result = await fut;
      expect(result.delivered, isTrue);
      expect(result.isAdmin, isFalse);
    });

    test('0x86 matching prefix => delivered=false', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.sendLogin(pubKey: _repeaterPubKey, password: 'wrong');
      await Future<void>.delayed(Duration.zero);
      tx.inject(_loginFailFrame(_repeaterPubKey));

      final result = await fut;
      expect(result.delivered, isFalse);
    });

    test('mismatched prefix on 0x85 is ignored => timeout', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final otherPubKey = Uint8List.fromList(
        List<int>.generate(32, (i) => 0xA0 + i),
      );
      final fut = session.sendLogin(
        pubKey: _repeaterPubKey,
        password: 'x',
        timeout: const Duration(milliseconds: 100),
      );
      await Future<void>.delayed(Duration.zero);
      // Push success for a DIFFERENT pubkey.
      tx.inject(_loginSuccessFrame(otherPubKey, admin: true));

      final result = await fut;
      expect(result.delivered, isFalse);
    });

    test('timeout => delivered=false', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final result = await session.sendLogin(
        pubKey: _repeaterPubKey,
        password: 'x',
        timeout: const Duration(milliseconds: 50),
      );
      expect(result.delivered, isFalse);
    });

    test('rejects non-32-byte pubKey with ArgumentError', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      expect(
        () => session.sendLogin(pubKey: Uint8List(8), password: 'x'),
        throwsArgumentError,
      );
    });
  });

  group('CMD_SEND_STATUS_REQ 0x1B - D49-A', () {
    test('outbound bytes are [0x1B][pubkey:32]', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.sendStatusRequest(
        pubKey: _repeaterPubKey,
        timeout: const Duration(milliseconds: 50),
      );
      await Future<void>.delayed(Duration.zero);

      expect(tx.sent, hasLength(1));
      final sent = MeshCoreFrame.fromBytes(tx.sent.single);
      expect(sent.command, MeshCoreCommands.sendStatusReq);
      expect(sent.payload, equals(_repeaterPubKey));
      await fut;
    });

    test('0x87 matching prefix + 52-byte body => parsed status', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.sendStatusRequest(pubKey: _repeaterPubKey);
      await Future<void>.delayed(Duration.zero);
      final body = _statusBody(
        batteryMv: 3700,
        queueLen: 2,
        noise: -95,
        rssi: -72,
        packetsRecv: 1234,
        packetsSent: 567,
        txSecs: 42,
        uptimeSecs: 86400,
        floodTx: 100,
        directTx: 50,
        floodRx: 200,
        directRx: 75,
        errEvents: 3,
        snrQuarter: 28, // 7 dB
        directDups: 1,
        floodDups: 4,
        rxSecs: 60,
      );
      tx.inject(_statusResponseFrame(_repeaterPubKey, body));

      final status = await fut;
      expect(status, isNotNull);
      expect(status!.batteryMv, 3700);
      expect(status.batteryVolts, closeTo(3.7, 1e-9));
      expect(status.queueLen, 2);
      expect(status.noiseFloorDbm, -95);
      expect(status.lastRssiDbm, -72);
      expect(status.packetsRecv, 1234);
      expect(status.packetsSent, 567);
      expect(status.txAirtime.inSeconds, 42);
      expect(status.uptime.inSeconds, 86400);
      expect(status.floodTx, 100);
      expect(status.directTx, 50);
      expect(status.floodRx, 200);
      expect(status.directRx, 75);
      expect(status.errEvents, 3);
      expect(status.lastSnrQuarter, 28);
      expect(status.lastSnrDb, closeTo(7.0, 1e-9));
      expect(status.directDups, 1);
      expect(status.floodDups, 4);
      expect(status.rxAirtime.inSeconds, 60);
    });

    test('mismatched prefix on 0x87 is ignored => null', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final otherPubKey = Uint8List.fromList(
        List<int>.generate(32, (i) => 0xA0 + i),
      );
      final fut = session.sendStatusRequest(
        pubKey: _repeaterPubKey,
        timeout: const Duration(milliseconds: 100),
      );
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        _statusResponseFrame(
          otherPubKey,
          _statusBody(
            batteryMv: 0,
            queueLen: 0,
            noise: 0,
            rssi: 0,
            packetsRecv: 0,
            packetsSent: 0,
            txSecs: 0,
            uptimeSecs: 0,
            floodTx: 0,
            directTx: 0,
            floodRx: 0,
            directRx: 0,
            errEvents: 0,
            snrQuarter: 0,
            directDups: 0,
            floodDups: 0,
            rxSecs: 0,
          ),
        ),
      );

      expect(await fut, isNull);
    });

    test('rejects non-32-byte pubKey with ArgumentError', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      expect(
        () => session.sendStatusRequest(pubKey: Uint8List(8)),
        throwsArgumentError,
      );
    });
  });

  group('MeshCoreRepeaterStatus.parse - D49-A', () {
    test('payload shorter than 59 bytes returns null', () {
      expect(MeshCoreRepeaterStatus.parse(Uint8List(58)), isNull);
      expect(MeshCoreRepeaterStatus.parse(Uint8List(10)), isNull);
    });

    test('batteryVolts is null when batteryMv == 0', () {
      final payload = Uint8List(59);
      // Embed prefix in payload[1..7] so the constructor takes a
      // non-null prefix; battery_mv at payload[7..9] stays zero.
      for (var i = 0; i < 6; i++) {
        payload[1 + i] = i;
      }
      final s = MeshCoreRepeaterStatus.parse(payload);
      expect(s, isNotNull);
      expect(s!.batteryVolts, isNull);
    });

    test('SNR quarter-dB converts to dB via /4', () {
      final body = _statusBody(
        batteryMv: 0,
        queueLen: 0,
        noise: 0,
        rssi: 0,
        packetsRecv: 0,
        packetsSent: 0,
        txSecs: 0,
        uptimeSecs: 0,
        floodTx: 0,
        directTx: 0,
        floodRx: 0,
        directRx: 0,
        errEvents: 0,
        snrQuarter: -12, // -3 dB
        directDups: 0,
        floodDups: 0,
        rxSecs: 0,
      );
      final payload = Uint8List(7 + body.length)
        ..setRange(7, 7 + body.length, body);
      final s = MeshCoreRepeaterStatus.parse(payload);
      expect(s, isNotNull);
      expect(s!.lastSnrDb, closeTo(-3.0, 1e-9));
    });
  });
}
