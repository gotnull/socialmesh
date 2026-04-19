// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/security/stl_envelope.dart';

void main() {
  group('StlVersion', () {
    test('current is v1', () {
      expect(StlVersion.current, 1);
    });
  });

  group('StlFlags', () {
    test('flag values are correct', () {
      expect(StlFlags.signed, 0x01);
      expect(StlFlags.encrypted, 0x02);
    });
  });

  group('StlOverhead', () {
    test('signedOnly overhead is 98 bytes', () {
      expect(StlOverhead.signedOnly, 98);
    });

    test('signedAndEncrypted overhead is 110 bytes', () {
      expect(StlOverhead.signedAndEncrypted, 110);
    });
  });

  group('StlEnvelope', () {
    late Uint8List senderPubKey;
    late Uint8List signature;
    late Uint8List payload;

    setUp(() {
      senderPubKey = Uint8List.fromList(List.generate(32, (i) => i));
      signature = Uint8List.fromList(List.generate(64, (i) => i + 100));
      payload = Uint8List.fromList([1, 2, 3, 4, 5]);
    });

    test('isSigned returns true when signed flag set', () {
      final envelope = StlEnvelope(
        version: StlVersion.current,
        flags: StlFlags.signed,
        senderPubKey: senderPubKey,
        payload: payload,
        signature: signature,
      );

      expect(envelope.isSigned, isTrue);
      expect(envelope.isEncrypted, isFalse);
    });

    test('isEncrypted returns true when encrypted flag set', () {
      final envelope = StlEnvelope(
        version: StlVersion.current,
        flags: StlFlags.signed | StlFlags.encrypted,
        senderPubKey: senderPubKey,
        nonce: Uint8List(12),
        payload: payload,
        signature: signature,
      );

      expect(envelope.isSigned, isTrue);
      expect(envelope.isEncrypted, isTrue);
    });

    group('encode/decode roundtrip', () {
      test('signed-only envelope', () {
        final original = StlEnvelope(
          version: StlVersion.current,
          flags: StlFlags.signed,
          senderPubKey: senderPubKey,
          payload: payload,
          signature: signature,
        );

        final encoded = original.encode();
        expect(encoded.length, StlOverhead.signedOnly + payload.length);

        final decoded = StlEnvelope.decode(encoded);
        expect(decoded, isNotNull);
        expect(decoded!.version, StlVersion.current);
        expect(decoded.flags, StlFlags.signed);
        expect(decoded.senderPubKey, senderPubKey);
        expect(decoded.nonce, isNull);
        expect(decoded.payload, payload);
        expect(decoded.signature, signature);
      });

      test('signed + encrypted envelope', () {
        final nonce = Uint8List.fromList(List.generate(12, (i) => i + 50));

        final original = StlEnvelope(
          version: StlVersion.current,
          flags: StlFlags.signed | StlFlags.encrypted,
          senderPubKey: senderPubKey,
          nonce: nonce,
          payload: payload,
          signature: signature,
        );

        final encoded = original.encode();
        expect(encoded.length, StlOverhead.signedAndEncrypted + payload.length);

        final decoded = StlEnvelope.decode(encoded);
        expect(decoded, isNotNull);
        expect(decoded!.version, StlVersion.current);
        expect(decoded.flags, StlFlags.signed | StlFlags.encrypted);
        expect(decoded.senderPubKey, senderPubKey);
        expect(decoded.nonce, nonce);
        expect(decoded.payload, payload);
        expect(decoded.signature, signature);
      });

      test('empty payload', () {
        final original = StlEnvelope(
          version: StlVersion.current,
          flags: StlFlags.signed,
          senderPubKey: senderPubKey,
          payload: Uint8List(0),
          signature: signature,
        );

        final encoded = original.encode();
        expect(encoded.length, StlOverhead.signedOnly);

        final decoded = StlEnvelope.decode(encoded);
        expect(decoded, isNotNull);
        expect(decoded!.payload.length, 0);
      });

      test('large payload', () {
        final largePayload = Uint8List.fromList(
          List.generate(10000, (i) => i % 256),
        );

        final original = StlEnvelope(
          version: StlVersion.current,
          flags: StlFlags.signed,
          senderPubKey: senderPubKey,
          payload: largePayload,
          signature: signature,
        );

        final encoded = original.encode();
        final decoded = StlEnvelope.decode(encoded);
        expect(decoded, isNotNull);
        expect(decoded!.payload, largePayload);
      });
    });

    group('decode edge cases', () {
      test('data too short returns null', () {
        expect(StlEnvelope.decode(Uint8List(10)), isNull);
        expect(StlEnvelope.decode(Uint8List(97)), isNull);
      });

      test('encrypted flag but too short for nonce returns null', () {
        // 98 bytes is enough for signed-only but not for encrypted
        // (needs 110 minimum)
        final data = Uint8List(98);
        data[0] = StlVersion.current;
        data[1] = StlFlags.signed | StlFlags.encrypted;
        expect(StlEnvelope.decode(data), isNull);
      });

      test('unsupported version returns null', () {
        final data = Uint8List(100);
        data[0] = 99; // Future version
        data[1] = StlFlags.signed;
        expect(StlEnvelope.decode(data), isNull);
      });

      test('minimum valid signed-only (empty payload) decodes', () {
        // Manually construct minimum valid: version+flags+pubkey+sig = 98
        final data = Uint8List(98);
        data[0] = StlVersion.current;
        data[1] = StlFlags.signed;
        // pubkey = zeros (bytes 2-33)
        // signature = last 64 bytes (34-97)
        final decoded = StlEnvelope.decode(data);
        expect(decoded, isNotNull);
        expect(decoded!.payload.length, 0);
        expect(decoded.senderPubKey.length, 32);
        expect(decoded.signature.length, 64);
      });
    });

    group('signedBytes', () {
      test('signed-only: version + flags + pubkey + payload', () {
        final envelope = StlEnvelope(
          version: StlVersion.current,
          flags: StlFlags.signed,
          senderPubKey: senderPubKey,
          payload: payload,
          signature: signature,
        );

        final signed = envelope.signedBytes;
        expect(signed.length, 1 + 1 + 32 + payload.length);
        expect(signed[0], StlVersion.current);
        expect(signed[1], StlFlags.signed);
        expect(signed.sublist(2, 34), senderPubKey);
        expect(signed.sublist(34), payload);
      });

      test('encrypted: version + flags + pubkey + nonce + payload', () {
        final nonce = Uint8List.fromList(List.generate(12, (i) => i));

        final envelope = StlEnvelope(
          version: StlVersion.current,
          flags: StlFlags.signed | StlFlags.encrypted,
          senderPubKey: senderPubKey,
          nonce: nonce,
          payload: payload,
          signature: signature,
        );

        final signed = envelope.signedBytes;
        expect(signed.length, 1 + 1 + 32 + 12 + payload.length);
        expect(signed.sublist(34, 46), nonce);
        expect(signed.sublist(46), payload);
      });

      test('computeSignedBytes matches instance signedBytes', () {
        final nonce = Uint8List.fromList(List.generate(12, (i) => i));

        final envelope = StlEnvelope(
          version: StlVersion.current,
          flags: StlFlags.signed | StlFlags.encrypted,
          senderPubKey: senderPubKey,
          nonce: nonce,
          payload: payload,
          signature: signature,
        );

        final fromInstance = envelope.signedBytes;
        final fromStatic = StlEnvelope.computeSignedBytes(
          version: StlVersion.current,
          flags: StlFlags.signed | StlFlags.encrypted,
          senderPubKey: senderPubKey,
          nonce: nonce,
          payload: payload,
        );

        expect(fromInstance, fromStatic);
      });
    });

    group('isStlPayload', () {
      test('returns true for valid STL data', () {
        final data = Uint8List(100);
        data[0] = StlVersion.current;
        expect(StlEnvelope.isStlPayload(data), isTrue);
      });

      test('returns false for data too short', () {
        expect(StlEnvelope.isStlPayload(Uint8List(50)), isFalse);
      });

      test('returns false for version 0', () {
        final data = Uint8List(100);
        data[0] = 0;
        expect(StlEnvelope.isStlPayload(data), isFalse);
      });

      test('returns false for version beyond current', () {
        final data = Uint8List(100);
        data[0] = StlVersion.current + 1;
        expect(StlEnvelope.isStlPayload(data), isFalse);
      });
    });

    group('wire format byte positions', () {
      test('version is byte 0, flags is byte 1', () {
        final envelope = StlEnvelope(
          version: StlVersion.current,
          flags: StlFlags.signed,
          senderPubKey: senderPubKey,
          payload: payload,
          signature: signature,
        );

        final encoded = envelope.encode();
        expect(encoded[0], StlVersion.current);
        expect(encoded[1], StlFlags.signed);
      });

      test('sender pubkey starts at byte 2', () {
        final envelope = StlEnvelope(
          version: StlVersion.current,
          flags: StlFlags.signed,
          senderPubKey: senderPubKey,
          payload: payload,
          signature: signature,
        );

        final encoded = envelope.encode();
        expect(encoded.sublist(2, 34), senderPubKey);
      });

      test('signature is always the last 64 bytes', () {
        final envelope = StlEnvelope(
          version: StlVersion.current,
          flags: StlFlags.signed,
          senderPubKey: senderPubKey,
          payload: payload,
          signature: signature,
        );

        final encoded = envelope.encode();
        expect(encoded.sublist(encoded.length - 64), signature);
      });
    });
  });

  group('StlOverhead wire overhead helpers', () {
    test('wireOverheadSignedOnly matches signedOnly', () {
      expect(StlOverhead.wireOverheadSignedOnly, StlOverhead.signedOnly);
      expect(StlOverhead.wireOverheadSignedOnly, 98);
    });

    test('wireOverheadEncrypted includes Poly1305 tag', () {
      expect(
        StlOverhead.wireOverheadEncrypted,
        StlOverhead.signedAndEncrypted + StlOverhead.poly1305Tag,
      );
      expect(StlOverhead.wireOverheadEncrypted, 126);
    });

    test('wireOverhead returns correct mode', () {
      expect(StlOverhead.wireOverhead(), StlOverhead.wireOverheadSignedOnly);
      expect(
        StlOverhead.wireOverhead(encrypted: true),
        StlOverhead.wireOverheadEncrypted,
      );
    });
  });

  group('computeStlAwareChunkSize', () {
    test('signed-only fits within LoRa MTU', () {
      final chunkSize = computeStlAwareChunkSize(
        mtu: 237,
        sppHeaderOverhead: 23,
        stlEnabled: true,
      );
      // 237 - 23 - 98 = 116
      expect(chunkSize, 116);
      // Wire check: 116 + 23 + 98 = 237 <= MTU
      expect(chunkSize + 23 + StlOverhead.wireOverheadSignedOnly, 237);
    });

    test('signed+encrypted fits within LoRa MTU', () {
      final chunkSize = computeStlAwareChunkSize(
        mtu: 237,
        sppHeaderOverhead: 23,
        stlEnabled: true,
        stlEncrypted: true,
      );
      // 237 - 23 - 126 = 88
      expect(chunkSize, 88);
      // Wire check: 88 + 23 + 126 = 237 <= MTU
      expect(chunkSize + 23 + StlOverhead.wireOverheadEncrypted, 237);
    });

    test('returns default when STL disabled', () {
      final chunkSize = computeStlAwareChunkSize(
        mtu: 237,
        sppHeaderOverhead: 23,
      );
      // 237 - 23 - 0 = 214 (no STL overhead)
      expect(chunkSize, 214);
    });

    test('throws when overhead exceeds MTU', () {
      expect(
        () => computeStlAwareChunkSize(
          mtu: 50,
          sppHeaderOverhead: 23,
          stlEnabled: true,
        ),
        throwsA(anything),
      );
    });

    test('throws when overhead exactly equals MTU', () {
      // 98 + 23 = 121 — use MTU = 121
      expect(
        () => computeStlAwareChunkSize(
          mtu: 121,
          sppHeaderOverhead: 23,
          stlEnabled: true,
        ),
        throwsA(anything),
      );
    });
  });
}
