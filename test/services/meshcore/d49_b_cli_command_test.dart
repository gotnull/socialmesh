// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-B: `MeshCoreSession.sendCliCommand` pins.
//
// Pinned invariants:
//
// TX byte vector:
//   - outbound bytes are
//     `[0x02][0x01][attempt:u8][ts:u32 LE][pubkey[0..5]:6 B]
//      [prefixToken:3 B][command utf-8...][0x00]`.
//   - multi-byte command UTF-8 encodes verbatim.
//
// RX correlation:
//   - 0x07 with matching sender prefix + matching token prefix
//     resolves with token-stripped text.
//   - 0x10 v3 (3 leading header bytes) with matching sender prefix
//     + matching token prefix resolves with token-stripped text.
//   - mismatched sender prefix is ignored => timeout.
//   - mismatched token is ignored => timeout.
//   - missing token (plain inbound DM from same repeater) is
//     ignored => timeout.
//
// Outcome states:
//   - timeout => MeshCoreCliResult.firmwareTimeout().
//   - rate-limiter rejection => MeshCoreCliResult.rateLimited().
//
// Argument validation:
//   - non-32-byte pubKey throws ArgumentError.
//   - prefixToken format ('5G|' / '12' / 'ABC' / '01' / 'AAA')
//     throws ArgumentError.
//   - attempt outside [0, 255] throws ArgumentError.

import 'dart:async';
import 'dart:convert';
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

final _repeaterPubKey = Uint8List.fromList(
  List<int>.generate(32, (i) => 0x10 + i),
);

// Build the inbound text-frame envelope the firmware would emit for a
// routed CLI reply. v3 (0x10) prefixes 3 reserved header bytes
// (snr/res/res); v1 (0x07) starts at the 6-byte sender prefix.
Uint8List _inboundCliReplyFrame({
  required Uint8List pubKey,
  required String text,
  bool v3 = false,
}) {
  final textBytes = utf8.encode(text);
  final headerBytes = v3 ? 3 : 0;
  final payload = Uint8List(headerBytes + 6 + 1 + 1 + 4 + textBytes.length + 1);
  var off = headerBytes;
  for (var i = 0; i < 6; i++) {
    payload[off++] = pubKey[i];
  }
  off++; // path_len
  payload[off++] = MeshCoreTextTypes.cliData; // txt_type
  off += 4; // timestamp (zeroed)
  for (var i = 0; i < textBytes.length; i++) {
    payload[off++] = textBytes[i];
  }
  payload[off] = 0; // C-string NUL
  return MeshCoreFrame(
    command: v3
        ? MeshCoreResponses.contactMsgRecvV3
        : MeshCoreResponses.contactMsgRecv,
    payload: payload,
  ).toBytes();
}

