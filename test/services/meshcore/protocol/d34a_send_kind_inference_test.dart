// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34a — `MeshCoreSession.sendTextMessage` send-kind attribution.
//
// Pins:
//   - explicit `sendKind` is honoured verbatim (no inference).
//   - omitted `sendKind`: payload starting with `[mrrp]` infers reply.
//   - omitted `sendKind`: any other payload infers plain.
//   - omitted `sendKind`: contact/channel resolves from the command
//     code (sendTxtMsg vs sendChannelTxtMsg).
//   - rejected sends still attribute by kind to the rejected counter
//     and DO NOT bump the sent counter.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/services/meshcore/meshcore_send_rate_limiter.dart';
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

  void simulateSent() {
    final sent = MeshCoreFrame(
      command: MeshCoreResponses.sent,
      payload: Uint8List.fromList(List.filled(9, 0xCC)),
    );
    _rx.add(sent.toBytes());
  }

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

Uint8List _routedPlainContact() {
  // Contact send payload: [txt_type:1][attempt:1][ts:4][peerPrefix:6]
  // [text...][\0]. The text starts at offset 12; prefix sniff on the
  // raw payload sees a routing byte, NOT '[mrrp]'.
  return Uint8List.fromList([
    0x00, 0x00, // txt_type, attempt
    0x00, 0x00, 0x00, 0x00, // timestamp
    0x01, 0x02, 0x03, 0x04, 0x05, 0x06, // peer prefix (6 bytes)
    0x68, 0x69, // 'h', 'i'
    0x00,
  ]);
}

Uint8List _payloadStartingWithMrrp() {
  // Synthetic payload literally beginning with the [mrrp] marker.
  // Real wire payloads NEVER start this way (the routing header is
  // non-printable). This synthetic shape exercises the literal-
  // startsWith inference branch.
  return Uint8List.fromList([
    0x5B, 0x6D, 0x72, 0x72, 0x70, 0x5D, // [mrrp]
    0x68, 0x69,
    0x00,
  ]);
}

Future<void> _drive(
  Future<void> Function() send,
  _RecordingTransport tx,
  int command,
) async {
  // Kick the firmware response into the rx stream after the limiter
  // accepts the send. Use the response code matching the command.
  scheduleMicrotask(() {
    if (command == MeshCoreCommands.sendTxtMsg) {
      tx.simulateSent();
    } else {
      tx.simulateOk();
    }
  });
  await send();
}

void main() {
  group('D34a — sendTextMessage send-kind attribution', () {
    test('explicit sendKind is honoured even when payload looks like a '
        'reply', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final lim = MeshCoreSendRateLimiter();
      final session = MeshCoreSession(tx, sendRateLimiter: lim);

      await _drive(
        () => session.sendTextMessage(
          command: MeshCoreCommands.sendTxtMsg,
          payload: _payloadStartingWithMrrp(),
          expectedResponse: MeshCoreResponses.sent,
          sendKind: MeshCoreSendKind.plainContact,
        ),
        tx,
        MeshCoreCommands.sendTxtMsg,
      );

      final s = lim.snapshot();
      expect(s.sendCountByKind[MeshCoreSendKind.plainContact], 1);
      expect(s.sendCountByKind[MeshCoreSendKind.replyContact], 0);

      session.dispose();
    });

    test('omitted sendKind + payload starting with [mrrp] + sendTxtMsg '
        '→ replyContact', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final lim = MeshCoreSendRateLimiter();
      final session = MeshCoreSession(tx, sendRateLimiter: lim);

      await _drive(
        () => session.sendTextMessage(
          command: MeshCoreCommands.sendTxtMsg,
          payload: _payloadStartingWithMrrp(),
          expectedResponse: MeshCoreResponses.sent,
        ),
        tx,
        MeshCoreCommands.sendTxtMsg,
      );

      final s = lim.snapshot();
      expect(s.sendCountByKind[MeshCoreSendKind.replyContact], 1);
      expect(s.sendCountByKind[MeshCoreSendKind.plainContact], 0);

      session.dispose();
    });

    test('omitted sendKind + payload starting with [mrrp] + '
        'sendChannelTxtMsg → replyChannel', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final lim = MeshCoreSendRateLimiter();
      final session = MeshCoreSession(tx, sendRateLimiter: lim);

      await _drive(
        () => session.sendTextMessage(
          command: MeshCoreCommands.sendChannelTxtMsg,
          payload: _payloadStartingWithMrrp(),
          expectedResponse: MeshCoreResponses.ok,
        ),
        tx,
        MeshCoreCommands.sendChannelTxtMsg,
      );

      final s = lim.snapshot();
      expect(s.sendCountByKind[MeshCoreSendKind.replyChannel], 1);

      session.dispose();
    });

    test(
      'omitted sendKind + non-mrrp payload + sendTxtMsg → plainContact',
      () async {
        final tx = _RecordingTransport();
        addTearDown(tx.dispose);
        final lim = MeshCoreSendRateLimiter();
        final session = MeshCoreSession(tx, sendRateLimiter: lim);

        await _drive(
          () => session.sendTextMessage(
            command: MeshCoreCommands.sendTxtMsg,
            payload: _routedPlainContact(),
            expectedResponse: MeshCoreResponses.sent,
          ),
          tx,
          MeshCoreCommands.sendTxtMsg,
        );

        final s = lim.snapshot();
        expect(s.sendCountByKind[MeshCoreSendKind.plainContact], 1);
        expect(s.sendCountByKind[MeshCoreSendKind.replyContact], 0);

        session.dispose();
      },
    );

    test('omitted sendKind + non-mrrp payload + sendChannelTxtMsg → '
        'plainChannel', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final lim = MeshCoreSendRateLimiter();
      final session = MeshCoreSession(tx, sendRateLimiter: lim);

      await _drive(
        () => session.sendTextMessage(
          command: MeshCoreCommands.sendChannelTxtMsg,
          payload: _routedPlainContact(),
          expectedResponse: MeshCoreResponses.ok,
        ),
        tx,
        MeshCoreCommands.sendChannelTxtMsg,
      );

      final s = lim.snapshot();
      expect(s.sendCountByKind[MeshCoreSendKind.plainChannel], 1);

      session.dispose();
    });

    test('rate-limited send with explicit replyContact attributes the '
        'rejection to replyContact (not the inferred kind)', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      // Capacity 64 so a 100-byte payload+cmd cannot fit.
      final lim = MeshCoreSendRateLimiter(capacityBytes: 64);
      final session = MeshCoreSession(tx, sendRateLimiter: lim);

      // 100 bytes + 1 cmd = 101 > 64 → rejected.
      final big = Uint8List(100);
      final result = await session.sendTextMessage(
        command: MeshCoreCommands.sendTxtMsg,
        payload: big,
        expectedResponse: MeshCoreResponses.sent,
        sendKind: MeshCoreSendKind.replyContact,
      );
      expect(result.rateLimited, isTrue);
      expect(tx.sent, isEmpty, reason: 'rejected sends never hit the wire');

      final s = lim.snapshot();
      expect(s.rejectedCountByKind[MeshCoreSendKind.replyContact], 1);
      expect(s.currentWindowSentBytes, 0);
      expect(s.currentWindowRejectedBytes, 101);
      expect(s.lastRejection, isNotNull);

      session.dispose();
    });
  });
}
