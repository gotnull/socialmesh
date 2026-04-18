// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tests for [OverlayHandshakeCodec] — the P3 signed LINK_OPEN body.
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_handshake_signer.dart';

Uint8List _mkBytes(int length, int seed) {
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = (seed + i) & 0xFF;
  }
  return out;
}

void main() {
  test('body length is 110 bytes', () {
    expect(OverlayHandshakeCodec.bodyLength, 110);
    expect(OverlayHandshakeCodec.signedRegionLength, 46);
    expect(OverlayHandshakeCodec.signatureOffset, 46);
  });

  test('buildSignedRegion produces the canonical byte layout', () {
    final pk = _mkBytes(32, 0x10);
    final nonce = _mkBytes(8, 0x20);
    final region = OverlayHandshakeCodec.buildSignedRegion(
      flags: overlayHandshakeFlagCapabilityPresent,
      senderPublicKey: pk,
      capabilityBitset: 0x01020304,
      nonce: nonce,
    );
    expect(region.length, 46);
    expect(region[0], 0x01); // schema_version
    expect(region[1], 0x01); // flags
    expect(region.sublist(2, 34), equals(pk));
    // capability_bitset 0x01020304 LE → 04 03 02 01
    expect(region.sublist(34, 38), equals(Uint8List.fromList([4, 3, 2, 1])));
    expect(region.sublist(38, 46), equals(nonce));
  });

  test('encode roundtrips through decode', () {
    final pk = _mkBytes(32, 1);
    final nonce = _mkBytes(8, 2);
    final region = OverlayHandshakeCodec.buildSignedRegion(
      flags: overlayHandshakeFlagCapabilityPresent,
      senderPublicKey: pk,
      capabilityBitset: 0xDEADBEEF,
      nonce: nonce,
    );
    final fakeSignature = _mkBytes(64, 0x80);
    final body = OverlayHandshakeCodec.encode(
      signedRegion: region,
      signature: fakeSignature,
    );
    expect(body.length, 110);
    final decoded = OverlayHandshakeCodec.decode(body);
    expect(decoded.isOk, isTrue);
    expect(decoded.body!.flags, overlayHandshakeFlagCapabilityPresent);
    expect(decoded.body!.senderPublicKey, equals(pk));
    expect(decoded.body!.capabilityBitset, 0xDEADBEEF);
    expect(decoded.body!.nonce, equals(nonce));
    expect(decoded.body!.signature, equals(fakeSignature));
  });

  test('decode rejects wrong length', () {
    final r = OverlayHandshakeCodec.decode(Uint8List(42));
    expect(r.error, OverlayHandshakeDecodeError.badLength);
  });

  test('decode rejects bad schema version', () {
    final body = Uint8List(110);
    body[0] = 0x02;
    final r = OverlayHandshakeCodec.decode(body);
    expect(r.error, OverlayHandshakeDecodeError.badSchema);
  });

  test('decode rejects reserved flag bits', () {
    final region = OverlayHandshakeCodec.buildSignedRegion(
      flags: 0x02, // reserved bit
      senderPublicKey: _mkBytes(32, 0),
      capabilityBitset: 0,
      nonce: _mkBytes(8, 0),
    );
    final body = OverlayHandshakeCodec.encode(
      signedRegion: region,
      signature: _mkBytes(64, 0),
    );
    final r = OverlayHandshakeCodec.decode(body);
    expect(r.error, OverlayHandshakeDecodeError.badFlags);
  });

  test('buildSignedRegion rejects wrong-length pubkey or nonce', () {
    expect(
      () => OverlayHandshakeCodec.buildSignedRegion(
        flags: 0,
        senderPublicKey: Uint8List(16),
        capabilityBitset: 0,
        nonce: _mkBytes(8, 0),
      ),
      throwsArgumentError,
    );
    expect(
      () => OverlayHandshakeCodec.buildSignedRegion(
        flags: 0,
        senderPublicKey: _mkBytes(32, 0),
        capabilityBitset: 0,
        nonce: Uint8List(4),
      ),
      throwsArgumentError,
    );
  });

  test('encode rejects wrong-length region or signature', () {
    expect(
      () => OverlayHandshakeCodec.encode(
        signedRegion: Uint8List(10),
        signature: _mkBytes(64, 0),
      ),
      throwsArgumentError,
    );
    expect(
      () => OverlayHandshakeCodec.encode(
        signedRegion: Uint8List(46),
        signature: Uint8List(32),
      ),
      throwsArgumentError,
    );
  });

  test('generateNonce returns 8 random bytes', () {
    final a = OverlayHandshakeCodec.generateNonce();
    final b = OverlayHandshakeCodec.generateNonce();
    expect(a.length, 8);
    expect(b.length, 8);
    // Two calls almost certainly differ.
    expect(a, isNot(equals(b)));
  });

  test('generateNonce is deterministic with seeded Random', () {
    final r1 = Random(42);
    final r2 = Random(42);
    final a = OverlayHandshakeCodec.generateNonce(randomSource: r1);
    final b = OverlayHandshakeCodec.generateNonce(randomSource: r2);
    expect(a, equals(b));
  });
}
