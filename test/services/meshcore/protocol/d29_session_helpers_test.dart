// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D29 - byte-for-byte regression pins for the contact management
// session helpers (`addUpdateContact` 0x09, `removeContact` 0x0F,
// `resetPath` 0x0D). Wire format is part of the protocol contract
// with the companion-radio firmware; pin the bytes so a future
// refactor can't silently change the encoding.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

class _FakeTransport implements MeshCoreTransport {
  final _rx = StreamController<Uint8List>.broadcast();
  final List<Uint8List> sentData = [];

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    sentData.add(Uint8List.fromList(data));
  }

  @override
  bool get isConnected => true;

  void simulateReceiveFrame(MeshCoreFrame frame) {
    _rx.add(frame.toBytes());
  }

  Future<void> dispose() async {
    if (!_rx.isClosed) await _rx.close();
  }
}

Future<Uint8List> _capture({
  required _FakeTransport transport,
  required Future<void> Function(MeshCoreSession) op,
  int replyCode = 0x00,
}) async {
  final session = MeshCoreSession(transport);
  final fut = op(session);
  await Future<void>.delayed(const Duration(milliseconds: 5));
  transport.simulateReceiveFrame(
    MeshCoreFrame(command: replyCode, payload: Uint8List(0)),
  );
  await fut;
  return transport.sentData.last;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Reusable 32-byte deterministic pubkey: 0x01..0x20.
  final pubKey = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));

  group('D29 addUpdateContact (0x09)', () {
    test('minimum payload (no GPS): 32 + 1 + 1 + 1 + 64 + 32 + 4 = 135 bytes '
        'after opcode, total 136 wire bytes', () async {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final wire = await _capture(
        transport: t,
        op: (s) => s.addUpdateContact(
          pubKey: pubKey,
          advType: 1,
          name: 'Alice',
          pathLength: -1,
          lastAdvertAt: DateTime.utc(2026, 5, 6, 0, 0, 0),
        ),
      );
      expect(wire[0], 0x09);
      expect(wire.length, 1 + 135);
      // pubkey at [1..32]
      expect(wire.sublist(1, 33), pubKey);
      // adv_type at [33]
      expect(wire[33], 1);
      // flags at [34]
      expect(wire[34], 0);
      // path_len at [35]: -1 (flood) encoded as 0xFF (signed int8 two's complement)
      expect(wire[35], 0xFF);
      // path bytes [36..99] zero-padded
      expect(wire.sublist(36, 100), Uint8List(64));
      // name 'Alice' at [100..]
      expect(wire.sublist(100, 105), [0x41, 0x6c, 0x69, 0x63, 0x65]);
      // remaining name bytes zero-padded out to offset 132
      expect(wire.sublist(105, 132), Uint8List(27));
      // timestamp at [132..135] u32 LE = epoch seconds
      final tsExpected =
          DateTime.utc(2026, 5, 6).millisecondsSinceEpoch ~/ 1000;
      final ts =
          wire[132] | (wire[133] << 8) | (wire[134] << 16) | (wire[135] << 24);
      expect(ts, tsExpected);
    });

    test(
      'with GPS extends payload to 143 bytes (lat+lon at 1e6 scale)',
      () async {
        final t = _FakeTransport();
        addTearDown(t.dispose);
        final wire = await _capture(
          transport: t,
          op: (s) => s.addUpdateContact(
            pubKey: pubKey,
            advType: 1,
            name: 'Bob',
            latitude: -37.601343,
            longitude: 145.087384,
          ),
        );
        // total = 1 (opcode) + 143
        expect(wire.length, 1 + 143);
        // lat at offsets [136..139] (i32 LE × 1e6)
        final latRaw =
            wire[136] |
            (wire[137] << 8) |
            (wire[138] << 16) |
            (wire[139] << 24);
        // signed int32
        final latSigned = latRaw < 0x80000000 ? latRaw : latRaw - 0x100000000;
        expect(latSigned, (-37.601343 * 1e6).round());
        // lon at offsets [140..143]
        final lonRaw =
            wire[140] |
            (wire[141] << 8) |
            (wire[142] << 16) |
            (wire[143] << 24);
        final lonSigned = lonRaw < 0x80000000 ? lonRaw : lonRaw - 0x100000000;
        expect(lonSigned, (145.087384 * 1e6).round());
      },
    );

    test('rejects pubkey of wrong length', () {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final session = MeshCoreSession(t);
      expect(
        () => session.addUpdateContact(
          pubKey: Uint8List(31),
          advType: 1,
          name: 'X',
        ),
        throwsArgumentError,
      );
    });

    test('rejects name >31 UTF-8 bytes', () {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final session = MeshCoreSession(t);
      expect(
        () => session.addUpdateContact(
          pubKey: pubKey,
          advType: 1,
          name: 'a' * 32,
        ),
        throwsArgumentError,
      );
    });

    test('rejects out-of-range latitude / longitude', () {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final session = MeshCoreSession(t);
      expect(
        () => session.addUpdateContact(
          pubKey: pubKey,
          advType: 1,
          name: 'X',
          latitude: 91.0,
          longitude: 0,
        ),
        throwsArgumentError,
      );
      expect(
        () => session.addUpdateContact(
          pubKey: pubKey,
          advType: 1,
          name: 'X',
          latitude: 0,
          longitude: -181.0,
        ),
        throwsArgumentError,
      );
    });

    test('rejects pathLength outside [-1, 64]', () {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final session = MeshCoreSession(t);
      expect(
        () => session.addUpdateContact(
          pubKey: pubKey,
          advType: 1,
          name: 'X',
          pathLength: -2,
        ),
        throwsArgumentError,
      );
      expect(
        () => session.addUpdateContact(
          pubKey: pubKey,
          advType: 1,
          name: 'X',
          pathLength: 65,
        ),
        throwsArgumentError,
      );
    });

    test(
      'returns false on RESP_CODE_ERR (no ACK = no local mutation)',
      () async {
        final t = _FakeTransport();
        addTearDown(t.dispose);
        final session = MeshCoreSession(t);
        final fut = session.addUpdateContact(
          pubKey: pubKey,
          advType: 1,
          name: 'X',
          timeout: const Duration(milliseconds: 50),
        );
        // Do not feed any ACK; helper should time out.
        final ok = await fut;
        expect(ok, isFalse);
      },
    );
  });

  group('D29 removeContact (0x0F)', () {
    test('emits [0x0F][pubkey 32B] = 33 wire bytes total', () async {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final wire = await _capture(
        transport: t,
        op: (s) => s.removeContact(pubKey),
      );
      expect(wire.length, 33);
      expect(wire[0], 0x0F);
      expect(wire.sublist(1, 33), pubKey);
    });

    test('rejects pubkey of wrong length', () {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final session = MeshCoreSession(t);
      expect(() => session.removeContact(Uint8List(16)), throwsArgumentError);
      expect(() => session.removeContact(Uint8List(33)), throwsArgumentError);
    });

    test('returns false on timeout (firmware did not ACK)', () async {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final session = MeshCoreSession(t);
      final ok = await session.removeContact(
        pubKey,
        timeout: const Duration(milliseconds: 50),
      );
      expect(ok, isFalse);
    });
  });

  group('D29 resetPath (0x0D)', () {
    test('emits [0x0D][pubkey 32B] = 33 wire bytes total', () async {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final wire = await _capture(transport: t, op: (s) => s.resetPath(pubKey));
      expect(wire.length, 33);
      expect(wire[0], 0x0D);
      expect(wire.sublist(1, 33), pubKey);
    });

    test('rejects pubkey of wrong length', () {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final session = MeshCoreSession(t);
      expect(() => session.resetPath(Uint8List(0)), throwsArgumentError);
    });

    test('returns false on timeout', () async {
      final t = _FakeTransport();
      addTearDown(t.dispose);
      final session = MeshCoreSession(t);
      final ok = await session.resetPath(
        pubKey,
        timeout: const Duration(milliseconds: 50),
      );
      expect(ok, isFalse);
    });
  });
}
