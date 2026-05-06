// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D24.B — `parseContact` byte-layout regression pins.
//
// Pre-D24 the parser read a phantom layout (`pub_key + adv_type +
// path_len + lastmod(uint16) + lat + lon + name`) that did not
// match the firmware's contact-response writer. As a result the
// parser landed on the path-bytes slot when looking for the name
// field; with an empty path (typical for nearby contacts) the
// first byte was `0x00` and `readCString` returned an empty
// string. The firmware actually stored the contact's name; we
// just never read it. The corrected ground-truth layout is now:
//
//   [0..31]    pub_key                      (32 bytes)
//   [32]       adv_type                     (uint8)
//   [33]       flags                        (uint8, currently
//                                            unused by app)
//   [34]       path_len                     (uint8; 0xFF = flood)
//   [35..98]   path                         (64 bytes,
//                                            valid prefix = path_len)
//   [99..130]  name                         (32 bytes, null-padded
//                                            ASCII / UTF-8)
//   [131..134] last_advert_timestamp        (uint32 LE seconds)
//   [135..138] gps_lat                      (int32 LE; 0 = absent)
//   [139..142] gps_lon                      (int32 LE; 0 = absent)
//   [143..146] lastmod                      (uint32 LE; 0 = absent)
//
// These tests pin the corrected offsets so a future refactor
// can't silently regress the name read path that surfaces real
// contact names like "WisMeshCore" instead of falling back to
// the D23 redacted-fingerprint placeholder.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

/// Build a fully valid 147-byte CONTACT response payload
/// (`RESP_CODE_CONTACT` / `PUSH_CODE_NEW_ADVERT`) with the given
/// name, pubkey, adv_type, and path_len. All other fields default
/// to zero. The leading code byte is NOT included — `parseContact`
/// expects the payload after the codec strips it.
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
  // Name slot is 32 bytes, null-padded; firmware encodes as UTF-8.
  final nameBytes = utf8.encode(name);
  for (var i = 0; i < nameBytes.length && i < 32; i++) {
    out[99 + i] = nameBytes[i];
  }
  // last_advert_timestamp at 131..134
  out[131] = lastAdvertTs & 0xff;
  out[132] = (lastAdvertTs >> 8) & 0xff;
  out[133] = (lastAdvertTs >> 16) & 0xff;
  out[134] = (lastAdvertTs >> 24) & 0xff;
  // gps_lat at 135..138
  out[135] = gpsLat & 0xff;
  out[136] = (gpsLat >> 8) & 0xff;
  out[137] = (gpsLat >> 16) & 0xff;
  out[138] = (gpsLat >> 24) & 0xff;
  // gps_lon at 139..142
  out[139] = gpsLon & 0xff;
  out[140] = (gpsLon >> 8) & 0xff;
  out[141] = (gpsLon >> 16) & 0xff;
  out[142] = (gpsLon >> 24) & 0xff;
  // lastmod at 143..146
  out[143] = lastMod & 0xff;
  out[144] = (lastMod >> 8) & 0xff;
  out[145] = (lastMod >> 16) & 0xff;
  out[146] = (lastMod >> 24) & 0xff;
  return out;
}

