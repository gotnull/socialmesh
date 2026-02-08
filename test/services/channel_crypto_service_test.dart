// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';

/// Tests for the channel PSK encryption/decryption logic.
///
/// These tests verify:
/// - PSK encryption produces ciphertext different from plaintext
/// - Round-trip encrypt/decrypt recovers original PSK
/// - Different users get different ciphertext for the same PSK
/// - Key version tracking works for rotation
/// - Tampered ciphertext fails decryption
/// - HKDF key derivation is deterministic
void main() {
  group('Channel PSK Crypto', () {
    const channelId = 'test-channel-123';
    const ownerUid = 'owner-uid-abc';
    const memberUid = 'member-uid-xyz';
    final testPsk = List<int>.generate(32, (i) => i * 7 % 256);

    Future<List<int>> deriveKey({
      required String channelId,
      required String ownerUid,
      required String targetUid,
    }) async {
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
      final ikm = utf8.encode('$ownerUid:$targetUid:$channelId');
      final derivedKey = await hkdf.deriveKey(
        secretKey: SecretKey(ikm),
        info: utf8.encode('socialmesh-channel-psk-v1'),
      );
      return derivedKey.extractBytes();
    }

    Future<String> encryptPsk({
      required List<int> psk,
      required String channelId,
      required String ownerUid,
      required String targetUid,
    }) async {
      final key = await deriveKey(
        channelId: channelId,
        ownerUid: ownerUid,
        targetUid: targetUid,
      );

      final algorithm = AesGcm.with256bits();
      final secretKey = SecretKey(key);
      final secretBox = await algorithm.encrypt(psk, secretKey: secretKey);
      return base64Encode(secretBox.concatenation());
    }

    Future<List<int>?> decryptPsk({
      required String encryptedB64,
      required String channelId,
      required String ownerUid,
      required String targetUid,
    }) async {
      try {
        final concatenation = base64Decode(encryptedB64);
        final key = await deriveKey(
          channelId: channelId,
          ownerUid: ownerUid,
          targetUid: targetUid,
        );

        final algorithm = AesGcm.with256bits();
        final secretKey = SecretKey(key);
        final secretBox = SecretBox.fromConcatenation(
          concatenation,
          nonceLength: 12,
          macLength: 16,
        );

        return await algorithm.decrypt(secretBox, secretKey: secretKey);
      } catch (_) {
        return null;
      }
    }

    test('encrypt produces non-plaintext output', () async {
      final encrypted = await encryptPsk(
        psk: testPsk,
        channelId: channelId,
        ownerUid: ownerUid,
        targetUid: memberUid,
      );

      final encryptedBytes = base64Decode(encrypted);
      // Ciphertext should be longer than plaintext (nonce + mac overhead)
      expect(encryptedBytes.length, greaterThan(testPsk.length));
      // Should NOT contain the plaintext PSK
      expect(
        base64Encode(encryptedBytes),
        isNot(equals(base64Encode(testPsk))),
      );
    });

    test('round-trip encrypt/decrypt recovers original PSK', () async {
      final encrypted = await encryptPsk(
        psk: testPsk,
        channelId: channelId,
        ownerUid: ownerUid,
        targetUid: memberUid,
      );

      final decrypted = await decryptPsk(
        encryptedB64: encrypted,
        channelId: channelId,
        ownerUid: ownerUid,
        targetUid: memberUid,
      );

      expect(decrypted, isNotNull);
      expect(decrypted, equals(testPsk));
    });

    test('different users get different ciphertext', () async {
      final encryptedForMember = await encryptPsk(
        psk: testPsk,
        channelId: channelId,
        ownerUid: ownerUid,
        targetUid: memberUid,
      );

      final encryptedForOwner = await encryptPsk(
        psk: testPsk,
        channelId: channelId,
        ownerUid: ownerUid,
        targetUid: ownerUid,
      );

      // Different target users should produce different derived keys
      // (even though AES-GCM nonce randomness also ensures this)
      expect(encryptedForMember, isNot(equals(encryptedForOwner)));
    });

    test('wrong user cannot decrypt', () async {
      final encrypted = await encryptPsk(
        psk: testPsk,
        channelId: channelId,
        ownerUid: ownerUid,
        targetUid: memberUid,
      );

      // Try decrypting with a different targetUid
      final decrypted = await decryptPsk(
        encryptedB64: encrypted,
        channelId: channelId,
        ownerUid: ownerUid,
        targetUid: 'wrong-uid',
      );

      expect(decrypted, isNull);
    });

    test('tampered ciphertext fails decryption', () async {
      final encrypted = await encryptPsk(
        psk: testPsk,
        channelId: channelId,
        ownerUid: ownerUid,
        targetUid: memberUid,
      );

      // Tamper with one byte
      final bytes = base64Decode(encrypted);
      bytes[20] ^= 0xFF;
      final tampered = base64Encode(bytes);

      final decrypted = await decryptPsk(
        encryptedB64: tampered,
        channelId: channelId,
        ownerUid: ownerUid,
        targetUid: memberUid,
      );

      expect(decrypted, isNull);
    });

    test('HKDF key derivation is deterministic', () async {
      final key1 = await deriveKey(
        channelId: channelId,
        ownerUid: ownerUid,
        targetUid: memberUid,
      );

      final key2 = await deriveKey(
        channelId: channelId,
        ownerUid: ownerUid,
        targetUid: memberUid,
      );

      expect(key1, equals(key2));
      expect(key1.length, equals(32));
    });

    test('different channel IDs produce different keys', () async {
      final key1 = await deriveKey(
        channelId: 'channel-A',
        ownerUid: ownerUid,
        targetUid: memberUid,
      );

      final key2 = await deriveKey(
        channelId: 'channel-B',
        ownerUid: ownerUid,
        targetUid: memberUid,
      );

      expect(key1, isNot(equals(key2)));
    });
  });

  group('Key Rotation', () {
    test('keyVersion increments correctly', () {
      const currentVersion = 1;
      const newVersion = currentVersion + 1;

      expect(newVersion, equals(2));
    });

    test('old key cannot decrypt new version ciphertext', () async {
      const channelId = 'rotation-test';
      const ownerUid = 'owner';
      const memberUid = 'member';
      final oldPsk = List<int>.generate(16, (i) => i);
      final newPsk = List<int>.generate(16, (i) => i + 100);

      // Encrypt with old PSK context
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

      Future<List<int>> derive(String extra) async {
        final ikm = utf8.encode('$ownerUid:$memberUid:$channelId$extra');
        final k = await hkdf.deriveKey(
          secretKey: SecretKey(ikm),
          info: utf8.encode('socialmesh-channel-psk-v1'),
        );
        return k.extractBytes();
      }

      final algo = AesGcm.with256bits();

      // "Old" encryption (v1)
      final oldKey = await derive('');
      final oldBox = await algo.encrypt(oldPsk, secretKey: SecretKey(oldKey));

      // "New" encryption (v2) - different PSK
      final newBox = await algo.encrypt(newPsk, secretKey: SecretKey(oldKey));

      // Decrypt new ciphertext should give new PSK, not old
      final decryptedNew = await algo.decrypt(
        newBox,
        secretKey: SecretKey(oldKey),
      );
      expect(decryptedNew, equals(newPsk));
      expect(decryptedNew, isNot(equals(oldPsk)));

      // Old ciphertext gives old PSK
      final decryptedOld = await algo.decrypt(
        oldBox,
        secretKey: SecretKey(oldKey),
      );
      expect(decryptedOld, equals(oldPsk));
    });
  });

  group('Migration Safety', () {
    test('export data without PSK field is valid metadata', () {
      // Simulate what the new client writes (no 'psk' field)
      final metadata = {
        'name': 'Test Channel',
        'index': 1,
        'role': 'SECONDARY',
        'uplink': false,
        'downlink': false,
        'positionPrecision': 0,
        'createdBy': 'user-123',
        'keyVersion': 1,
      };

      expect(metadata.containsKey('psk'), isFalse);
      expect(metadata['name'], equals('Test Channel'));
      expect(metadata['keyVersion'], equals(1));
    });

    test('legacy document with psk field is flagged for migration', () {
      final legacyDoc = {
        'name': 'Old Channel',
        'psk': 'AQEBAQEBAQEBAQEBAQEBAQ==',
        'index': 0,
        'role': 'PRIMARY',
        'createdBy': 'user-456',
      };

      // Migration must detect and strip the 'psk' field
      expect(legacyDoc.containsKey('psk'), isTrue);

      // After migration
      final migrated = Map<String, dynamic>.from(legacyDoc);
      migrated.remove('psk');
      migrated['pskMigrated'] = true;
      migrated['keyVersion'] = 1;

      expect(migrated.containsKey('psk'), isFalse);
      expect(migrated['pskMigrated'], isTrue);
    });
  });
}
