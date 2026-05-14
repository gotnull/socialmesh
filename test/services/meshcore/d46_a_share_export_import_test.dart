// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D46-A: `MeshCoreSession.shareSelfContact` / `exportContact` /
// `importContact` integration pins.
//
// Pinned invariants:
//   - shareSelfContact wire payload is `[0x10][pubKey:32B]` (33 B);
//     RESP_CODE_OK → true; RESP_CODE_ERR / timeout → false.
//   - exportContact wire payload is `[0x11][pubKey:32B]` (33 B);
//     RESP_CODE_EXPORT_CONTACT (0x0B) + 135..147-byte frame → returns
//     bytes; short / malformed frame → null; timeout → null.
//   - importContact wire payload is `[0x12][frame:N]` where N in
//     [135,147]; RESP_CODE_OK → true; RESP_CODE_ERR / timeout →
//     false. Out-of-range frame throws ArgumentError BEFORE bytes
//     hit the wire.
//   - wrong-length pubkey on share/export throws ArgumentError
//     before bytes hit the wire.

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

Uint8List _pubkey(int seed) =>
    Uint8List.fromList(List.generate(32, (i) => (seed + i) & 0xFF));

Uint8List _contactFrame(int len, {int seed = 0}) {
  if (len < 135 || len > 147) {
    throw ArgumentError('test helper: invalid frame length');
  }
  return Uint8List.fromList(List.generate(len, (i) => (seed + i) & 0xFF));
}

void main() {
  group('D46-A: shareSelfContact', () {
    test('wire payload is [0x10][pubKey:32B]; RESP_CODE_OK → true', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final pk = _pubkey(0x10);
      final fut = session.shareSelfContact(pk);
      await Future<void>.delayed(Duration.zero);

      expect(tx.sent, hasLength(1));
      final sent = MeshCoreFrame.fromBytes(tx.sent.single);
      expect(sent.command, MeshCoreCommands.shareContact);
      expect(sent.payload.length, 32);
      expect(sent.payload, equals(pk));

      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.ok,
          payload: Uint8List(0),
        ).toBytes(),
      );
      expect(await fut, isTrue);
    });

    test('RESP_CODE_ERR returns false', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.shareSelfContact(
        _pubkey(0x20),
        timeout: const Duration(milliseconds: 200),
      );
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.err,
          payload: Uint8List(0),
        ).toBytes(),
      );
      expect(await fut, isFalse);
    });

    test('timeout returns false', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final ok = await session.shareSelfContact(
        _pubkey(0x30),
        timeout: const Duration(milliseconds: 200),
      );
      expect(ok, isFalse);
    });

    test('wrong-length pubkey throws ArgumentError before send', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      expect(
        () => session.shareSelfContact(Uint8List(16)),
        throwsArgumentError,
      );
      expect(tx.sent, isEmpty);
    });
  });

  group('D46-A: exportContact', () {
    test(
      'wire payload is [0x11][pubKey:32B]; RESP_CODE_EXPORT_CONTACT + 135-byte '
      'frame → returns bytes',
      () async {
        final tx = _RecordingTransport();
        addTearDown(tx.dispose);
        final session = MeshCoreSession(tx);
        addTearDown(session.dispose);

        final pk = _pubkey(0x40);
        final fut = session.exportContact(pk);
        await Future<void>.delayed(Duration.zero);

        expect(tx.sent, hasLength(1));
        final sent = MeshCoreFrame.fromBytes(tx.sent.single);
        expect(sent.command, MeshCoreCommands.exportContact);
        expect(sent.payload, equals(pk));

        final frame = _contactFrame(135, seed: 7);
        tx.inject(
          MeshCoreFrame(
            command: MeshCoreResponses.exportContact,
            payload: frame,
          ).toBytes(),
        );
        final out = await fut;
        expect(out, equals(frame));
      },
    );

    test('147-byte frame accepted', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.exportContact(_pubkey(0x50));
      await Future<void>.delayed(Duration.zero);
      final frame = _contactFrame(147);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.exportContact,
          payload: frame,
        ).toBytes(),
      );
      expect(await fut, equals(frame));
    });

    test('short frame (< 135B) returns null defensively', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.exportContact(_pubkey(0x60));
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.exportContact,
          payload: Uint8List(100),
        ).toBytes(),
      );
      expect(await fut, isNull);
    });

    test('over-long frame (> 147B) returns null defensively', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.exportContact(_pubkey(0x61));
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.exportContact,
          payload: Uint8List(200),
        ).toBytes(),
      );
      expect(await fut, isNull);
    });

    test('timeout returns null', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final out = await session.exportContact(
        _pubkey(0x70),
        timeout: const Duration(milliseconds: 200),
      );
      expect(out, isNull);
    });

    test('wrong-length pubkey throws ArgumentError before send', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      expect(() => session.exportContact(Uint8List(31)), throwsArgumentError);
      expect(tx.sent, isEmpty);
    });
  });

  group('D46-A: importContact', () {
    test('wire payload is [0x12][frame:N]; RESP_CODE_OK → true', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final frame = _contactFrame(135, seed: 11);
      final fut = session.importContact(frame);
      await Future<void>.delayed(Duration.zero);

      expect(tx.sent, hasLength(1));
      final sent = MeshCoreFrame.fromBytes(tx.sent.single);
      expect(sent.command, MeshCoreCommands.importContact);
      expect(sent.payload, equals(frame));

      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.ok,
          payload: Uint8List(0),
        ).toBytes(),
      );
      expect(await fut, isTrue);
    });

    test('RESP_CODE_ERR returns false', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.importContact(
        _contactFrame(135),
        timeout: const Duration(milliseconds: 200),
      );
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.err,
          payload: Uint8List(0),
        ).toBytes(),
      );
      expect(await fut, isFalse);
    });

    test('timeout returns false', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final ok = await session.importContact(
        _contactFrame(135),
        timeout: const Duration(milliseconds: 200),
      );
      expect(ok, isFalse);
    });

    test('out-of-range frame throws ArgumentError before send', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      expect(() => session.importContact(Uint8List(134)), throwsArgumentError);
      expect(() => session.importContact(Uint8List(148)), throwsArgumentError);
      expect(tx.sent, isEmpty);
    });
  });
}
