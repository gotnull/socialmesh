// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Integration tests for the P3 signed-handshake flow through
/// [OverlayLinkEngine].
///
/// These tests spin up two engines — a signer and a verifier — and
/// drive the LINK_OPEN handshake end-to-end, covering:
///   - signed LINK_OPEN accepted + endpoint persisted
///   - tampered signature rejected with authFailure
///   - a peer with no endpoint manager (unsigned path) still accepted
///   - symmetric verification on LINK_OPEN_OK
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_endpoint_id.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_endpoint_manager.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_endpoint_record.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_identity_keypair.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_codec.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_egress.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_engine.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_models.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

import '_overlay_link_test_harness.dart';

class _SignedRig {
  final OverlayLinkEngine engine;
  final RecordingOverlayLinkEgress egress;
  final OverlayEndpointManager manager;

  _SignedRig({
    required this.engine,
    required this.egress,
    required this.manager,
  });
}

Future<_SignedRig> _buildSignedEngine() async {
  final linkStore = await openInMemoryStore();
  final endpointStore = await openInMemoryEndpointStore();
  final keypair = OverlayIdentityKeypair(storage: FakeSecureStorage());
  final manager = OverlayEndpointManager(
    keypair: keypair,
    store: endpointStore,
  );
  await manager.ensureInitialized();
  final egress = RecordingOverlayLinkEgress();
  final engine = OverlayLinkEngine(
    store: linkStore,
    egress: egress,
    clock: FakeClock().now,
    endpointManager: manager,
  );
  return _SignedRig(engine: engine, egress: egress, manager: manager);
}

Future<_SignedRig> _buildUnsignedEngine() async {
  final linkStore = await openInMemoryStore();
  final endpointStore = await openInMemoryEndpointStore();
  final keypair = OverlayIdentityKeypair(storage: FakeSecureStorage());
  final manager = OverlayEndpointManager(
    keypair: keypair,
    store: endpointStore,
  );
  await manager.ensureInitialized();
  final egress = RecordingOverlayLinkEgress();
  // No endpointManager → unsigned behaviour.
  final engine = OverlayLinkEngine(
    store: linkStore,
    egress: egress,
    clock: FakeClock().now,
  );
  return _SignedRig(engine: engine, egress: egress, manager: manager);
}

