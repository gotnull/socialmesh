// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/mesh_feed/mesh_post.dart';

void main() {
  group('MeshPost deterministic identity', () {
    test('same inputs produce identical IDs', () {
      final a = MeshPost(
        authorNodeNum: 0x12345678,
        createdAtMs: 1700000000000,
        content: 'Hello mesh!',
      );
      final b = MeshPost(
        authorNodeNum: 0x12345678,
        createdAtMs: 1700000000000,
        content: 'Hello mesh!',
      );
      expect(a.id, equals(b.id));
      expect(a.id.length, equals(32));
    });

    test('different author produces different ID', () {
      final a = MeshPost(
        authorNodeNum: 0x12345678,
        createdAtMs: 1700000000000,
        content: 'Hello mesh!',
      );
      final b = MeshPost(
        authorNodeNum: 0x87654321,
        createdAtMs: 1700000000000,
        content: 'Hello mesh!',
      );
      expect(a.id, isNot(equals(b.id)));
    });

    test('different timestamp produces different ID', () {
      final a = MeshPost(
        authorNodeNum: 0x12345678,
        createdAtMs: 1700000000000,
        content: 'Hello mesh!',
      );
      final b = MeshPost(
        authorNodeNum: 0x12345678,
        createdAtMs: 1700000001000,
        content: 'Hello mesh!',
      );
      expect(a.id, isNot(equals(b.id)));
    });

    test('different content produces different ID', () {
      final a = MeshPost(
        authorNodeNum: 0x12345678,
        createdAtMs: 1700000000000,
        content: 'Hello mesh!',
      );
      final b = MeshPost(
        authorNodeNum: 0x12345678,
        createdAtMs: 1700000000000,
        content: 'Hello mesh!!',
      );
      expect(a.id, isNot(equals(b.id)));
    });

    test('ID is hex-encoded 32-char string', () {
      final post = MeshPost(authorNodeNum: 1, createdAtMs: 0, content: '');
      expect(post.id.length, equals(32));
      expect(
        RegExp(r'^[0-9a-f]{32}$').hasMatch(post.id),
        isTrue,
        reason: 'ID must be lowercase hex',
      );
    });

    test('cross-transport dedup — same content from different transports', () {
      final loraPost = MeshPost(
        authorNodeNum: 42,
        createdAtMs: 1700000000000,
        content: 'Emergency: bridge out on trail 7',
        seenViaTransports: {MeshTransportType.lora},
      );
      final syncPost = MeshPost(
        authorNodeNum: 42,
        createdAtMs: 1700000000000,
        content: 'Emergency: bridge out on trail 7',
        seenViaTransports: {MeshTransportType.lanPeerSync},
      );
      expect(loraPost.id, equals(syncPost.id));
    });

    test('equality is based on ID only', () {
      final a = MeshPost(
        authorNodeNum: 1,
        createdAtMs: 1000,
        content: 'test',
        ttl: MeshPostTtl.hours1,
      );
      final b = MeshPost(
        authorNodeNum: 1,
        createdAtMs: 1000,
        content: 'test',
        ttl: MeshPostTtl.days7,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });

  group('MeshPost expiry', () {
    test('expiresAt computed from createdAtMs + ttl', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: now,
        content: 'test',
        ttl: MeshPostTtl.hours1,
      );
      final expected = DateTime.fromMillisecondsSinceEpoch(
        now,
      ).add(const Duration(hours: 1));
      expect(post.expiresAt, equals(expected));
    });

    test('isExpired is true for old posts', () {
      final oldMs = DateTime.now()
          .subtract(const Duration(hours: 2))
          .millisecondsSinceEpoch;
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: oldMs,
        content: 'old',
        ttl: MeshPostTtl.hours1,
      );
      expect(post.isExpired, isTrue);
    });

    test('isExpired is false for fresh posts', () {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: DateTime.now().millisecondsSinceEpoch,
        content: 'fresh',
        ttl: MeshPostTtl.hours24,
      );
      expect(post.isExpired, isFalse);
    });
  });

  group('MeshPost LoRa wire format', () {
    test('encode and decode round-trip', () {
      final original = MeshPost(
        authorNodeNum: 0xDEADBEEF,
        createdAtMs: 1700000000000,
        content: 'Round trip test!',
        ttl: MeshPostTtl.hours6,
        propagation: MeshPostPropagation.conservative,
      );

      final encoded = original.encodeForLora();
      expect(encoded, isNotNull);

      final decoded = MeshPost.decodeFromLora(encoded!, 0xDEADBEEF);
      expect(decoded, isNotNull);
      expect(decoded!.content, equals('Round trip test!'));
      // Timestamps lose sub-second precision (wire uses seconds)
      expect(decoded.createdAtMs, equals(1700000000000));
      expect(decoded.ttl, equals(MeshPostTtl.hours6));
      expect(decoded.propagation, equals(MeshPostPropagation.conservative));
      expect(decoded.id, equals(original.id));
    });

    test('header byte encodes kind 0x0B', () {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: 1000000000000,
        content: 'X',
      );
      final encoded = post.encodeForLora()!;
      expect(encoded[0] & 0x0F, equals(0x0B));
    });

    test('content exceeding 200 bytes returns null', () {
      final longContent = 'A' * 201;
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: 1000000000000,
        content: longContent,
      );
      expect(post.encodeForLora(), isNull);
    });

    test('exactly 200 bytes encodes successfully', () {
      final maxContent = 'A' * 200;
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: 1000000000000,
        content: maxContent,
      );
      expect(post.encodeForLora(), isNotNull);
    });

    test('empty content encodes and decodes', () {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: 1000000000000,
        content: '',
      );
      final encoded = post.encodeForLora()!;
      final decoded = MeshPost.decodeFromLora(encoded, 1);
      expect(decoded, isNotNull);
      expect(decoded!.content, equals(''));
    });

    test('decode rejects truncated data', () {
      expect(MeshPost.decodeFromLora(Uint8List(6), 1), isNull);
    });

    test('decode rejects wrong kind', () {
      final data = Uint8List(8);
      data[0] = 0x0A; // Wrong kind
      expect(MeshPost.decodeFromLora(data, 1), isNull);
    });

    test('flags encode ttl and propagation correctly', () {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: 1000000000000,
        content: 'X',
        ttl: MeshPostTtl.days3, // index 3
        propagation: MeshPostPropagation.localOnly, // index 2
      );
      final encoded = post.encodeForLora()!;
      final flags = encoded[5];
      expect(flags & 0x07, equals(3)); // ttl bits
      expect((flags >> 3) & 0x03, equals(2)); // propagation bits
    });
  });

  group('MeshPost database round-trip', () {
    test('toRow and fromRow preserve all fields', () {
      final post = MeshPost(
        authorNodeNum: 42,
        createdAtMs: 1700000000000,
        content: 'DB test',
        ttl: MeshPostTtl.days7,
        propagation: MeshPostPropagation.conservative,
        seenViaTransports: {
          MeshTransportType.lora,
          MeshTransportType.lanPeerSync,
        },
        hopCount: 3,
        isLocal: true,
        trustScore: 0.75,
        syncState: MeshPostSyncState.synced,
      );

      final row = post.toRow();
      final restored = MeshPost.fromRow(row);

      expect(restored.id, equals(post.id));
      expect(restored.authorNodeNum, equals(42));
      expect(restored.createdAtMs, equals(1700000000000));
      expect(restored.content, equals('DB test'));
      expect(restored.ttl, equals(MeshPostTtl.days7));
      expect(restored.propagation, equals(MeshPostPropagation.conservative));
      expect(restored.hopCount, equals(3));
      expect(restored.isLocal, isTrue);
      expect(restored.trustScore, equals(0.75));
      expect(restored.syncState, equals(MeshPostSyncState.synced));
      expect(
        restored.seenViaTransports,
        containsAll([MeshTransportType.lora, MeshTransportType.lanPeerSync]),
      );
    });
  });

  group('MeshPost copyWith', () {
    test('preserves ID and immutable fields', () {
      final original = MeshPost(
        authorNodeNum: 1,
        createdAtMs: 1000,
        content: 'test',
      );
      final copy = original.copyWith(
        trustScore: 0.9,
        syncState: MeshPostSyncState.synced,
      );
      expect(copy.id, equals(original.id));
      expect(copy.authorNodeNum, equals(1));
      expect(copy.content, equals('test'));
      expect(copy.trustScore, equals(0.9));
      expect(copy.syncState, equals(MeshPostSyncState.synced));
    });
  });

  group('MeshPostTtl', () {
    test('wireIndex matches enum index', () {
      expect(MeshPostTtl.hours1.wireIndex, equals(0));
      expect(MeshPostTtl.hours6.wireIndex, equals(1));
      expect(MeshPostTtl.hours24.wireIndex, equals(2));
      expect(MeshPostTtl.days3.wireIndex, equals(3));
      expect(MeshPostTtl.days7.wireIndex, equals(4));
    });

    test('fromWireIndex round-trips', () {
      for (final ttl in MeshPostTtl.values) {
        expect(MeshPostTtl.fromWireIndex(ttl.wireIndex), equals(ttl));
      }
    });

    test('fromWireIndex defaults to hours24 for unknown', () {
      expect(MeshPostTtl.fromWireIndex(99), equals(MeshPostTtl.hours24));
      expect(MeshPostTtl.fromWireIndex(-1), equals(MeshPostTtl.hours24));
    });
  });

  group('MeshPostPropagation', () {
    test('fromWireIndex round-trips', () {
      for (final p in MeshPostPropagation.values) {
        expect(MeshPostPropagation.fromWireIndex(p.wireIndex), equals(p));
      }
    });

    test('fromWireIndex defaults to normal for unknown', () {
      expect(
        MeshPostPropagation.fromWireIndex(99),
        equals(MeshPostPropagation.normal),
      );
    });
  });

  group('MeshPostSyncState', () {
    test('fromValue round-trips', () {
      for (final s in MeshPostSyncState.values) {
        expect(MeshPostSyncState.fromValue(s.value), equals(s));
      }
    });

    test('fromValue defaults to pending for unknown', () {
      expect(
        MeshPostSyncState.fromValue(99),
        equals(MeshPostSyncState.pending),
      );
    });
  });
}
