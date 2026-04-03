// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/security/stl_envelope.dart';
import 'package:socialmesh/services/security/stl_middleware.dart';

void main() {
  group('StlMiddleware', () {
    late StlMiddleware middleware;
    late Ed25519 ed25519;

    setUp(() {
      ed25519 = Ed25519();
      middleware = StlMiddleware();
    });

    group('wrapOutbound', () {
      test('wraps payload with STL envelope', () async {
        final keyPair = await ed25519.newKeyPair();
        final pubKey = Uint8List.fromList(
          (await keyPair.extractPublicKey()).bytes,
        );

        Future<Uint8List> signFn(Uint8List data) async {
          final sig = await ed25519.sign(data, keyPair: keyPair);
          return Uint8List.fromList(sig.bytes);
        }

        final payload = Uint8List.fromList([0x14, 1, 2, 3, 4, 5]); // SPP offer

        final wrapped = await middleware.wrapOutbound(
          payload: payload,
          signFn: signFn,
          senderPubKey: pubKey,
        );

        // Should be 98 bytes overhead + original payload
        expect(wrapped.length, payload.length + StlOverhead.signedOnly);

        // Should be detectable as STL
        expect(StlEnvelope.isStlWrapped(wrapped), isTrue);

        // Should decode
        final envelope = StlEnvelope.decode(wrapped);
        expect(envelope, isNotNull);
        expect(envelope!.payload, payload);
        expect(envelope.senderPubKey, pubKey);
        expect(envelope.isSigned, isTrue);
        expect(envelope.isEncrypted, isFalse);
      });

      test('signature verifies after wrap', () async {
        final keyPair = await ed25519.newKeyPair();
        final pubKey = Uint8List.fromList(
          (await keyPair.extractPublicKey()).bytes,
        );

        Future<Uint8List> signFn(Uint8List data) async {
          final sig = await ed25519.sign(data, keyPair: keyPair);
          return Uint8List.fromList(sig.bytes);
        }

        final payload = Uint8List.fromList([0x15, 10, 20, 30]);

        final wrapped = await middleware.wrapOutbound(
          payload: payload,
          signFn: signFn,
          senderPubKey: pubKey,
        );

        // Decode and verify
        final envelope = StlEnvelope.decode(wrapped)!;
        final canonical = envelope.signedBytes;
        final sig = Signature(
          envelope.signature,
          publicKey: SimplePublicKey(pubKey, type: KeyPairType.ed25519),
        );
        final valid = await ed25519.verify(canonical, signature: sig);
        expect(valid, isTrue);
      });
    });

    group('unwrapInbound', () {
      test('passes through non-STL payload unchanged', () async {
        // SPP v1 offer header: (1 << 4) | 4 = 0x14
        final sppPayload = Uint8List.fromList([0x14, 1, 2, 3, 4, 5]);

        final result = await middleware.unwrapInbound(sppPayload);

        expect(result.wasWrapped, isFalse);
        expect(result.payload, sppPayload);
        expect(result.signatureValid, isNull);
        expect(result.senderPubKey, isNull);
      });

      test('unwraps valid STL envelope', () async {
        final keyPair = await ed25519.newKeyPair();
        final pubKey = Uint8List.fromList(
          (await keyPair.extractPublicKey()).bytes,
        );

        Future<Uint8List> signFn(Uint8List data) async {
          final sig = await ed25519.sign(data, keyPair: keyPair);
          return Uint8List.fromList(sig.bytes);
        }

        final innerPayload = Uint8List.fromList([0x15, 5, 6, 7, 8]);
        final wrapped = await middleware.wrapOutbound(
          payload: innerPayload,
          signFn: signFn,
          senderPubKey: pubKey,
        );

        final result = await middleware.unwrapInbound(wrapped);

        expect(result.wasWrapped, isTrue);
        expect(result.signatureValid, isTrue);
        expect(result.payload, innerPayload);
        expect(result.senderPubKey, pubKey);
      });

      test('detects invalid signature on tampered envelope', () async {
        final keyPair = await ed25519.newKeyPair();
        final pubKey = Uint8List.fromList(
          (await keyPair.extractPublicKey()).bytes,
        );

        Future<Uint8List> signFn(Uint8List data) async {
          final sig = await ed25519.sign(data, keyPair: keyPair);
          return Uint8List.fromList(sig.bytes);
        }

        final innerPayload = Uint8List.fromList([0x14, 1, 2, 3]);
        final wrapped = await middleware.wrapOutbound(
          payload: innerPayload,
          signFn: signFn,
          senderPubKey: pubKey,
        );

        // Tamper with a payload byte inside the envelope
        final tampered = Uint8List.fromList(wrapped);
        // Payload starts at offset 34 (version+flags+pubkey=34)
        tampered[35] ^= 0xFF;

        final result = await middleware.unwrapInbound(tampered);

        expect(result.wasWrapped, isTrue);
        expect(result.signatureValid, isFalse);
      });

      test('too-short data passes through', () async {
        final shortData = Uint8List(50); // Less than 98 bytes minimum

        final result = await middleware.unwrapInbound(shortData);

        expect(result.wasWrapped, isFalse);
        expect(result.payload, shortData);
      });
    });

    group('roundtrip', () {
      test('wrap then unwrap preserves original payload', () async {
        final keyPair = await ed25519.newKeyPair();
        final pubKey = Uint8List.fromList(
          (await keyPair.extractPublicKey()).bytes,
        );

        Future<Uint8List> signFn(Uint8List data) async {
          final sig = await ed25519.sign(data, keyPair: keyPair);
          return Uint8List.fromList(sig.bytes);
        }

        final original = Uint8List.fromList(List.generate(200, (i) => i % 256));

        final wrapped = await middleware.wrapOutbound(
          payload: original,
          signFn: signFn,
          senderPubKey: pubKey,
        );

        final result = await middleware.unwrapInbound(wrapped);

        expect(result.wasWrapped, isTrue);
        expect(result.signatureValid, isTrue);
        expect(result.payload, original);
      });
    });
  });

  group('StlEnvelope.isStlWrapped', () {
    test('detects STL envelope', () {
      final data = Uint8List(100);
      data[0] = StlVersion.current; // 0x01
      data[1] = StlFlags.signed; // 0x01
      expect(StlEnvelope.isStlWrapped(data), isTrue);
    });

    test('rejects SPP v1 packet', () {
      // SPP v1 offer: (1 << 4) | 4 = 0x14
      final data = Uint8List(100);
      data[0] = 0x14;
      expect(StlEnvelope.isStlWrapped(data), isFalse);
    });

    test('rejects short data', () {
      expect(StlEnvelope.isStlWrapped(Uint8List(50)), isFalse);
    });

    test('rejects unsigned envelope', () {
      final data = Uint8List(100);
      data[0] = StlVersion.current;
      data[1] = 0x00; // No flags
      expect(StlEnvelope.isStlWrapped(data), isFalse);
    });
  });

  group('StlEnvelope.stripEnvelopeForTestsOnly', () {
    test('returns inner payload from valid envelope', () async {
      final ed25519 = Ed25519();
      final keyPair = await ed25519.newKeyPair();
      final pubKey = Uint8List.fromList(
        (await keyPair.extractPublicKey()).bytes,
      );

      final inner = Uint8List.fromList([0x15, 1, 2, 3, 4]);

      // Build an STL envelope manually
      final flags = StlFlags.signed;
      final signedBytes = StlEnvelope.computeSignedBytes(
        version: StlVersion.current,
        flags: flags,
        senderPubKey: pubKey,
        payload: inner,
      );
      final sig = await ed25519.sign(signedBytes, keyPair: keyPair);
      final envelope = StlEnvelope(
        version: StlVersion.current,
        flags: flags,
        senderPubKey: pubKey,
        payload: inner,
        signature: Uint8List.fromList(sig.bytes),
      );

      final encoded = envelope.encode();
      final stripped = StlEnvelope.stripEnvelopeForTestsOnly(encoded);

      expect(stripped, isNotNull);
      expect(stripped, inner);
    });

    test('returns null for non-STL data', () {
      final sppData = Uint8List.fromList([0x14, 1, 2, 3]);
      expect(StlEnvelope.stripEnvelopeForTestsOnly(sppData), isNull);
    });
  });

  group('StlMiddleware.verifyAndUnwrap', () {
    late StlMiddleware middleware;
    late Ed25519 ed25519;

    setUp(() {
      ed25519 = Ed25519();
      middleware = StlMiddleware();
    });

    test('returns null for non-STL data', () async {
      final sppPayload = Uint8List.fromList([0x14, 1, 2, 3, 4, 5]);
      final result = await middleware.verifyAndUnwrap(sppPayload);
      expect(result, isNull);
    });

    test('returns VerifiedStlPayload for valid envelope', () async {
      final keyPair = await ed25519.newKeyPair();
      final pubKey = Uint8List.fromList(
        (await keyPair.extractPublicKey()).bytes,
      );

      Future<Uint8List> signFn(Uint8List data) async {
        final sig = await ed25519.sign(data, keyPair: keyPair);
        return Uint8List.fromList(sig.bytes);
      }

      final innerPayload = Uint8List.fromList([0x15, 5, 6, 7, 8]);
      final wrapped = await middleware.wrapOutbound(
        payload: innerPayload,
        signFn: signFn,
        senderPubKey: pubKey,
      );

      final result = await middleware.verifyAndUnwrap(wrapped);

      expect(result, isNotNull);
      expect(result!.payload, innerPayload);
      expect(result.senderPubKey, pubKey);
    });

    test('returns null for tampered envelope (fail-closed)', () async {
      final keyPair = await ed25519.newKeyPair();
      final pubKey = Uint8List.fromList(
        (await keyPair.extractPublicKey()).bytes,
      );

      Future<Uint8List> signFn(Uint8List data) async {
        final sig = await ed25519.sign(data, keyPair: keyPair);
        return Uint8List.fromList(sig.bytes);
      }

      final innerPayload = Uint8List.fromList([0x14, 1, 2, 3]);
      final wrapped = await middleware.wrapOutbound(
        payload: innerPayload,
        signFn: signFn,
        senderPubKey: pubKey,
      );

      // Tamper with a payload byte
      final tampered = Uint8List.fromList(wrapped);
      tampered[35] ^= 0xFF;

      final result = await middleware.verifyAndUnwrap(tampered);
      expect(result, isNull);
    });

    test('returns null for too-short data', () async {
      final result = await middleware.verifyAndUnwrap(Uint8List(50));
      expect(result, isNull);
    });
  });
}
