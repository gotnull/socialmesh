// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/tak/geochat_bridge.dart';
import 'package:socialmesh/services/tak/tak_client_session.dart';

class FakeSecureSocket extends Fake implements SecureSocket {
  @override
  InternetAddress get remoteAddress => InternetAddress.loopbackIPv4;

  @override
  int get remotePort => 12345;
}

class FakeClientSession extends Fake implements TakClientSession {
  @override
  final String uid;

  @override
  final String callsign;

  @override
  String get remoteAddress => '127.0.0.1:12345';

  FakeClientSession({this.uid = 'ANDROID-1234', this.callsign = 'ALPHA1'});
}

void main() {
  late GeoChatBridge bridge;
  late List<(String, int, int?)> sentMessages;

  setUp(() {
    sentMessages = [];
    bridge = GeoChatBridge(
      meshSend: (text, {int channelIndex = 0, int? destination}) async {
        sentMessages.add((text, channelIndex, destination));
        return sentMessages.length; // Return a fake message ID.
      },
    );
  });

  group('GeoChatBridge', () {
    group('parseGeoChatCot', () {
      test('parses valid GeoChat CoT', () {
        final cot = GeoChatBridge.buildGeoChatCot(
          fromNodeNum: 0xABCDEF01,
          callsign: 'BRAVO1',
          text: 'Rally at checkpoint 3',
        );

        final parsed = GeoChatBridge.parseGeoChatCot(cot);
        expect(parsed, isNotNull);
        expect(parsed!.senderCallsign, 'BRAVO1');
        expect(parsed.text, 'Rally at checkpoint 3');
        expect(parsed.senderUid, 'MESHTASTIC-ABCDEF01');
      });

      test('returns null for non-GeoChat event', () {
        const pliCot =
            '<event version="2.0" type="a-f-G-U-C" uid="test"><point lat="0" lon="0" hae="0" ce="0" le="0"/><detail/></event>';
        expect(GeoChatBridge.parseGeoChatCot(pliCot), isNull);
      });

      test('returns null for invalid XML', () {
        expect(GeoChatBridge.parseGeoChatCot('not xml'), isNull);
      });

      test('returns null for GeoChat without text', () {
        const emptyCot =
            '<event version="2.0" type="b-t-f" uid="GeoChat.a.b.c"><point lat="0" lon="0" hae="0" ce="0" le="0"/><detail><__chat senderCallsign="X"/><remarks/></detail></event>';
        expect(GeoChatBridge.parseGeoChatCot(emptyCot), isNull);
      });
    });

    group('buildGeoChatCot', () {
      test('produces valid GeoChat XML', () {
        final xml = GeoChatBridge.buildGeoChatCot(
          fromNodeNum: 0x12345678,
          callsign: 'DELTA',
          text: 'Hello mesh',
        );

        expect(xml, contains('b-t-f'));
        expect(xml, contains('MESHTASTIC-12345678'));
        expect(xml, contains('Hello mesh'));
        expect(xml, contains('DELTA'));
        expect(xml, contains('<__chat'));
        expect(xml, contains('<remarks'));
      });

      test('directed GeoChat includes recipient UID', () {
        final xml = GeoChatBridge.buildGeoChatCot(
          fromNodeNum: 0x11111111,
          callsign: 'ALPHA',
          text: 'DM test',
          toUid: 'ANDROID-ABCD',
        );

        expect(xml, contains('ANDROID-ABCD'));
      });
    });

    group('buildReceiptCot', () {
      test('produces receipt CoT with type b-t-f-r', () {
        final xml = GeoChatBridge.buildReceiptCot(
          originalMessageUid: 'msg-123',
          senderUid: 'ANDROID-1234',
        );

        expect(xml, contains('b-t-f-r'));
        expect(xml, contains('msg-123'));
      });
    });

    group('handleTakGeoChat', () {
      test('forwards GeoChat to mesh', () async {
        final cotXml = GeoChatBridge.buildGeoChatCot(
          fromNodeNum: 0xDEADBEEF,
          callsign: 'SENDER',
          text: 'Test message',
        );

        final session = FakeClientSession();
        final msgId = await bridge.handleTakGeoChat(
          session: session,
          cotXml: cotXml,
        );

        expect(msgId, isNotNull);
        expect(sentMessages, hasLength(1));
        expect(sentMessages.first.$1, contains('Test message'));
        expect(sentMessages.first.$2, 0); // channel 0
      });

      test('returns null for non-GeoChat CoT', () async {
        final session = FakeClientSession();
        final result = await bridge.handleTakGeoChat(
          session: session,
          cotXml:
              '<event version="2.0" type="a-f-G-U-C" uid="x"><point lat="0" lon="0" hae="0" ce="0" le="0"/><detail/></event>',
        );
        expect(result, isNull);
      });

      test('rate limits per client', () async {
        final session = FakeClientSession(uid: 'RATE-TEST');
        final cotXml = GeoChatBridge.buildGeoChatCot(
          fromNodeNum: 0x11111111,
          callsign: 'RL',
          text: 'msg',
        );

        // First 2 should succeed (maxOutboundPerWindow = 2).
        for (var i = 0; i < GeoChatBridge.maxOutboundPerWindow; i++) {
          final result = await bridge.handleTakGeoChat(
            session: session,
            cotXml: cotXml,
          );
          expect(result, isNotNull);
        }

        // Third should be rate-limited.
        final result = await bridge.handleTakGeoChat(
          session: session,
          cotXml: cotXml,
        );
        expect(result, isNull);
      });

      test('directed GeoChat resolves MESHTASTIC-hex UID', () async {
        bridge = GeoChatBridge(
          meshSend: (text, {int channelIndex = 0, int? destination}) async {
            sentMessages.add((text, channelIndex, destination));
            return sentMessages.length;
          },
          callsignResolver: (uid) => null,
        );

        final cotXml = GeoChatBridge.buildGeoChatCot(
          fromNodeNum: 0xAAAAAAAA,
          callsign: 'DM-TEST',
          text: 'Direct message',
          toUid: 'MESHTASTIC-BBBBBBBB',
        );

        final session = FakeClientSession();
        await bridge.handleTakGeoChat(session: session, cotXml: cotXml);

        expect(sentMessages, hasLength(1));
        // Destination should be resolved from MESHTASTIC-BBBBBBBB.
        expect(sentMessages.first.$3, 0xBBBBBBBB);
      });
    });

    group('handleMeshText', () {
      test('converts mesh text to GeoChat CoT', () {
        final cot = bridge.handleMeshText(
          fromNodeNum: 0x1A2B3C4D,
          callsign: 'BRAVO-2',
          text: 'Copy, moving to CP3',
        );

        expect(cot, isNotNull);
        expect(cot, contains('b-t-f'));
        expect(cot, contains('BRAVO-2'));
        expect(cot, contains('Copy, moving to CP3'));
        expect(cot, contains('MESHTASTIC-1A2B3C4D'));
      });

      test('returns null for empty text', () {
        final cot = bridge.handleMeshText(
          fromNodeNum: 0x11111111,
          callsign: 'EMPTY',
          text: '',
        );
        expect(cot, isNull);
      });
    });

    group('handleMeshAck', () {
      test('generates receipt for tracked message', () async {
        final session = FakeClientSession(uid: 'ACK-TEST');
        final cotXml = GeoChatBridge.buildGeoChatCot(
          fromNodeNum: 0xDEADDEAD,
          callsign: 'ACK',
          text: 'Ack test',
        );

        final msgId = await bridge.handleTakGeoChat(
          session: session,
          cotXml: cotXml,
        );
        expect(msgId, isNotNull);

        final receipt = bridge.handleMeshAck(msgId!);
        expect(receipt, isNotNull);
        expect(receipt!.cotXml, contains('b-t-f-r'));
        expect(receipt.clientUid, 'ACK-TEST');
      });

      test('returns null for untracked message', () {
        expect(bridge.handleMeshAck(999999), isNull);
      });
    });
  });
}