void main() {
  group('parseContact (D24.B byte layout)', () {
    test('reads name from offset 99 (32-byte null-padded slot)', () {
      final pub = Uint8List.fromList(List.generate(32, (i) => 0x90 + (i % 16)));
      final payload = _buildPayload(pubKey: pub, name: 'WisMeshCore');

      final result = parseContact(payload);
      expect(result.isSuccess, isTrue);
      expect(result.value!.name, equals('WisMeshCore'));
    });

    test('name with trailing zero-padding terminates at first null', () {
      final pub = Uint8List.fromList(List.generate(32, (i) => i));
      final payload = _buildPayload(pubKey: pub, name: 'TerryDev');

      final result = parseContact(payload);
      expect(result.isSuccess, isTrue);
      // The raw 32-byte slot has 'TerryDev' followed by 24 null
      // bytes; `readCString` must stop at the first null.
      expect(result.value!.name, equals('TerryDev'));
      expect(result.value!.name.length, equals(8));
    });

    test('empty name slot returns empty string (not garbage path bytes)', () {
      // Pre-D24 with an empty path the parser read offset 44 as
      // the start of the name and got '' (because path[0]=0). Now
      // it reads offset 99 — also '' because the slot is zero-
      // padded — but for the RIGHT reason. Pin so a regression
      // that "shifts" the name offset stays caught.
      final pub = Uint8List.fromList(List.generate(32, (i) => 0xaa));
      final payload = _buildPayload(pubKey: pub, name: '');

      final result = parseContact(payload);
      expect(result.isSuccess, isTrue);
      expect(result.value!.name, isEmpty);
    });

    test('reads pub_key from offset 0..31', () {
      final pub = Uint8List.fromList(List.generate(32, (i) => 0x79 + (i % 7)));
      final payload = _buildPayload(pubKey: pub, name: 'ignored');

      final result = parseContact(payload);
      expect(result.isSuccess, isTrue);
      expect(result.value!.publicKey, equals(pub));
    });

    test('reads adv_type from offset 32', () {
      final pub = Uint8List.fromList(List.generate(32, (i) => i));
      // Type 2 = repeater per `MeshCoreAdvertTypes`.
      final payload = _buildPayload(pubKey: pub, advType: 2, name: 'Hub');

      final result = parseContact(payload);
      expect(result.isSuccess, isTrue);
      expect(result.value!.advType, equals(2));
    });

    test('flags byte at offset 33 is consumed but not surfaced', () {
      final pub = Uint8List.fromList(List.generate(32, (i) => i));
      final payload = _buildPayload(pubKey: pub, flags: 0x42, name: 'A');

      final result = parseContact(payload);
      expect(result.isSuccess, isTrue);
      // flags is intentionally not exposed on `MeshCoreContactInfo`
      // pending a future use case; pin only that the parser doesn't
      // confuse it for `path_len` or `name`.
      expect(result.value!.advType, equals(1));
      expect(result.value!.name, equals('A'));
    });

    test('reads path_len from offset 34 and slices path[35..]', () {
      final pub = Uint8List.fromList(List.generate(32, (i) => i));
      final path = Uint8List.fromList([0x11, 0x22, 0x33, 0x44, 0x55]);
      final payload = _buildPayload(
        pubKey: pub,
        pathLen: 5,
        path: path,
        name: 'PathPeer',
      );

      final result = parseContact(payload);
      expect(result.isSuccess, isTrue);
      expect(result.value!.pathLength, equals(5));
      expect(result.value!.pathBytes, equals(path));
      // Name unaffected by non-zero path bytes.
      expect(result.value!.name, equals('PathPeer'));
    });

    test('path_len 0xFF maps to -1 (flood marker)', () {
      final pub = Uint8List.fromList(List.generate(32, (i) => i));
      final payload = _buildPayload(pubKey: pub, pathLen: 0xFF, name: 'Far');

      final result = parseContact(payload);
      expect(result.isSuccess, isTrue);
      expect(result.value!.pathLength, equals(-1));
      // Flood means no direct path bytes are surfaced even though
      // the 64-byte slot may contain stale data.
      expect(result.value!.pathBytes, isEmpty);
    });

    test('rejects payloads shorter than the minimum 135 bytes', () {
      // Anything below `pubkey + type + flags + path_len + path +
      // name + last_advert_ts` cannot be parsed; the firmware
      // never sends shorter frames in practice.
      final result = parseContact(Uint8List(40));
      expect(result.isSuccess, isFalse);
      expect(result.error, contains('too short'));
    });

    test('ASCII names round-trip cleanly through readCString', () {
      // The firmware's name slot is documented as ASCII / UTF-8 in
      // upstream sources, but `readCString` historically uses
      // `String.fromCharCodes` (latin-1) for compatibility with
      // pre-D24 callers. Pure-ASCII names are the common case and
      // round-trip identically; pin that here. Multi-byte UTF-8
      // decoding is a pre-existing buffer-reader concern outside
      // D24.B scope.
      final pub = Uint8List.fromList(List.generate(32, (i) => i));
      for (final name in const ['TerryDev', 'WisMeshCore', 'Hub-01', 'A']) {
        final payload = _buildPayload(pubKey: pub, name: name);
        final result = parseContact(payload);
        expect(result.isSuccess, isTrue, reason: 'name="$name"');
        expect(result.value!.name, equals(name), reason: 'name="$name"');
      }
    });
  });
}
