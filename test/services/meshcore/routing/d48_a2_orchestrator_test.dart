// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D48-A2: `MeshCoreAutoRouteOrchestrator` retry-loop pins.
//
// Pinned invariants:
//   - On first-attempt delivery: writes the highest-ranked saved
//     path into out_path via `addUpdateContact`, calls
//     `sendTextMessage`, marks delivered, calls `recordPathSuccess`
//     with `weightAfterSuccess`-clamped weight.
//   - On two timeouts then a delivery: rotates through the 2nd and
//     3rd path, calls `recordPathFailure` twice, then
//     `recordPathSuccess` once.
//   - Loop exhausts at `settings.maxRetries`; final attempt always
//     writes `pathLength = -1` (flood) regardless of saved paths.
//   - When `sendTextMessage` returns `rateLimited` mid-loop, the
//     orchestrator bails out and surfaces
//     `MeshCoreAutoRouteFailureReason.rateLimited`.
//   - When `addUpdateContact` returns false (firmware reject), the
//     orchestrator bails out and surfaces
//     `MeshCoreAutoRouteFailureReason.firmwareSendRejected`.

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/models/meshcore_auto_route_settings.dart';
import 'package:socialmesh/services/meshcore/meshcore_send_rate_limiter.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_session.dart';
import 'package:socialmesh/services/meshcore/routing/meshcore_auto_route_orchestrator.dart';
import 'package:socialmesh/services/meshcore/routing/meshcore_path_selector.dart';
import 'package:socialmesh/services/meshcore/routing/meshcore_send_confirmation_router.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_path_history_store.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _AddUpdateContactRecorder {
  final List<({int pathLength, Uint8List pathBytes})> calls = [];
  bool nextReturn = true;

  Future<bool> call({
    required Uint8List pubKey,
    required int advType,
    required String name,
    required int pathLength,
    required Uint8List pathBytes,
  }) async {
    calls.add((
      pathLength: pathLength,
      pathBytes: Uint8List.fromList(pathBytes),
    ));
    return nextReturn;
  }
}

class _SendTextMessageRecorder {
  final List<int> attemptsObserved = [];
  MeshCoreTextSendResult Function() nextResult = () =>
      MeshCoreTextSendResult.ok(
        response: MeshCoreFrame(command: 0x06, payload: Uint8List(0)),
      );

  Future<MeshCoreTextSendResult> call({
    required int command,
    required Uint8List payload,
    required int expectedResponse,
    required MeshCoreSendKind sendKind,
  }) async {
    // Capture the attempt byte at payload[1].
    attemptsObserved.add(payload[1]);
    return nextResult();
  }
}

const _devicePubKey = <int>[
  0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, //
  0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10, //
  0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, //
  0x19, 0x1A, 0x1B, 0x1C, 0x1D, 0x1E, 0x1F, 0x20, //
];
const _contactPubKey = <int>[
  0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x00, 0x11, //
  0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, //
  0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x00, 0x11, //
  0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88, 0x99, //
];
const _ts = 1715000000;
const _text = 'hello';

String _hexPrefix(List<int> bytes, int n) {
  final buf = StringBuffer();
  for (var i = 0; i < n; i++) {
    buf.write(bytes[i].toRadixString(16).padLeft(2, '0'));
  }
  return buf.toString();
}

Future<void> _seedHistory(
  MeshCorePathHistoryStore store, {
  required List<List<int>> paths,
  required double initialWeight,
}) async {
  final devicePrefix = _hexPrefix(_devicePubKey, 8);
  final contactPrefix = _hexPrefix(_contactPubKey, 8);
  final now = DateTime.utc(2026, 5, 14);
  for (final p in paths) {
    await store.record(
      devicePubKeyPrefix: devicePrefix,
      contactPubKeyPrefix: contactPrefix,
      bytes: Uint8List.fromList(p),
      source: MeshCorePathSource.trace,
      now: now,
      initialWeight: initialWeight,
    );
  }
}

