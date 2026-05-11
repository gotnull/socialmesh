// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D42-A - MeshCorePathOverlay model + pure resolver pins.
//
// Pinned invariants:
//   - fromContact resolves hop bytes to contacts-with-location.
//   - Missing hops surface as latLng=null (no fabricated position).
//   - Collision tiebreaker: newest lastSeen wins.
//   - Flood paths return null (no overlay).
//   - pathOverride=-1 (Force Flood) returns null.
//   - pathOverride=0 (Force Direct) draws self→target only.
//   - pathOverrideBytes takes precedence over live `path`.
//   - Empty / 0-length hops list builds a direct overlay.
//   - >64-byte hopBytes in fromHistory rejected (returns null).
//   - drawablePoints filters null-latLng hops out.
//   - hasDrawableData requires ≥2 points.
//   - Hop label is 2-char lowercase hex.
//   - SelfInfo with (0,0) treated as unknown location.
//   - toString / labels never contain a full pubkey hex.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/models/meshcore_path_overlay.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

MeshCoreContact _contact({
  required int firstByte,
  String name = '',
  double? lat,
  double? lng,
  DateTime? lastSeen,
  Uint8List? path,
  int pathLength = -1,
  int? pathOverride,
  Uint8List? pathOverrideBytes,
}) {
  final pubKey = Uint8List(32);
  pubKey[0] = firstByte;
  // Fill remaining bytes deterministically so two contacts with the
  // same first byte are still distinct identities.
  for (int i = 1; i < 32; i++) {
    pubKey[i] = (firstByte + i) & 0xFF;
  }
  return MeshCoreContact(
    publicKey: pubKey,
    name: name,
    type: MeshCoreAdvType.repeater,
    pathLength: pathLength,
    path: path ?? Uint8List(0),
    pathOverride: pathOverride,
    pathOverrideBytes: pathOverrideBytes,
    latitude: lat,
    longitude: lng,
    lastSeen: lastSeen ?? DateTime(2026, 5, 11, 12),
  );
}

MeshCoreSelfInfo _selfInfo({double? lat, double? lng}) {
  return MeshCoreSelfInfo(
    advType: 1,
    txPowerDbm: 22,
    maxLoraTxPower: 22,
    pubKey: Uint8List.fromList(List.generate(32, (i) => 0xAA - i)),
    latitude: lat != null ? (lat * 1e7).round() : null,
    longitude: lng != null ? (lng * 1e7).round() : null,
    nodeName: 'self',
    rawPayload: Uint8List(0),
  );
}

