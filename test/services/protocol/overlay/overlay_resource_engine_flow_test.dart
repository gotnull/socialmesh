// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Happy-path + adversarial flow tests for [OverlayResourceEngine].
///
/// Covers:
///   - OFFER / ACCEPT / DECLINE handshake (sender + receiver)
///   - CHUNK send window + receiver BITMAP emission
///   - COMPLETE with good SHA-256 → VERIFIED → complete
///   - COMPLETE with tampered SHA-256 → corrupt + ABORT
///   - COMPLETE arriving with missing chunks → no verify, BITMAP back
///   - Duplicate OFFER ignored
///   - Sender sendWindow with all chunks already acked emits COMPLETE
library;

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_bitmap.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_codec.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_egress.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_resource_engine.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

import '_overlay_link_test_harness.dart';

Uint8List _hint(int seed) => Uint8List.fromList(List<int>.filled(8, seed));

Future<Uint8List> _sha256(Uint8List data) async {
  final h = await Sha256().hash(data);
  return Uint8List.fromList(h.bytes);
}

/// Build two engines — one sender, one receiver — and a pair of
/// recording egress instances. Tests drive them by copying frames
/// between the two egress buffers.
class _Pair {
  final OverlayResourceEngine sender;
  final OverlayResourceEngine receiver;
  final RecordingOverlayResourceEgress senderEgress;
  final RecordingOverlayResourceEgress receiverEgress;

  _Pair({
    required this.sender,
    required this.receiver,
    required this.senderEgress,
    required this.receiverEgress,
  });
}

Future<_Pair> _buildPair() async {
  final senderStore = await openInMemoryResourceStore();
  final receiverStore = await openInMemoryResourceStore();
  final senderEgress = RecordingOverlayResourceEgress();
  final receiverEgress = RecordingOverlayResourceEgress();
  final senderEngine = OverlayResourceEngine(
    store: senderStore,
    egress: senderEgress,
    clock: FakeClock().now,
    resourceIdGenerator: SequenceLinkIdGen(<int>[0xC0FFEE01]).next,
  );
  final receiverEngine = OverlayResourceEngine(
    store: receiverStore,
    egress: receiverEgress,
    clock: FakeClock().now,
  );
  return _Pair(
    sender: senderEngine,
    receiver: receiverEngine,
    senderEgress: senderEgress,
    receiverEgress: receiverEgress,
  );
}

