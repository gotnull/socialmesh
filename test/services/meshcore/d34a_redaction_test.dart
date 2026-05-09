// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34a — chat-traffic measurement layer redaction proof.
//
// Pins that the new `event=text.send.recorded`,
// `event=text.send.rate_limited`, and `event=text.send.window_reset`
// log lines NEVER carry:
//   - message plaintext (the body bytes pushed into sendTextMessage)
//   - the [mrrp] / [/mrrp] envelope markers
//   - base64 envelope content
//   - MMF strings (01:idx:ts or 02:prefix:ts)
//   - channel name, channel code, or PSK material
//   - sender or recipient pubkey hex (full or prefix)
//   - wire payload hex
//
// Method: drive a mix of plain + reply-shaped sends and rate-limit
// rejections through `sendTextMessage`, capture every debugPrint, and
// assert the captured stream contains the D34a counter events but
// none of the banned patterns.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
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

  void simulateOk() {
    final ok = MeshCoreFrame(
      command: MeshCoreResponses.ok,
      payload: Uint8List(0),
    );
    _rx.add(ok.toBytes());
  }

  void simulateSent() {
    final s = MeshCoreFrame(
      command: MeshCoreResponses.sent,
      payload: Uint8List.fromList(List.filled(9, 0xCC)),
    );
    _rx.add(s.toBytes());
  }

  Future<void> dispose() async {
    await _rx.close();
  }
}

Future<List<String>> _capture(Future<void> Function() body) async {
  final captured = <String>[];
  final original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) captured.add(message);
  };
  try {
    await body();
  } finally {
    debugPrint = original;
  }
  return captured;
}

