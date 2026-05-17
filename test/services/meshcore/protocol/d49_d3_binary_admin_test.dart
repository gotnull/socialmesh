// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-D3: byte-vector pins for the three optional admin binary-RPC
// wrappers (`requestRepeaterStatus / KeepAlive / AccessList`). Each
// wrapper is a thin layer over D36-A's `sendBinaryRequest`; the
// pins assert:
//   - The outbound wire is `[CMD_SEND_BINARY_REQ 0x32][32 B pubkey]
//     [REQ_TYPE_BYTE]`.
//   - The single byte after the pubkey is the correct
//     `MeshCoreBinaryReqType.{getStatus|keepAlive|getAccessList}`.
//   - A matching `PUSH_CODE_BINARY_RESPONSE 0x8C` returns the body
//     bytes verbatim.
//   - REQ_TYPE constants are pinned to their upstream wire values
//     (0x01 / 0x02 / 0x05) so a future refactor cannot silently
//     mis-derive the wire payload.

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
    Uint8List.fromList(List.generate(32, (i) => seed + i));

Uint8List _sentPayload({required int tag}) {
  final body = Uint8List(9);
  final bd = ByteData.sublistView(body);
  body[0] = 0; // route_type
  bd.setUint32(1, tag, Endian.little);
  bd.setUint32(5, 1500, Endian.little); // est_timeout_ms
  return body;
}

Uint8List _pushPayload({required int tag, required Uint8List responseData}) {
  final body = Uint8List(5 + responseData.length);
  body[0] = 0; // reserved
  final bd = ByteData.sublistView(body);
  bd.setUint32(1, tag, Endian.little);
  body.setRange(5, 5 + responseData.length, responseData);
  return body;
}

Future<Uint8List?> _runOpAndDispatch({
  required Future<Uint8List?> Function() trigger,
  required _RecordingTransport tx,
  required int tag,
  required Uint8List responseData,
}) async {
  final fut = trigger();
  // Allow the outbound to flush.
  await Future<void>.delayed(Duration.zero);
  // Inject the RESP_CODE_SENT ACK so the helper can extract the
  // correlation tag, then the matching PUSH_CODE_BINARY_RESPONSE.
  tx.inject(
    MeshCoreFrame(
      command: MeshCoreResponses.sent,
      payload: _sentPayload(tag: tag),
    ).toBytes(),
  );
  await Future<void>.delayed(Duration.zero);
  tx.inject(
    MeshCoreFrame(
      command: MeshCorePushCodes.binaryResponse,
      payload: _pushPayload(tag: tag, responseData: responseData),
    ).toBytes(),
  );
  return fut;
}

void main() {
  group('D49-D3: REQ_TYPE constants pinned to upstream wire values', () {
    test('getStatus is 0x01', () {
      expect(MeshCoreBinaryReqType.getStatus, 0x01);
    });

    test('keepAlive is 0x02', () {
      expect(MeshCoreBinaryReqType.keepAlive, 0x02);
    });

    test('getAccessList is 0x05', () {
      expect(MeshCoreBinaryReqType.getAccessList, 0x05);
    });
  });

  group('D49-D3: requestRepeaterStatus', () {
    test(
      'outbound wire is [0x32][32 B pubkey][0x01] and response routes back',
      () async {
        final tx = _RecordingTransport();
        addTearDown(tx.dispose);
        final session = MeshCoreSession(tx);
        addTearDown(session.dispose);

        const tag = 0xCAFEBABE;
        final pubKey = _pubkey(7);
        final expectedBody = Uint8List.fromList([0xAA, 0xBB, 0xCC]);

        final result = await _runOpAndDispatch(
          trigger: () => session.requestRepeaterStatus(recipientPubKey: pubKey),
          tx: tx,
          tag: tag,
          responseData: expectedBody,
        );

        expect(result, equals(expectedBody));
        final outbound = MeshCoreFrame.fromBytes(tx.sent.first);
        expect(outbound.command, MeshCoreCommands.sendBinaryReq);
        expect(outbound.payload.length, 32 + 1);
        expect(outbound.payload.sublist(0, 32), equals(pubKey));
        expect(outbound.payload[32], MeshCoreBinaryReqType.getStatus);
      },
    );
  });

  group('D49-D3: requestRepeaterKeepAlive', () {
    test('outbound wire is [0x32][32 B pubkey][0x02]', () async {
      final tx = _RecordingTransport();
      addTearDown(tx.dispose);
      final session = MeshCoreSession(tx);
      addTearDown(session.dispose);

      const tag = 0x12345678;
      final pubKey = _pubkey(13);
      final expectedBody = Uint8List.fromList([0x01]); // ACK byte

      final result = await _runOpAndDispatch(
        trigger: () =>
            session.requestRepeaterKeepAlive(recipientPubKey: pubKey),
        tx: tx,
        tag: tag,
        responseData: expectedBody,
      );

      expect(result, equals(expectedBody));
      final outbound = MeshCoreFrame.fromBytes(tx.sent.first);
      expect(outbound.payload[32], MeshCoreBinaryReqType.keepAlive);
    });
  });

  group('D49-D3: requestRepeaterAccessList', () {
    test(
      'outbound wire is [0x32][32 B pubkey][0x05] and response routes back',
      () async {
        final tx = _RecordingTransport();
        addTearDown(tx.dispose);
        final session = MeshCoreSession(tx);
        addTearDown(session.dispose);

        const tag = 0xFEEDFACE;
        final pubKey = _pubkey(21);
        // Synthetic access list: 3 rows, each 32 bytes.
        final expectedBody = Uint8List.fromList(
          List.generate(96, (i) => i & 0xFF),
        );

        final result = await _runOpAndDispatch(
          trigger: () =>
              session.requestRepeaterAccessList(recipientPubKey: pubKey),
          tx: tx,
          tag: tag,
          responseData: expectedBody,
        );

        expect(result, equals(expectedBody));
        final outbound = MeshCoreFrame.fromBytes(tx.sent.first);
        expect(outbound.payload[32], MeshCoreBinaryReqType.getAccessList);
      },
    );
  });

  group('D49-D3: single-flight shared across the trio', () {
    test(
      'second wrapper call before the first completes returns null',
      () async {
        final tx = _RecordingTransport();
        addTearDown(tx.dispose);
        final session = MeshCoreSession(tx);
        addTearDown(session.dispose);

        final pubKey = _pubkey(3);
        // Start one without injecting any response; it will sit
        // waiting for PUSH_CODE_BINARY_RESPONSE.
        final first = session.requestRepeaterStatus(
          recipientPubKey: pubKey,
          timeout: const Duration(milliseconds: 50),
        );
        await Future<void>.delayed(Duration.zero);

        // Second one fires while first is in-flight. The shared
        // `_binaryRequestInFlight` single-flight flag in
        // `sendBinaryRequest` returns null without sending bytes.
        final secondResult = await session.requestRepeaterKeepAlive(
          recipientPubKey: pubKey,
        );
        expect(secondResult, isNull);
        expect(
          tx.sent.length,
          1,
          reason:
              'Second wrapper must NOT hit the wire while a first '
              'binary-RPC is still in flight.',
        );

        // Let the first call time out so the session settles.
        final firstResult = await first;
        expect(firstResult, isNull);
      },
    );
  });
}
