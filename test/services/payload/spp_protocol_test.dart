// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/payload/spp_constants.dart';
import 'package:socialmesh/services/payload/spp_protocol.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_file_transfer.dart';

void main() {
  /// A fixed 16-byte payload ID for deterministic tests.
  final testPayloadId = Uint8List.fromList(List.generate(16, (i) => i + 0x10));
  final testPayloadIdHex = fileIdToHex(testPayloadId);

  group('SppAccept', () {
    test('encodes to 17 bytes', () {
      final accept = SppAccept(payloadId: testPayloadId);
      final encoded = accept.encode();
      expect(encoded, isNotNull);
      expect(encoded!.length, 17);
    });

    test('header byte encodes version and kind correctly', () {
      final accept = SppAccept(payloadId: testPayloadId);
      final encoded = accept.encode()!;
      final version = (encoded[0] >> 4) & 0x0F;
      final kind = encoded[0] & 0x0F;
      expect(version, SppVersion.current);
      expect(kind, SppPacketKind.accept);
    });

    test('payloadId is correctly embedded in bytes 1-16', () {
      final accept = SppAccept(payloadId: testPayloadId);
      final encoded = accept.encode()!;
      expect(encoded.sublist(1, 17), testPayloadId);
    });

    test('decode round-trips correctly', () {
      final accept = SppAccept(payloadId: testPayloadId);
      final encoded = accept.encode()!;
      final decoded = SppAccept.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.payloadId, testPayloadId);
      expect(decoded.payloadIdHex, testPayloadIdHex);
    });

    test('returns null for payloadId not 16 bytes', () {
      final accept = SppAccept(payloadId: Uint8List(8));
      expect(accept.encode(), isNull);
    });

    test('decode returns null for data < 17 bytes', () {
      expect(SppAccept.decode(Uint8List(16)), isNull);
      expect(SppAccept.decode(Uint8List(0)), isNull);
    });

    test('decode returns null for wrong kind nibble', () {
      final buffer = Uint8List(17);
      buffer[0] = (SppVersion.current << 4) | SppPacketKind.decline;
      buffer.setRange(1, 17, testPayloadId);
      expect(SppAccept.decode(buffer), isNull);
    });

    test('decode accepts extra trailing bytes gracefully', () {
      final buffer = Uint8List(30);
      buffer[0] = (SppVersion.current << 4) | SppPacketKind.accept;
      buffer.setRange(1, 17, testPayloadId);
      final decoded = SppAccept.decode(buffer);
      expect(decoded, isNotNull);
      expect(decoded!.payloadId, testPayloadId);
    });
  });

  group('SppDecline', () {
    test('encodes to 18 bytes', () {
      final decline = SppDecline(
        payloadId: testPayloadId,
        reason: SppDeclineReason.userDeclined,
      );
      final encoded = decline.encode();
      expect(encoded, isNotNull);
      expect(encoded!.length, 18);
    });

    test('header byte encodes version and kind correctly', () {
      final decline = SppDecline(
        payloadId: testPayloadId,
        reason: SppDeclineReason.tooLarge,
      );
      final encoded = decline.encode()!;
      final version = (encoded[0] >> 4) & 0x0F;
      final kind = encoded[0] & 0x0F;
      expect(version, SppVersion.current);
      expect(kind, SppPacketKind.decline);
    });

    test('reason byte is at position 17', () {
      final decline = SppDecline(
        payloadId: testPayloadId,
        reason: SppDeclineReason.storageFull,
      );
      final encoded = decline.encode()!;
      expect(encoded[17], SppDeclineReason.storageFull);
    });

    test('decode round-trips all reason codes', () {
      for (final reason in [
        SppDeclineReason.userDeclined,
        SppDeclineReason.typeNotAllowed,
        SppDeclineReason.tooLarge,
        SppDeclineReason.storageFull,
        SppDeclineReason.rateLimited,
        SppDeclineReason.untrusted,
      ]) {
        final decline = SppDecline(payloadId: testPayloadId, reason: reason);
        final encoded = decline.encode()!;
        final decoded = SppDecline.decode(encoded);
        expect(decoded, isNotNull, reason: 'reason=$reason');
        expect(decoded!.reason, reason);
        expect(decoded.payloadId, testPayloadId);
      }
    });

    test('returns null for payloadId not 16 bytes', () {
      final decline = SppDecline(
        payloadId: Uint8List(4),
        reason: SppDeclineReason.userDeclined,
      );
      expect(decline.encode(), isNull);
    });

    test('decode returns null for data < 18 bytes', () {
      expect(SppDecline.decode(Uint8List(17)), isNull);
      expect(SppDecline.decode(Uint8List(0)), isNull);
    });

    test('decode returns null for wrong kind nibble', () {
      final buffer = Uint8List(18);
      buffer[0] = (SppVersion.current << 4) | SppPacketKind.accept;
      buffer.setRange(1, 17, testPayloadId);
      buffer[17] = SppDeclineReason.userDeclined;
      expect(SppDecline.decode(buffer), isNull);
    });
  });

  group('SppAbort', () {
    test('encodes to 18 bytes', () {
      final abort = SppAbort(
        payloadId: testPayloadId,
        reason: SppAbortReason.userCancelled,
      );
      final encoded = abort.encode();
      expect(encoded, isNotNull);
      expect(encoded!.length, 18);
    });

    test('header byte encodes version and kind correctly', () {
      final abort = SppAbort(
        payloadId: testPayloadId,
        reason: SppAbortReason.timeout,
      );
      final encoded = abort.encode()!;
      final version = (encoded[0] >> 4) & 0x0F;
      final kind = encoded[0] & 0x0F;
      expect(version, SppVersion.current);
      expect(kind, SppPacketKind.abort);
    });

    test('reason byte is at position 17', () {
      final abort = SppAbort(
        payloadId: testPayloadId,
        reason: SppAbortReason.error,
      );
      final encoded = abort.encode()!;
      expect(encoded[17], SppAbortReason.error);
    });

    test('decode round-trips all reason codes', () {
      for (final reason in [
        SppAbortReason.userCancelled,
        SppAbortReason.timeout,
        SppAbortReason.error,
      ]) {
        final abort = SppAbort(payloadId: testPayloadId, reason: reason);
        final encoded = abort.encode()!;
        final decoded = SppAbort.decode(encoded);
        expect(decoded, isNotNull, reason: 'reason=$reason');
        expect(decoded!.reason, reason);
        expect(decoded.payloadId, testPayloadId);
      }
    });

    test('returns null for payloadId not 16 bytes', () {
      final abort = SppAbort(
        payloadId: Uint8List(32),
        reason: SppAbortReason.userCancelled,
      );
      expect(abort.encode(), isNull);
    });

    test('decode returns null for data < 18 bytes', () {
      expect(SppAbort.decode(Uint8List(17)), isNull);
      expect(SppAbort.decode(Uint8List(0)), isNull);
    });

    test('decode returns null for wrong kind nibble', () {
      final buffer = Uint8List(18);
      buffer[0] = (SppVersion.current << 4) | SppPacketKind.decline;
      buffer.setRange(1, 17, testPayloadId);
      buffer[17] = SppAbortReason.userCancelled;
      expect(SppAbort.decode(buffer), isNull);
    });
  });

  group('decodeSppNegotiation', () {
    test('decodes ACCEPT packet', () {
      final accept = SppAccept(payloadId: testPayloadId);
      final encoded = accept.encode()!;
      final decoded = decodeSppNegotiation(encoded);
      expect(decoded, isA<SppAccept>());
      expect((decoded! as SppAccept).payloadId, testPayloadId);
    });

    test('decodes DECLINE packet', () {
      final decline = SppDecline(
        payloadId: testPayloadId,
        reason: SppDeclineReason.tooLarge,
      );
      final encoded = decline.encode()!;
      final decoded = decodeSppNegotiation(encoded);
      expect(decoded, isA<SppDecline>());
      expect((decoded! as SppDecline).reason, SppDeclineReason.tooLarge);
    });

    test('decodes ABORT packet', () {
      final abort = SppAbort(
        payloadId: testPayloadId,
        reason: SppAbortReason.timeout,
      );
      final encoded = abort.encode()!;
      final decoded = decodeSppNegotiation(encoded);
      expect(decoded, isA<SppAbort>());
      expect((decoded! as SppAbort).reason, SppAbortReason.timeout);
    });

    test('returns null for empty data', () {
      expect(decodeSppNegotiation(Uint8List(0)), isNull);
    });

    test('returns null for non-negotiation packet kinds', () {
      // OFFER kind should not decode as negotiation
      final buffer = Uint8List(18);
      buffer[0] = (SppVersion.current << 4) | SppPacketKind.offer;
      expect(decodeSppNegotiation(buffer), isNull);

      // CHUNK kind
      buffer[0] = (SppVersion.current << 4) | SppPacketKind.chunk;
      expect(decodeSppNegotiation(buffer), isNull);
    });

    test('returns null for truncated negotiation packets', () {
      // Valid kind but insufficient length
      final buffer = Uint8List(10);
      buffer[0] = (SppVersion.current << 4) | SppPacketKind.accept;
      expect(decodeSppNegotiation(buffer), isNull);
    });
  });

  group('isSppPayload', () {
    test('returns true for all valid SPP kinds', () {
      for (final kind in SppPacketKind.all) {
        final buffer = Uint8List(1);
        buffer[0] = (SppVersion.current << 4) | kind;
        expect(
          isSppPayload(buffer),
          isTrue,
          reason: 'kind=0x${kind.toRadixString(16)}',
        );
      }
    });

    test('returns false for empty data', () {
      expect(isSppPayload(Uint8List(0)), isFalse);
    });

    test('returns false for non-SPP kind nibbles', () {
      for (final kind in [0x00, 0x01, 0x02, 0x03, 0x0B, 0x0F]) {
        final buffer = Uint8List(1);
        buffer[0] = (SppVersion.current << 4) | kind;
        expect(
          isSppPayload(buffer),
          isFalse,
          reason: 'kind=0x${kind.toRadixString(16)}',
        );
      }
    });
  });

  group('isSppNegotiationPayload', () {
    test('returns true for ACCEPT, DECLINE, ABORT', () {
      for (final kind in [
        SppPacketKind.accept,
        SppPacketKind.decline,
        SppPacketKind.abort,
      ]) {
        final buffer = Uint8List(1);
        buffer[0] = (SppVersion.current << 4) | kind;
        expect(
          isSppNegotiationPayload(buffer),
          isTrue,
          reason: 'kind=0x${kind.toRadixString(16)}',
        );
      }
    });

    test('returns false for data-plane packets', () {
      for (final kind in [
        SppPacketKind.offer,
        SppPacketKind.chunk,
        SppPacketKind.nack,
        SppPacketKind.ack,
      ]) {
        final buffer = Uint8List(1);
        buffer[0] = (SppVersion.current << 4) | kind;
        expect(
          isSppNegotiationPayload(buffer),
          isFalse,
          reason: 'kind=0x${kind.toRadixString(16)}',
        );
      }
    });

    test('returns false for empty data', () {
      expect(isSppNegotiationPayload(Uint8List(0)), isFalse);
    });
  });

  group('SppPacketKind', () {
    test('isValid returns true for all defined kinds', () {
      expect(SppPacketKind.isValid(0x04), isTrue);
      expect(SppPacketKind.isValid(0x05), isTrue);
      expect(SppPacketKind.isValid(0x06), isTrue);
      expect(SppPacketKind.isValid(0x07), isTrue);
      expect(SppPacketKind.isValid(0x08), isTrue);
      expect(SppPacketKind.isValid(0x09), isTrue);
      expect(SppPacketKind.isValid(0x0A), isTrue);
    });

    test('isValid returns false for out-of-range kinds', () {
      expect(SppPacketKind.isValid(0x00), isFalse);
      expect(SppPacketKind.isValid(0x03), isFalse);
      expect(SppPacketKind.isValid(0x0B), isFalse);
      expect(SppPacketKind.isValid(0x0F), isFalse);
    });
  });

  group('SppVersion', () {
    test('current version is v1', () {
      expect(SppVersion.current, 1);
      expect(SppVersion.v0, 0);
      expect(SppVersion.v1, 1);
    });

    test('maxSupported >= current', () {
      expect(SppVersion.maxSupported, greaterThanOrEqualTo(SppVersion.current));
    });
  });

  group('SppPayloadType', () {
    test('name returns human-readable names for all types', () {
      expect(SppPayloadType.name(SppPayloadType.file), 'file');
      expect(SppPayloadType.name(SppPayloadType.image), 'image');
      expect(SppPayloadType.name(SppPayloadType.voice), 'voice');
      expect(SppPayloadType.name(SppPayloadType.tak), 'tak');
      expect(SppPayloadType.name(SppPayloadType.custom), 'custom');
    });

    test('name returns unknown for undefined types', () {
      expect(SppPayloadType.name(0x42), 'unknown(66)');
    });
  });

  group('SppDeclineReason', () {
    test('name returns human-readable names for all reasons', () {
      expect(
        SppDeclineReason.name(SppDeclineReason.userDeclined),
        'user_declined',
      );
      expect(
        SppDeclineReason.name(SppDeclineReason.typeNotAllowed),
        'type_not_allowed',
      );
      expect(SppDeclineReason.name(SppDeclineReason.tooLarge), 'too_large');
      expect(
        SppDeclineReason.name(SppDeclineReason.storageFull),
        'storage_full',
      );
      expect(
        SppDeclineReason.name(SppDeclineReason.rateLimited),
        'rate_limited',
      );
      expect(SppDeclineReason.name(SppDeclineReason.untrusted), 'untrusted');
    });

    test('name returns unknown for undefined reasons', () {
      expect(SppDeclineReason.name(0xFF), 'unknown(255)');
    });
  });

  group('SppAbortReason', () {
    test('name returns human-readable names for all reasons', () {
      expect(
        SppAbortReason.name(SppAbortReason.userCancelled),
        'user_cancelled',
      );
      expect(SppAbortReason.name(SppAbortReason.timeout), 'timeout');
      expect(SppAbortReason.name(SppAbortReason.error), 'error');
    });

    test('name returns unknown for undefined reasons', () {
      expect(SppAbortReason.name(0x99), 'unknown(153)');
    });
  });

  group('wire format byte offsets (spec compliance)', () {
    test('ACCEPT header at offset 0, payloadId at offset 1-16', () {
      final accept = SppAccept(payloadId: testPayloadId);
      final bytes = accept.encode()!;
      // Header byte
      expect(bytes[0] & 0x0F, SppPacketKind.accept);
      expect((bytes[0] >> 4) & 0x0F, SppVersion.v1);
      // PayloadId bytes
      for (var i = 0; i < 16; i++) {
        expect(bytes[i + 1], testPayloadId[i]);
      }
    });

    test('DECLINE header at offset 0, payloadId 1-16, reason at 17', () {
      final decline = SppDecline(
        payloadId: testPayloadId,
        reason: SppDeclineReason.untrusted,
      );
      final bytes = decline.encode()!;
      expect(bytes[0] & 0x0F, SppPacketKind.decline);
      for (var i = 0; i < 16; i++) {
        expect(bytes[i + 1], testPayloadId[i]);
      }
      expect(bytes[17], SppDeclineReason.untrusted);
    });

    test('ABORT header at offset 0, payloadId 1-16, reason at 17', () {
      final abort = SppAbort(
        payloadId: testPayloadId,
        reason: SppAbortReason.error,
      );
      final bytes = abort.encode()!;
      expect(bytes[0] & 0x0F, SppPacketKind.abort);
      for (var i = 0; i < 16; i++) {
        expect(bytes[i + 1], testPayloadId[i]);
      }
      expect(bytes[17], SppAbortReason.error);
    });
  });
}
