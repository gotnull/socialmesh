// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/payload/spp_constants.dart';
import 'package:socialmesh/services/payload/spp_types.dart';

void main() {
  group('SppPayload', () {
    test('fromWire maps all known wire values', () {
      expect(SppPayload.fromWire(SppPayloadType.file), SppPayload.file);
      expect(SppPayload.fromWire(SppPayloadType.image), SppPayload.image);
      expect(SppPayload.fromWire(SppPayloadType.voice), SppPayload.voice);
      expect(SppPayload.fromWire(SppPayloadType.tak), SppPayload.tak);
      expect(SppPayload.fromWire(SppPayloadType.custom), SppPayload.custom);
    });

    test('fromWire maps unknown values to custom', () {
      expect(SppPayload.fromWire(0x42), SppPayload.custom);
      expect(SppPayload.fromWire(0xFE), SppPayload.custom);
    });

    test('wireValue round-trips for all enum values', () {
      for (final payload in SppPayload.values) {
        final wireValue = payload.wireValue;
        final roundTripped = SppPayload.fromWire(wireValue);
        expect(roundTripped, payload, reason: 'round-trip failed for $payload');
      }
    });

    test('wireValue returns correct constants', () {
      expect(SppPayload.file.wireValue, SppPayloadType.file);
      expect(SppPayload.image.wireValue, SppPayloadType.image);
      expect(SppPayload.voice.wireValue, SppPayloadType.voice);
      expect(SppPayload.tak.wireValue, SppPayloadType.tak);
      expect(SppPayload.custom.wireValue, SppPayloadType.custom);
    });
  });

  group('SppNegotiationState', () {
    test('has all expected values', () {
      expect(
        SppNegotiationState.values,
        contains(SppNegotiationState.offerSent),
      );
      expect(
        SppNegotiationState.values,
        contains(SppNegotiationState.offerPending),
      );
      expect(
        SppNegotiationState.values,
        contains(SppNegotiationState.accepted),
      );
      expect(
        SppNegotiationState.values,
        contains(SppNegotiationState.declined),
      );
      expect(SppNegotiationState.values, contains(SppNegotiationState.aborted));
      expect(
        SppNegotiationState.values,
        contains(SppNegotiationState.timedOut),
      );
    });

    test('enum count is exactly 6', () {
      expect(SppNegotiationState.values.length, 6);
    });
  });

  group('SppAutoAcceptConfig', () {
    test('default config has auto-accept disabled', () {
      const config = SppAutoAcceptConfig.defaultConfig;
      expect(config.enabled, isFalse);
      expect(config.trustedOnly, isTrue);
      expect(config.maxSizeBytes, 4096);
      expect(
        config.allowedTypes,
        containsAll([SppPayload.image, SppPayload.voice, SppPayload.file]),
      );
    });

    test('shouldAutoAccept returns false when disabled', () {
      const config = SppAutoAcceptConfig(enabled: false);
      expect(
        config.shouldAutoAccept(
          payloadType: SppPayload.image,
          payloadSize: 100,
          isTrusted: true,
        ),
        isFalse,
      );
    });

    test('shouldAutoAccept returns true when all criteria met', () {
      const config = SppAutoAcceptConfig(
        enabled: true,
        trustedOnly: true,
        maxSizeBytes: 4096,
        allowedTypes: {SppPayload.image},
      );
      expect(
        config.shouldAutoAccept(
          payloadType: SppPayload.image,
          payloadSize: 1000,
          isTrusted: true,
        ),
        isTrue,
      );
    });

    test('shouldAutoAccept rejects untrusted when trustedOnly', () {
      const config = SppAutoAcceptConfig(
        enabled: true,
        trustedOnly: true,
        maxSizeBytes: 4096,
        allowedTypes: {SppPayload.image},
      );
      expect(
        config.shouldAutoAccept(
          payloadType: SppPayload.image,
          payloadSize: 1000,
          isTrusted: false,
        ),
        isFalse,
      );
    });

    test('shouldAutoAccept accepts untrusted when trustedOnly is false', () {
      const config = SppAutoAcceptConfig(
        enabled: true,
        trustedOnly: false,
        maxSizeBytes: 4096,
        allowedTypes: {SppPayload.image},
      );
      expect(
        config.shouldAutoAccept(
          payloadType: SppPayload.image,
          payloadSize: 1000,
          isTrusted: false,
        ),
        isTrue,
      );
    });

    test('shouldAutoAccept rejects oversized payloads', () {
      const config = SppAutoAcceptConfig(
        enabled: true,
        trustedOnly: false,
        maxSizeBytes: 1000,
        allowedTypes: {SppPayload.image},
      );
      expect(
        config.shouldAutoAccept(
          payloadType: SppPayload.image,
          payloadSize: 1001,
          isTrusted: true,
        ),
        isFalse,
      );
    });

    test('shouldAutoAccept rejects payload at exact size limit', () {
      const config = SppAutoAcceptConfig(
        enabled: true,
        trustedOnly: false,
        maxSizeBytes: 1000,
        allowedTypes: {SppPayload.image},
      );
      // Exact limit should pass (not >, it's >)
      expect(
        config.shouldAutoAccept(
          payloadType: SppPayload.image,
          payloadSize: 1000,
          isTrusted: true,
        ),
        isTrue,
      );
    });

    test('shouldAutoAccept rejects disallowed types', () {
      const config = SppAutoAcceptConfig(
        enabled: true,
        trustedOnly: false,
        maxSizeBytes: 8192,
        allowedTypes: {SppPayload.image},
      );
      expect(
        config.shouldAutoAccept(
          payloadType: SppPayload.file,
          payloadSize: 100,
          isTrusted: true,
        ),
        isFalse,
      );
      expect(
        config.shouldAutoAccept(
          payloadType: SppPayload.voice,
          payloadSize: 100,
          isTrusted: true,
        ),
        isFalse,
      );
    });

    test('copyWith preserves unmodified fields', () {
      const original = SppAutoAcceptConfig(
        enabled: true,
        trustedOnly: true,
        maxSizeBytes: 2048,
        allowedTypes: {SppPayload.voice},
      );
      final modified = original.copyWith(maxSizeBytes: 4096);
      expect(modified.enabled, isTrue);
      expect(modified.trustedOnly, isTrue);
      expect(modified.maxSizeBytes, 4096);
      expect(modified.allowedTypes, {SppPayload.voice});
    });

    test('copyWith replaces all fields when specified', () {
      const original = SppAutoAcceptConfig.defaultConfig;
      final modified = original.copyWith(
        enabled: true,
        trustedOnly: false,
        maxSizeBytes: 100,
        allowedTypes: {SppPayload.tak},
      );
      expect(modified.enabled, isTrue);
      expect(modified.trustedOnly, isFalse);
      expect(modified.maxSizeBytes, 100);
      expect(modified.allowedTypes, {SppPayload.tak});
    });
  });

  group('SppPayloadOffer', () {
    final testPayloadId = Uint8List.fromList(List.generate(16, (i) => i));
    final now = DateTime.now();

    SppPayloadOffer makeOffer({
      SppNegotiationState state = SppNegotiationState.offerPending,
    }) {
      return SppPayloadOffer(
        payloadIdHex: 'deadbeef01234567deadbeef01234567',
        payloadId: testPayloadId,
        payloadType: SppPayload.image,
        filename: 'test.webp',
        mimeType: 'image/webp',
        payloadSize: 2048,
        sourceNodeNum: 0x12345678,
        receivedAt: now,
        state: state,
      );
    }

    test('constructs with all required fields', () {
      final offer = makeOffer();
      expect(offer.payloadIdHex, 'deadbeef01234567deadbeef01234567');
      expect(offer.payloadId, testPayloadId);
      expect(offer.payloadType, SppPayload.image);
      expect(offer.filename, 'test.webp');
      expect(offer.mimeType, 'image/webp');
      expect(offer.payloadSize, 2048);
      expect(offer.sourceNodeNum, 0x12345678);
      expect(offer.receivedAt, now);
      expect(offer.state, SppNegotiationState.offerPending);
    });

    test('sourceNodeNum defaults to null', () {
      final offer = SppPayloadOffer(
        payloadIdHex: 'abc',
        payloadId: testPayloadId,
        payloadType: SppPayload.file,
        filename: 'f.txt',
        mimeType: 'text/plain',
        payloadSize: 10,
        receivedAt: now,
      );
      expect(offer.sourceNodeNum, isNull);
    });

    test('copyWith updates state', () {
      final offer = makeOffer();
      final accepted = offer.copyWith(state: SppNegotiationState.accepted);
      expect(accepted.state, SppNegotiationState.accepted);
      expect(accepted.payloadIdHex, offer.payloadIdHex);
      expect(accepted.filename, offer.filename);
      expect(accepted.payloadSize, offer.payloadSize);
    });

    test('copyWith without arguments preserves state', () {
      final offer = makeOffer(state: SppNegotiationState.declined);
      final copy = offer.copyWith();
      expect(copy.state, SppNegotiationState.declined);
    });
  });
}