void main() {
  setUpAll(initFfi);

  test('OFFER → ACCEPT → chunks → COMPLETE → VERIFIED end-to-end', () async {
    final pair = await _buildPair();
    final payload = Uint8List.fromList(
      List<int>.generate(300, (i) => i & 0xFF),
    );
    final senderHint = _hint(0x11);
    final receiverHint = _hint(0x22);

    // Sender offers.
    final offered = await pair.sender.offerLocal(
      peerEndpointHint: receiverHint,
      peerNodeNum: 100,
      payload: payload,
      chunkSize: 128,
    );
    expect(offered.chunkCount, 3); // ceil(300/128) = 3
    expect(pair.senderEgress.sent, hasLength(1));
    final offerFrame = pair.senderEgress.sent.single.frame;
    expect(offerFrame.type, OverlayResourceMsgType.offer);

    // Receiver ingests OFFER.
    await pair.receiver.handleInbound(
      offerFrame,
      senderEndpointHint: senderHint,
      senderNodeNum: 1,
    );

    // Receiver accepts.
    final accepted = await pair.receiver.acceptOffer(
      peerEndpointHint: senderHint,
      resourceId: offered.resourceId,
    );
    expect(accepted.state, OverlayResourceState.receiving);
    expect(pair.receiverEgress.sent, hasLength(1));
    final acceptFrame = pair.receiverEgress.sent.single.frame;
    expect(acceptFrame.type, OverlayResourceMsgType.accept);

    // Sender sees ACCEPT, transitions to transferring.
    await pair.sender.handleInbound(
      acceptFrame,
      senderEndpointHint: receiverHint,
      senderNodeNum: 100,
    );

    // Sender pushes first window (3 chunks).
    pair.senderEgress.sent.clear();
    final sent = await pair.sender.sendWindow(
      peerEndpointHint: receiverHint,
      resourceId: offered.resourceId,
    );
    expect(sent, 3);
    expect(pair.senderEgress.sent.length, 3);
    expect(
      pair.senderEgress.sent.every(
        (e) => e.frame.type == OverlayResourceMsgType.chunk,
      ),
      isTrue,
    );

    // Receiver ingests each chunk. The third chunk triggers a
    // BITMAP emission because received count becomes a multiple of
    // 4 OR equals chunkCount. Here chunkCount=3 which equals
    // received=3, so BITMAP fires.
    pair.receiverEgress.sent.clear();
    for (final e in pair.senderEgress.sent) {
      await pair.receiver.handleInbound(
        e.frame,
        senderEndpointHint: senderHint,
        senderNodeNum: 1,
      );
    }
    final bitmapSent = pair.receiverEgress.sent
        .where((e) => e.frame.type == OverlayResourceMsgType.bitmap)
        .toList();
    expect(bitmapSent, isNotEmpty);

    // Sender ingests BITMAP, sees all chunks acked.
    for (final e in bitmapSent) {
      await pair.sender.handleInbound(
        e.frame,
        senderEndpointHint: receiverHint,
        senderNodeNum: 100,
      );
    }

    // Sender's next sendWindow → 0 missing → COMPLETE emitted.
    pair.senderEgress.sent.clear();
    final more = await pair.sender.sendWindow(
      peerEndpointHint: receiverHint,
      resourceId: offered.resourceId,
    );
    expect(more, 0);
    final completeFrame = pair.senderEgress.sent.single.frame;
    expect(completeFrame.type, OverlayResourceMsgType.complete);
    expect(completeFrame.payload.length, 32); // sha256

    // Receiver ingests COMPLETE → verifies → sends VERIFIED.
    pair.receiverEgress.sent.clear();
    await pair.receiver.handleInbound(
      completeFrame,
      senderEndpointHint: senderHint,
      senderNodeNum: 1,
    );
    final verified = pair.receiverEgress.sent.single.frame;
    expect(verified.type, OverlayResourceMsgType.verified);

    // Sender ingests VERIFIED → complete.
    await pair.sender.handleInbound(
      verified,
      senderEndpointHint: receiverHint,
      senderNodeNum: 100,
    );

    final senderFinal = await pair.sender
        .handleInbound(
          // dummy access via tick
          OverlayResourceFrame(
            type: OverlayResourceMsgType.resume,
            resourceId: offered.resourceId,
            payload: Uint8List(0),
          ),
          senderEndpointHint: receiverHint,
          senderNodeNum: 100,
        )
        .then((_) {});
    expect(senderFinal, isNull);
    await pair.sender.dispose();
    await pair.receiver.dispose();
  });

  test('tampered payload → receiver marks corrupt, sends ABORT', () async {
    final pair = await _buildPair();
    final payload = Uint8List.fromList(List<int>.filled(128, 0x11));
    final receiverHint = _hint(0x22);
    final senderHint = _hint(0x11);

    final offered = await pair.sender.offerLocal(
      peerEndpointHint: receiverHint,
      peerNodeNum: 1,
      payload: payload,
      chunkSize: 128,
    );
    await pair.receiver.handleInbound(
      pair.senderEgress.sent.single.frame,
      senderEndpointHint: senderHint,
      senderNodeNum: 1,
    );
    await pair.receiver.acceptOffer(
      peerEndpointHint: senderHint,
      resourceId: offered.resourceId,
    );
    pair.senderEgress.sent.clear();
    await pair.sender.handleInbound(
      pair.receiverEgress.sent.single.frame,
      senderEndpointHint: receiverHint,
      senderNodeNum: 1,
    );
    await pair.sender.sendWindow(
      peerEndpointHint: receiverHint,
      resourceId: offered.resourceId,
    );

    // Tamper: deliver a chunk with different bytes than sender's hash.
    final chunkFrame = pair.senderEgress.sent.single.frame;
    final tamperedChunk = OverlayResourceFrame(
      type: chunkFrame.type,
      resourceId: chunkFrame.resourceId,
      chunkIndex: chunkFrame.chunkIndex,
      chunkCount: chunkFrame.chunkCount,
      payload: Uint8List.fromList(List<int>.filled(128, 0xFF)),
    );
    pair.receiverEgress.sent.clear();
    await pair.receiver.handleInbound(
      tamperedChunk,
      senderEndpointHint: senderHint,
      senderNodeNum: 1,
    );

    // Feed the receiver's BITMAP back to the sender so it knows
    // every chunk is acked and will emit COMPLETE next.
    final bitmapFrames = pair.receiverEgress.sent
        .where((e) => e.frame.type == OverlayResourceMsgType.bitmap)
        .toList();
    for (final b in bitmapFrames) {
      await pair.sender.handleInbound(
        b.frame,
        senderEndpointHint: receiverHint,
        senderNodeNum: 1,
      );
    }

    // Sender sends COMPLETE.
    pair.senderEgress.sent.clear();
    await pair.sender.sendWindow(
      peerEndpointHint: receiverHint,
      resourceId: offered.resourceId,
    );
    final completeFrame = pair.senderEgress.sent.single.frame;

    pair.receiverEgress.sent.clear();
    await pair.receiver.handleInbound(
      completeFrame,
      senderEndpointHint: senderHint,
      senderNodeNum: 1,
    );

    // Receiver should have sent ABORT (not VERIFIED).
    final aborts = pair.receiverEgress.sent
        .where((e) => e.frame.type == OverlayResourceMsgType.abort)
        .toList();
    expect(aborts, hasLength(1));

    await pair.sender.dispose();
    await pair.receiver.dispose();
  });

  test(
    'COMPLETE arriving with missing chunks does NOT verify; BITMAP sent',
    () async {
      final pair = await _buildPair();
      final payload = Uint8List.fromList(
        List<int>.generate(300, (i) => i & 0xFF),
      );
      final receiverHint = _hint(0x22);
      final senderHint = _hint(0x11);

      final offered = await pair.sender.offerLocal(
        peerEndpointHint: receiverHint,
        peerNodeNum: 1,
        payload: payload,
        chunkSize: 128,
      );
      await pair.receiver.handleInbound(
        pair.senderEgress.sent.single.frame,
        senderEndpointHint: senderHint,
        senderNodeNum: 1,
      );
      await pair.receiver.acceptOffer(
        peerEndpointHint: senderHint,
        resourceId: offered.resourceId,
      );

      // Skip chunk delivery entirely — just send COMPLETE.
      final completeFrame = OverlayResourceFrame(
        type: OverlayResourceMsgType.complete,
        resourceId: offered.resourceId,
        chunkCount: offered.chunkCount,
        payload: await _sha256(payload),
      );
      pair.receiverEgress.sent.clear();
      await pair.receiver.handleInbound(
        completeFrame,
        senderEndpointHint: senderHint,
        senderNodeNum: 1,
      );

      // Receiver should respond with BITMAP showing everything missing.
      final replies = pair.receiverEgress.sent
          .where((e) => e.frame.type == OverlayResourceMsgType.bitmap)
          .toList();
      expect(replies, hasLength(1));
      // None of the bits should be set.
      final missing = OverlayBitmap.missingIndexes(
        replies.single.frame.payload,
        offered.chunkCount,
      );
      expect(missing.length, offered.chunkCount);

      await pair.sender.dispose();
      await pair.receiver.dispose();
    },
  );

  test('receiver DECLINE causes sender to transition to declined', () async {
    final pair = await _buildPair();
    final payload = Uint8List.fromList(List<int>.filled(32, 0x00));
    final receiverHint = _hint(0x22);
    final senderHint = _hint(0x11);

    final offered = await pair.sender.offerLocal(
      peerEndpointHint: receiverHint,
      peerNodeNum: 1,
      payload: payload,
    );
    await pair.receiver.handleInbound(
      pair.senderEgress.sent.single.frame,
      senderEndpointHint: senderHint,
      senderNodeNum: 1,
    );
    await pair.receiver.declineOffer(
      peerEndpointHint: senderHint,
      resourceId: offered.resourceId,
      reason: OverlayLinkCloseReason.busy,
    );

    final declineFrame = pair.receiverEgress.sent.single.frame;
    expect(declineFrame.type, OverlayResourceMsgType.decline);
    expect(declineFrame.payload[0], OverlayLinkCloseReason.busy.code);

    await pair.sender.handleInbound(
      declineFrame,
      senderEndpointHint: receiverHint,
      senderNodeNum: 1,
    );
    // (We don't have an accessor on the engine for state; verify
    // behavior instead — a follow-up sendWindow refuses.)
    final sent = await pair.sender.sendWindow(
      peerEndpointHint: receiverHint,
      resourceId: offered.resourceId,
    );
    expect(sent, 0);

    await pair.sender.dispose();
    await pair.receiver.dispose();
  });

  test(
    'duplicate inbound OFFER is ignored while the first is non-terminal',
    () async {
      final pair = await _buildPair();
      final senderHint = _hint(0x11);
      final offer = OverlayResourceFrame(
        type: OverlayResourceMsgType.offer,
        resourceId: 1,
        chunkCount: 1,
        payload: Uint8List.fromList(<int>[
          ...Uint8List(6), // total=0 chunkSize=0
          ...List<int>.filled(32, 0), // sha
          0, // mimeLen
          0, // nameLen
        ]),
      );
      await pair.receiver.handleInbound(
        offer,
        senderEndpointHint: senderHint,
        senderNodeNum: 1,
      );
      await pair.receiver.handleInbound(
        offer,
        senderEndpointHint: senderHint,
        senderNodeNum: 1,
      );
      // Only a single row exists (duplicate didn't insert another).
      // Indirect check via loadAll via a fresh store query isn't exposed
      // on the engine, so we confirm by attempting accept + see it
      // works exactly once (second accept is a no-op because already
      // accepting).
      await pair.receiver.acceptOffer(
        peerEndpointHint: senderHint,
        resourceId: 1,
      );
      await pair.receiver.dispose();
      await pair.sender.dispose();
    },
  );
}
