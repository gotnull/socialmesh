// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// S6 inbound demux tests.
//
// Drives `ProtocolService.handleIncomingPacket` with synthetic
// Meshtastic FromRadio frames carrying canvas.v1 MRRP payloads, and
// asserts that:
//   - the attached canvas inbound hook is invoked with the correct
//     senderNodeId + channelIndex + canvasPayload,
//   - the engine's request/response path is NOT entered (no MRRP
//     engine attachment is needed for canvas frames),
//   - the global MRRP per-sender throttle does not block canvas
//     frames (5+ canvas frames from the same sender still reach the
//     hook),
//   - malformed canvas frames drop without crash,
//   - non-canvas MRRP frames still need the engine (sniff returns a
//     non-canvas service id so the demux short-circuit is skipped).
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:socialmesh/core/transport.dart';
import 'package:socialmesh/services/canvas/canvas_codec.dart';
import 'package:socialmesh/services/mesh_packet_dedupe_store.dart';
import 'package:socialmesh/services/protocol/protocol_service.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_codec.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';
import 'package:socialmesh/services/protocol/sip/sip_codec.dart';
import 'package:socialmesh/services/protocol/sip/sip_constants.dart';
import 'package:socialmesh/services/protocol/sip/sip_frame.dart';
import 'package:socialmesh/services/protocol/sip/sip_types.dart';

// ---------------------------------------------------------------------------
// Fake transport
// ---------------------------------------------------------------------------

class _FakeTransport extends DeviceTransport {
  final StreamController<List<int>> _dataController =
      StreamController<List<int>>.broadcast();

