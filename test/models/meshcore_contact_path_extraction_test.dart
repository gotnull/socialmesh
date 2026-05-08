// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34c-A — model-level `parseContact` adapter regression pins.
//
// The model-level [parseContact] in `lib/models/meshcore_contact.dart` is a
// thin adapter over the canonical byte-layout parser at
// `lib/services/meshcore/protocol/meshcore_messages.dart`. Pre-D34c-A this
// model-level function was an out-of-date inline parser that silently
// dropped the firmware's path bytes (returned `Uint8List(0)`
// unconditionally) and read fields at the wrong offsets. The canonical
// parser was already correct (D24.B). D34c-A switches the adapter to
// delegate, so callers that take a [MeshCoreContact] (rather than the
// richer [MeshCoreContactInfo]) now see the path bytes too.
//
// Pinned invariants:
//   - pathLength > 0  → exactly N bytes copied into MeshCoreContact.path
//   - pathLength == 0 → MeshCoreContact.path is empty
//   - pathLength == 0xFF → maps to -1 (flood sentinel) and path is empty
//   - GPS lat==0 && lon==0 means "no real location" — both null on the model
//   - name and adv_type pass through correctly (D24.B layout)
//
// Wire-byte layout pinning lives in
// `test/services/meshcore/protocol/parse_contact_layout_test.dart`.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/meshcore_contact.dart';

/// Mirror of the canonical 147-byte CONTACT response builder used by
/// `parse_contact_layout_test.dart`. Kept private to this file so the
/// model-level test stays self-contained.
Uint8List _buildPayload({
  required Uint8List pubKey,
  int advType = 1,
  int flags = 0,
  int pathLen = 0,
  Uint8List? path,
  String name = '',
  int lastAdvertTs = 0,
  int gpsLat = 0,
  int gpsLon = 0,
  int lastMod = 0,
}) {
  assert(pubKey.length == 32);
  final out = Uint8List(147);
  out.setRange(0, 32, pubKey);
  out[32] = advType;
  out[33] = flags;
  out[34] = pathLen & 0xff;
  if (path != null) {
    out.setRange(35, 35 + path.length.clamp(0, 64), path.take(64).toList());
  }
  final nameBytes = utf8.encode(name);
  for (var i = 0; i < nameBytes.length && i < 32; i++) {
    out[99 + i] = nameBytes[i];
  }
  out[131] = lastAdvertTs & 0xff;
  out[132] = (lastAdvertTs >> 8) & 0xff;
  out[133] = (lastAdvertTs >> 16) & 0xff;
  out[134] = (lastAdvertTs >> 24) & 0xff;
  out[135] = gpsLat & 0xff;
  out[136] = (gpsLat >> 8) & 0xff;
  out[137] = (gpsLat >> 16) & 0xff;
  out[138] = (gpsLat >> 24) & 0xff;
  out[139] = gpsLon & 0xff;
  out[140] = (gpsLon >> 8) & 0xff;
  out[141] = (gpsLon >> 16) & 0xff;
  out[142] = (gpsLon >> 24) & 0xff;
  out[143] = lastMod & 0xff;
  out[144] = (lastMod >> 8) & 0xff;
  out[145] = (lastMod >> 16) & 0xff;
  out[146] = (lastMod >> 24) & 0xff;
  return out;
}

void main() {
  group('parseContact (model adapter, D34c-A)', () {
    test('pathLength > 0: extracts exactly N path bytes into '
        'MeshCoreContact.path (closes pre-D34c-A drop-to-empty stub)', () {
      final pubKey = Uint8List.fromList(List.generate(32, (i) => i + 1));
      final path = Uint8List.fromList([0xAA, 0xBB, 0xCC, 0xDD, 0xEE]);
      final payload = _buildPayload(
        pubKey: pubKey,
        pathLen: 5,
        path: path,
        name: 'WisMeshCore',
      );
      final contact = parseContact(payload);
      expect(contact, isNotNull);
      expect(contact!.pathLength, 5);
      expect(contact.path, equals(path));
      expect(contact.name, 'WisMeshCore');
    });

    test('pathLength == 0: MeshCoreContact.path is empty (direct route)', () {
      final pubKey = Uint8List.fromList(List.generate(32, (i) => 0x10 + i));
      final payload = _buildPayload(pubKey: pubKey, pathLen: 0, name: 'Direct');
      final contact = parseContact(payload);
      expect(contact, isNotNull);
      expect(contact!.pathLength, 0);
      expect(contact.path, isEmpty);
    });

    test('pathLength == 0xFF: maps to -1 flood sentinel and path is empty', () {
      final pubKey = Uint8List.fromList(List.generate(32, (i) => 0x20 + i));
      final payload = _buildPayload(
        pubKey: pubKey,
        pathLen: 0xFF,
        name: 'Flood',
      );
      final contact = parseContact(payload);
      expect(contact, isNotNull);
      expect(contact!.pathLength, -1);
      expect(contact.path, isEmpty);
    });

    test('absent location (lat==0 && lon==0) yields null lat/lon on model', () {
      final pubKey = Uint8List.fromList(List.generate(32, (i) => 0x30 + i));
      final payload = _buildPayload(pubKey: pubKey, pathLen: 0, name: 'NoGps');
      final contact = parseContact(payload);
      expect(contact, isNotNull);
      expect(contact!.latitude, isNull);
      expect(contact.longitude, isNull);
    });

    test('present location passes through to model (degree scale)', () {
      // Canonical parser keeps the firmware's int32 raw scale; the
      // [MeshCoreContactInfo.latitudeDegrees] getter divides by 1e7.
      // The adapter forwards the degrees-scaled float onto
      // [MeshCoreContact.latitude]. We pin a representative pair so a
      // future scale change surfaces as a test diff.
      final pubKey = Uint8List.fromList(List.generate(32, (i) => 0x40 + i));
      final payload = _buildPayload(
        pubKey: pubKey,
        pathLen: 0,
        name: 'GeoNode',
        gpsLat: 514_080_000, // raw int32; 51.408° via /1e7
        gpsLon: -1_234_000,
      );
      final contact = parseContact(payload);
      expect(contact, isNotNull);
      expect(contact!.latitude, closeTo(51.408, 1e-6));
      expect(contact.longitude, closeTo(-0.1234, 1e-6));
    });

    test('payload shorter than the canonical minimum returns null', () {
      // The canonical parser rejects anything below the 135-byte
      // mandatory layout (pub+type+flags+plen+path+name+ts).
      final tooShort = Uint8List(40);
      final contact = parseContact(tooShort);
      expect(contact, isNull);
    });

    test('roundtrip: name and adv_type survive through the adapter', () {
      final pubKey = Uint8List.fromList(List.generate(32, (i) => 0x50 + i));
      final payload = _buildPayload(
        pubKey: pubKey,
        advType: 2, // repeater
        pathLen: 1,
        path: Uint8List.fromList([0xAB]),
        name: 'RepeaterX',
      );
      final contact = parseContact(payload);
      expect(contact, isNotNull);
      expect(contact!.type, 2);
      expect(contact.isRepeater, isTrue);
      expect(contact.name, 'RepeaterX');
      expect(contact.path, equals(Uint8List.fromList([0xAB])));
    });
  });
}