void main() {
  group('MeshCorePathOverlay.fromContact', () {
    test('flood path (pathLength == -1, no override) returns null', () {
      final target = _contact(
        firstByte: 0x10,
        lat: 1.0,
        lng: 2.0,
        pathLength: -1,
      );
      final overlay = MeshCorePathOverlay.fromContact(
        target: target,
        contacts: const [],
        selfInfo: null,
      );
      expect(overlay, isNull);
    });

    test('pathOverride == -1 (Force Flood) returns null', () {
      final target = _contact(
        firstByte: 0x10,
        lat: 1.0,
        lng: 2.0,
        pathOverride: -1,
        pathOverrideBytes: null,
      );
      final overlay = MeshCorePathOverlay.fromContact(
        target: target,
        contacts: const [],
        selfInfo: null,
      );
      expect(overlay, isNull);
    });

    test('pathOverride == 0 (Force Direct) builds self→target only', () {
      final target = _contact(
        firstByte: 0x10,
        lat: 1.0,
        lng: 2.0,
        pathOverride: 0,
        pathOverrideBytes: null,
      );
      final overlay = MeshCorePathOverlay.fromContact(
        target: target,
        contacts: const [],
        selfInfo: _selfInfo(lat: 4.0, lng: 5.0),
      );
      expect(overlay, isNotNull);
      expect(overlay!.hops, isEmpty);
      expect(overlay.originLatLng, LatLng(4.0, 5.0));
      expect(overlay.targetLatLng, LatLng(1.0, 2.0));
      expect(overlay.drawablePoints(), hasLength(2));
      expect(overlay.hasDrawableData, isTrue);
      expect(overlay.isForced, isTrue);
    });

    test('resolves hop bytes to contacts with location', () {
      final hopA = _contact(firstByte: 0x11, lat: 10.0, lng: 20.0);
      final hopB = _contact(firstByte: 0x22, lat: 30.0, lng: 40.0);
      final target = _contact(
        firstByte: 0x99,
        lat: 50.0,
        lng: 60.0,
        pathLength: 2,
        path: Uint8List.fromList([0x11, 0x22]),
      );
      final overlay = MeshCorePathOverlay.fromContact(
        target: target,
        contacts: [hopA, hopB, target],
        selfInfo: _selfInfo(lat: 0.5, lng: 0.7),
      )!;
      expect(overlay.hops, hasLength(2));
      expect(overlay.hops[0].byte, 0x11);
      expect(overlay.hops[0].label, '11');
      expect(overlay.hops[0].latLng, LatLng(10.0, 20.0));
      expect(overlay.hops[1].byte, 0x22);
      expect(overlay.hops[1].label, '22');
      expect(overlay.hops[1].latLng, LatLng(30.0, 40.0));
      expect(overlay.drawablePoints(), hasLength(4));
    });

    test('hop with no matching contact surfaces as null latLng', () {
      final target = _contact(
        firstByte: 0x99,
        lat: 50.0,
        lng: 60.0,
        pathLength: 2,
        path: Uint8List.fromList([0x11, 0x22]),
      );
      final overlay = MeshCorePathOverlay.fromContact(
        target: target,
        contacts: [target],
        selfInfo: _selfInfo(lat: 1.0, lng: 1.0),
      )!;
      expect(overlay.hops, hasLength(2));
      expect(overlay.hops[0].latLng, isNull);
      expect(overlay.hops[1].latLng, isNull);
      // self + target = 2 drawable points
      expect(overlay.drawablePoints(), hasLength(2));
      expect(overlay.knownHopCount, 0);
      expect(overlay.totalHopCount, 2);
    });

    test('hop matched contact must have location to contribute coords', () {
      // Hop A: same byte, but NO location.
      final hopA = _contact(firstByte: 0x11);
      final target = _contact(
        firstByte: 0x99,
        lat: 50.0,
        lng: 60.0,
        pathLength: 1,
        path: Uint8List.fromList([0x11]),
      );
      final overlay = MeshCorePathOverlay.fromContact(
        target: target,
        contacts: [hopA, target],
        selfInfo: _selfInfo(lat: 1.0, lng: 1.0),
      )!;
      expect(overlay.hops.single.latLng, isNull);
    });

    test('collision: newest lastSeen wins', () {
      final older = _contact(
        firstByte: 0x11,
        lat: 10.0,
        lng: 20.0,
        name: 'OLD',
        lastSeen: DateTime(2026, 1, 1),
      );
      final newer = _contact(
        firstByte: 0x11,
        lat: 99.0,
        lng: 88.0,
        name: 'NEW',
        lastSeen: DateTime(2026, 12, 31),
      );
      final target = _contact(
        firstByte: 0x99,
        lat: 50.0,
        lng: 60.0,
        pathLength: 1,
        path: Uint8List.fromList([0x11]),
      );
      final overlay = MeshCorePathOverlay.fromContact(
        target: target,
        contacts: [older, newer, target],
        selfInfo: null,
      )!;
      expect(overlay.hops.single.latLng, LatLng(99.0, 88.0));
      expect(overlay.hops.single.displayName, 'NEW');
    });

    test('pathOverrideBytes takes precedence over live path', () {
      final hop = _contact(firstByte: 0xAA, lat: 1.0, lng: 1.0);
      final target = _contact(
        firstByte: 0x99,
        lat: 50.0,
        lng: 60.0,
        pathLength: 2,
        path: Uint8List.fromList([0x11, 0x22]), // live path bytes
        pathOverride: 1,
        pathOverrideBytes: Uint8List.fromList([0xAA]), // forced override
      );
      final overlay = MeshCorePathOverlay.fromContact(
        target: target,
        contacts: [hop, target],
        selfInfo: null,
      )!;
      expect(overlay.hops, hasLength(1));
      expect(overlay.hops.single.byte, 0xAA);
      expect(overlay.isForced, isTrue);
    });

    test('direct route (pathLength == 0) with both endpoints', () {
      final target = _contact(
        firstByte: 0x99,
        lat: 50.0,
        lng: 60.0,
        pathLength: 0,
      );
      final overlay = MeshCorePathOverlay.fromContact(
        target: target,
        contacts: const [],
        selfInfo: _selfInfo(lat: 1.0, lng: 1.0),
      )!;
      expect(overlay.hops, isEmpty);
      expect(overlay.drawablePoints(), hasLength(2));
    });

    test('all hops unresolved + no endpoints -> hasDrawableData false', () {
      final target = _contact(
        firstByte: 0x99,
        pathLength: 1,
        path: Uint8List.fromList([0x11]),
      );
      final overlay = MeshCorePathOverlay.fromContact(
        target: target,
        contacts: const [],
        selfInfo: null,
      )!;
      expect(overlay.hops, hasLength(1));
      expect(overlay.drawablePoints(), isEmpty);
      expect(overlay.hasDrawableData, isFalse);
    });
  });

  group('MeshCorePathOverlay.fromHistory', () {
    test('builds overlay from saved hop bytes', () {
      final hopA = _contact(firstByte: 0x11, lat: 1.0, lng: 2.0);
      final target = _contact(firstByte: 0x99, lat: 5.0, lng: 6.0);
      final overlay = MeshCorePathOverlay.fromHistory(
        target: target,
        contacts: [hopA, target],
        selfInfo: _selfInfo(lat: 0.0, lng: 0.0),
        hopBytes: Uint8List.fromList([0x11]),
      )!;
      expect(overlay.source, MeshCorePathOverlaySource.history);
      expect(overlay.hops.single.byte, 0x11);
      expect(overlay.hops.single.latLng, LatLng(1.0, 2.0));
    });

    test('rejects hopBytes longer than 64', () {
      final target = _contact(firstByte: 0x99, lat: 5.0, lng: 6.0);
      final overlay = MeshCorePathOverlay.fromHistory(
        target: target,
        contacts: const [],
        selfInfo: null,
        hopBytes: Uint8List.fromList(List.filled(65, 0x11)),
      );
      expect(overlay, isNull);
    });

    test('64-byte path accepted', () {
      final target = _contact(firstByte: 0x99, lat: 5.0, lng: 6.0);
      final overlay = MeshCorePathOverlay.fromHistory(
        target: target,
        contacts: const [],
        selfInfo: null,
        hopBytes: Uint8List.fromList(List.filled(64, 0x11)),
      )!;
      expect(overlay.hops, hasLength(64));
    });
  });

  group('hop labels are 2-char hex; no full-pubkey leakage', () {
    test('label is 2-char lowercase hex per hop byte', () {
      final target = _contact(
        firstByte: 0x99,
        lat: 5.0,
        lng: 6.0,
        pathLength: 4,
        path: Uint8List.fromList([0x00, 0x0F, 0xAA, 0xFF]),
      );
      final overlay = MeshCorePathOverlay.fromContact(
        target: target,
        contacts: const [],
        selfInfo: null,
      )!;
      expect(
        overlay.hops.map((h) => h.label).toList(),
        orderedEquals(['00', '0f', 'aa', 'ff']),
      );
    });

    test('toString / labels never contain a 64-char pubkey hex', () {
      final hop = _contact(firstByte: 0x11, lat: 1.0, lng: 2.0);
      final target = _contact(
        firstByte: 0x99,
        lat: 5.0,
        lng: 6.0,
        pathLength: 1,
        path: Uint8List.fromList([0x11]),
      );
      final overlay = MeshCorePathOverlay.fromContact(
        target: target,
        contacts: [hop, target],
        selfInfo: _selfInfo(lat: 1.0, lng: 1.0),
      )!;
      final combined =
          overlay.hops.map((h) => h.toString()).join(' ') +
          (overlay.contactPubKeyHex);
      // 32-char or 64-char hex shapes must not appear in toString. The
      // contactPubKeyHex IS a full pubkey - intentionally - and is
      // never rendered to the user; it's an internal id.
      final hopToStrings = overlay.hops.map((h) => h.toString()).join(' ');
      expect(RegExp(r'[0-9a-fA-F]{32}').hasMatch(hopToStrings), isFalse);
      expect(RegExp(r'[0-9a-fA-F]{64}').hasMatch(hopToStrings), isFalse);
      // Reference the contact pubkey too to keep the locals used.
      expect(combined, isNotEmpty);
    });
  });

  group('SelfInfo position edge cases', () {
    test('(0, 0) lat/lng treated as unknown', () {
      final target = _contact(
        firstByte: 0x99,
        lat: 5.0,
        lng: 6.0,
        pathLength: 0,
      );
      final overlay = MeshCorePathOverlay.fromContact(
        target: target,
        contacts: const [],
        selfInfo: _selfInfo(lat: 0.0, lng: 0.0),
      )!;
      expect(overlay.originLatLng, isNull);
      // target only - 1 point - not drawable
      expect(overlay.drawablePoints(), hasLength(1));
      expect(overlay.hasDrawableData, isFalse);
    });

    test('null selfInfo -> null origin', () {
      final target = _contact(
        firstByte: 0x99,
        lat: 5.0,
        lng: 6.0,
        pathLength: 0,
      );
      final overlay = MeshCorePathOverlay.fromContact(
        target: target,
        contacts: const [],
        selfInfo: null,
      )!;
      expect(overlay.originLatLng, isNull);
    });
  });
}