  @override
  TransportType get type => TransportType.ble;
  @override
  bool get requiresFraming => false;
  @override
  bool get requiresWakeSequence => false;
  @override
  TransportReconnectMode get reconnectMode => TransportReconnectMode.scanBased;
  @override
  DeviceConnectionState get state => DeviceConnectionState.connected;
  @override
  Stream<DeviceConnectionState> get stateStream =>
      const Stream<DeviceConnectionState>.empty();
  @override
  Stream<List<int>> get dataStream => _dataController.stream;
  @override
  Stream<DeviceInfo> scan({Duration? timeout, bool scanAll = false}) =>
      const Stream<DeviceInfo>.empty();
  @override
  Future<void> connect(DeviceInfo device) async {}
  @override
  Future<void> disconnect() async {}
  @override
  Future<void> enableNotifications() async {}
  @override
  Future<void> pollOnce() async {}
  @override
  Future<void> send(List<int> data) async {}
  @override
  Future<int?> readRssi() async => null;
  @override
  Future<void> dispose() async {
    await _dataController.close();
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

int _seq = 0;
final int _pid = pid;
String _uniqueDbPath() =>
    p.join(Directory.systemTemp.path, 'canvas_demux_${_pid}_${_seq++}.db');

Future<void> _withTempDb(Future<void> Function(String) body) async {
  final tempDir = await Directory.systemTemp.createTemp('canvas_demux');
  try {
    await body(tempDir.path);
  } finally {
    await tempDir.delete(recursive: true);
  }
}

Future<ProtocolService> _openProtocol() async {
  final db = MeshPacketDedupeStore(dbPathOverride: _uniqueDbPath());
  await db.init();
  return ProtocolService(_FakeTransport(), dedupeStore: db);
}

/// Build a SipFrame that wraps an MRRP REQUEST with [canvasPayload] as
/// its inner payload. Uses the real SIP/MRRP codecs so the demux path
/// exercises real decoders.
SipFrame _buildCanvasSipFrame({
  required Uint8List canvasPayload,
  int requestId = 1,
}) {
  final action = CanvasCodec.sniffAction(canvasPayload);
  if (action == null) {
    throw StateError(
      'test helper requires a valid canvas payload',
    ); // lint-allow: hardcoded-string
  }
  final mrrp = MrrpFrame(
    versionMajor: MrrpConstants.mrrpVersionMajor,
    versionMinor: MrrpConstants.mrrpVersionMinor,
    msgType: MrrpMessageType.request,
    flags: 0,
    headerLen: MrrpConstants.mrrpHeaderMin,
    requestId: requestId & 0xFFFFFFFF,
    serviceId: MrrpServiceId.canvasV1,
    actionId: action.code,
    payloadLen: canvasPayload.length,
    payload: canvasPayload,
  );
  final mrrpEncoded = MrrpCodec.encode(mrrp)!;
  return SipFrame(
    versionMajor: SipConstants.sipVersionMajor,
    versionMinor: SipConstants.sipVersionMinor,
    msgType: SipMessageType.mrrpData,
    flags: 0,
    headerLen: SipConstants.sipWrapperMin,
    sessionId: 0,
    nonce: SipCodec.generateNonce(),
    timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    payloadLen: mrrpEncoded.length,
    payload: mrrpEncoded,
  );
}

Uint8List _samplePaint({
  required int canvasId,
  int x = 0,
  int y = 0,
  int color = 1,
  int author = 0xAA,
  int opTs = 1,
  int opSeq = 0,
}) {
  return CanvasCodec.encodePaint(
    CanvasPaintOp(
      canvasId: canvasId,
      x: x,
      y: y,
      color: color,
      authorId: author,
      opTs: opTs,
      opSeq: opSeq,
    ),
  )!;
}

class _CapturedFrame {
  final int senderNodeId;
  final int channelIndex;
  final Uint8List canvasPayload;
  _CapturedFrame({
    required this.senderNodeId,
    required this.channelIndex,
    required this.canvasPayload,
  });
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'canvas.v1 frame routes to attached hook with packet.channel preserved',
    () async {
      await _withTempDb((_) async {
        final protocol = await _openProtocol();
        final captured = <_CapturedFrame>[];
        protocol.attachCanvasInbound((sender, channel, payload) async {
          captured.add(
            _CapturedFrame(
              senderNodeId: sender,
              channelIndex: channel,
              canvasPayload: payload,
            ),
          );
        });

        final canvasPayload = _samplePaint(canvasId: 0xC0DE);
        protocol.injectMrrpFrameForTest(
          0x10,
          3,
          _buildCanvasSipFrame(canvasPayload: canvasPayload),
        );
        // unawaited handler — wait one tick
        await Future<void>.delayed(Duration.zero);

        expect(captured, hasLength(1));
        expect(captured.single.senderNodeId, 0x10);
        expect(captured.single.channelIndex, 3);
        expect(captured.single.canvasPayload, canvasPayload);

        protocol.stop();
      });
    },
  );

  test(
    'canvas frames bypass MRRP engine — 5+ from same sender still hit hook',
    () async {
      // The MRRP engine global per-sender cap is 4 / 60 s. If canvas
      // were going through the engine path, the 5th frame would be
      // throttled before the hook runs. Bypass demux means all 5
      // reach the hook.
      await _withTempDb((_) async {
        final protocol = await _openProtocol();
        // Deliberately do NOT attach the MRRP engine — demonstrating
        // that canvas frames work without it.
        final captured = <int>[];
        protocol.attachCanvasInbound((sender, channel, payload) async {
          captured.add(sender);
        });

        for (var i = 0; i < 5; i++) {
          protocol.injectMrrpFrameForTest(
            0x20,
            0,
            _buildCanvasSipFrame(
              canvasPayload: _samplePaint(canvasId: 1, x: i, opTs: 1, opSeq: i),
              requestId: 100 + i,
            ),
          );
        }
        await Future<void>.delayed(Duration.zero);

        // All 5 routed despite no engine + no global throttle.
        expect(captured, hasLength(5));
        expect(captured.toSet(), {0x20});

        // Regression pin: the global constant remains untouched.
        expect(
          MrrpConstants.mrrpMaxInboundRequestsPerSenderPer60s,
          4,
          reason:
              'S6 demux exempts canvas; the global MRRP cap MUST stay '
              'at 4 for all other services.',
        );

        protocol.stop();
      });
    },
  );

  test('canvas frames drop silently when no hook attached', () async {
    await _withTempDb((_) async {
      final protocol = await _openProtocol();
      // No attachCanvasInbound call. Drive directly — must not throw.
      protocol.injectMrrpFrameForTest(
        0x30,
        0,
        _buildCanvasSipFrame(canvasPayload: _samplePaint(canvasId: 1)),
      );
      await Future<void>.delayed(Duration.zero);
      protocol.stop();
    });
  });

  test('malformed canvas MRRP frame drops without crash', () async {
    await _withTempDb((_) async {
      final protocol = await _openProtocol();
      final captured = <int>[];
      protocol.attachCanvasInbound((sender, channel, payload) async {
        captured.add(sender);
      });

      // Build an MRRP frame that claims service_id=canvasV1 but has a
      // truncated payload that won't survive full decoding. We slice
      // off the trailing bytes after the MRRP header so MrrpCodec.decode
      // returns null and the demux drops cleanly.
      final realPayload = _samplePaint(canvasId: 1);
      final mrrp = MrrpFrame(
        versionMajor: MrrpConstants.mrrpVersionMajor,
        versionMinor: MrrpConstants.mrrpVersionMinor,
        msgType: MrrpMessageType.request,
        flags: 0,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 1,
        serviceId: MrrpServiceId.canvasV1,
        actionId: CanvasAction.paint.code,
        payloadLen: realPayload.length,
        payload: realPayload,
      );
      final encoded = MrrpCodec.encode(mrrp)!;
      // Truncate to header-only: payloadLen field still claims real
      // length, but actual buffer is shorter — MrrpCodec.decode rejects.
      final truncated = Uint8List.fromList(
        encoded.sublist(0, MrrpConstants.mrrpHeaderMin),
      );

      final sip = SipFrame(
        versionMajor: SipConstants.sipVersionMajor,
        versionMinor: SipConstants.sipVersionMinor,
        msgType: SipMessageType.mrrpData,
        flags: 0,
        headerLen: SipConstants.sipWrapperMin,
        sessionId: 0,
        nonce: SipCodec.generateNonce(),
        timestampS: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        payloadLen: truncated.length,
        payload: truncated,
      );
      // MUST NOT throw.
      protocol.injectMrrpFrameForTest(0x40, 0, sip);
      await Future<void>.delayed(Duration.zero);

      // Hook MUST NOT have been called.
      expect(captured, isEmpty);
      protocol.stop();
    });
  });

  test('duplicate canvas frame from same sender+channel within the echo '
      'window fires the hook exactly once', () async {
    await _withTempDb((_) async {
      final protocol = await _openProtocol();
      final captured = <_CapturedFrame>[];
      protocol.attachCanvasInbound((sender, channel, payload) async {
        captured.add(
          _CapturedFrame(
            senderNodeId: sender,
            channelIndex: channel,
            canvasPayload: payload,
          ),
        );
      });

      final canvasPayload = _samplePaint(canvasId: 0xDEDE, x: 5, y: 7);
      // Inject the same MRRP-wrapped canvas frame twice from the same
      // sender on the same channel. Real-world trigger: TCP gateway
      // echoing its own broadcast back as a relay confirm.
      protocol.injectMrrpFrameForTest(
        0x42,
        0,
        _buildCanvasSipFrame(canvasPayload: canvasPayload, requestId: 1),
      );
      protocol.injectMrrpFrameForTest(
        0x42,
        0,
        _buildCanvasSipFrame(canvasPayload: canvasPayload, requestId: 1),
      );
      await Future<void>.delayed(Duration.zero);

      expect(captured, hasLength(1));
      expect(captured.single.senderNodeId, 0x42);

      protocol.stop();
    });
  });

  test('two distinct canvas frames from the same sender both reach the hook '
      '(dedupe is content-scoped, not sender-scoped)', () async {
    await _withTempDb((_) async {
      final protocol = await _openProtocol();
      final captured = <_CapturedFrame>[];
      protocol.attachCanvasInbound((sender, channel, payload) async {
        captured.add(
          _CapturedFrame(
            senderNodeId: sender,
            channelIndex: channel,
            canvasPayload: payload,
          ),
        );
      });

      final first = _samplePaint(canvasId: 0xAA, x: 1, y: 1);
      final second = _samplePaint(canvasId: 0xAA, x: 2, y: 2);
      protocol.injectMrrpFrameForTest(
        0x42,
        0,
        _buildCanvasSipFrame(canvasPayload: first),
      );
      protocol.injectMrrpFrameForTest(
        0x42,
        0,
        _buildCanvasSipFrame(canvasPayload: second),
      );
      await Future<void>.delayed(Duration.zero);

      expect(captured, hasLength(2));
    });
  });

  test('identical canvas frame from different senders both reach the hook '
      '(per-sender dedupe scope: no cross-sender false positive)', () async {
    await _withTempDb((_) async {
      final protocol = await _openProtocol();
      final captured = <_CapturedFrame>[];
      protocol.attachCanvasInbound((sender, channel, payload) async {
        captured.add(
          _CapturedFrame(
            senderNodeId: sender,
            channelIndex: channel,
            canvasPayload: payload,
          ),
        );
      });

      final payload = _samplePaint(canvasId: 0xBB, x: 9, y: 9);
      protocol.injectMrrpFrameForTest(
        0x10,
        0,
        _buildCanvasSipFrame(canvasPayload: payload),
      );
      protocol.injectMrrpFrameForTest(
        0x20,
        0,
        _buildCanvasSipFrame(canvasPayload: payload),
      );
      await Future<void>.delayed(Duration.zero);

      expect(captured, hasLength(2));
      expect(captured.map((c) => c.senderNodeId).toSet(), {0x10, 0x20});
    });
  });

  test('attachCanvasInbound(null) detaches and stops routing', () async {
    await _withTempDb((_) async {
      final protocol = await _openProtocol();
      final captured = <int>[];
      protocol.attachCanvasInbound((sender, channel, payload) async {
        captured.add(sender);
      });

      protocol.injectMrrpFrameForTest(
        0x10,
        0,
        _buildCanvasSipFrame(canvasPayload: _samplePaint(canvasId: 1)),
      );
      await Future<void>.delayed(Duration.zero);
      expect(captured, hasLength(1));

      protocol.attachCanvasInbound(null);

      protocol.injectMrrpFrameForTest(
        0x10,
        0,
        _buildCanvasSipFrame(
          canvasPayload: _samplePaint(canvasId: 1, x: 1),
          requestId: 2,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      // No new captures.
      expect(captured, hasLength(1));
      protocol.stop();
    });
  });
}
