// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// End-to-end integration test: two [OverlayLinkEngine] instances
/// with attached [OverlaySecureSessionManager]s drive the full v0.3
/// secure-session handshake through the link layer.
///
/// Verifies the Phase 1 contract documented in
/// `docs/sip/OVERLAY_V0_2.md §25`:
///   - auto-init fires on initiator side after `LINK_OPEN_OK`
///   - `LINK_SECURE_INIT` round-trips → `LINK_SECURE_ACK` installs
///     keys on both sides
///   - `LINK_SECURE_DATA` round-trips opaque payload + emits the
///     inbound-stream event on the receiver
///   - link state remains `active` whether or not secure succeeds
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_endpoint_manager.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_endpoint_record.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_identity_keypair.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_egress.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_engine.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_models.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_link_store.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_secure_session_manager.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

import '_overlay_link_test_harness.dart';

const int _peerAdvertisesSecure =
    OverlayCapabilityFeature.linkV02 | OverlayCapabilityFeature.secureV03;

class _Rig {
  final OverlayLinkEngine engine;
  final RecordingOverlayLinkEgress egress;
  final OverlaySecureSessionManager secureManager;
  final OverlayEndpointManager endpointManager;
  final OverlayLinkStore linkStore;
  final List<OverlayLinkEvent> events = [];
  late final StreamSubscription<OverlayLinkEvent> _sub;

  _Rig({
    required this.engine,
    required this.egress,
    required this.secureManager,
    required this.endpointManager,
    required this.linkStore,
  }) {
    _sub = engine.events.listen(events.add);
  }

  Future<void> dispose() async {
    await _sub.cancel();
    await secureManager.dispose();
    await engine.dispose();
  }
}

Future<_Rig> _buildRig({required bool secureEnabled}) async {
  final linkStore = await openInMemoryStore();
  final endpointStore = await openInMemoryEndpointStore();
  final keypair = OverlayIdentityKeypair(storage: FakeSecureStorage());
  final endpointManager = OverlayEndpointManager(
    keypair: keypair,
    store: endpointStore,
  );
  await endpointManager.ensureInitialized();

  final egress = RecordingOverlayLinkEgress();
  final secureManager = OverlaySecureSessionManager(
    store: linkStore,
    egress: egress,
    endpointManager: endpointManager,
    enabledFlag: () => secureEnabled,
  );
  final engine = OverlayLinkEngine(
    store: linkStore,
    egress: egress,
    clock: FakeClock().now,
    endpointManager: endpointManager,
    secureSessionManager: secureManager,
  );
  return _Rig(
    engine: engine,
    egress: egress,
    secureManager: secureManager,
    endpointManager: endpointManager,
    linkStore: linkStore,
  );
}

/// Pre-register [peer]'s endpoint on [local]'s store so
/// `resolvePeerByHints` finds it. In production this happens during
/// LINK_OPEN signature verification; this helper shortcuts it for
/// the test.
Future<void> _crossRegister({
  required _Rig local,
  required _Rig peer,
  required int peerNodeNum,
}) async {
  final peerPub = peer.endpointManager.localPublicKey();
  final peerEndpointId = peer.endpointManager.localEndpointId();
  await local.endpointManager.recordObservation(
    endpointId: peerEndpointId,
    personaPubEd: peerPub,
    peerNodeNum: peerNodeNum,
    supportedFeatures: _peerAdvertisesSecure,
    trustLevel: OverlayEndpointTrustLevel.signatureVerified,
    source: OverlayEndpointObservationSource.linkFrame,
  );
}