void main() {
  setUpAll(initFfi);

  test('outbound LINK_OPEN carries a 110-byte signed body', () async {
    final rig = await _buildSignedEngine();
    await rig.engine.openLocal(peerPersonaHint: Uint8List(8), peerNodeNum: 42);
    expect(rig.egress.sent, hasLength(1));
    final frame = rig.egress.sent.single.frame;
    expect(frame.msgType, OverlayLinkMsgType.linkOpen);
    expect(frame.payload.length, 110);
    await rig.engine.dispose();
  });

  test('receiver accepts valid signed LINK_OPEN + persists endpoint '
      'with trust=signatureVerified', () async {
    // Initiator signs LINK_OPEN.
    final initiator = await _buildSignedEngine();
    await initiator.engine.openLocal(
      peerPersonaHint: Uint8List(8),
      peerNodeNum: 200,
    );
    final sentFrame = initiator.egress.sent.single.frame;

    // Responder (fresh engine + manager) decodes + verifies.
    final responder = await _buildSignedEngine();
    final events = <OverlayLinkEvent>[];
    final sub = responder.engine.events.listen(events.add);

    await responder.engine.handleInbound(sentFrame, 200);
    await Future<void>.delayed(Duration.zero);

    expect(
      events.map((e) => e.kind),
      containsAllInOrder([
        OverlayLinkEventKind.opened,
        OverlayLinkEventKind.activated,
      ]),
    );

    // Endpoint record was persisted with signatureVerified trust.
    final initiatorPub = initiator.manager.localPublicKey();
    final endpointId = await OverlayEndpointId.deriveRoot(initiatorPub);
    final endpointRecord = await responder.manager.getByEndpointId(endpointId);
    expect(endpointRecord, isNotNull);
    expect(
      endpointRecord!.trustLevel,
      OverlayEndpointTrustLevel.signatureVerified,
    );
    expect(endpointRecord.peerNodeNumHint, 200);

    await sub.cancel();
    await initiator.engine.dispose();
    await responder.engine.dispose();
  });

  test(
    'tampered signature is rejected with LINK_OPEN_NO(authFailure)',
    () async {
      final initiator = await _buildSignedEngine();
      await initiator.engine.openLocal(
        peerPersonaHint: Uint8List(8),
        peerNodeNum: 1,
      );
      final sent = initiator.egress.sent.single.frame;

      // Flip a bit in the signature region (last byte).
      final tamperedPayload = Uint8List.fromList(sent.payload);
      tamperedPayload[tamperedPayload.length - 1] ^= 0x01;
      final tamperedFrame = OverlayLinkFrame(
        msgType: sent.msgType,
        flags: sent.flags,
        requestId: sent.requestId,
        serviceId: sent.serviceId,
        actionId: sent.actionId,
        payloadLen: tamperedPayload.length,
        linkId: sent.linkId,
        seq: sent.seq,
        ackHi: sent.ackHi,
        payload: tamperedPayload,
      );

      final responder = await _buildSignedEngine();
      await responder.engine.handleInbound(tamperedFrame, 1);

      // Responder replies LINK_OPEN_NO(authFailure); no endpoint
      // persisted; no active link created.
      expect(responder.egress.sent, hasLength(1));
      final reply = responder.egress.sent.single.frame;
      expect(reply.msgType, OverlayLinkMsgType.linkOpenNo);
      expect(reply.payload.single, OverlayLinkCloseReason.authFailure.code);
      expect(await responder.manager.endpointCount(), 0);

      await initiator.engine.dispose();
      await responder.engine.dispose();
    },
  );

  test('peer without endpoint manager sends empty LINK_OPEN; signed responder '
      'still accepts (mixed v0.2/P3 interop)', () async {
    final unsignedInitiator = await _buildUnsignedEngine();
    await unsignedInitiator.engine.openLocal(
      peerPersonaHint: Uint8List(8),
      peerNodeNum: 9,
    );
    final sent = unsignedInitiator.egress.sent.single.frame;
    expect(sent.payload.length, 0); // unsigned path

    final responder = await _buildSignedEngine();
    await responder.engine.handleInbound(sent, 9);

    // Accepted even though unsigned — no endpoint persisted.
    expect(responder.egress.sent, hasLength(1));
    expect(
      responder.egress.sent.single.frame.msgType,
      OverlayLinkMsgType.linkOpenOk,
    );
    expect(await responder.manager.endpointCount(), 0);

    await unsignedInitiator.engine.dispose();
    await responder.engine.dispose();
  });

  test(
    'malformed signed body (bad length) rejected with authFailure',
    () async {
      final responder = await _buildSignedEngine();
      // Craft a LINK_OPEN with a 50-byte payload (not 0, not 110).
      final badFrame = OverlayLinkFrame(
        msgType: OverlayLinkMsgType.linkOpen,
        flags: OverlayLinkFlags.linkFrame,
        requestId: 0,
        serviceId: 0,
        actionId: 0,
        payloadLen: 50,
        linkId: 0x99,
        seq: 0,
        ackHi: 0,
        payload: Uint8List(50),
      );
      await responder.engine.handleInbound(badFrame, 1);
      expect(responder.egress.sent, hasLength(1));
      expect(
        responder.egress.sent.single.frame.msgType,
        OverlayLinkMsgType.linkOpenNo,
      );
      expect(
        responder.egress.sent.single.frame.payload.single,
        OverlayLinkCloseReason.authFailure.code,
      );

      await responder.engine.dispose();
    },
  );

  test('LINK_OPEN_OK signature validation is symmetric', () async {
    // Initiator opens locally; responder sends a valid LINK_OPEN_OK
    // back (built from responder's own handshake body).
    final initiator = await _buildSignedEngine();
    await initiator.engine.openLocal(
      peerPersonaHint: Uint8List(8),
      peerNodeNum: 55,
    );
    final initiatorOpen = initiator.egress.sent.single.frame;

    final responder = await _buildSignedEngine();
    await responder.engine.handleInbound(initiatorOpen, 55);
    // Responder's egress now has a LINK_OPEN_OK with a fresh signed body.
    final responderOk = responder.egress.sent.single.frame;

    // Feed it back into the initiator.
    initiator.egress.sent.clear();
    final events = <OverlayLinkEvent>[];
    final sub = initiator.engine.events.listen(events.add);
    await initiator.engine.handleInbound(responderOk, 55);
    await Future<void>.delayed(Duration.zero);

    // Initiator activated + persisted responder endpoint.
    expect(events.map((e) => e.kind), contains(OverlayLinkEventKind.activated));
    final responderPub = responder.manager.localPublicKey();
    final responderEndpointId = await OverlayEndpointId.deriveRoot(
      responderPub,
    );
    final persisted = await initiator.manager.getByEndpointId(
      responderEndpointId,
    );
    expect(persisted, isNotNull);
    expect(persisted!.trustLevel, OverlayEndpointTrustLevel.signatureVerified);

    await sub.cancel();
    await initiator.engine.dispose();
    await responder.engine.dispose();
  });

  test(
    'tampered LINK_OPEN_OK signature fails the link locally (failed)',
    () async {
      final initiator = await _buildSignedEngine();
      await initiator.engine.openLocal(
        peerPersonaHint: Uint8List(8),
        peerNodeNum: 77,
      );
      final initiatorOpen = initiator.egress.sent.single.frame;
      final initiatorLinkId = initiatorOpen.linkId;

      final responder = await _buildSignedEngine();
      await responder.engine.handleInbound(initiatorOpen, 77);
      final okFrame = responder.egress.sent.single.frame;
      final tampered = Uint8List.fromList(okFrame.payload);
      tampered[0] ^= 0xFF; // corrupt schema version + more

      final tamperedOk = OverlayLinkFrame(
        msgType: okFrame.msgType,
        flags: okFrame.flags,
        requestId: okFrame.requestId,
        serviceId: okFrame.serviceId,
        actionId: okFrame.actionId,
        payloadLen: tampered.length,
        linkId: okFrame.linkId,
        seq: okFrame.seq,
        ackHi: okFrame.ackHi,
        payload: tampered,
      );

      final events = <OverlayLinkEvent>[];
      final sub = initiator.engine.events.listen(events.add);
      await initiator.engine.handleInbound(tamperedOk, 77);
      await Future<void>.delayed(Duration.zero);

      final terminated = events
          .where((e) => e.kind == OverlayLinkEventKind.terminated)
          .toList();
      expect(terminated, isNotEmpty);
      expect(
        terminated.last.record.closeReason,
        OverlayLinkCloseReason.authFailure,
      );
      expect(terminated.last.record.linkId, initiatorLinkId);

      await sub.cancel();
      await initiator.engine.dispose();
      await responder.engine.dispose();
    },
  );
}
