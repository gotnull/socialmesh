// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_dedup_cache.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';

void main() {
  group('MrrpDedupKey', () {
    test('equality and hashCode', () {
      const a = MrrpDedupKey(
        pubkeyHint: 0xA1B2C3D4,
        sessionTag: 0x0001,
        requestId: 0x0042,
      );
      const b = MrrpDedupKey(
        pubkeyHint: 0xA1B2C3D4,
        sessionTag: 0x0001,
        requestId: 0x0042,
      );
      const c = MrrpDedupKey(
        pubkeyHint: 0xDEADBEEF,
        sessionTag: 0x0001,
        requestId: 0x0042,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('MrrpDedupCache — request dedup', () {
    late MrrpDedupCache cache;
    const key1 = MrrpDedupKey(
      pubkeyHint: 0xA1B2C3D4,
      sessionTag: 0x0001,
      requestId: 0x0001,
    );
    const key2 = MrrpDedupKey(
      pubkeyHint: 0xA1B2C3D4,
      sessionTag: 0x0001,
      requestId: 0x0002,
    );

    setUp(() {
      cache = MrrpDedupCache();
    });

    test('first request returns null (cache miss)', () {
      final result = cache.checkAndRecordRequest(key1);
      expect(result, isNull);
      expect(cache.requestCacheSize, 1);
    });

    test(
      'duplicate request without cached response returns null but isDuplicate true',
      () {
        cache.checkAndRecordRequest(key1);
        final result = cache.checkAndRecordRequest(key1);
        expect(result, isNull);
        expect(cache.isDuplicate(key1), isTrue);
      },
    );

    test('duplicate request with cached response returns the response', () {
      cache.checkAndRecordRequest(key1);

      final response = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.response,
        flags: MrrpFlags.isResponse,
        headerLen: 20,
        requestId: 0x0001,
        serviceId: 0x00000001,
        actionId: 0x0001,
        payloadLen: 4,
        payload: Uint8List.fromList([0xCA, 0xFE, 0xBA, 0xBE]),
      );
      cache.cacheResponse(key1, response);

      final result = cache.checkAndRecordRequest(key1);
      expect(result, isNotNull);
      expect(result!.requestId, 0x0001);
      expect(result.payload, equals([0xCA, 0xFE, 0xBA, 0xBE]));
    });

    test('different keys are independent', () {
      cache.checkAndRecordRequest(key1);
      final result = cache.checkAndRecordRequest(key2);
      expect(result, isNull);
      expect(cache.isDuplicate(key1), isTrue);
      expect(cache.isDuplicate(key2), isTrue);
      expect(cache.requestCacheSize, 2);
    });

    test('LRU eviction when capacity exceeded', () {
      // Fill cache to capacity (64 entries).
      for (var i = 0; i < 64; i++) {
        cache.checkAndRecordRequest(
          MrrpDedupKey(pubkeyHint: 0xAAAA, sessionTag: 0, requestId: i),
        );
      }
      expect(cache.requestCacheSize, 64);

      // Adding one more should evict the oldest.
      cache.checkAndRecordRequest(
        const MrrpDedupKey(pubkeyHint: 0xAAAA, sessionTag: 0, requestId: 999),
      );
      expect(cache.requestCacheSize, 64);

      // The first entry (requestId=0) should have been evicted.
      expect(
        cache.isDuplicate(
          const MrrpDedupKey(pubkeyHint: 0xAAAA, sessionTag: 0, requestId: 0),
        ),
        isFalse,
      );
      // The newest should be present.
      expect(
        cache.isDuplicate(
          const MrrpDedupKey(pubkeyHint: 0xAAAA, sessionTag: 0, requestId: 999),
        ),
        isTrue,
      );
    });

    test('clear removes all entries', () {
      cache.checkAndRecordRequest(key1);
      cache.checkAndRecordRequest(key2);
      expect(cache.requestCacheSize, 2);

      cache.clear();
      expect(cache.requestCacheSize, 0);
      expect(cache.responseCacheSize, 0);
    });
  });

  group('MrrpDedupCache — response dedup', () {
    late MrrpDedupCache cache;

    setUp(() {
      cache = MrrpDedupCache();
    });

    test('first response returns true (should process)', () {
      expect(cache.checkAndRecordResponse(0x0001), isTrue);
      expect(cache.responseCacheSize, 1);
    });

    test('duplicate response returns false (should suppress)', () {
      cache.checkAndRecordResponse(0x0001);
      expect(cache.checkAndRecordResponse(0x0001), isFalse);
    });

    test('different request IDs are independent', () {
      expect(cache.checkAndRecordResponse(0x0001), isTrue);
      expect(cache.checkAndRecordResponse(0x0002), isTrue);
      expect(cache.responseCacheSize, 2);
    });

    test('LRU eviction when response cache capacity exceeded', () {
      // Fill to capacity (32 entries).
      for (var i = 0; i < 32; i++) {
        cache.checkAndRecordResponse(i);
      }
      expect(cache.responseCacheSize, 32);

      // Adding one more evicts the oldest.
      cache.checkAndRecordResponse(999);
      expect(cache.responseCacheSize, 32);

      // Oldest (0) was evicted, so it should be treated as new.
      expect(cache.checkAndRecordResponse(0), isTrue);
    });
  });

  group('MrrpDedupCache — concurrent requests to same ID', () {
    test(
      'parallel requests with same key: first processes, second is dedup',
      () {
        final cache = MrrpDedupCache();
        const key = MrrpDedupKey(
          pubkeyHint: 0xBEEF,
          sessionTag: 0x0042,
          requestId: 0x0001,
        );

        // First request -> new, should process.
        final r1 = cache.checkAndRecordRequest(key);
        expect(r1, isNull);
        expect(cache.isDuplicate(key), isTrue);

        // Simulate handler completing and caching response.
        final response = MrrpFrame(
          versionMajor: 0,
          versionMinor: 1,
          msgType: MrrpMessageType.response,
          flags: MrrpFlags.isResponse,
          headerLen: 20,
          requestId: 0x0001,
          serviceId: 0x00000001,
          actionId: 0x0001,
          payloadLen: 2,
          payload: Uint8List.fromList([0x01, 0x02]),
        );
        cache.cacheResponse(key, response);

        // Second request with same key -> dedup, returns cached response.
        final r2 = cache.checkAndRecordRequest(key);
        expect(r2, isNotNull);
        expect(r2!.payload, equals([0x01, 0x02]));
      },
    );
  });

  group('buildDedupKey', () {
    test('extracts pubkey_hint and session_tag from TLV extensions', () {
      // Build a frame with TLV extensions for pubkey hint and session tag.
      final pubkeyBytes = Uint8List(4);
      ByteData.sublistView(pubkeyBytes).setUint32(0, 0xCAFEBABE, Endian.little);

      final sessionBytes = Uint8List(4);
      ByteData.sublistView(
        sessionBytes,
      ).setUint32(0, 0x00001234, Endian.little);

      final frame = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.request,
        flags: 0,
        headerLen: 20,
        requestId: 0x0099,
        serviceId: 0x00000001,
        actionId: 0x0001,
        payloadLen: 0,
        payload: Uint8List(0),
        headerExtensions: [
          MrrpTlvEntry(
            type: MrrpTlvType.senderPubkeyHint.code,
            value: pubkeyBytes,
          ),
          MrrpTlvEntry(
            type: MrrpTlvType.sessionTagHint.code,
            value: sessionBytes,
          ),
        ],
      );

      final key = buildDedupKey(frame, 0xDEAD);
      expect(key.pubkeyHint, 0xCAFEBABE);
      expect(key.sessionTag, 0x00001234);
      expect(key.requestId, 0x0099);
    });

    test('falls back to senderNodeId when no TLV extensions', () {
      final frame = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.request,
        flags: 0,
        headerLen: 20,
        requestId: 0x0055,
        serviceId: 0x00000001,
        actionId: 0x0001,
        payloadLen: 0,
        payload: Uint8List(0),
      );

      final key = buildDedupKey(frame, 0xABCD1234);
      expect(key.pubkeyHint, 0xABCD1234);
      expect(key.sessionTag, 0);
      expect(key.requestId, 0x0055);
    });
  });
}
