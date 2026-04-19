// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/payload/spp_constants.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_file_transfer.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_codec.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_constants.dart';

void main() {
  group('SmFileOffer', () {
    test('encode/decode round-trip', () {
      final fileId = generateFileId();
      final sha = Uint8List.fromList(List.generate(32, (i) => i + 10));
      final offer = SmFileOffer(
        fileId: fileId,
        filename: 'test.txt',
        mimeType: 'text/plain',
        totalBytes: 1024,
        chunkSize: 200,
        chunkCount: 6,
        sha256Hash: sha,
        createdAt: 1700000000,
        expiresAt: 1700086400,
      );

      final encoded = offer.encode();
      expect(encoded, isNotNull);

      final decoded = SmFileOffer.decode(encoded!);
      expect(decoded, isNotNull);
      expect(decoded!.filename, 'test.txt');
      expect(decoded.mimeType, 'text/plain');
      expect(decoded.totalBytes, 1024);
      expect(decoded.chunkSize, 200);
      expect(decoded.chunkCount, 6);
      expect(decoded.createdAt, 1700000000);
      expect(decoded.expiresAt, 1700086400);
      expect(fileIdToHex(decoded.fileId), fileIdToHex(fileId));
    });

    test('decode rejects too-short payload', () {
      final decoded = SmFileOffer.decode(Uint8List(5));
      expect(decoded, isNull);
    });

    test('decode rejects wrong version', () {
      // Build a valid-length packet but with version 0xF0 (nibble=15)
      final data = Uint8List(50);
      data[0] = 0xF4; // version=15, kind=FILE_OFFER(4)
      final decoded = SmFileOffer.decode(data);
      expect(decoded, isNull);
    });

    test('enforces max filename length', () {
      final fileId = generateFileId();
      final longName = 'x' * 100; // exceeds 64 bytes
      final offer = SmFileOffer(
        fileId: fileId,
        filename: longName,
        mimeType: 'text/plain',
        totalBytes: 100,
        chunkSize: 100,
        chunkCount: 1,
        sha256Hash: Uint8List(32),
        createdAt: 0,
        expiresAt: 0,
      );

      // encode() returns null for filenames > 64 bytes
      final encoded = offer.encode();
      expect(encoded, isNull);
    });
  });

  group('SmFileChunk', () {
    test('encode/decode round-trip', () {
      final fileId = generateFileId();
      final payload = Uint8List.fromList([1, 2, 3, 4, 5]);
      final chunk = SmFileChunk(
        fileId: fileId,
        chunkIndex: 3,
        chunkCount: 10,
        payload: payload,
      );

      final encoded = chunk.encode();
      expect(encoded, isNotNull);

      final decoded = SmFileChunk.decode(encoded!);
      expect(decoded, isNotNull);
      expect(decoded!.chunkIndex, 3);
      expect(decoded.chunkCount, 10);
      expect(decoded.payload, payload);
      expect(fileIdToHex(decoded.fileId), fileIdToHex(fileId));
    });

    test('decode rejects too-short payload', () {
      final decoded = SmFileChunk.decode(Uint8List(3));
      expect(decoded, isNull);
    });
  });

  group('SmFileNack', () {
    test('encode/decode round-trip', () {
      final fileId = generateFileId();
      final nack = SmFileNack(fileId: fileId, missingIndexes: [0, 2, 5, 9]);

      final encoded = nack.encode();
      expect(encoded, isNotNull);

      final decoded = SmFileNack.decode(encoded!);
      expect(decoded, isNotNull);
      expect(decoded!.missingIndexes, [0, 2, 5, 9]);
      expect(fileIdToHex(decoded.fileId), fileIdToHex(fileId));
    });

    test('decode rejects too-short payload', () {
      final decoded = SmFileNack.decode(Uint8List(3));
      expect(decoded, isNull);
    });

    test('limits missing indexes to max', () {
      final fileId = generateFileId();
      final tooMany = List.generate(32, (i) => i);
      final nack = SmFileNack(fileId: fileId, missingIndexes: tooMany);

      final encoded = nack.encode();
      expect(encoded, isNotNull);

      final decoded = SmFileNack.decode(encoded!);
      expect(decoded, isNotNull);
      expect(
        decoded!.missingIndexes.length,
        lessThanOrEqualTo(SmFileTransferLimits.maxNackIndexes),
      );
    });
  });

  group('SmFileAck', () {
    test('encode/decode round-trip', () {
      final fileId = generateFileId();
      final ack = SmFileAck(fileId: fileId, status: FileAckStatus.complete);

      final encoded = ack.encode();
      expect(encoded, isNotNull);

      final decoded = SmFileAck.decode(encoded!);
      expect(decoded, isNotNull);
      expect(decoded!.status, FileAckStatus.complete);
      expect(fileIdToHex(decoded.fileId), fileIdToHex(fileId));
    });

    test('all status values round-trip', () {
      for (final status in FileAckStatus.values) {
        final fileId = generateFileId();
        final ack = SmFileAck(fileId: fileId, status: status);

        final encoded = ack.encode();
        final decoded = SmFileAck.decode(encoded!);
        expect(decoded, isNotNull);
        expect(decoded!.status, status);
      }
    });

    test('decode rejects too-short payload', () {
      final decoded = SmFileAck.decode(Uint8List(3));
      expect(decoded, isNull);
    });
  });

  group('SmCodec file transfer routing', () {
    test('decodes FILE_OFFER via SmCodec.decode', () {
      final fileId = generateFileId();
      final offer = SmFileOffer(
        fileId: fileId,
        filename: 'test.gpx',
        mimeType: 'application/gpx+xml',
        totalBytes: 500,
        chunkSize: 200,
        chunkCount: 3,
        sha256Hash: Uint8List(32),
        createdAt: 0,
        expiresAt: 0,
      );

      final encoded = offer.encode()!;
      final packet = SmCodec.decode(SmPortnum.fileTransfer, encoded);
      expect(packet, isNotNull);
      expect(packet!.type, SmPacketType.fileOffer);
      expect(packet.fileOffer.filename, 'test.gpx');
    });

    test('decodes FILE_CHUNK via SmCodec.decode', () {
      final fileId = generateFileId();
      final chunk = SmFileChunk(
        fileId: fileId,
        chunkIndex: 0,
        chunkCount: 1,
        payload: Uint8List.fromList([42]),
      );

      final encoded = chunk.encode()!;
      final packet = SmCodec.decode(SmPortnum.fileTransfer, encoded);
      expect(packet, isNotNull);
      expect(packet!.type, SmPacketType.fileChunk);
      expect(packet.fileChunk.chunkIndex, 0);
    });

    test('decodes FILE_NACK via SmCodec.decode', () {
      final fileId = generateFileId();
      final nack = SmFileNack(fileId: fileId, missingIndexes: [1, 3]);

      final encoded = nack.encode()!;
      final packet = SmCodec.decode(SmPortnum.fileTransfer, encoded);
      expect(packet, isNotNull);
      expect(packet!.type, SmPacketType.fileNack);
      expect(packet.fileNack.missingIndexes, [1, 3]);
    });

    test('decodes FILE_ACK via SmCodec.decode', () {
      final fileId = generateFileId();
      final ack = SmFileAck(fileId: fileId, status: FileAckStatus.complete);

      final encoded = ack.encode()!;
      final packet = SmCodec.decode(SmPortnum.fileTransfer, encoded);
      expect(packet, isNotNull);
      expect(packet!.type, SmPacketType.fileAck);
      expect(packet.fileAck.status, FileAckStatus.complete);
    });

    test('returns null for unknown portnum', () {
      final packet = SmCodec.decode(999, Uint8List(10));
      expect(packet, isNull);
    });
  });

  group('generateFileId', () {
    test('produces 16-byte IDs', () {
      final id = generateFileId();
      expect(id.length, 16);
    });

    test('produces unique IDs', () {
      final ids = List.generate(100, (_) => fileIdToHex(generateFileId()));
      expect(ids.toSet().length, 100);
    });

    test('hex round-trip', () {
      final id = generateFileId();
      final hex = fileIdToHex(id);
      final restored = fileIdFromHex(hex);
      expect(restored, id);
    });
  });

  group('SmRateLimiter file transfer support', () {
    test('file transfer portnum is recognized', () {
      final limiter = SmRateLimiter();
      expect(limiter.canSend(SmPortnum.fileTransfer), isTrue);
    });

    test('rate limits after send', () {
      final limiter = SmRateLimiter();
      limiter.recordSend(SmPortnum.fileTransfer);
      // Immediately after send, should be rate-limited
      expect(limiter.canSend(SmPortnum.fileTransfer), isFalse);
    });
  });

  // ─── SPP v1 wire format verification ─────────────────────────────

  group('SPP v1 header encoding', () {
    test('SmFileOffer.encode produces v1 header byte 0x14', () {
      final offer = SmFileOffer(
        fileId: generateFileId(),
        filename: 'test.txt',
        mimeType: 'text/plain',
        totalBytes: 100,
        chunkSize: 100,
        chunkCount: 1,
        sha256Hash: Uint8List(32),
        createdAt: 0,
        expiresAt: 0,
      );

      final encoded = offer.encode()!;
      // Header byte: (SppVersion.current << 4) | 4 = 0x14
      expect(
        encoded[0],
        0x14,
        reason: 'Offer header must be v1 (0x14), not v0 (0x04)',
      );
      expect(
        encoded[0] >> 4,
        SppVersion.current,
        reason: 'High nibble must be SppVersion.current',
      );
      expect(
        encoded[0] & 0x0F,
        SmPacketKind.fileOffer,
        reason: 'Low nibble must be FILE_OFFER (4)',
      );
    });

    test('SmFileChunk.encode produces v1 header byte 0x15', () {
      final chunk = SmFileChunk(
        fileId: generateFileId(),
        chunkIndex: 0,
        chunkCount: 1,
        payload: Uint8List.fromList([42]),
      );

      final encoded = chunk.encode()!;
      expect(
        encoded[0],
        0x15,
        reason: 'Chunk header must be v1 (0x15), not v0 (0x05)',
      );
      expect(encoded[0] >> 4, SppVersion.current);
      expect(encoded[0] & 0x0F, SmPacketKind.fileChunk);
    });

    test('SmFileNack.encode produces v1 header byte 0x16', () {
      final nack = SmFileNack(fileId: generateFileId(), missingIndexes: [0, 1]);

      final encoded = nack.encode()!;
      expect(
        encoded[0],
        0x16,
        reason: 'Nack header must be v1 (0x16), not v0 (0x06)',
      );
      expect(encoded[0] >> 4, SppVersion.current);
      expect(encoded[0] & 0x0F, SmPacketKind.fileNack);
    });

    test('SmFileAck.encode produces v1 header byte 0x17', () {
      final ack = SmFileAck(
        fileId: generateFileId(),
        status: FileAckStatus.complete,
      );

      final encoded = ack.encode()!;
      expect(
        encoded[0],
        0x17,
        reason: 'Ack header must be v1 (0x17), not v0 (0x07)',
      );
      expect(encoded[0] >> 4, SppVersion.current);
      expect(encoded[0] & 0x0F, SmPacketKind.fileAck);
    });

    test(
      'encode→SmCodec.decodeFileTransfer round-trip preserves version=1',
      () {
        final offer = SmFileOffer(
          fileId: generateFileId(),
          filename: 'round-trip.bin',
          mimeType: 'application/octet-stream',
          totalBytes: 500,
          chunkSize: 200,
          chunkCount: 3,
          sha256Hash: Uint8List(32),
          createdAt: 1700000000,
          expiresAt: 1700086400,
        );

        final encoded = offer.encode()!;
        final packet = SmCodec.decodeFileTransfer(encoded);
        expect(packet, isNotNull);
        expect(
          packet!.version,
          1,
          reason: 'Decoded version must be 1 (SPP v1)',
        );
        expect(packet.type, SmPacketType.fileOffer);
        expect(packet.fileOffer.filename, 'round-trip.bin');
      },
    );

    test('legacy v0 offer (header 0x04) still decodes with version=0', () {
      // Manually construct a v0 offer by patching the first byte.
      final offer = SmFileOffer(
        fileId: generateFileId(),
        filename: 'legacy.bin',
        mimeType: 'application/octet-stream',
        totalBytes: 100,
        chunkSize: 100,
        chunkCount: 1,
        sha256Hash: Uint8List(32),
        createdAt: 0,
        expiresAt: 0,
      );

      final encoded = offer.encode()!;
      // Patch header to v0.
      encoded[0] = SmPacketKind.fileOffer; // 0x04 (version=0)

      final packet = SmCodec.decodeFileTransfer(encoded);
      expect(packet, isNotNull);
      expect(
        packet!.version,
        0,
        reason: 'Legacy v0 offer decodes with version=0',
      );
      expect(packet.type, SmPacketType.fileOffer);
      expect(packet.fileOffer.filename, 'legacy.bin');
    });
  });
}
