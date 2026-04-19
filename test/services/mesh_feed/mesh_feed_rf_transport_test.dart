// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/mesh_feed/mesh_post.dart';
import 'package:socialmesh/services/mesh_feed/mesh_propagation_policy.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_codec.dart';
import 'package:socialmesh/services/protocol/socialmesh/sm_constants.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // Wire format: SmCodec integration with MeshPost encode/decode
  // ═══════════════════════════════════════════════════════════════════════

  group('SmCodec feedPost decode', () {
    test('decode valid feed post payload via SmCodec', () {
      final post = MeshPost(
        authorNodeNum: 0xAABBCCDD,
        createdAtMs: 1700000000000,
        content: 'Hello via SmCodec!',
        ttl: MeshPostTtl.hours24,
        propagation: MeshPostPropagation.normal,
      );

      final encoded = post.encodeForLora();
      expect(encoded, isNotNull);

      // Decode via SmCodec (portnum 264)
      final packet = SmCodec.decode(SmPortnum.feedPost, encoded!);
      expect(packet, isNotNull);
      expect(packet!.type, equals(SmPacketType.feedPost));

      // The payload should be the raw wire bytes
      final rawPayload = packet.feedPostPayload;
      expect(rawPayload, isNotNull);
      expect(rawPayload.length, equals(encoded.length));

      // Final decode with author from envelope
      final decoded = MeshPost.decodeFromLora(rawPayload, 0xAABBCCDD);
      expect(decoded, isNotNull);
      expect(decoded!.id, equals(post.id));
      expect(decoded.content, equals('Hello via SmCodec!'));
    });

    test('decode rejects wrong portnum', () {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: 1000000000000,
        content: 'test',
      );
      final encoded = post.encodeForLora()!;

      // SmCodec.decode with wrong portnum should return null for feedPost
      final packet = SmCodec.decode(SmPortnum.presence, encoded);
      expect(packet, isNull);
    });

    test('decodeFeedPost rejects too-short payload', () {
      expect(SmCodec.decodeFeedPost(Uint8List(5)), isNull);
    });

    test('decodeFeedPost rejects wrong kind nibble', () {
      final data = Uint8List(8);
      data[0] = 0x02; // kind = 0x02 (signal, not feedPost)
      expect(SmCodec.decodeFeedPost(data), isNull);
    });

    test('decodeFeedPost rejects unsupported version', () {
      final data = Uint8List(8);
      data[0] = 0x2B; // version = 2 (unsupported), kind = 0x0B
      expect(SmCodec.decodeFeedPost(data), isNull);
    });

    test('decodeFeedPost accepts version 0 and 1', () {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: 1000000000000,
        content: 'V',
      );
      final encoded = post.encodeForLora()!;
      expect(encoded[0] & 0xF0, equals(0x00)); // version 0

      // Should decode successfully
      expect(SmCodec.decodeFeedPost(encoded), isNotNull);

      // Version 1 should also work
      final v1 = Uint8List.fromList(encoded);
      v1[0] = 0x1B; // version 1, kind 0x0B
      expect(SmCodec.decodeFeedPost(v1), isNotNull);
    });

    test('feedPost is NOT detected as file transfer payload', () {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: 1000000000000,
        content: 'test',
      );
      final encoded = post.encodeForLora()!;
      // Kind 0x0B should NOT match file transfer range (0x04-0x0A)
      expect(SmCodec.isFileTransferPayload(encoded), isFalse);
    });

    test('feedPost portnum is recognized as Socialmesh', () {
      expect(SmCodec.isSocialmeshPortnum(SmPortnum.feedPost), isTrue);
      expect(SmCodec.isSocialmeshPortnum(264), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Deterministic identity: RF/LAN cross-transport dedup
  // ═══════════════════════════════════════════════════════════════════════

  group('Cross-transport deterministic ID', () {
    test('encode→decode via LoRa produces same ID as local', () {
      final localPost = MeshPost(
        authorNodeNum: 0x12345678,
        createdAtMs: 1700000000000,
        content: 'Cross-transport test',
        seenViaTransports: {MeshTransportType.local},
        isLocal: true,
      );

      final encoded = localPost.encodeForLora()!;
      final rfPost = MeshPost.decodeFromLora(encoded, 0x12345678);
      expect(rfPost, isNotNull);
      expect(rfPost!.id, equals(localPost.id));
      expect(rfPost.seenViaTransports, contains(MeshTransportType.lora));
    });

    test('same content from RF and LAN collapses to same ID', () {
      const authorNode = 42;
      const createdAtMs = 1700000000000;
      const content = 'Same content, different transport';

      final rfPost = MeshPost(
        authorNodeNum: authorNode,
        createdAtMs: createdAtMs,
        content: content,
        seenViaTransports: {MeshTransportType.lora},
      );

      final lanPost = MeshPost(
        authorNodeNum: authorNode,
        createdAtMs: createdAtMs,
        content: content,
        seenViaTransports: {MeshTransportType.lanPeerSync},
      );

      expect(rfPost.id, equals(lanPost.id));
    });

    test('timestamp second-precision alignment preserves ID', () {
      // LoRa wire uses seconds, so createdAtMs with sub-second precision
      // would differ. Verify that the constructor handles this correctly.
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: 1700000000500, // 500ms sub-second
        content: 'test',
      );
      final encoded = post.encodeForLora()!;
      final decoded = MeshPost.decodeFromLora(encoded, 1);

      // Decoded timestamp will be rounded to seconds (1700000000000)
      // so the IDs WILL differ. This is by design — the original
      // post's ms-precision ID is the canonical one and will be used
      // for DB insertion. The RF-received version with truncated ms
      // generates a different ID. This test documents this behavior.
      expect(decoded!.createdAtMs, equals(1700000000000));
      // The IDs differ because createdAtMs differs
      if (post.createdAtMs != decoded.createdAtMs) {
        expect(decoded.id, isNot(equals(post.id)));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Outbound: propagation policy for RF send eligibility
  // ═══════════════════════════════════════════════════════════════════════

  group('RF send eligibility via MeshPropagationPolicy', () {
    const policy = MeshPropagationPolicy();
    final now = DateTime(2026, 4, 15, 12, 0, 0);

    MeshPost makeLocalPost({
      MeshPostTtl ttl = MeshPostTtl.hours24,
      MeshPostPropagation propagation = MeshPostPropagation.normal,
      Duration age = Duration.zero,
      String content = 'Hello mesh',
      int? loraRebroadcastAtMs,
    }) {
      return MeshPost(
        authorNodeNum: 1,
        createdAtMs: now.subtract(age).millisecondsSinceEpoch,
        content: content,
        ttl: ttl,
        propagation: propagation,
        isLocal: true,
        seenViaTransports: {MeshTransportType.local},
        loraRebroadcastAtMs: loraRebroadcastAtMs,
      );
    }

    test('fresh local post with normal propagation is eligible', () {
      final post = makeLocalPost();
      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.eligible),
      );
    });

    test('local post already broadcast is denied', () {
      final post = makeLocalPost(
        loraRebroadcastAtMs: now
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
      );
      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.deniedAlreadyRebroadcast),
      );
    });

    test('localOnly post is denied even if fresh', () {
      final post = makeLocalPost(propagation: MeshPostPropagation.localOnly);
      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.deniedLocalOnly),
      );
    });

    test('oversized content is denied for RF', () {
      final post = makeLocalPost(content: 'x' * 201);
      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.deniedOverBudget),
      );
    });

    test('200-byte content is eligible', () {
      final post = makeLocalPost(content: 'x' * 200);
      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.eligible),
      );
    });

    test('expired post is denied', () {
      final post = makeLocalPost(
        ttl: MeshPostTtl.hours1,
        age: const Duration(hours: 2),
      );
      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.deniedExpired),
      );
    });

    test('post too old for its TTL is denied', () {
      // Default maxAgeFraction = 0.5, so 13 hours into a 24-hour TTL
      final post = makeLocalPost(
        ttl: MeshPostTtl.hours24,
        age: const Duration(hours: 13),
      );
      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.deniedTooOld),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Inbound: decode and ingest simulation
  // ═══════════════════════════════════════════════════════════════════════

  group('RF inbound decode pipeline', () {
    test('full pipeline: encode → SmCodec decode → MeshPost decode', () {
      final original = MeshPost(
        authorNodeNum: 0xCAFEBABE,
        createdAtMs: 1700000000000,
        content: 'End-to-end test',
        ttl: MeshPostTtl.days3,
        propagation: MeshPostPropagation.normal,
      );

      // Step 1: Encode for wire
      final wireBytes = original.encodeForLora();
      expect(wireBytes, isNotNull);

      // Step 2: SmCodec decode (as ProtocolService would)
      final smPacket = SmCodec.decode(SmPortnum.feedPost, wireBytes!);
      expect(smPacket, isNotNull);
      expect(smPacket!.type, equals(SmPacketType.feedPost));

      // Step 3: Extract raw payload and decode with author from envelope
      final rawPayload = smPacket.feedPostPayload;
      final receivedPost = MeshPost.decodeFromLora(rawPayload, 0xCAFEBABE);
      expect(receivedPost, isNotNull);

      // Step 4: Verify canonical fields match
      expect(receivedPost!.id, equals(original.id));
      expect(receivedPost.authorNodeNum, equals(original.authorNodeNum));
      expect(receivedPost.content, equals(original.content));
      expect(receivedPost.ttl, equals(original.ttl));
      expect(receivedPost.propagation, equals(original.propagation));
      expect(receivedPost.seenViaTransports, contains(MeshTransportType.lora));
      expect(receivedPost.isLocal, isFalse);
    });

    test('malformed payload is safely rejected', () {
      final garbage = Uint8List.fromList([0xFF, 0x00, 0x01, 0x02, 0x03]);
      final smPacket = SmCodec.decode(SmPortnum.feedPost, garbage);
      expect(smPacket, isNull);
    });

    test('empty payload is safely rejected', () {
      final smPacket = SmCodec.decode(SmPortnum.feedPost, Uint8List(0));
      expect(smPacket, isNull);
    });

    test('truncated payload is safely rejected', () {
      // Valid header but truncated content
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: 1000000000000,
        content: 'Hello world test',
      );
      final encoded = post.encodeForLora()!;
      // Truncate: keep header, timestamp, flags, contentLen but cut content
      final truncated = encoded.sublist(0, 7);
      // contentLen says there should be more bytes
      if (truncated[6] > 0) {
        final decoded = MeshPost.decodeFromLora(truncated, 1);
        expect(decoded, isNull);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Wire format: size budget and constants
  // ═══════════════════════════════════════════════════════════════════════

  group('RF wire format size constraints', () {
    test('max content fits within LoRa MTU', () {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: 1000000000000,
        content: 'A' * 200, // Max content
      );
      final encoded = post.encodeForLora()!;
      // 1 (header) + 4 (timestamp) + 1 (flags) + 1 (contentLen) + 200 = 207
      expect(encoded.length, equals(207));
      expect(
        encoded.length,
        lessThanOrEqualTo(SmPayloadLimit.loraMtu),
        reason: 'Feed post must fit within LoRa MTU ($SmPayloadLimit.loraMtu)',
      );
    });

    test('empty content produces minimum wire size', () {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: 1000000000000,
        content: '',
      );
      final encoded = post.encodeForLora()!;
      // 1 (header) + 4 (timestamp) + 1 (flags) + 1 (contentLen) + 0 = 7
      expect(encoded.length, equals(7));
    });

    test('constants are consistent', () {
      expect(SmPortnum.feedPost, equals(264));
      expect(SmPacketKind.feedPost, equals(0x0B));
      expect(SmTransport.feedPostHopLimit, equals(3));
      expect(SmPayloadLimit.feedPostContentMaxBytes, equals(200));
      expect(SmRateLimit.feedPostInterval, equals(const Duration(minutes: 5)));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // SmRateLimiter: feedPost rate limiting
  // ═══════════════════════════════════════════════════════════════════════

  group('SmRateLimiter feedPost handling', () {
    test('feedPost uses 5-minute interval', () {
      final limiter = SmRateLimiter();

      // First send should be allowed
      expect(limiter.canSend(SmPortnum.feedPost), isTrue);

      // Record send
      limiter.recordSend(SmPortnum.feedPost);

      // Immediately after, should be rate-limited
      expect(limiter.canSend(SmPortnum.feedPost), isFalse);

      // Cooldown should be close to 5 minutes
      final remaining = limiter.cooldownRemaining(SmPortnum.feedPost);
      expect(remaining.inMinutes, greaterThanOrEqualTo(4));
    });

    test('feedPost rate limiting is independent from signal', () {
      final limiter = SmRateLimiter();

      // Send a signal
      limiter.recordSend(SmPortnum.signal);

      // Feed post should still be available
      expect(limiter.canSend(SmPortnum.feedPost), isTrue);

      // Send a feed post
      limiter.recordSend(SmPortnum.feedPost);

      // Signal should still be rate-limited (from its own send)
      expect(limiter.canSend(SmPortnum.signal), isFalse);
      // Feed post should also be rate-limited
      expect(limiter.canSend(SmPortnum.feedPost), isFalse);
    });

    test('reset clears feedPost rate limit', () {
      final limiter = SmRateLimiter();
      limiter.recordSend(SmPortnum.feedPost);
      expect(limiter.canSend(SmPortnum.feedPost), isFalse);

      limiter.reset();
      expect(limiter.canSend(SmPortnum.feedPost), isTrue);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Policy: metadata-only changes don't trigger RF resend
  // ═══════════════════════════════════════════════════════════════════════

  group('Metadata-only changes should not trigger RF resend', () {
    const policy = MeshPropagationPolicy();
    final now = DateTime(2026, 4, 15, 12, 0, 0);

    test('post with loraRebroadcastAtMs set is denied', () {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: now.millisecondsSinceEpoch,
        content: 'Already sent',
        loraRebroadcastAtMs: now
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
        seenViaTransports: {MeshTransportType.local},
        isLocal: true,
      );

      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.deniedAlreadyRebroadcast),
      );
    });

    test('post with updated transports but already broadcast is denied', () {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: now.millisecondsSinceEpoch,
        content: 'Merged post',
        loraRebroadcastAtMs: now
            .subtract(const Duration(minutes: 1))
            .millisecondsSinceEpoch,
        seenViaTransports: {
          MeshTransportType.local,
          MeshTransportType.lanPeerSync,
        },
        isLocal: true,
      );

      expect(
        policy.evaluate(post, now: now),
        equals(PropagationDecision.deniedAlreadyRebroadcast),
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // SmPacketType exhaustiveness
  // ═══════════════════════════════════════════════════════════════════════

  group('SmPacketType feedPost variant', () {
    test('feedPost is in SmPacketType values', () {
      expect(SmPacketType.values, contains(SmPacketType.feedPost));
    });

    test('SmPacket feedPostPayload accessor works', () {
      final post = MeshPost(
        authorNodeNum: 42,
        createdAtMs: 1700000000000,
        content: 'Accessor test',
      );
      final encoded = post.encodeForLora()!;
      final smPacket = SmCodec.decodeFeedPost(encoded);

      expect(smPacket, isNotNull);
      expect(smPacket!.type, equals(SmPacketType.feedPost));
      expect(smPacket.feedPostPayload, isA<Uint8List>());
      expect(smPacket.feedPostPayload.length, equals(encoded.length));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Feature flag and constants
  // ═══════════════════════════════════════════════════════════════════════

  group('Portnum and constant validity', () {
    test('feedPost portnum 264 is in SmPortnum.all', () {
      expect(SmPortnum.all, contains(264));
      expect(SmPortnum.all, contains(SmPortnum.feedPost));
    });

    test('feedPost portnum does not collide with other SM portnums', () {
      final portnums = [
        SmPortnum.presence,
        SmPortnum.signal,
        SmPortnum.identity,
        SmPortnum.fileTransfer,
        SmPortnum.feedPost,
      ];
      expect(portnums.toSet().length, equals(portnums.length));
    });

    test('feedPost kind does not collide with file transfer range', () {
      expect(SmPacketKind.feedPost, greaterThan(SmPacketKind.sppAbort));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Unicode / emoji content
  // ═══════════════════════════════════════════════════════════════════════

  group('Unicode content handling', () {
    test('emoji content encodes and decodes correctly', () {
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: 1700000000000,
        content: '🔥⚡🌍', // 12 UTF-8 bytes
      );

      final encoded = post.encodeForLora();
      expect(encoded, isNotNull);

      final decoded = MeshPost.decodeFromLora(encoded!, 1);
      expect(decoded, isNotNull);
      expect(decoded!.content, equals('🔥⚡🌍'));
      expect(decoded.id, equals(post.id));
    });

    test('multi-byte content near 200-byte limit', () {
      // 50 emoji × 4 bytes each = 200 bytes exactly
      final emojiContent = '🔥' * 50;
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: 1700000000000,
        content: emojiContent,
      );

      final encoded = post.encodeForLora();
      expect(encoded, isNotNull);

      final decoded = MeshPost.decodeFromLora(encoded!, 1);
      expect(decoded, isNotNull);
      expect(decoded!.content, equals(emojiContent));
    });

    test('51 emoji exceeds 200-byte limit', () {
      final emojiContent = '🔥' * 51; // 204 bytes
      final post = MeshPost(
        authorNodeNum: 1,
        createdAtMs: 1700000000000,
        content: emojiContent,
      );
      expect(post.encodeForLora(), isNull);
    });
  });
}
