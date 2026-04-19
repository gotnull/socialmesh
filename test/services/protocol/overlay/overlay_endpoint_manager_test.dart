// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for [OverlayEndpointManager] — tie-break + persistence.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_endpoint_id.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_endpoint_manager.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_endpoint_record.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_identity_keypair.dart';

import '_overlay_link_test_harness.dart';

Future<OverlayEndpointManager> _makeManager({int Function()? clock}) async {
  final store = await openInMemoryEndpointStore();
  final keypair = OverlayIdentityKeypair(storage: FakeSecureStorage());
  final manager = OverlayEndpointManager(
    keypair: keypair,
    store: store,
    clock: clock,
  );
  await manager.ensureInitialized();
  return manager;
}

Uint8List _peerPubKey(int seed) {
  final out = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    out[i] = (seed * 13 + i) & 0xFF;
  }
  return out;
}

void main() {
  setUpAll(initFfi);

  test('ensureInitialized caches local endpointId', () async {
    final mgr = await _makeManager();
    final id1 = mgr.localEndpointId();
    final id2 = mgr.localEndpointId();
    expect(id1, equals(id2));
    expect(id1.length, 8);
    expect(mgr.localPublicKey().length, 32);
    expect(mgr.localPersonaHint().length, 8);
  });

  test('recordObservation upserts and reports record', () async {
    final mgr = await _makeManager();
    final peerPub = _peerPubKey(1);
    final endpointId = await OverlayEndpointId.deriveRoot(peerPub);
    final record = await mgr.recordObservation(
      endpointId: endpointId,
      personaPubEd: peerPub,
      peerNodeNum: 7,
      supportedFeatures: 0x01,
      trustLevel: OverlayEndpointTrustLevel.signatureVerified,
      source: OverlayEndpointObservationSource.linkFrame,
    );
    expect(record.trustLevel, OverlayEndpointTrustLevel.signatureVerified);
    expect(record.peerNodeNumHint, 7);
    expect(await mgr.endpointCount(), 1);
  });

  test('observed observation does NOT downgrade a verified record', () async {
    final mgr = await _makeManager();
    final peerPub = _peerPubKey(2);
    final id = await OverlayEndpointId.deriveRoot(peerPub);

    await mgr.recordObservation(
      endpointId: id,
      personaPubEd: peerPub,
      peerNodeNum: 1,
      supportedFeatures: 0x01,
      trustLevel: OverlayEndpointTrustLevel.signatureVerified,
      source: OverlayEndpointObservationSource.linkFrame,
    );

    await mgr.recordObservation(
      endpointId: id,
      personaPubEd: peerPub,
      peerNodeNum: 2,
      supportedFeatures: 0x00,
      trustLevel: OverlayEndpointTrustLevel.observed,
      source: OverlayEndpointObservationSource.capBeacon,
    );

    final loaded = await mgr.getByEndpointId(id);
    expect(loaded!.trustLevel, OverlayEndpointTrustLevel.signatureVerified);
    expect(loaded.peerNodeNumHint, 2);
    expect(loaded.supportedFeatures, 0x01);
  });

  test('verified overwrites observed', () async {
    final mgr = await _makeManager();
    final peerPub = _peerPubKey(3);
    final id = await OverlayEndpointId.deriveRoot(peerPub);

    await mgr.recordObservation(
      endpointId: id,
      personaPubEd: peerPub,
      trustLevel: OverlayEndpointTrustLevel.observed,
      source: OverlayEndpointObservationSource.capBeacon,
    );
    await mgr.recordObservation(
      endpointId: id,
      personaPubEd: peerPub,
      supportedFeatures: 0xF0,
      trustLevel: OverlayEndpointTrustLevel.signatureVerified,
      source: OverlayEndpointObservationSource.linkFrame,
    );

    final loaded = await mgr.getByEndpointId(id);
    expect(loaded!.trustLevel, OverlayEndpointTrustLevel.signatureVerified);
    expect(loaded.supportedFeatures, 0xF0);
  });

  test('resolvePeerByHints returns the known-hint record', () async {
    final mgr = await _makeManager();
    final pubA = _peerPubKey(4);
    final idA = await OverlayEndpointId.deriveRoot(pubA);
    await mgr.recordObservation(
      endpointId: idA,
      personaPubEd: pubA,
      trustLevel: OverlayEndpointTrustLevel.signatureVerified,
      source: OverlayEndpointObservationSource.linkFrame,
    );

    final hintA = await OverlayEndpointId.personaHint(pubA);
    final hitA = await mgr.resolvePeerByHints(personaHint: hintA);
    expect(hitA, isNotNull);
    expect(hitA!.trustLevel, OverlayEndpointTrustLevel.signatureVerified);

    final hitNone = await mgr.resolvePeerByHints(personaHint: Uint8List(8));
    expect(hitNone, isNull);
  });

  test(
    'resolvePeerByHints falls back to peerNodeNum when hint absent',
    () async {
      final mgr = await _makeManager();
      final pub = _peerPubKey(6);
      final id = await OverlayEndpointId.deriveRoot(pub);
      await mgr.recordObservation(
        endpointId: id,
        personaPubEd: pub,
        peerNodeNum: 123,
        trustLevel: OverlayEndpointTrustLevel.signatureVerified,
        source: OverlayEndpointObservationSource.linkFrame,
      );
      final hit = await mgr.resolvePeerByHints(peerNodeNum: 123);
      expect(hit, isNotNull);
      expect(hit!.endpointId, equals(id));
    },
  );

  test('firstSeenMs preserved across updates, lastSeenMs advances', () async {
    var now = 1_000;
    int clock() => now;
    final mgr = await _makeManager(clock: clock);
    final peerPub = _peerPubKey(7);
    final id = await OverlayEndpointId.deriveRoot(peerPub);

    await mgr.recordObservation(
      endpointId: id,
      personaPubEd: peerPub,
      trustLevel: OverlayEndpointTrustLevel.observed,
      source: OverlayEndpointObservationSource.linkFrame,
    );
    final first = await mgr.getByEndpointId(id);
    expect(first!.firstSeenMs, 1_000);

    now = 5_000;
    await mgr.recordObservation(
      endpointId: id,
      personaPubEd: peerPub,
      trustLevel: OverlayEndpointTrustLevel.signatureVerified,
      source: OverlayEndpointObservationSource.linkFrame,
    );
    final second = await mgr.getByEndpointId(id);
    expect(second!.firstSeenMs, 1_000);
    expect(second.lastSeenMs, 5_000);
  });
}
