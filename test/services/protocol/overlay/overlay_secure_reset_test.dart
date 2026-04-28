// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Pins for `OverlaySecureSessionManager.resetSession` — the
/// user-driven secure-session revoke surface added for the Trust +
/// Safety "Reset secure session" action on accepted SIP DM sessions.
///
/// Contract:
///   1. Calling `resetSession(linkId)` on an established session
///      drops the in-memory session entry. `isEstablished` flips
///      from true to false. Returns `true`.
///   2. Calling `resetSession(linkId)` again returns `false` —
///      idempotent, no exception.
///   3. The underlying overlay link record is NOT closed: `state`
///      stays `active`, `closeReason` stays null.
///   4. After reset, a fresh outbound `sendEncrypted` triggers
///      re-init via `onLinkActivated` (the auto-init fires
///      because the manager observes "no session for active link"
///      again).
///
/// Per `OVERLAY_V0_2.md` §25 secure-session state is in-memory only:
/// nothing on disk to clean up. This test asserts that the link
/// store row remains intact, confirming the spec invariant.
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

Future<_Rig> _buildRig() async {
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
    enabledFlag: () => true,
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

/// Drives a full `LINK_OPEN → LINK_OPEN_OK → LINK_SECURE_INIT →
/// LINK_SECURE_ACK` round-trip between two rigs and returns the
/// canonical `linkId` once both sides report `isEstablished == true`.
Future<int> _establishSecureSession(_Rig alice, _Rig bob) async {
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
  final linkOpen = alice.egress.sent.first.frame;

  await bob.engine.handleInbound(linkOpen, aliceNodeNum);
  await Future<void>.delayed(Duration.zero);
  final linkOpenOk = bob.egress.sent.first.frame;

  alice.egress.sent.clear();
  await alice.engine.handleInbound(linkOpenOk, bobNodeNum);
  await Future<void>.delayed(Duration.zero);
  final secureInit = alice.egress.sent
      .firstWhere((e) => e.frame.msgType == OverlayLinkMsgType.linkSecureInit)
      .frame;

  bob.egress.sent.clear();
  await bob.engine.handleInbound(secureInit, aliceNodeNum);
  await Future<void>.delayed(Duration.zero);
  final secureAck = bob.egress.sent
      .firstWhere((e) => e.frame.msgType == OverlayLinkMsgType.linkSecureAck)
      .frame;

  alice.egress.sent.clear();
  await alice.engine.handleInbound(secureAck, bobNodeNum);
  await Future<void>.delayed(Duration.zero);

  expect(alice.secureManager.isEstablished(openRecord.linkId), isTrue);
  expect(bob.secureManager.isEstablished(openRecord.linkId), isTrue);
  return openRecord.linkId;
}

void main() {
  setUpAll(initFfi);

  group('OverlaySecureSessionManager.resetSession', () {
    test('drops an established session and returns true', () async {
      final alice = await _buildRig();
      final bob = await _buildRig();
      addTearDown(() async {
        await alice.dispose();
        await bob.dispose();
      });

      final linkId = await _establishSecureSession(alice, bob);
      expect(alice.secureManager.isEstablished(linkId), isTrue);
      expect(alice.secureManager.sessionCount, equals(1));

      final didReset = alice.secureManager.resetSession(linkId);
      expect(didReset, isTrue);
      expect(alice.secureManager.isEstablished(linkId), isFalse);
      expect(alice.secureManager.sessionCount, equals(0));
    });

    test('idempotent — second call returns false, no exception', () async {
      final alice = await _buildRig();
      final bob = await _buildRig();
      addTearDown(() async {
        await alice.dispose();
        await bob.dispose();
      });

      final linkId = await _establishSecureSession(alice, bob);
      expect(alice.secureManager.resetSession(linkId), isTrue);
      expect(alice.secureManager.resetSession(linkId), isFalse);
      // And on a never-existed linkId.
      expect(alice.secureManager.resetSession(0xDEADBEEF), isFalse);
    });

    test('underlying overlay link record is NOT closed by reset', () async {
      // Per OVERLAY_V0_2 §25 secure session state is purely in-memory
      // and decoupled from link state. Resetting the session must
      // leave the link active and reusable for plaintext overlay
      // features (resource transfer etc.).
      final alice = await _buildRig();
      final bob = await _buildRig();
      addTearDown(() async {
        await alice.dispose();
        await bob.dispose();
      });

      final linkId = await _establishSecureSession(alice, bob);
      final beforeRecord = await alice.linkStore.getByLinkId(linkId);
      expect(beforeRecord, isNotNull);
      expect(beforeRecord!.state, equals(OverlayLinkState.active));
      expect(beforeRecord.closeReason, isNull);

      alice.secureManager.resetSession(linkId);

      final afterRecord = await alice.linkStore.getByLinkId(linkId);
      expect(afterRecord, isNotNull);
      expect(
        afterRecord!.state,
        equals(OverlayLinkState.active),
        reason: 'reset must NOT terminate the underlying link',
      );
      expect(afterRecord.closeReason, isNull);
      expect(afterRecord.peerNodeNum, equals(beforeRecord.peerNodeNum));
    });

    test('post-reset sendEncrypted no longer succeeds (session is gone) '
        'until a fresh negotiation lands', () async {
      // The point of reset: the next outbound goes through a fresh
      // re-negotiation. Calling sendEncrypted immediately after
      // reset must fail (no session). A real client would either
      // (a) wait for auto-init to land, or (b) drive a new
      // LINK_SECURE_INIT manually. This test asserts (a)'s
      // precondition: the session is genuinely gone.
      final alice = await _buildRig();
      final bob = await _buildRig();
      addTearDown(() async {
        await alice.dispose();
        await bob.dispose();
      });

      final linkId = await _establishSecureSession(alice, bob);
      // Before reset: sendEncrypted succeeds.
      final ok = await alice.secureManager.sendEncrypted(
        linkId,
        Uint8List.fromList(<int>[1, 2, 3]),
        subtype: OverlaySecureDataSubtype.dmText,
      );
      expect(ok, isTrue);

      alice.secureManager.resetSession(linkId);

      // After reset: sendEncrypted fails because no session is
      // established. (The manager's send path returns false when
      // there is no key material installed for the link.)
      final afterReset = await alice.secureManager.sendEncrypted(
        linkId,
        Uint8List.fromList(<int>[4, 5, 6]),
        subtype: OverlaySecureDataSubtype.dmText,
      );
      expect(
        afterReset,
        isFalse,
        reason:
            'sendEncrypted must fail until re-negotiation completes; '
            'silent failure is the contract',
      );
    });
  });
}
