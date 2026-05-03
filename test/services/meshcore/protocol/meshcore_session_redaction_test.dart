// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// D4 regression: kDebugMode TX/RX dump in MeshCoreSession used to print
// the full payload hex for every frame. This leaked message plaintext,
// public keys, and channel PSKs into developer log captures (xcrun
// simctl log stream / Console.app). The fix denylists payload-bearing
// command/response codes whose body is user-secret material; sensitive
// codes redact `payload=` (and TX `raw=`), non-sensitive ones still get
// their full debug dump for protocol debugging utility.
//
// These tests verify:
//   1. The denylists cover the obvious sensitive codes.
//   2. Driving a sendChannelTxtMsg through the session causes a TX
//      debugPrint that does NOT contain the message plaintext hex.
//   3. Driving a non-sensitive command (getBattAndStorage) still emits
//      a full payload preview — sanity check we didn't over-redact.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';

class _FakeTransport implements MeshCoreTransport {
  final StreamController<Uint8List> _rx =
      StreamController<Uint8List>.broadcast();
  final List<Uint8List> sent = [];

  @override
  Stream<Uint8List> get rawRxStream => _rx.stream;

  @override
  Future<void> sendRaw(Uint8List data) async {
    sent.add(data);
  }

  @override
  bool get isConnected => true;

  Future<void> dispose() async {
    await _rx.close();
  }
}