void main() {
  setUpAll(initFfi);

  test('auto-init: initiator side fires LINK_SECURE_INIT after a LINK_OPEN_OK '
      'activation and the session establishes on both ends', () async {
    final alice = await _buildRig(secureEnabled: true);
    final bob = await _buildRig(secureEnabled: true);
    addTearDown(() async {
      await alice.dispose();
      await bob.dispose();
    });

    // Pre-register cross endpoints. In the field this happens
    // during LINK_OPEN signature verification; here we short-
    // circuit it so the secure layer can resolve peer pubkeys.
    const aliceNodeNum = 100;
    const bobNodeNum = 200;
    await _crossRegister(local: alice, peer: bob, peerNodeNum: bobNodeNum);
    await _crossRegister(local: bob, peer: alice, peerNodeNum: aliceNodeNum);

    // Alice opens a link to Bob advertising secure support. Caps
    // propagate through the signed LINK_OPEN body → Bob stores them
    // on its link record → Bob's LINK_OPEN_OK signs them back → Alice
    // stores the peer-advertised caps on her link record, which the
    // secure manager inspects when deciding to auto-init.
    const secureCaps = OverlayLinkCapabilities(
      supportedFeatures: _peerAdvertisesSecure,
    );
    final openRecord = await alice.engine.openLocal(
      peerPersonaHint: Uint8List(8),
      peerNodeNum: bobNodeNum,
      localCapabilities: secureCaps,
    );

    // The first egress frame is the signed LINK_OPEN.
    expect(alice.egress.sent, hasLength(1));
    final linkOpen = alice.egress.sent.first.frame;
    expect(linkOpen.msgType, OverlayLinkMsgType.linkOpen);

    // Deliver Alice's LINK_OPEN to Bob. Bob accepts, sends
    // LINK_OPEN_OK, fires activated, and (because secure + peer
    // caps both set) stays passive awaiting SECURE_INIT.
    await bob.engine.handleInbound(linkOpen, aliceNodeNum);
    await Future<void>.delayed(Duration.zero);
    final bobSent = bob.egress.sent;
    expect(bobSent, hasLength(1));
    expect(bobSent.first.frame.msgType, OverlayLinkMsgType.linkOpenOk);
    expect(bob.secureManager.sessionCount, 0);

    // Deliver Bob's LINK_OPEN_OK back to Alice. Activation triggers
    // SECURE_INIT.
    alice.egress.sent.clear();
    await alice.engine.handleInbound(bobSent.first.frame, bobNodeNum);
    await Future<void>.delayed(Duration.zero);

    // Alice should now have sent a LINK_SECURE_INIT.
    expect(alice.egress.sent, isNotEmpty);
    final secureInit = alice.egress.sent
        .where((e) => e.frame.msgType == OverlayLinkMsgType.linkSecureInit)
        .toList();
    expect(
      secureInit,
      isNotEmpty,
      reason: 'auto-init should emit LINK_SECURE_INIT',
    );
    expect(secureInit.single.frame.linkId, openRecord.linkId);
    expect(alice.secureManager.sessionCount, 1);
    expect(alice.secureManager.isEstablished(openRecord.linkId), isFalse);

    // Deliver SECURE_INIT to Bob. He builds an ACK and becomes
    // established as responder.
    bob.egress.sent.clear();
    await bob.engine.handleInbound(secureInit.single.frame, aliceNodeNum);
    await Future<void>.delayed(Duration.zero);

    final secureAck = bob.egress.sent
        .where((e) => e.frame.msgType == OverlayLinkMsgType.linkSecureAck)
        .toList();
    expect(secureAck, hasLength(1));
    expect(bob.secureManager.sessionCount, 1);
    expect(bob.secureManager.isEstablished(openRecord.linkId), isTrue);

    // Deliver ACK to Alice. Her session transitions to active.
    alice.egress.sent.clear();
    await alice.engine.handleInbound(secureAck.single.frame, bobNodeNum);
    await Future<void>.delayed(Duration.zero);
    expect(alice.secureManager.isEstablished(openRecord.linkId), isTrue);

    // Now Alice wraps + sends a DATA frame. Bob decrypts it.
    final inboundPayloads = <OverlaySecureInboundPayload>[];
    final inboundSub = bob.secureManager.inbound.listen(inboundPayloads.add);
    addTearDown(inboundSub.cancel);

    final sent = await alice.secureManager.sendEncrypted(
      openRecord.linkId,
      Uint8List.fromList('hello secure mesh'.codeUnits),
      subtype: OverlaySecureDataSubtype.dmText,
    );
    expect(sent, isTrue);
    final secureData = alice.egress.sent
        .where((e) => e.frame.msgType == OverlayLinkMsgType.linkSecureData)
        .toList();
    expect(secureData, hasLength(1));

    await bob.engine.handleInbound(secureData.single.frame, aliceNodeNum);
    await Future<void>.delayed(Duration.zero);

    expect(inboundPayloads, hasLength(1));
    final payload = inboundPayloads.single;
    expect(payload.linkId, openRecord.linkId);
    expect(payload.subtype, OverlaySecureDataSubtype.dmText);
    expect(payload.seq, 0);
    expect(String.fromCharCodes(payload.cleartext), 'hello secure mesh');
  });

  test('fail-closed: when secure flag is off on the responder, the link '
      'still activates but no secure session ever establishes', () async {
    final alice = await _buildRig(secureEnabled: true);
    final bob = await _buildRig(secureEnabled: false);
    addTearDown(() async {
      await alice.dispose();
      await bob.dispose();
    });

    const aliceNodeNum = 100;
    const bobNodeNum = 200;
    await _crossRegister(local: alice, peer: bob, peerNodeNum: bobNodeNum);
    await _crossRegister(local: bob, peer: alice, peerNodeNum: aliceNodeNum);

    const secureCaps = OverlayLinkCapabilities(
      supportedFeatures: _peerAdvertisesSecure,
    );
    final openRecord = await alice.engine.openLocal(
      peerPersonaHint: Uint8List(8),
      peerNodeNum: bobNodeNum,
      localCapabilities: secureCaps,
    );
    final linkOpen = alice.egress.sent.single.frame;
    await bob.engine.handleInbound(linkOpen, aliceNodeNum);
    await Future<void>.delayed(Duration.zero);
    final linkOpenOk = bob.egress.sent.single.frame;

    alice.egress.sent.clear();
    await alice.engine.handleInbound(linkOpenOk, bobNodeNum);
    await Future<void>.delayed(Duration.zero);

    // Alice tried to auto-init; SECURE_INIT went out to Bob.
    final secureInit = alice.egress.sent
        .where((e) => e.frame.msgType == OverlayLinkMsgType.linkSecureInit)
        .toList();
    expect(secureInit, hasLength(1));

    // Bob receives SECURE_INIT but his manager is disabled → drops.
    bob.egress.sent.clear();
    await bob.engine.handleInbound(secureInit.single.frame, aliceNodeNum);
    await Future<void>.delayed(Duration.zero);

    expect(bob.egress.sent, isEmpty);
    expect(bob.secureManager.isEstablished(openRecord.linkId), isFalse);

    // Link state on Bob's side remains `active`: the `activated`
    // event was emitted by the engine before we stopped recording,
    // and no `terminated` event fired afterwards. That's the fail-
    // closed invariant — secure-layer failures never tear down the
    // link.
    final lastState = bob.events.last;
    expect(lastState.kind, OverlayLinkEventKind.activated);
    expect(lastState.record.state, OverlayLinkState.active);
  });

  test('restored-canonical reuse: two engines holding a stale canonical '
      'from a prior run can still negotiate a fresh secure session', () async {
    final alice = await _buildRig(secureEnabled: true);
    final bob = await _buildRig(secureEnabled: true);
    addTearDown(() async {
      await alice.dispose();
      await bob.dispose();
    });

    const aliceNodeNum = 100;
    const bobNodeNum = 200;
    await _crossRegister(local: alice, peer: bob, peerNodeNum: bobNodeNum);
    await _crossRegister(local: bob, peer: alice, peerNodeNum: aliceNodeNum);

    // Reach into each rig's store and pre-seed a matching stale
    // canonical record for the other peer. Simulates the "app just
    // restarted; links.db restored prior rows as stale" state.
    const sharedLinkId = 0xABCDEF01;
    const secureCaps = OverlayLinkCapabilities(
      supportedFeatures: _peerAdvertisesSecure,
    );

    Future<void> seedStale(_Rig rig, int peerNodeNum, bool initiator) async {
      await rig.linkStore.upsert(
        OverlayLinkRecord(
          linkId: sharedLinkId,
          peerPersonaHint: Uint8List(8),
          peerNodeNum: peerNodeNum,
          state: OverlayLinkState.stale,
          isInitiator: initiator,
          capabilities: secureCaps,
          openedAtMs: 0,
          lastActivityMs: 0,
          expiresAtMs: 1 << 40,
          txNextSeq: 0,
          txAckHi: 0,
          rxExpectedSeq: 0,
          retryCount: 0,
        ),
      );
    }

    await seedStale(alice, bobNodeNum, true);
    await seedStale(bob, aliceNodeNum, false);

    alice.egress.sent.clear();

    // Alice's openLocal reuses the stale canonical, promotes it to
    // active, and the secure-activation hook fires → SECURE_INIT.
    await alice.engine.openLocal(
      peerPersonaHint: Uint8List(8),
      peerNodeNum: bobNodeNum,
      localCapabilities: secureCaps,
    );
    await Future<void>.delayed(Duration.zero);

    final secureInit = alice.egress.sent
        .where((e) => e.frame.msgType == OverlayLinkMsgType.linkSecureInit)
        .toList();
    expect(
      secureInit,
      hasLength(1),
      reason: 'canonical reuse on stale must still fire SECURE_INIT',
    );
    expect(secureInit.single.frame.linkId, sharedLinkId);

    // Bob's side is also stale. The manager must accept SECURE_INIT
    // despite the stale state (not only active).
    bob.egress.sent.clear();
    await bob.engine.handleInbound(secureInit.single.frame, aliceNodeNum);
    await Future<void>.delayed(Duration.zero);

    final secureAck = bob.egress.sent
        .where((e) => e.frame.msgType == OverlayLinkMsgType.linkSecureAck)
        .toList();
    expect(
      secureAck,
      hasLength(1),
      reason: 'responder must accept SECURE_INIT on a stale canonical',
    );

    alice.egress.sent.clear();
    await alice.engine.handleInbound(secureAck.single.frame, bobNodeNum);
    await Future<void>.delayed(Duration.zero);

    expect(alice.secureManager.isEstablished(sharedLinkId), isTrue);
    expect(bob.secureManager.isEstablished(sharedLinkId), isTrue);
  });
}
