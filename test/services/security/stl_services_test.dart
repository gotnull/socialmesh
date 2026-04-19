// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/security/stl_encryption_service.dart';
import 'package:socialmesh/services/security/stl_envelope.dart';
import 'package:socialmesh/services/security/stl_signing_service.dart';

void main() {
  group('StlSigningService', () {
    late StlSigningService signingService;
    late Ed25519 ed25519;

    setUp(() {
      ed25519 = Ed25519();
      signingService = StlSigningService(algorithm: ed25519);
    });

    test('sign and verify roundtrip succeeds', () async {
      final keyPair = await ed25519.newKeyPair();
      final pubKeyBytes = Uint8List.fromList(
        (await keyPair.extractPublicKey()).bytes,
      );
      final payload = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);

      final envelope = await signingService.signPayload(
        payload: payload,
        privateKey: keyPair,
        senderPubKey: pubKeyBytes,
      );

      expect(envelope.isSigned, isTrue);
      expect(envelope.isEncrypted, isFalse);
      expect(envelope.payload, payload);
      expect(envelope.signature.length, 64);
      expect(envelope.senderPubKey, pubKeyBytes);

      final valid = await signingService.verifyEnvelope(envelope);
      expect(valid, isTrue);
    });

    test('invalid signature is rejected', () async {
      final keyPair = await ed25519.newKeyPair();
      final pubKeyBytes = Uint8List.fromList(
        (await keyPair.extractPublicKey()).bytes,
      );
      final payload = Uint8List.fromList([10, 20, 30]);

      final envelope = await signingService.signPayload(
        payload: payload,
        privateKey: keyPair,
        senderPubKey: pubKeyBytes,
      );

      // Tamper with signature
      final tamperedSig = Uint8List.fromList(envelope.signature);
      tamperedSig[0] ^= 0xFF;

      final tampered = StlEnvelope(
        version: envelope.version,
        flags: envelope.flags,
        senderPubKey: envelope.senderPubKey,
        payload: envelope.payload,
        signature: tamperedSig,
      );

      final valid = await signingService.verifyEnvelope(tampered);
      expect(valid, isFalse);
    });

    test('tampered payload invalidates signature', () async {
      final keyPair = await ed25519.newKeyPair();
      final pubKeyBytes = Uint8List.fromList(
        (await keyPair.extractPublicKey()).bytes,
      );
      final payload = Uint8List.fromList([42, 43, 44]);

      final envelope = await signingService.signPayload(
        payload: payload,
        privateKey: keyPair,
        senderPubKey: pubKeyBytes,
      );

      // Tamper with payload
      final tamperedPayload = Uint8List.fromList(envelope.payload);
      tamperedPayload[0] = 0;

      final tampered = StlEnvelope(
        version: envelope.version,
        flags: envelope.flags,
        senderPubKey: envelope.senderPubKey,
        payload: tamperedPayload,
        signature: envelope.signature,
      );

      final valid = await signingService.verifyEnvelope(tampered);
      expect(valid, isFalse);
    });

    test('wrong public key rejects signature', () async {
      final keyPair = await ed25519.newKeyPair();
      final pubKeyBytes = Uint8List.fromList(
        (await keyPair.extractPublicKey()).bytes,
      );
      final payload = Uint8List.fromList([1, 2, 3]);

      final envelope = await signingService.signPayload(
        payload: payload,
        privateKey: keyPair,
        senderPubKey: pubKeyBytes,
      );

      // Use a different public key
      final otherKeyPair = await ed25519.newKeyPair();
      final otherPubKey = Uint8List.fromList(
        (await otherKeyPair.extractPublicKey()).bytes,
      );

      final wrongKey = StlEnvelope(
        version: envelope.version,
        flags: envelope.flags,
        senderPubKey: otherPubKey,
        payload: envelope.payload,
        signature: envelope.signature,
      );

      final valid = await signingService.verifyEnvelope(wrongKey);
      expect(valid, isFalse);
    });

    test('unsigned envelope verification returns false', () async {
      final envelope = StlEnvelope(
        version: StlVersion.current,
        flags: 0, // No flags set
        senderPubKey: Uint8List(32),
        payload: Uint8List.fromList([1, 2, 3]),
        signature: Uint8List(64),
      );

      final valid = await signingService.verifyEnvelope(envelope);
      expect(valid, isFalse);
    });

    test('sign with encrypted flag sets both flags', () async {
      final keyPair = await ed25519.newKeyPair();
      final pubKeyBytes = Uint8List.fromList(
        (await keyPair.extractPublicKey()).bytes,
      );
      final payload = Uint8List.fromList([1, 2, 3]);
      final nonce = Uint8List(12);

      final envelope = await signingService.signPayload(
        payload: payload,
        privateKey: keyPair,
        senderPubKey: pubKeyBytes,
        nonce: nonce,
        encrypted: true,
      );

      expect(envelope.isSigned, isTrue);
      expect(envelope.isEncrypted, isTrue);
      expect(envelope.nonce, nonce);
    });

    test('encode/decode preserves valid signature', () async {
      final keyPair = await ed25519.newKeyPair();
      final pubKeyBytes = Uint8List.fromList(
        (await keyPair.extractPublicKey()).bytes,
      );
      final payload = Uint8List.fromList(List.generate(200, (i) => i % 256));

      final envelope = await signingService.signPayload(
        payload: payload,
        privateKey: keyPair,
        senderPubKey: pubKeyBytes,
      );

      // Encode to wire format and decode back
      final encoded = envelope.encode();
      final decoded = StlEnvelope.decode(encoded);
      expect(decoded, isNotNull);

      // Signature should still verify after roundtrip
      final valid = await signingService.verifyEnvelope(decoded!);
      expect(valid, isTrue);
    });
  });

  group('StlEncryptionService', () {
    late StlEncryptionService encryptionService;
    late X25519 x25519;

    setUp(() {
      x25519 = X25519();
      encryptionService = StlEncryptionService(keyExchange: x25519);
    });

    test('encrypt/decrypt roundtrip succeeds', () async {
      final senderKeyPair = await x25519.newKeyPair();
      final receiverKeyPair = await x25519.newKeyPair();

      final senderPubKey = Uint8List.fromList(
        (await senderKeyPair.extractPublicKey()).bytes,
      );
      final receiverPubKey = Uint8List.fromList(
        (await receiverKeyPair.extractPublicKey()).bytes,
      );

      final payload = Uint8List.fromList([10, 20, 30, 40, 50]);
      final nonce = Uint8List.fromList(List.generate(12, (i) => i + 1));

      final ciphertext = await encryptionService.encrypt(
        payload: payload,
        senderKeyPair: senderKeyPair,
        receiverPubKey: receiverPubKey,
        nonce: nonce,
      );

      // Ciphertext should be payload + 16-byte MAC
      expect(ciphertext.length, payload.length + 16);
      expect(ciphertext, isNot(equals(payload)));

      final decrypted = await encryptionService.decrypt(
        ciphertext: ciphertext,
        receiverKeyPair: receiverKeyPair,
        senderPubKey: senderPubKey,
        nonce: nonce,
      );

      expect(decrypted, isNotNull);
      expect(decrypted, payload);
    });

    test('wrong nonce fails decryption', () async {
      final senderKeyPair = await x25519.newKeyPair();
      final receiverKeyPair = await x25519.newKeyPair();

      final receiverPubKey = Uint8List.fromList(
        (await receiverKeyPair.extractPublicKey()).bytes,
      );
      final senderPubKey = Uint8List.fromList(
        (await senderKeyPair.extractPublicKey()).bytes,
      );

      final payload = Uint8List.fromList([1, 2, 3, 4, 5]);
      final nonce = Uint8List(12);

      final ciphertext = await encryptionService.encrypt(
        payload: payload,
        senderKeyPair: senderKeyPair,
        receiverPubKey: receiverPubKey,
        nonce: nonce,
      );

      // Use wrong nonce
      final wrongNonce = Uint8List.fromList(List.generate(12, (i) => 99));

      final decrypted = await encryptionService.decrypt(
        ciphertext: ciphertext,
        receiverKeyPair: receiverKeyPair,
        senderPubKey: senderPubKey,
        nonce: wrongNonce,
      );

      expect(decrypted, isNull);
    });

    test('wrong receiver key fails decryption', () async {
      final senderKeyPair = await x25519.newKeyPair();
      final receiverKeyPair = await x25519.newKeyPair();
      final wrongKeyPair = await x25519.newKeyPair();

      final receiverPubKey = Uint8List.fromList(
        (await receiverKeyPair.extractPublicKey()).bytes,
      );
      final senderPubKey = Uint8List.fromList(
        (await senderKeyPair.extractPublicKey()).bytes,
      );

      final payload = Uint8List.fromList([1, 2, 3]);
      final nonce = Uint8List(12);

      final ciphertext = await encryptionService.encrypt(
        payload: payload,
        senderKeyPair: senderKeyPair,
        receiverPubKey: receiverPubKey,
        nonce: nonce,
      );

      // Decrypt with wrong receiver key
      final decrypted = await encryptionService.decrypt(
        ciphertext: ciphertext,
        receiverKeyPair: wrongKeyPair,
        senderPubKey: senderPubKey,
        nonce: nonce,
      );

      expect(decrypted, isNull);
    });

    test('tampered ciphertext fails decryption', () async {
      final senderKeyPair = await x25519.newKeyPair();
      final receiverKeyPair = await x25519.newKeyPair();

      final receiverPubKey = Uint8List.fromList(
        (await receiverKeyPair.extractPublicKey()).bytes,
      );
      final senderPubKey = Uint8List.fromList(
        (await senderKeyPair.extractPublicKey()).bytes,
      );

      final payload = Uint8List.fromList([5, 10, 15, 20, 25]);
      final nonce = Uint8List(12);

      final ciphertext = await encryptionService.encrypt(
        payload: payload,
        senderKeyPair: senderKeyPair,
        receiverPubKey: receiverPubKey,
        nonce: nonce,
      );

      // Tamper with ciphertext
      final tampered = Uint8List.fromList(ciphertext);
      tampered[0] ^= 0xFF;

      final decrypted = await encryptionService.decrypt(
        ciphertext: tampered,
        receiverKeyPair: receiverKeyPair,
        senderPubKey: senderPubKey,
        nonce: nonce,
      );

      expect(decrypted, isNull);
    });

    test('ciphertext too short for MAC tag returns null', () async {
      final receiverKeyPair = await x25519.newKeyPair();
      final senderPubKey = Uint8List(32);
      final nonce = Uint8List(12);

      final decrypted = await encryptionService.decrypt(
        ciphertext: Uint8List(15), // Less than 16 bytes for MAC
        receiverKeyPair: receiverKeyPair,
        senderPubKey: senderPubKey,
        nonce: nonce,
      );

      expect(decrypted, isNull);
    });

    test('large payload encrypt/decrypt roundtrip', () async {
      final senderKeyPair = await x25519.newKeyPair();
      final receiverKeyPair = await x25519.newKeyPair();

      final receiverPubKey = Uint8List.fromList(
        (await receiverKeyPair.extractPublicKey()).bytes,
      );
      final senderPubKey = Uint8List.fromList(
        (await senderKeyPair.extractPublicKey()).bytes,
      );

      final payload = Uint8List.fromList(
        List.generate(4096, (i) => (i * 13 + 7) % 256),
      );
      final nonce = Uint8List.fromList(List.generate(12, (i) => i));

      final ciphertext = await encryptionService.encrypt(
        payload: payload,
        senderKeyPair: senderKeyPair,
        receiverPubKey: receiverPubKey,
        nonce: nonce,
      );

      final decrypted = await encryptionService.decrypt(
        ciphertext: ciphertext,
        receiverKeyPair: receiverKeyPair,
        senderPubKey: senderPubKey,
        nonce: nonce,
      );

      expect(decrypted, payload);
    });
  });

  group('STL integration', () {
    test('sign then encrypt then decrypt then verify', () async {
      final ed25519 = Ed25519();
      final x25519 = X25519();
      final signingService = StlSigningService(algorithm: ed25519);
      final encryptionService = StlEncryptionService(keyExchange: x25519);

      // Generate keys
      final senderEdKeyPair = await ed25519.newKeyPair();
      final senderEdPubKey = Uint8List.fromList(
        (await senderEdKeyPair.extractPublicKey()).bytes,
      );

      final senderX25519KeyPair = await x25519.newKeyPair();
      final receiverX25519KeyPair = await x25519.newKeyPair();

      final receiverX25519PubKey = Uint8List.fromList(
        (await receiverX25519KeyPair.extractPublicKey()).bytes,
      );
      final senderX25519PubKey = Uint8List.fromList(
        (await senderX25519KeyPair.extractPublicKey()).bytes,
      );

      // Original payload
      final payload = Uint8List.fromList([100, 200, 42, 99, 1]);
      final nonce = Uint8List.fromList(List.generate(12, (i) => i + 10));

      // Step 1: Encrypt payload
      final ciphertext = await encryptionService.encrypt(
        payload: payload,
        senderKeyPair: senderX25519KeyPair,
        receiverPubKey: receiverX25519PubKey,
        nonce: nonce,
      );

      // Step 2: Sign the encrypted payload
      final envelope = await signingService.signPayload(
        payload: ciphertext,
        privateKey: senderEdKeyPair,
        senderPubKey: senderEdPubKey,
        nonce: nonce,
        encrypted: true,
      );

      // Step 3: Encode to wire and decode
      final wireBytes = envelope.encode();
      final decoded = StlEnvelope.decode(wireBytes);
      expect(decoded, isNotNull);

      // Step 4: Verify signature
      final verified = await signingService.verifyEnvelope(decoded!);
      expect(verified, isTrue);

      // Step 5: Decrypt payload
      final decrypted = await encryptionService.decrypt(
        ciphertext: decoded.payload,
        receiverKeyPair: receiverX25519KeyPair,
        senderPubKey: senderX25519PubKey,
        nonce: decoded.nonce!,
      );

      expect(decrypted, payload);
    });

    test('MTU compliance after STL overhead', () {
      // Meshtastic max payload ~233 bytes (LoRa)
      const meshtasticMaxPayload = 233;

      // Space available for actual data after STL signed-only overhead
      const availableSignedOnly = meshtasticMaxPayload - StlOverhead.signedOnly;
      expect(availableSignedOnly, 135);

      // Space available after signed + encrypted overhead
      const availableEncrypted =
          meshtasticMaxPayload - StlOverhead.signedAndEncrypted;
      expect(availableEncrypted, 123);

      // Both should leave room for meaningful payload
      expect(availableSignedOnly, greaterThan(0));
      expect(availableEncrypted, greaterThan(0));
    });
  });
}
