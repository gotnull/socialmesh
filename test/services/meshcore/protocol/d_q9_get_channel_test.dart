// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q9 Row 28: byte-vector pins for `MeshCoreSession.getChannel(int)`.
//
// Pinned invariants:
//   - Outbound wire is exactly `[CMD_GET_CHANNEL 0x1F][slot:u8]`.
//   - A matching `respCodeChannelInfo 0x12` frame parses back to
//     the expected `MeshCoreChannelInfo`.
//   - Out-of-range slot indices throw `ArgumentError` BEFORE
//     anything hits the wire.
//   - A null / empty / unparseable response returns null (caller
//     treats as "no channel configured at that slot").

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

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    sent.add(Uint8List.fromList(data));
  }

  @override
  bool get isConnected => true;

  void inject(Uint8List bytes) {
    _rx.add(bytes);
  }

  Future<void> dispose() async {
    await _rx.close();
  }
}

/// Build a synthetic CHANNEL_INFO frame for slot [slot], name [name],
/// and PSK [psk]. Wire shape is `[0x12][slot:u8][name:32 null-padded]
/// [psk:16]`.
Uint8List _channelInfoPayload({
  required int slot,
  required String name,
  required Uint8List psk,
}) {
  if (psk.length != 16) {
    throw ArgumentError('psk must be 16 bytes');
  }
  final nameBytes = Uint8List(32);
  final encoded = name.codeUnits;
  for (var i = 0; i < encoded.length && i < 32; i++) {
    nameBytes[i] = encoded[i];
  }
  return Uint8List.fromList([slot, ...nameBytes, ...psk]);
}

void main() {
  group('D-Q9 Row 28: getChannel single-slot fetch', () {
    test('outbound wire is exactly [0x1F][slot]', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final psk = Uint8List.fromList(List.generate(16, (i) => 0xA0 + i));
      final fut = session.getChannel(
        3,
        timeout: const Duration(milliseconds: 200),
      );
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.channelInfo,
          payload: _channelInfoPayload(slot: 3, name: 'CH3', psk: psk),
        ).toBytes(),
      );
      final channel = await fut;

      expect(tx.sent, hasLength(1));
      final wire = tx.sent.single;
      // Total frame = cmd(1) + slot(1) = 2 bytes.
      expect(wire, equals(Uint8List.fromList([0x1F, 0x03])));
      expect(channel, isNotNull);
      expect(channel!.index, 3);
      expect(channel.name, 'CH3');
      expect(channel.psk, equals(psk));
    });

    test(
      'out-of-range slot (-1) throws ArgumentError before any wire send',
      () async {
        final tx = _RecordingTransport();
        addTearDown(tx.dispose);
        final session = MeshCoreSession(tx);
        addTearDown(session.dispose);

        expect(() => session.getChannel(-1), throwsArgumentError);
        expect(tx.sent, isEmpty);
      },
    );

    test(
      'out-of-range slot (8) throws ArgumentError before any wire send',
      () async {
        final tx = _RecordingTransport();
        addTearDown(tx.dispose);
        final session = MeshCoreSession(tx);
        addTearDown(session.dispose);

        expect(() => session.getChannel(8), throwsArgumentError);
        expect(tx.sent, isEmpty);
      },
    );

    test('null response (timeout) returns null', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final channel = await session.getChannel(
        0,
        timeout: const Duration(milliseconds: 50),
      );
      expect(channel, isNull);
    });

    test('empty-channel response returns null (slot unconfigured)', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.getChannel(
        7,
        timeout: const Duration(milliseconds: 200),
      );
      await Future<void>.delayed(Duration.zero);
      // Empty channel: name is all-zero bytes, PSK is all-zero
      // bytes. The parser flags this as `isEmpty == true`, and
      // getChannel surfaces it as null.
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.channelInfo,
          payload: _channelInfoPayload(slot: 7, name: '', psk: Uint8List(16)),
        ).toBytes(),
      );
      final channel = await fut;
      expect(channel, isNull);
    });

    test('boundary: slot 0 is accepted', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final psk = Uint8List.fromList(List.filled(16, 0x42));
      final fut = session.getChannel(
        0,
        timeout: const Duration(milliseconds: 200),
      );
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.channelInfo,
          payload: _channelInfoPayload(slot: 0, name: 'Public', psk: psk),
        ).toBytes(),
      );
      final channel = await fut;
      expect(channel, isNotNull);
      expect(channel!.index, 0);
      expect(channel.name, 'Public');
    });

    test('boundary: slot 7 is accepted', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final psk = Uint8List.fromList(List.filled(16, 0x77));
      final fut = session.getChannel(
        7,
        timeout: const Duration(milliseconds: 200),
      );
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        MeshCoreFrame(
          command: MeshCoreResponses.channelInfo,
          payload: _channelInfoPayload(slot: 7, name: 'Last', psk: psk),
        ).toBytes(),
      );
      final channel = await fut;
      expect(channel, isNotNull);
      expect(channel!.index, 7);
    });
  });
}
