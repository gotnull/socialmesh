// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for [OverlayEndpointStore] — `endpoints.db` schema v1.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_endpoint_record.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_endpoint_store.dart';

import '_overlay_link_test_harness.dart';

OverlayEndpointRecord _mkRecord({
  int endpointSeed = 0x11,
  int personaSeed = 0x22,
  int serviceId = 0,
  int? peerNodeNum,
  int supportedFeatures = 1,
  int firstSeenMs = 1_700_000_000_000,
  int? lastSeenMs,
  OverlayEndpointTrustLevel trustLevel = OverlayEndpointTrustLevel.observed,
  String source = OverlayEndpointObservationSource.linkFrame,
}) {
  final endpointId = Uint8List(8);
  for (var i = 0; i < 8; i++) {
    endpointId[i] = (endpointSeed + i) & 0xFF;
  }
  final personaPub = Uint8List(32);
  for (var i = 0; i < 32; i++) {
    personaPub[i] = (personaSeed + i) & 0xFF;
  }
  final personaHint = Uint8List.fromList(personaPub.sublist(0, 8));
  return OverlayEndpointRecord(
    endpointId: endpointId,
    personaPubEd: personaPub,
    personaHint: personaHint,
    serviceId: serviceId,
    peerNodeNumHint: peerNodeNum,
    supportedFeatures: supportedFeatures,
    firstSeenMs: firstSeenMs,
    lastSeenMs: lastSeenMs ?? firstSeenMs,
    trustLevel: trustLevel,
    source: source,
  );
}

void main() {
  setUpAll(initFfi);

  test('init + close lifecycle', () async {
    final s = await openInMemoryEndpointStore();
    expect(s.isOpen, isTrue);
    await s.close();
    expect(s.isOpen, isFalse);
  });

  test('upsert + getByEndpointId roundtrip', () async {
    final s = await openInMemoryEndpointStore();
    final r = _mkRecord(
      supportedFeatures: 0x03,
      peerNodeNum: 42,
      trustLevel: OverlayEndpointTrustLevel.signatureVerified,
    );
    await s.upsert(r);
    final loaded = await s.getByEndpointId(r.endpointId);
    expect(loaded, isNotNull);
    expect(loaded!.supportedFeatures, 0x03);
    expect(loaded.peerNodeNumHint, 42);
    expect(loaded.trustLevel, OverlayEndpointTrustLevel.signatureVerified);
    expect(loaded.personaPubEd, equals(r.personaPubEd));
  });

  test('upsert replaces on conflict (primary key endpoint_id)', () async {
    final s = await openInMemoryEndpointStore();
    final a = _mkRecord(supportedFeatures: 1);
    await s.upsert(a);
    final b = a.copyWith(supportedFeatures: 0xFFFF, lastSeenMs: 9_999);
    await s.upsert(b);
    final loaded = await s.getByEndpointId(a.endpointId);
    expect(loaded!.supportedFeatures, 0xFFFF);
    expect(loaded.lastSeenMs, 9_999);
  });

  test(
    'getByPersonaHint returns all matching rows ordered by last_seen DESC',
    () async {
      final s = await openInMemoryEndpointStore();
      final a = _mkRecord(endpointSeed: 0x01, lastSeenMs: 1_000);
      final b = _mkRecord(endpointSeed: 0x02, lastSeenMs: 2_000);
      await s.upsert(a);
      await s.upsert(b);
      // Both share personaSeed, so personaHint matches.
      final hits = await s.getByPersonaHint(a.personaHint);
      expect(hits.map((r) => r.endpointId[0]), equals([0x02, 0x01]));
    },
  );

  test('getByPeerNodeNum orders verified above observed', () async {
    final s = await openInMemoryEndpointStore();
    final observed = _mkRecord(
      endpointSeed: 0x10,
      peerNodeNum: 99,
      trustLevel: OverlayEndpointTrustLevel.observed,
      lastSeenMs: 5_000,
    );
    final verified = _mkRecord(
      endpointSeed: 0x20,
      peerNodeNum: 99,
      trustLevel: OverlayEndpointTrustLevel.signatureVerified,
      lastSeenMs: 3_000, // older but higher trust
    );
    await s.upsert(observed);
    await s.upsert(verified);
    final hits = await s.getByPeerNodeNum(99);
    expect(hits.first.endpointId[0], 0x20);
  });

  test('count / loadAll / delete', () async {
    final s = await openInMemoryEndpointStore();
    await s.upsert(_mkRecord(endpointSeed: 0x01));
    await s.upsert(_mkRecord(endpointSeed: 0x02));
    expect(await s.count(), 2);
    expect((await s.loadAll()).length, 2);
    final first = (await s.loadAll()).first;
    await s.delete(first.endpointId);
    expect(await s.count(), 1);
  });

  test('calling methods before init throws', () {
    final s = OverlayEndpointStore(testDbPath: ':memory:');
    expect(() => s.getByEndpointId(Uint8List(8)), throwsStateError);
  });
}