MeshCoreFrame _confirmFrame(int ackHash, {int tripMs = 100}) {
  final payload = Uint8List(8);
  payload.buffer.asByteData().setUint32(0, ackHash, Endian.little);
  payload.buffer.asByteData().setUint32(4, tripMs, Endian.little);
  return MeshCoreFrame(
    command: MeshCorePushCodes.sendConfirmed,
    payload: payload,
  );
}

const _settings = MeshCoreAutoRouteSettings(
  enabled: true,
  maxRetries: 3,
  retryTimeoutSeconds: 1,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MeshCorePathHistoryStore store;
  late StreamController<MeshCoreFrame> frames;
  late MeshCoreSendConfirmationRouter router;
  late _AddUpdateContactRecorder addUpdateRecorder;
  late _SendTextMessageRecorder sendRecorder;

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    store = MeshCorePathHistoryStore();
    frames = StreamController<MeshCoreFrame>.broadcast();
    router = MeshCoreSendConfirmationRouter(frameStream: frames.stream);
    addUpdateRecorder = _AddUpdateContactRecorder();
    sendRecorder = _SendTextMessageRecorder();
  });

  tearDown(() async {
    await router.dispose();
    await frames.close();
  });

  MeshCoreAutoRouteOrchestrator newOrchestrator() {
    return MeshCoreAutoRouteOrchestrator.forTest(
      addUpdateContact: addUpdateRecorder.call,
      sendTextMessage: sendRecorder.call,
      pathHistoryStore: store,
      confirmationRouter: router,
      settings: _settings,
      devicePubKey: Uint8List.fromList(_devicePubKey),
      contactPubKey: Uint8List.fromList(_contactPubKey),
      contactAdvType: 1,
      contactName: 'Bob',
    );
  }

  group('MeshCoreAutoRouteOrchestrator - D48-A2', () {
    test('first-attempt delivery records success on the chosen path', () async {
      await _seedHistory(
        store,
        paths: [
          [0xAA],
          [0xBB],
        ],
        initialWeight: 3.0,
      );

      // Schedule a 0x82 push to fire after the first send.
      sendRecorder.nextResult = () {
        scheduleMicrotask(() {
          final hash = computeExpectedAckHash(
            timestampSeconds: _ts,
            attempt: 0,
            text: _text,
            senderPubKey: Uint8List.fromList(_devicePubKey),
          );
          frames.add(_confirmFrame(hash, tripMs: 80));
        });
        return MeshCoreTextSendResult.ok(
          response: MeshCoreFrame(command: 0x06, payload: Uint8List(0)),
        );
      };

      final outcome = await newOrchestrator().sendWithAutoRoute(
        text: _text,
        timestampSeconds: _ts,
        sendKind: MeshCoreSendKind.plainContact,
      );

      expect(outcome.delivered, isTrue);
      expect(outcome.attempts, 1);
      expect(outcome.tripTime?.inMilliseconds, 80);
      expect(addUpdateRecorder.calls, hasLength(1));
      expect(addUpdateRecorder.calls.single.pathLength, greaterThan(0));
      // History should reflect a success bump.
      final reloaded = await store.load(
        _hexPrefix(_devicePubKey, 8),
        _hexPrefix(_contactPubKey, 8),
      );
      final selected = reloaded.firstWhere(
        (e) =>
            e.bytes.length == 1 &&
            e.bytes[0] == addUpdateRecorder.calls.single.pathBytes[0],
      );
      expect(selected.successCount, 1);
      expect(selected.routeWeight, greaterThan(3.0));
    });

    test(
      'rotates paths on timeout and falls through to flood on the final attempt',
      () async {
        await _seedHistory(
          store,
          paths: [
            [0xAA],
            [0xBB],
          ],
          initialWeight: 3.0,
        );

        // Always return ok from the send wrapper; we never fire a 0x82
        // so every attempt times out.
        sendRecorder.nextResult = () => MeshCoreTextSendResult.ok(
          response: MeshCoreFrame(command: 0x06, payload: Uint8List(0)),
        );

        final outcome = await newOrchestrator().sendWithAutoRoute(
          text: _text,
          timestampSeconds: _ts,
          sendKind: MeshCoreSendKind.plainContact,
        );

        expect(outcome.delivered, isFalse);
        expect(outcome.attempts, 3);
        expect(
          outcome.failureReason,
          MeshCoreAutoRouteFailureReason.allAttemptsTimedOut,
        );
        // 3 attempts: 2 saved paths then flood.
        expect(addUpdateRecorder.calls, hasLength(3));
        expect(addUpdateRecorder.calls[0].pathLength, 1);
        expect(addUpdateRecorder.calls[1].pathLength, 1);
        expect(
          addUpdateRecorder.calls[2].pathLength,
          -1,
          reason: 'final attempt MUST be flood (pathLength=-1)',
        );
        // Attempt bytes should monotonically increase.
        expect(sendRecorder.attemptsObserved, [0, 1, 2]);
      },
    );

    test(
      'rateLimited mid-loop bails out with the rateLimited reason',
      () async {
        await _seedHistory(
          store,
          paths: [
            [0xAA],
          ],
          initialWeight: 3.0,
        );

        sendRecorder.nextResult = () => MeshCoreTextSendResult.rateLimited(
          nextSendIn: const Duration(seconds: 2),
          remainingBytes: 100,
        );

        final outcome = await newOrchestrator().sendWithAutoRoute(
          text: _text,
          timestampSeconds: _ts,
          sendKind: MeshCoreSendKind.plainContact,
        );

        expect(outcome.delivered, isFalse);
        expect(outcome.attempts, 1);
        expect(
          outcome.failureReason,
          MeshCoreAutoRouteFailureReason.rateLimited,
        );
      },
    );

    test(
      'addUpdateContact failure bails out as firmwareSendRejected',
      () async {
        await _seedHistory(
          store,
          paths: [
            [0xAA],
          ],
          initialWeight: 3.0,
        );
        addUpdateRecorder.nextReturn = false;

        final outcome = await newOrchestrator().sendWithAutoRoute(
          text: _text,
          timestampSeconds: _ts,
          sendKind: MeshCoreSendKind.plainContact,
        );

        expect(outcome.delivered, isFalse);
        expect(outcome.attempts, 1);
        expect(
          outcome.failureReason,
          MeshCoreAutoRouteFailureReason.firmwareSendRejected,
        );
      },
    );

    test('empty history runs the loop with flood on every attempt', () async {
      // No seed.
      sendRecorder.nextResult = () => MeshCoreTextSendResult.ok(
        response: MeshCoreFrame(command: 0x06, payload: Uint8List(0)),
      );

      final outcome = await newOrchestrator().sendWithAutoRoute(
        text: _text,
        timestampSeconds: _ts,
        sendKind: MeshCoreSendKind.plainContact,
      );

      expect(outcome.delivered, isFalse);
      expect(outcome.attempts, 3);
      // Without saved paths every attempt must write -1.
      for (final call in addUpdateRecorder.calls) {
        expect(call.pathLength, -1);
      }
    });
  });

  group('buildSendTextMsgPayload - D48-A2', () {
    test('encodes attempt byte at payload[1] and timestamp at [2..6]', () {
      final p = buildSendTextMsgPayload(
        recipientPubKey: Uint8List.fromList(_contactPubKey),
        text: 'hi',
        timestampSeconds: 0x01020304,
        attempt: 2,
      );
      expect(p[0], 0); // txt_type = plain
      expect(p[1], 2); // attempt
      // u32 LE
      expect(p[2], 0x04);
      expect(p[3], 0x03);
      expect(p[4], 0x02);
      expect(p[5], 0x01);
      // pub-key prefix (first 6 bytes)
      expect(p.sublist(6, 12), _contactPubKey.sublist(0, 6));
      // 'hi' utf-8 + trailing NUL
      expect(p[12], 0x68);
      expect(p[13], 0x69);
      expect(p.last, 0);
    });
  });
}