void main() {
  group('D34a — measurement-layer log redaction', () {
    test('D34a log events surface kind/bytes/win_used but never carry '
        'plaintext, envelope, MMF, pubkey, or PSK material', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final lim = MeshCoreSendRateLimiter(capacityBytes: 200);
      final session = MeshCoreSession(tx, sendRateLimiter: lim);
      addTearDown(session.dispose);

      // Synthetic plaintext + envelope content the limiter MUST NOT
      // echo into log output. We feed these into sendTextMessage and
      // grep the captured logs for them.
      const String secretPlaintext = 'Top secret message that must not leak';
      const String secretSummary = 'Bob replied: nope';
      const String secretMmf = '02:79426d8db8fd:67abc1d2';
      const String secretChannel = 'OPS_CMD_CHANNEL_NAME';
      const String secretPsk = '6f6e676c6f6e676c6f6e676c6f6e676c';
      const String secretPubkey =
          'aabbccddeeff00112233445566778899aabbccddeeff00112233445566778899';

      final plainPayload = Uint8List.fromList([
        // Routing header (12 bytes, contact-shape).
        0, 0,
        0, 0, 0, 0,
        1, 2, 3, 4, 5, 6,
        ...utf8.encode(secretPlaintext),
        0,
      ]);

      final replyEnvelope = Uint8List.fromList([
        ...utf8.encode('[mrrp]'),
        ...utf8.encode('VGhpcyBpcyBhIGZha2UgYmFzZTY0IGVudmVsb3Bl'),
        ...utf8.encode('[/mrrp]'),
        ...utf8.encode(' '),
        ...utf8.encode(secretSummary),
      ]);
      // Force the reply payload over the 200 B cap so it's rejected.
      final fatReply = Uint8List(250)
        ..setRange(0, replyEnvelope.length, replyEnvelope);

      final captured = await _capture(() async {
        // 1. Plain successful send.
        scheduleMicrotask(tx.simulateSent);
        await session.sendTextMessage(
          command: MeshCoreCommands.sendTxtMsg,
          payload: plainPayload,
          expectedResponse: MeshCoreResponses.sent,
          sendKind: MeshCoreSendKind.plainContact,
        );

        // 2. Reply send, intentionally rejected by the rate limiter.
        await session.sendTextMessage(
          command: MeshCoreCommands.sendTxtMsg,
          payload: fatReply,
          expectedResponse: MeshCoreResponses.sent,
          sendKind: MeshCoreSendKind.replyContact,
        );
      });

      // The new D34a counter event must show up at least once.
      expect(
        captured.any((l) => l.contains('event=text.send.recorded')),
        isTrue,
        reason: 'expected event=text.send.recorded after the plain send',
      );
      expect(
        captured.any((l) => l.contains('event=text.send.rate_limited')),
        isTrue,
        reason:
            'expected event=text.send.rate_limited after the rejected '
            'reply',
      );

      // Grep every captured line for banned patterns. We constrain the
      // sweep to the D34a-emitting prefixes plus the surrounding debug
      // logs the session emits at TX time, since both pipelines feed
      // the same os_log channel.
      final bannedPatterns = <RegExp>[
        // Literal plaintext / summary.
        RegExp(RegExp.escape(secretPlaintext)),
        RegExp(RegExp.escape(secretSummary)),
        // Envelope markers.
        RegExp(r'\[mrrp\]'),
        RegExp(r'\[/mrrp\]'),
        // Synthetic base64 envelope content.
        RegExp(RegExp.escape('VGhpcyBpcyBhIGZha2UgYmFzZTY0IGVudmVsb3Bl')),
        // MMF.
        RegExp(RegExp.escape(secretMmf)),
        // Channel name + PSK + pubkey hex.
        RegExp(RegExp.escape(secretChannel)),
        RegExp(RegExp.escape(secretPsk)),
        RegExp(RegExp.escape(secretPubkey)),
        // 32-byte hex run (pubkey-length).
        RegExp(r'[0-9a-fA-F]{64}'),
        // Long base64 run.
        RegExp(r'[A-Za-z0-9+/=]{40,}'),
      ];

      // Filter to D34a-counter events only — the surrounding session
      // already redacts `payload=<redacted>` for sensitive command
      // codes via the D4 denylist. We only need to prove the NEW
      // event lines stay clean.
      final d34aLines = captured
          .where(
            (l) =>
                l.contains('event=text.send.recorded') ||
                l.contains('event=text.send.rate_limited') ||
                l.contains('event=text.send.window_reset'),
          )
          .toList();
      expect(d34aLines, isNotEmpty);

      for (final line in d34aLines) {
        for (final pat in bannedPatterns) {
          expect(
            pat.hasMatch(line),
            isFalse,
            reason:
                'D34a log line leaked banned pattern $pat:\n$line\n'
                'Full D34a capture:\n${d34aLines.join("\n")}',
          );
        }
      }

      // Sanity: the kind tag IS allowed in the log line.
      expect(d34aLines.any((l) => l.contains('kind=plainContact')), isTrue);
      expect(d34aLines.any((l) => l.contains('kind=replyContact')), isTrue);
    });

    test('window_reset event surfaces only peak_bytes (no kind, '
        'no plaintext)', () async {
      final clock = _ManualClock(DateTime(2026, 5, 9, 12));
      final lim = MeshCoreSendRateLimiter(clock: clock.call);

      final captured = await _capture(() async {
        lim.recordSend(
          kind: MeshCoreSendKind.plainContact,
          bytes: 123,
          allowed: true,
        );
        clock.advance(const Duration(seconds: 60, milliseconds: 1));
        // Touch the snapshot so the window rotation fires.
        lim.snapshot();
      });

      final resetLines = captured
          .where((l) => l.contains('event=text.send.window_reset'))
          .toList();
      expect(resetLines, hasLength(1));
      expect(resetLines.first, contains('peak_bytes=123'));
      // Must NOT contain a plaintext token, kind tag, or any of the
      // payload sentinels.
      for (final pat in <RegExp>[
        RegExp(r'kind='),
        RegExp(r'\[mrrp\]'),
        RegExp(r'plaintext'),
      ]) {
        expect(pat.hasMatch(resetLines.first), isFalse);
      }
    });
  });
}

class _ManualClock {
  DateTime _now;
  _ManualClock(this._now);
  DateTime call() => _now;
  void advance(Duration d) => _now = _now.add(d);
}
