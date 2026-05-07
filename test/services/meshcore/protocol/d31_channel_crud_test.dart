// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// D31 Part A: byte-vector tests for `MeshCoreSession.setChannel` and
// `MeshCoreSession.removeChannel`. Pins the wire format the
// companion-radio firmware reads so a future refactor cannot
// reintroduce the pre-D31 off-by-one (name region padded to 33 instead
// of 32) which silently corrupted every PSK ever written through this
// path.
//
// Wire format (after the cmd byte the codec strips):
//   [idx:u8][name:32 bytes (null-padded)][psk:16 bytes] = 49 bytes
//
// Firmware references:
//   - cmd opcode: CMD_SET_CHANNEL = 32 (0x20) — verified against the
//     pinned SHA in `meshcore_protocol/pin.yml`.
//   - response: RESP_CODE_OK (0x00) on accept; RESP_CODE_ERR (0x01)
//     with ERR_CODE_NOT_FOUND on bad slot.
//   - delete semantics: no dedicated CMD; effective delete = SET with
//     empty name + all-zero PSK so `MeshCoreChannelInfo.isEmpty`
//     considers the slot unconfigured.

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

  Future<void> dispose() async {
    await _rx.close();
  }
}

void main() {
  group('MeshCoreSession.setChannel wire format (D31 Part A)', () {
    test(
      'encodes [idx][name:32 null-padded][psk:16] — total 50 bytes incl cmd',
      () async {
        final transport = _RecordingTransport();
        final session = MeshCoreSession(transport);

        Future.microtask(() => transport.simulateOk());

        // Distinct PSK so a 1-byte shift would be unmissable.
        final psk = Uint8List.fromList([
          0x10,
          0x11,
          0x12,
          0x13,
          0x14,
          0x15,
          0x16,
          0x17,
          0x18,
          0x19,
          0x1A,
          0x1B,
          0x1C,
          0x1D,
          0x1E,
          0x1F,
        ]);

        final ok = await session.setChannel(index: 3, name: 'Test', psk: psk);

        expect(ok, isTrue);
        expect(transport.sent, hasLength(1));
        final wire = transport.sent.single;

        // Total frame = cmd(1) + idx(1) + name(32) + psk(16) = 50 bytes.
        // Pre-D31 this was 51 because the name region was padded to 33.
        expect(
          wire.length,
          50,
          reason:
              'Wire frame must be exactly 50 bytes (D31 fix); '
              'pre-D31 the name region was off-by-one, padded to 33, '
              'producing 51 bytes and silently shifting the PSK by 1 '
              'on the firmware side.',
        );
        expect(wire[0], MeshCoreCommands.setChannel, reason: 'cmd byte 0x20');
        expect(wire[1], 3, reason: 'idx byte = slot index');

        // Name region: bytes 2..33 (32 bytes). "Test" + 28 zero pads.
        final nameRegion = wire.sublist(2, 34);
        expect(nameRegion.length, 32);
        expect(nameRegion[0], 0x54, reason: '"T"');
        expect(nameRegion[1], 0x65, reason: '"e"');
        expect(nameRegion[2], 0x73, reason: '"s"');
        expect(nameRegion[3], 0x74, reason: '"t"');
        for (int i = 4; i < 32; i++) {
          expect(nameRegion[i], 0, reason: 'name pad byte $i must be zero');
        }

        // PSK region: bytes 34..49 (16 bytes). Must equal supplied PSK
        // BYTE-FOR-BYTE — pre-D31 this was off-by-one (psk[0] became 0
        // and psk[15] was dropped).
        final pskRegion = wire.sublist(34, 50);
        expect(pskRegion, equals(psk));

        await session.dispose();
        await transport.dispose();
      },
    );

    test('encodes 32-byte name with no null pad', () async {
      // Boundary: name fills the entire 32-byte region. There is no
      // 33rd "trailing null" — firmware reads the buffer as a 32-char
      // C-string with implicit termination by length.
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);

      Future.microtask(() => transport.simulateOk());

      // 32 ASCII characters exactly.
      const name = 'abcdefghijklmnopqrstuvwxyz012345';
      expect(name.length, 32);

      final psk = Uint8List(16);
      await session.setChannel(index: 0, name: name, psk: psk);

      expect(transport.sent.single.length, 50);
      final nameRegion = transport.sent.single.sublist(2, 34);
      expect(nameRegion, equals(Uint8List.fromList(name.codeUnits)));

      await session.dispose();
      await transport.dispose();
    });

    test('encodes empty name as 32 zero bytes', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);

      Future.microtask(() => transport.simulateOk());

      final psk = Uint8List.fromList(List.generate(16, (i) => 0xAA));
      await session.setChannel(index: 7, name: '', psk: psk);

      final wire = transport.sent.single;
      expect(wire.length, 50);
      expect(wire[1], 7);
      // Name region is 32 zero bytes.
      for (int i = 2; i < 34; i++) {
        expect(wire[i], 0);
      }
      // PSK starts at offset 34, not 35 — the off-by-one regression
      // would surface here as wire[34] == 0 and wire[35] == 0xAA.
      expect(wire[34], 0xAA);
      expect(wire[49], 0xAA);

      await session.dispose();
      await transport.dispose();
    });

    test('rejects PSK that is not exactly 16 bytes', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);

      // Firmware also has a 32-byte branch but returns
      // ERR_CODE_UNSUPPORTED_CMD at the pinned SHA — block at the
      // wrapper rather than waste an airtime round-trip.
      expect(
        () => session.setChannel(index: 0, name: 'x', psk: Uint8List(15)),
        throwsArgumentError,
      );
      expect(
        () => session.setChannel(index: 0, name: 'x', psk: Uint8List(32)),
        throwsArgumentError,
      );

      await session.dispose();
      await transport.dispose();
    });

    test('rejects out-of-range slot index', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);

      // Index is u8 on the wire — anything beyond 255 cannot be encoded.
      // Negative indices are also nonsensical.
      expect(
        () => session.setChannel(index: -1, name: 'x', psk: Uint8List(16)),
        throwsArgumentError,
      );
      expect(
        () => session.setChannel(index: 256, name: 'x', psk: Uint8List(16)),
        throwsArgumentError,
      );

      await session.dispose();
      await transport.dispose();
    });

    test('returns false on timeout (no OK frame from firmware)', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);

      final ok = await session.setChannel(
        index: 0,
        name: 'never-acked',
        psk: Uint8List(16),
        timeout: const Duration(milliseconds: 80),
      );
      expect(ok, isFalse);

      await session.dispose();
      await transport.dispose();
    });
  });

  group('MeshCoreSession.removeChannel wire format (D31 Part A)', () {
    test(
      'encodes as setChannel(idx, "", zeros) — 50-byte empty frame',
      () async {
        // Pin the convention: removeChannel must produce exactly the
        // same byte vector as setChannel with empty name + zero PSK.
        // Firmware has no dedicated delete opcode at the pinned SHA;
        // this encoding is what makes `MeshCoreChannelInfo.isEmpty`
        // hide the slot from `getChannels` afterwards.
        final transport = _RecordingTransport();
        final session = MeshCoreSession(transport);

        Future.microtask(() => transport.simulateOk());

        final ok = await session.removeChannel(index: 5);
        expect(ok, isTrue);

        final wire = transport.sent.single;
        expect(wire.length, 50);
        expect(wire[0], MeshCoreCommands.setChannel);
        expect(wire[1], 5);
        // Bytes 2..49 must all be zero (empty name + zero PSK).
        for (int i = 2; i < 50; i++) {
          expect(wire[i], 0, reason: 'byte $i must be zero on remove');
        }

        await session.dispose();
        await transport.dispose();
      },
    );

    test('rejects out-of-range slot index', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);

      expect(() => session.removeChannel(index: -1), throwsArgumentError);
      expect(() => session.removeChannel(index: 256), throwsArgumentError);

      await session.dispose();
      await transport.dispose();
    });

    test('returns false on timeout', () async {
      final transport = _RecordingTransport();
      final session = MeshCoreSession(transport);

      final ok = await session.removeChannel(
        index: 0,
        timeout: const Duration(milliseconds: 80),
      );
      expect(ok, isFalse);

      await session.dispose();
      await transport.dispose();
    });
  });
}