/// Capture every debugPrint message to a string buffer for the duration
/// of [body]. Restores the original handler on exit.
Future<List<String>> captureDebugPrints(Future<void> Function() body) async {
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
  group('D4 — sensitive payload denylists', () {
    test('TX denylist contains all known body/identity-bearing commands', () {
      // Spot-check: regressions here mean a new sensitive code was added
      // to MeshCoreCommands without joining the denylist.
      expect(
        MeshCoreSession.sensitiveTxPayloadCodes,
        containsAll(<int>{
          MeshCoreCommands.sendTxtMsg,
          MeshCoreCommands.sendChannelTxtMsg,
          MeshCoreCommands.addUpdateContact,
          MeshCoreCommands.shareContact,
          MeshCoreCommands.exportContact,
          MeshCoreCommands.importContact,
          MeshCoreCommands.getContactByKey,
          MeshCoreCommands.setChannel,
        }),
      );
    });

    test('RX denylist contains all known body/identity-bearing responses', () {
      expect(
        MeshCoreSession.sensitiveRxPayloadCodes,
        containsAll(<int>{
          MeshCoreResponses.contact,
          MeshCoreResponses.selfInfo,
          MeshCoreResponses.contactMsgRecv,
          MeshCoreResponses.channelMsgRecv,
          MeshCoreResponses.contactMsgRecvV3,
          MeshCoreResponses.channelMsgRecvV3,
          MeshCoreResponses.channelInfo,
        }),
      );
    });

    test(
      'safe commands are NOT on the denylist (sanity — we did not over-redact)',
      () {
        expect(
          MeshCoreSession.sensitiveTxPayloadCodes,
          isNot(contains(MeshCoreCommands.getBattAndStorage)),
        );
        expect(
          MeshCoreSession.sensitiveTxPayloadCodes,
          isNot(contains(MeshCoreCommands.deviceQuery)),
        );
        expect(
          MeshCoreSession.sensitiveTxPayloadCodes,
          isNot(contains(MeshCoreCommands.appStart)),
        );
        expect(
          MeshCoreSession.sensitiveRxPayloadCodes,
          isNot(contains(MeshCoreResponses.battAndStorage)),
        );
      },
    );
  });

  group('D4 — runtime redaction in kDebugMode TX/RX dump', () {
    test(
      'sendChannelTxtMsg TX dump never contains the message plaintext hex',
      () async {
        final transport = _FakeTransport();
        final session = MeshCoreSession(transport);
        const plaintext = 'sim->channel #1';

        // Build the same payload shape ProtocolService emits for channel
        // text: [channel:1][senderTimestamp:6][text+null]
        final builder = BytesBuilder();
        builder.addByte(0); // channel slot
        builder.add(Uint8List(6)); // sender + timestamp
        builder.add(Uint8List.fromList(plaintext.codeUnits));
        builder.addByte(0); // null terminator
        final payload = builder.toBytes();

        final captured = await captureDebugPrints(() async {
          await session.sendFrame(
            MeshCoreFrame(
              command: MeshCoreCommands.sendChannelTxtMsg,
              payload: payload,
            ),
          );
        });

        // Build the hex form that the OLD code would have leaked.
        final plaintextHex = plaintext.codeUnits
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();

        final txLines = captured
            .where((l) => l.contains('MeshCore TX:'))
            .toList();
        expect(
          txLines,
          isNotEmpty,
          reason: 'TX dump must still emit code+len for protocol debugging',
        );
        for (final line in txLines) {
          expect(
            line.toLowerCase().contains(plaintextHex.toLowerCase()),
            isFalse,
            reason: 'TX dump leaked plaintext hex: $line',
          );
          expect(
            line.contains(plaintext),
            isFalse,
            reason: 'TX dump leaked plaintext literal: $line',
          );
          expect(
            line.contains('payload=<redacted>'),
            isTrue,
            reason: 'TX dump must mark sensitive payload redacted: $line',
          );
        }

        await session.dispose();
        await transport.dispose();
      },
    );

    test('getBattAndStorage TX dump still emits full payload preview '
        '(no over-redaction)', () async {
      final transport = _FakeTransport();
      final session = MeshCoreSession(transport);

      final captured = await captureDebugPrints(() async {
        // getBattAndStorage is a 1-byte command (no payload) — we just
        // want to verify it does NOT get redacted.
        await session.sendFrame(
          MeshCoreFrame.simple(MeshCoreCommands.getBattAndStorage),
        );
      });

      final txLines = captured
          .where((l) => l.contains('MeshCore TX:'))
          .toList();
      expect(txLines, isNotEmpty);
      for (final line in txLines) {
        expect(
          line.contains('payload=<redacted>'),
          isFalse,
          reason: 'getBattAndStorage must NOT be redacted: $line',
        );
      }

      await session.dispose();
      await transport.dispose();
    });

    test('selfInfo RX dump never contains the device public key hex', () async {
      final transport = _FakeTransport();
      final session = MeshCoreSession(transport);

      // Canonical selfInfo response payload shape:
      // [type:1][role:1][txPower:1][pk:32][...padding...][nodeName]
      // Build a fake pk that's clearly identifiable.
      final fakePk = Uint8List.fromList(List.generate(32, (i) => 0xa0 + i));
      final builder = BytesBuilder();
      builder.addByte(0x01); // type
      builder.addByte(0x16); // role
      builder.addByte(0x16); // txPower
      builder.add(fakePk); // 32-byte pk
      // pad to >=35 bytes minimum — selfInfo parser requires it
      builder.add(Uint8List(48));
      final payload = builder.toBytes();

      final captured = await captureDebugPrints(() async {
        transport._rx.add(
          MeshCoreFrame(
            command: MeshCoreResponses.selfInfo,
            payload: payload,
          ).toBytes(),
        );
        // give the codec async pump time to flush
        await Future<void>.delayed(Duration.zero);
      });

      final pkHex = fakePk
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

      final rxLines = captured
          .where((l) => l.contains('MeshCore RX decoded:'))
          .toList();
      expect(
        rxLines,
        isNotEmpty,
        reason: 'RX dump must still emit code+len for protocol debugging',
      );
      for (final line in rxLines) {
        expect(
          line.toLowerCase().contains(pkHex.toLowerCase()),
          isFalse,
          reason: 'RX dump leaked full public key: $line',
        );
        expect(
          line.contains('payload=<redacted>'),
          isTrue,
          reason: 'selfInfo RX must be redacted: $line',
        );
      }

      await session.dispose();
      await transport.dispose();
    });
  });
}