void main() {
  group('CMD_SEND_TXT_MSG 0x02 + TXT_TYPE_CLI_DATA - D49-B', () {
    test('outbound bytes match the companion-radio CLI wire shape', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.sendCliCommand(
        pubKey: _repeaterPubKey,
        command: 'ver',
        prefixToken: '01|',
        attempt: 0,
        timestampSeconds: 0x12345678,
        timeout: const Duration(milliseconds: 100),
      );
      await Future<void>.delayed(Duration.zero);

      expect(tx.sent, hasLength(1));
      final sent = MeshCoreFrame.fromBytes(tx.sent.single);
      expect(sent.command, MeshCoreCommands.sendTxtMsg);

      // payload layout pins:
      // [0]=0x01 (cliData), [1]=attempt, [2..6]=ts LE, [6..12]=prefix,
      // [12..15]=token, [15..18]='ver', [18]=0x00.
      final p = sent.payload;
      expect(p[0], MeshCoreTextTypes.cliData);
      expect(p[1], 0);
      expect(p.sublist(2, 6), equals([0x78, 0x56, 0x34, 0x12]));
      expect(p.sublist(6, 12), equals(_repeaterPubKey.sublist(0, 6)));
      expect(p.sublist(12, 15), equals(utf8.encode('01|')));
      expect(p.sublist(15, 18), equals(utf8.encode('ver')));
      expect(p.last, 0);

      await fut; // timeout
    });

    test('multi-byte UTF-8 command encodes verbatim', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.sendCliCommand(
        pubKey: _repeaterPubKey,
        command: 'set name TerryDev-é',
        prefixToken: 'A0|',
        timestampSeconds: 0,
        timeout: const Duration(milliseconds: 50),
      );
      await Future<void>.delayed(Duration.zero);

      final sent = MeshCoreFrame.fromBytes(tx.sent.single);
      // Last byte is NUL; the bytes preceding NUL after the 12-byte
      // header + 3-char token = command bytes.
      final cmdBytes = sent.payload.sublist(15, sent.payload.length - 1);
      expect(cmdBytes, equals(utf8.encode('set name TerryDev-é')));
      await fut;
    });

    test(
      '0x07 routed reply with matching prefix + token resolves ok',
      () async {
        final tx = _RecordingTransport();
        addTearDown(tx.dispose);
        final session = MeshCoreSession(tx);
        addTearDown(session.dispose);

        final fut = session.sendCliCommand(
          pubKey: _repeaterPubKey,
          command: 'ver',
          prefixToken: '02|',
          timestampSeconds: 0,
        );
        await Future<void>.delayed(Duration.zero);
        tx.inject(
          _inboundCliReplyFrame(
            pubKey: _repeaterPubKey,
            text: '02|MeshCore Repeater v1.7.0',
          ),
        );

        final result = await fut;
        expect(result.ok, isTrue);
        expect(result.response, 'MeshCore Repeater v1.7.0');
      },
    );

    test(
      '0x10 v3 routed reply with matching prefix + token resolves ok',
      () async {
        final tx = _RecordingTransport();
        addTearDown(tx.dispose);
        final session = MeshCoreSession(tx);
        addTearDown(session.dispose);

        final fut = session.sendCliCommand(
          pubKey: _repeaterPubKey,
          command: 'ver',
          prefixToken: '03|',
          timestampSeconds: 0,
        );
        await Future<void>.delayed(Duration.zero);
        tx.inject(
          _inboundCliReplyFrame(
            pubKey: _repeaterPubKey,
            text: '03|v3-envelope-reply',
            v3: true,
          ),
        );

        final result = await fut;
        expect(result.ok, isTrue);
        expect(result.response, 'v3-envelope-reply');
      },
    );

    test('mismatched sender prefix is ignored => firmwareTimeout', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final otherPubKey = Uint8List.fromList(
        List<int>.generate(32, (i) => 0xA0 + i),
      );
      final fut = session.sendCliCommand(
        pubKey: _repeaterPubKey,
        command: 'ver',
        prefixToken: '04|',
        timestampSeconds: 0,
        timeout: const Duration(milliseconds: 100),
      );
      await Future<void>.delayed(Duration.zero);
      // Reply from a DIFFERENT repeater carrying the same token.
      tx.inject(
        _inboundCliReplyFrame(pubKey: otherPubKey, text: '04|ghost reply'),
      );

      final result = await fut;
      expect(result.firmwareTimeout, isTrue);
    });

    test('mismatched token is ignored => firmwareTimeout', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final fut = session.sendCliCommand(
        pubKey: _repeaterPubKey,
        command: 'ver',
        prefixToken: '05|',
        timestampSeconds: 0,
        timeout: const Duration(milliseconds: 100),
      );
      await Future<void>.delayed(Duration.zero);
      tx.inject(
        _inboundCliReplyFrame(pubKey: _repeaterPubKey, text: '99|wrong token'),
      );

      final result = await fut;
      expect(result.firmwareTimeout, isTrue);
    });

    test(
      'missing token (plain DM from same repeater) is ignored => timeout',
      () async {
        final tx = _RecordingTransport();
        addTearDown(tx.dispose);
        final session = MeshCoreSession(tx);
        addTearDown(session.dispose);

        final fut = session.sendCliCommand(
          pubKey: _repeaterPubKey,
          command: 'ver',
          prefixToken: '06|',
          timestampSeconds: 0,
          timeout: const Duration(milliseconds: 100),
        );
        await Future<void>.delayed(Duration.zero);
        tx.inject(
          _inboundCliReplyFrame(
            pubKey: _repeaterPubKey,
            text: 'hello human, no token here',
          ),
        );

        final result = await fut;
        expect(result.firmwareTimeout, isTrue);
      },
    );

    test('timeout with no reply => firmwareTimeout', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      final result = await session.sendCliCommand(
        pubKey: _repeaterPubKey,
        command: 'ver',
        prefixToken: '07|',
        timestampSeconds: 0,
        timeout: const Duration(milliseconds: 50),
      );
      expect(result.firmwareTimeout, isTrue);
    });

    test('rejects non-32-byte pubKey with ArgumentError', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      expect(
        () => session.sendCliCommand(
          pubKey: Uint8List(8),
          command: 'ver',
          prefixToken: '08|',
        ),
        throwsArgumentError,
      );
    });

    test('rejects malformed prefixToken with ArgumentError', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      const bad = <String>['5G|', '12', 'ABC', '01', 'AAA', 'a1|', '1|'];
      for (final token in bad) {
        expect(
          () => session.sendCliCommand(
            pubKey: _repeaterPubKey,
            command: 'ver',
            prefixToken: token,
          ),
          throwsArgumentError,
          reason: 'token "$token" should be rejected',
        );
      }
    });

    test('rejects out-of-range attempt with ArgumentError', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      expect(
        () => session.sendCliCommand(
          pubKey: _repeaterPubKey,
          command: 'ver',
          prefixToken: '09|',
          attempt: -1,
        ),
        throwsArgumentError,
      );
      expect(
        () => session.sendCliCommand(
          pubKey: _repeaterPubKey,
          command: 'ver',
          prefixToken: '09|',
          attempt: 256,
        ),
        throwsArgumentError,
      );
    });

    test('rate limiter rejection short-circuits without sending', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      // Drain the 1024 B / 60 s default budget with mid-size frames.
      // Each frame charges (payload + 1) bytes; payload = 12 header +
      // 3 token + 100 text + 1 NUL = 116, charge = 117.
      // 1024 / 117 ~= 9, so the 9th send should hit the limit. Stay
      // under the 172-byte frame cap.
      final filler = 'x' * 100;
      var rejected = false;
      for (var i = 0; i < 16; i++) {
        final hex = i.toRadixString(16).padLeft(2, '0').toUpperCase();
        final result = await session.sendCliCommand(
          pubKey: _repeaterPubKey,
          command: filler,
          prefixToken: '$hex|',
          timestampSeconds: 0,
          timeout: const Duration(milliseconds: 10),
        );
        if (result.rateLimited) {
          rejected = true;
          expect(result.remainingBytes, isNotNull);
          expect(result.nextSendIn, isNotNull);
          break;
        }
      }
      expect(
        rejected,
        isTrue,
        reason: 'rate limiter must reject within 16 mid-size CLI sends',
      );
    });
  });
}
