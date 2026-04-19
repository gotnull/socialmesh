// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Wire-format tests for overlay v0.3 secure frames.
///
/// Covers byte layout, round-trip fidelity, length guards, and the
/// transcript / AEAD helper builders. All tests operate on fixed
/// byte patterns so the file also doubles as a wire-format
/// specification cross-check.
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_secure_codec.dart';
import 'package:socialmesh/services/protocol/overlay/overlay_types.dart';

Uint8List _bytes(int length, int fill) =>
    Uint8List.fromList(List<int>.filled(length, fill));

void main() {
  group('OverlaySecureCodec INIT', () {
    test('encoded payload is exactly 121 bytes', () {
      final out = OverlaySecureCodec.encodeInit(
        version: overlaySecureSchemaVersion,
        initEndpointId: _bytes(8, 0x11),
        initX25519Pub: _bytes(32, 0x22),
        nonceI: _bytes(16, 0x33),
        signature: _bytes(64, 0x44),
      );
      expect(out.length, overlaySecureHandshakePayloadLen);
      expect(out.length, 121);
    });

    test('field order and offsets match the spec', () {
      final out = OverlaySecureCodec.encodeInit(
        version: 0x01,
        initEndpointId: _bytes(8, 0xAA),
        initX25519Pub: _bytes(32, 0xBB),
        nonceI: _bytes(16, 0xCC),
        signature: _bytes(64, 0xDD),
      );
      expect(out[0], 0x01);
      expect(out.sublist(1, 9), everyElement(0xAA));
      expect(out.sublist(9, 41), everyElement(0xBB));
      expect(out.sublist(41, 57), everyElement(0xCC));
      expect(out.sublist(57, 121), everyElement(0xDD));
    });

    test('decode recovers every field', () {
      final out = OverlaySecureCodec.encodeInit(
        version: 0x01,
        initEndpointId: _bytes(8, 0xA1),
        initX25519Pub: _bytes(32, 0xB2),
        nonceI: _bytes(16, 0xC3),
        signature: _bytes(64, 0xD4),
      );
      final dec = OverlaySecureCodec.decodeInit(out)!;
      expect(dec.version, 0x01);
      expect(dec.initEndpointId, _bytes(8, 0xA1));
      expect(dec.initX25519Pub, _bytes(32, 0xB2));
      expect(dec.nonceI, _bytes(16, 0xC3));
      expect(dec.signature, _bytes(64, 0xD4));
    });

    test('decode returns null on wrong length', () {
      expect(OverlaySecureCodec.decodeInit(Uint8List(120)), isNull);
      expect(OverlaySecureCodec.decodeInit(Uint8List(122)), isNull);
      expect(OverlaySecureCodec.decodeInit(Uint8List(0)), isNull);
    });

    test('encode rejects any field with wrong length', () {
      expect(
        () => OverlaySecureCodec.encodeInit(
          version: 0x01,
          initEndpointId: _bytes(7, 0),
          initX25519Pub: _bytes(32, 0),
          nonceI: _bytes(16, 0),
          signature: _bytes(64, 0),
        ),
        throwsArgumentError,
      );
      expect(
        () => OverlaySecureCodec.encodeInit(
          version: 0x01,
          initEndpointId: _bytes(8, 0),
          initX25519Pub: _bytes(33, 0),
          nonceI: _bytes(16, 0),
          signature: _bytes(64, 0),
        ),
        throwsArgumentError,
      );
    });
  });

  group('OverlaySecureCodec ACK', () {
    test('encoded payload is exactly 121 bytes (same shape as INIT)', () {
      final out = OverlaySecureCodec.encodeAck(
        version: overlaySecureSchemaVersion,
        respEndpointId: _bytes(8, 0),
        respX25519Pub: _bytes(32, 0),
        nonceR: _bytes(16, 0),
        signature: _bytes(64, 0),
      );
      expect(out.length, 121);
    });

    test('round-trip preserves fields', () {
      final out = OverlaySecureCodec.encodeAck(
        version: 0x01,
        respEndpointId: _bytes(8, 0xEE),
        respX25519Pub: _bytes(32, 0xDD),
        nonceR: _bytes(16, 0xCC),
        signature: _bytes(64, 0xBB),
      );
      final dec = OverlaySecureCodec.decodeAck(out)!;
      expect(dec.version, 0x01);
      expect(dec.respEndpointId, _bytes(8, 0xEE));
      expect(dec.respX25519Pub, _bytes(32, 0xDD));
      expect(dec.nonceR, _bytes(16, 0xCC));
      expect(dec.signature, _bytes(64, 0xBB));
    });
  });

  group('OverlaySecureCodec DATA', () {
    test('header is 21 bytes + ciphertext', () {
      final out = OverlaySecureCodec.encodeData(
        subtype: OverlaySecureDataSubtype.generic.code,
        seq: 0,
        aeadTag: _bytes(16, 0),
        ciphertext: _bytes(50, 0xAB),
      );
      expect(out.length, overlaySecureDataHeaderLen + 50);
      expect(out.length, 21 + 50);
    });

    test('subtype + seq + tag land at the expected offsets', () {
      final out = OverlaySecureCodec.encodeData(
        subtype: 0x02,
        seq: 0xDEADBEEF,
        aeadTag: _bytes(16, 0x7F),
        ciphertext: Uint8List.fromList(<int>[1, 2, 3]),
      );
      expect(out[0], 0x02);
      expect(out[1], 0xDE);
      expect(out[2], 0xAD);
      expect(out[3], 0xBE);
      expect(out[4], 0xEF);
      expect(out.sublist(5, 21), everyElement(0x7F));
      expect(out.sublist(21), Uint8List.fromList(<int>[1, 2, 3]));
    });

    test('decode splits subtype / seq / tag / ciphertext cleanly', () {
      final out = OverlaySecureCodec.encodeData(
        subtype: 0x03,
        seq: 42,
        aeadTag: _bytes(16, 0x99),
        ciphertext: Uint8List.fromList(<int>[0xAA, 0xBB]),
      );
      final dec = OverlaySecureCodec.decodeData(out)!;
      expect(dec.rawSubtype, 0x03);
      expect(dec.subtype, OverlaySecureDataSubtype.dmReaction);
      expect(dec.seq, 42);
      expect(dec.aeadTag, _bytes(16, 0x99));
      expect(dec.ciphertext, Uint8List.fromList(<int>[0xAA, 0xBB]));
    });

    test('decode surfaces unknown subtype as null enum but raw preserved', () {
      final out = OverlaySecureCodec.encodeData(
        subtype: 0xEF,
        seq: 1,
        aeadTag: _bytes(16, 0),
        ciphertext: Uint8List(0),
      );
      final dec = OverlaySecureCodec.decodeData(out)!;
      expect(dec.rawSubtype, 0xEF);
      expect(dec.subtype, isNull);
    });

    test('decode returns null if shorter than header', () {
      expect(OverlaySecureCodec.decodeData(Uint8List(20)), isNull);
      expect(OverlaySecureCodec.decodeData(Uint8List(0)), isNull);
    });

    test('encode rejects out-of-range seq / subtype', () {
      expect(
        () => OverlaySecureCodec.encodeData(
          subtype: 0x01,
          seq: -1,
          aeadTag: _bytes(16, 0),
          ciphertext: Uint8List(0),
        ),
        throwsArgumentError,
      );
      expect(
        () => OverlaySecureCodec.encodeData(
          subtype: 0x100,
          seq: 0,
          aeadTag: _bytes(16, 0),
          ciphertext: Uint8List(0),
        ),
        throwsArgumentError,
      );
    });
  });

  group('Transcript builders', () {
    test('buildTranscriptInit layout is 70 bytes and spec-aligned', () {
      final t = OverlaySecureCodec.buildTranscriptInit(
        version: 0x01,
        linkId: 0x01020304,
        initEndpointId: _bytes(8, 0xAA),
        respEndpointId: _bytes(8, 0xBB),
        initX25519Pub: _bytes(32, 0xCC),
        nonceI: _bytes(16, 0xDD),
      );
      expect(t.length, 70);
      expect(t[0], 0x01); // version
      expect(t[1], OverlayLinkMsgType.linkSecureInit.code);
      expect(t.sublist(2, 6), Uint8List.fromList(<int>[1, 2, 3, 4]));
      expect(t.sublist(6, 14), everyElement(0xAA));
      expect(t.sublist(14, 22), everyElement(0xBB));
      expect(t.sublist(22, 54), everyElement(0xCC));
      expect(t.sublist(54, 70), everyElement(0xDD));
    });

    test('buildTranscriptFull layout is 118 bytes and spec-aligned', () {
      final t = OverlaySecureCodec.buildTranscriptFull(
        version: 0x01,
        linkId: 0x01020304,
        initEndpointId: _bytes(8, 0xAA),
        respEndpointId: _bytes(8, 0xBB),
        initX25519Pub: _bytes(32, 0xCC),
        respX25519Pub: _bytes(32, 0xEE),
        nonceI: _bytes(16, 0x11),
        nonceR: _bytes(16, 0x22),
      );
      expect(t.length, 118);
      expect(t[0], 0x01);
      expect(t[1], OverlayLinkMsgType.linkSecureAck.code);
      expect(t.sublist(2, 6), Uint8List.fromList(<int>[1, 2, 3, 4]));
      expect(t.sublist(6, 14), everyElement(0xAA));
      expect(t.sublist(14, 22), everyElement(0xBB));
      expect(t.sublist(22, 54), everyElement(0xCC));
      expect(t.sublist(54, 86), everyElement(0xEE));
      expect(t.sublist(86, 102), everyElement(0x11));
      expect(t.sublist(102, 118), everyElement(0x22));
    });
  });

  group('AEAD nonce and AAD', () {
    test('buildAeadNonce layout: BE(epoch) | 0x00000000 | BE(seq)', () {
      final n = OverlaySecureCodec.buildAeadNonce(
        epochDir: 0x0A0B0C0D,
        seq: 0x11223344,
      );
      expect(n.length, 12);
      expect(
        n,
        Uint8List.fromList(<int>[
          0x0A, 0x0B, 0x0C, 0x0D, // epoch
          0x00, 0x00, 0x00, 0x00, // reserved middle
          0x11, 0x22, 0x33, 0x44, // seq
        ]),
      );
    });

    test('buildAead layout is 26 bytes and spec-aligned', () {
      final a = OverlaySecureCodec.buildAead(
        subtype: OverlaySecureDataSubtype.dmText.code,
        linkId: 0x01020304,
        seq: 0xABCDEF00,
        initEndpointId: _bytes(8, 0xAA),
        respEndpointId: _bytes(8, 0xBB),
      );
      expect(a.length, 26);
      expect(a[0], OverlayLinkMsgType.linkSecureData.code);
      expect(a[1], OverlaySecureDataSubtype.dmText.code);
      expect(a.sublist(2, 6), Uint8List.fromList(<int>[1, 2, 3, 4]));
      expect(
        a.sublist(6, 10),
        Uint8List.fromList(<int>[0xAB, 0xCD, 0xEF, 0x00]),
      );
      expect(a.sublist(10, 18), everyElement(0xAA));
      expect(a.sublist(18, 26), everyElement(0xBB));
    });
  });
}
