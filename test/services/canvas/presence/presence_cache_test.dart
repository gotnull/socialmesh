// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// In-memory presence cache tests.
//
// Source of truth: docs/canvas/CANVAS_PRESENCE_V0_1.md §4 + §9.2.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/canvas/canvas_constants.dart';
import 'package:socialmesh/services/canvas/presence_cache.dart';
import 'package:socialmesh/services/canvas/presence_models.dart';

const int _defaultCanvas = 1;
const int _defaultChannel = 0;
const int _defaultNode = 0xA0;
const int _defaultEmitTs = 1000;
const int _defaultTtl = 180;
const int _defaultNow = 5000;

bool _upsert(
  PresenceCache cache, {
  required PresenceState state,
  int canvasLocalId = _defaultCanvas,
  int channelIndex = _defaultChannel,
  int nodeNum = _defaultNode,
  int emitTsSec = _defaultEmitTs,
  int ttlSeconds = _defaultTtl,
  int nowMs = _defaultNow,
  PresenceSource source = PresenceSource.radio,
  String? displayNameHint,
}) {
  return cache.upsert(
    nodeNum: nodeNum,
    canvasLocalId: canvasLocalId,
    channelIndex: channelIndex,
    state: state,
    emitTsSec: emitTsSec,
    ttlSeconds: ttlSeconds,
    source: source,
    nowMs: nowMs,
    displayNameHint: displayNameHint,
  );
}

void main() {
  group('PresenceCache empty state', () {
    test('a fresh cache reports zero counts and empty entries', () {
      final cache = PresenceCache();
      expect(cache.entriesForCanvas(_defaultCanvas), isEmpty);
      expect(cache.countsForCanvas(_defaultCanvas).total, 0);
      expect(cache.debugEntryCount, 0);
      expect(cache.debugTrackedCanvases, isEmpty);
    });
  });

  group('PresenceCache insert + state mapping', () {
    test('viewing frame creates an entry with null lastActivityMs', () {
      final cache = PresenceCache();
      expect(_upsert(cache, state: PresenceState.viewing), isTrue);

      final entries = cache.entriesForCanvas(_defaultCanvas);
      expect(entries, hasLength(1));
      final e = entries.single;
      expect(e.nodeNum, _defaultNode);
      expect(e.canvasLocalId, _defaultCanvas);
      expect(e.channelIndex, _defaultChannel);
      expect(e.state, PresenceState.viewing);
      expect(e.emitTsSec, _defaultEmitTs);
      expect(e.lastSeenMs, _defaultNow);
      expect(e.lastActivityMs, isNull);
      expect(e.expiresAtMs, _defaultNow + _defaultTtl * 1000);
      expect(e.source, PresenceSource.radio);
    });

    test('active frame sets lastActivityMs == lastSeenMs', () {
      final cache = PresenceCache();
      expect(_upsert(cache, state: PresenceState.active), isTrue);
      final e = cache.entriesForCanvas(_defaultCanvas).single;
      expect(e.state, PresenceState.active);
      expect(e.lastActivityMs, e.lastSeenMs);
    });

    test('painting frame sets lastActivityMs == lastSeenMs', () {
      final cache = PresenceCache();
      expect(_upsert(cache, state: PresenceState.painting), isTrue);
      final e = cache.entriesForCanvas(_defaultCanvas).single;
      expect(e.state, PresenceState.painting);
      expect(e.lastActivityMs, e.lastSeenMs);
    });

    test('displayNameHint persists when provided', () {
      final cache = PresenceCache();
      expect(
        _upsert(cache, state: PresenceState.viewing, displayNameHint: 'zephyr'),
        isTrue,
      );
      expect(
        cache.entriesForCanvas(_defaultCanvas).single.displayNameHint,
        'zephyr',
      );
    });

    test('source attribution round-trips', () {
      final cache = PresenceCache();
      expect(
        _upsert(
          cache,
          state: PresenceState.viewing,
          source: PresenceSource.self,
        ),
        isTrue,
      );
      expect(
        cache.entriesForCanvas(_defaultCanvas).single.source,
        PresenceSource.self,
      );
    });
  });

  group('PresenceCache leaving + evict', () {
    test('leaving evicts the matching entry and returns true', () {
      final cache = PresenceCache();
      _upsert(cache, state: PresenceState.viewing);
      expect(cache.debugEntryCount, 1);
      expect(_upsert(cache, state: PresenceState.leaving), isTrue);
      expect(cache.entriesForCanvas(_defaultCanvas), isEmpty);
      expect(cache.debugTrackedCanvases, isEmpty);
    });

    test('leaving on a non-existent entry is a no-op (returns false)', () {
      final cache = PresenceCache();
      expect(_upsert(cache, state: PresenceState.leaving), isFalse);
      expect(cache.debugEntryCount, 0);
    });

    test('evict() removes by key and returns true/false correctly', () {
      final cache = PresenceCache();
      _upsert(cache, state: PresenceState.viewing);
      expect(
        cache.evict(
          canvasLocalId: _defaultCanvas,
          channelIndex: _defaultChannel,
          nodeNum: _defaultNode,
        ),
        isTrue,
      );
      expect(cache.debugEntryCount, 0);
      expect(
        cache.evict(
          canvasLocalId: _defaultCanvas,
          channelIndex: _defaultChannel,
          nodeNum: _defaultNode,
        ),
        isFalse,
      );
    });
  });

  group('PresenceCache LWW + emit_ts handling', () {
    test('duplicate same state newer nowMs refreshes lastSeen + expires', () {
      final cache = PresenceCache();
      _upsert(cache, state: PresenceState.viewing, nowMs: 1000);
      _upsert(
        cache,
        state: PresenceState.viewing,
        emitTsSec: _defaultEmitTs + 30,
        nowMs: 2000,
      );
      final e = cache.entriesForCanvas(_defaultCanvas).single;
      expect(e.lastSeenMs, 2000);
      expect(e.expiresAtMs, 2000 + _defaultTtl * 1000);
      expect(e.emitTsSec, _defaultEmitTs + 30);
    });

    test('older emit_ts is dropped (returns false, no state change)', () {
      final cache = PresenceCache();
      _upsert(cache, state: PresenceState.active, emitTsSec: 200);
      final ok = _upsert(
        cache,
        state: PresenceState.painting,
        emitTsSec: 100,
        nowMs: _defaultNow + 1000,
      );
      expect(ok, isFalse);
      final e = cache.entriesForCanvas(_defaultCanvas).single;
      expect(e.state, PresenceState.active);
      expect(e.emitTsSec, 200);
      expect(e.lastSeenMs, _defaultNow);
    });

    test('equal emit_ts upgrade is allowed', () {
      final cache = PresenceCache();
      _upsert(cache, state: PresenceState.viewing, emitTsSec: 500, nowMs: 100);
      final ok = _upsert(
        cache,
        state: PresenceState.painting,
        emitTsSec: 500,
        nowMs: 200,
      );
      expect(ok, isTrue);
      final e = cache.entriesForCanvas(_defaultCanvas).single;
      expect(e.state, PresenceState.painting);
      expect(e.lastSeenMs, 200);
    });
  });

  group('PresenceCache state upgrade + downgrade rules', () {
    test('viewing -> active upgrade applies', () {
      final cache = PresenceCache();
      _upsert(cache, state: PresenceState.viewing, emitTsSec: 100);
      expect(
        _upsert(cache, state: PresenceState.active, emitTsSec: 110),
        isTrue,
      );
      expect(
        cache.entriesForCanvas(_defaultCanvas).single.state,
        PresenceState.active,
      );
    });

    test('active -> painting upgrade applies', () {
      final cache = PresenceCache();
      _upsert(cache, state: PresenceState.active, emitTsSec: 100);
      expect(
        _upsert(cache, state: PresenceState.painting, emitTsSec: 110),
        isTrue,
      );
      expect(
        cache.entriesForCanvas(_defaultCanvas).single.state,
        PresenceState.painting,
      );
    });

    test('viewing -> painting upgrade applies (two-step jump)', () {
      final cache = PresenceCache();
      _upsert(cache, state: PresenceState.viewing, emitTsSec: 100);
      expect(
        _upsert(cache, state: PresenceState.painting, emitTsSec: 110),
        isTrue,
      );
      expect(
        cache.entriesForCanvas(_defaultCanvas).single.state,
        PresenceState.painting,
      );
    });

    test('painting -> viewing downgrade within TTL is rejected', () {
      final cache = PresenceCache();
      _upsert(
        cache,
        state: PresenceState.painting,
        emitTsSec: 100,
        ttlSeconds: 180,
        nowMs: 1000,
      );
      expect(
        _upsert(
          cache,
          state: PresenceState.viewing,
          emitTsSec: 200,
          nowMs: 2000,
        ),
        isFalse,
      );
      expect(
        cache.entriesForCanvas(_defaultCanvas).single.state,
        PresenceState.painting,
      );
    });

    test('painting -> active downgrade within TTL is rejected', () {
      final cache = PresenceCache();
      _upsert(
        cache,
        state: PresenceState.painting,
        emitTsSec: 100,
        nowMs: 1000,
      );
      expect(
        _upsert(
          cache,
          state: PresenceState.active,
          emitTsSec: 200,
          nowMs: 2000,
        ),
        isFalse,
      );
      expect(
        cache.entriesForCanvas(_defaultCanvas).single.state,
        PresenceState.painting,
      );
    });

    test('downgrade is allowed once the existing entry expired', () {
      final cache = PresenceCache();
      _upsert(
        cache,
        state: PresenceState.painting,
        emitTsSec: 100,
        ttlSeconds: 60,
        nowMs: 1000,
      );
      // Expired at nowMs = 1000 + 60 * 1000 = 61000. Run upsert at
      // 61001 — the existing entry is past TTL, so a lower-state
      // upsert is accepted.
      final ok = _upsert(
        cache,
        state: PresenceState.viewing,
        emitTsSec: 200,
        nowMs: 61001,
      );
      expect(ok, isTrue);
      expect(
        cache.entriesForCanvas(_defaultCanvas).single.state,
        PresenceState.viewing,
      );
    });
  });

  group('PresenceCache scope isolation', () {
    test('same canvasLocalId, different channelIndex stays isolated', () {
      final cache = PresenceCache();
      _upsert(cache, channelIndex: 0, state: PresenceState.viewing);
      _upsert(cache, channelIndex: 1, state: PresenceState.painting);
      final entries = cache.entriesForCanvas(_defaultCanvas);
      expect(entries, hasLength(2));
      final byChannel = {for (final e in entries) e.channelIndex: e.state};
      expect(byChannel[0], PresenceState.viewing);
      expect(byChannel[1], PresenceState.painting);
    });

    test('different canvasLocalId entries are isolated', () {
      final cache = PresenceCache();
      _upsert(cache, canvasLocalId: 1, state: PresenceState.viewing);
      _upsert(cache, canvasLocalId: 2, state: PresenceState.painting);
      expect(cache.entriesForCanvas(1), hasLength(1));
      expect(cache.entriesForCanvas(2), hasLength(1));
      expect(cache.entriesForCanvas(1).single.state, PresenceState.viewing);
      expect(cache.entriesForCanvas(2).single.state, PresenceState.painting);
      expect(cache.debugTrackedCanvases, {1, 2});
    });

    test('different nodeNum on the same canvas+channel creates separate '
        'entries', () {
      final cache = PresenceCache();
      _upsert(cache, nodeNum: 0xA0, state: PresenceState.viewing);
      _upsert(cache, nodeNum: 0xB1, state: PresenceState.painting);
      final entries = cache.entriesForCanvas(_defaultCanvas);
      expect(entries, hasLength(2));
      final byNode = {for (final e in entries) e.nodeNum: e.state};
      expect(byNode[0xA0], PresenceState.viewing);
      expect(byNode[0xB1], PresenceState.painting);
    });
  });

  group('PresenceCache TTL and sweep', () {
    test('sweepExpired removes entries with expiresAtMs <= nowMs', () {
      final cache = PresenceCache();
      _upsert(cache, state: PresenceState.viewing, ttlSeconds: 60, nowMs: 1000);
      expect(cache.sweepExpired(61001), 1);
      expect(cache.debugEntryCount, 0);
      expect(cache.debugTrackedCanvases, isEmpty);
    });

    test('sweepExpired leaves still-fresh entries alone', () {
      final cache = PresenceCache();
      _upsert(
        cache,
        nodeNum: 0xA0,
        state: PresenceState.viewing,
        ttlSeconds: 60,
        nowMs: 1000,
      );
      _upsert(
        cache,
        nodeNum: 0xB1,
        state: PresenceState.viewing,
        ttlSeconds: 600,
        nowMs: 1000,
      );
      expect(cache.sweepExpired(61001), 1);
      final remaining = cache.entriesForCanvas(_defaultCanvas);
      expect(remaining, hasLength(1));
      expect(remaining.single.nodeNum, 0xB1);
    });

    test('boundary: expiresAtMs == nowMs counts as expired', () {
      final cache = PresenceCache();
      _upsert(cache, state: PresenceState.viewing, ttlSeconds: 60, nowMs: 0);
      expect(cache.sweepExpired(60 * 1000), 1);
    });

    test('boundary: one ms before expiry is still alive', () {
      final cache = PresenceCache();
      _upsert(cache, state: PresenceState.viewing, ttlSeconds: 60, nowMs: 0);
      expect(cache.sweepExpired(60 * 1000 - 1), 0);
      expect(cache.debugEntryCount, 1);
    });
  });

  group('PresenceCache sort order (entriesForCanvas)', () {
    test('painting first, then active, then viewing', () {
      final cache = PresenceCache();
      _upsert(cache, nodeNum: 0xA0, state: PresenceState.viewing, nowMs: 1000);
      _upsert(cache, nodeNum: 0xB1, state: PresenceState.painting, nowMs: 2000);
      _upsert(cache, nodeNum: 0xC2, state: PresenceState.active, nowMs: 3000);
      final entries = cache.entriesForCanvas(_defaultCanvas);
      expect(entries.map((e) => e.state).toList(), [
        PresenceState.painting,
        PresenceState.active,
        PresenceState.viewing,
      ]);
    });

    test('lastSeenMs descending within the same state', () {
      final cache = PresenceCache();
      _upsert(cache, nodeNum: 0xA0, state: PresenceState.viewing, nowMs: 1000);
      _upsert(cache, nodeNum: 0xB1, state: PresenceState.viewing, nowMs: 3000);
      _upsert(cache, nodeNum: 0xC2, state: PresenceState.viewing, nowMs: 2000);
      final entries = cache.entriesForCanvas(_defaultCanvas);
      expect(entries.map((e) => e.nodeNum).toList(), [0xB1, 0xC2, 0xA0]);
    });
  });

  group('PresenceCache 256-entry cap', () {
    test('inserting beyond the cap evicts the oldest lastSeenMs', () {
      final cache = PresenceCache();
      // Fill exactly 256 distinct nodeNums with strictly-increasing
      // lastSeenMs so node 0 is the oldest.
      for (var i = 0; i < PresenceCache.maxEntriesPerCanvas; i++) {
        _upsert(
          cache,
          nodeNum: 0x1000 + i,
          state: PresenceState.viewing,
          emitTsSec: i,
          nowMs: 1000 + i,
        );
      }
      expect(cache.debugEntryCount, PresenceCache.maxEntriesPerCanvas);

      // 257th insert should boot the lowest-lastSeenMs entry (0x1000).
      expect(
        _upsert(
          cache,
          nodeNum: 0x9999,
          state: PresenceState.viewing,
          emitTsSec: 9999,
          nowMs: 99999,
        ),
        isTrue,
      );
      expect(cache.debugEntryCount, PresenceCache.maxEntriesPerCanvas);
      final nodeNums = cache
          .entriesForCanvas(_defaultCanvas)
          .map((e) => e.nodeNum)
          .toSet();
      expect(nodeNums.contains(0x9999), isTrue);
      expect(nodeNums.contains(0x1000), isFalse);
    });

    test('upserting an existing key does not count against the cap', () {
      final cache = PresenceCache();
      for (var i = 0; i < PresenceCache.maxEntriesPerCanvas; i++) {
        _upsert(
          cache,
          nodeNum: 0x1000 + i,
          state: PresenceState.viewing,
          emitTsSec: i,
          nowMs: 1000 + i,
        );
      }
      // Refresh an existing node; cap should remain steady and the
      // oldest entry should NOT be evicted.
      expect(
        _upsert(
          cache,
          nodeNum: 0x1000,
          state: PresenceState.painting,
          emitTsSec: 5000,
          nowMs: 5000,
        ),
        isTrue,
      );
      expect(cache.debugEntryCount, PresenceCache.maxEntriesPerCanvas);
      final stillThere = cache
          .entriesForCanvas(_defaultCanvas)
          .map((e) => e.nodeNum)
          .toSet();
      expect(stillThere.contains(0x1000), isTrue);
      expect(stillThere.contains(0x1001), isTrue);
    });

    test('cap is scoped per canvas, not global', () {
      final cache = PresenceCache();
      for (var i = 0; i < PresenceCache.maxEntriesPerCanvas; i++) {
        _upsert(
          cache,
          canvasLocalId: 1,
          nodeNum: 0x1000 + i,
          state: PresenceState.viewing,
          emitTsSec: i,
          nowMs: 1000 + i,
        );
      }
      // Inserting on canvas 2 must not displace anything on canvas 1.
      expect(
        _upsert(
          cache,
          canvasLocalId: 2,
          nodeNum: 0x2000,
          state: PresenceState.viewing,
        ),
        isTrue,
      );
      expect(cache.entriesForCanvas(1), hasLength(256));
      expect(cache.entriesForCanvas(2), hasLength(1));
    });
  });

  group('PresenceCache defensive guards + clear', () {
    test('ttl below the min (59) is rejected with no state change', () {
      final cache = PresenceCache();
      expect(
        _upsert(
          cache,
          state: PresenceState.viewing,
          ttlSeconds: CanvasPresenceLimits.ttlSecondsMin - 1,
        ),
        isFalse,
      );
      expect(cache.debugEntryCount, 0);
    });

    test('ttl above the max (601) is rejected with no state change', () {
      final cache = PresenceCache();
      expect(
        _upsert(
          cache,
          state: PresenceState.viewing,
          ttlSeconds: CanvasPresenceLimits.ttlSecondsMax + 1,
        ),
        isFalse,
      );
      expect(cache.debugEntryCount, 0);
    });

    test('boundary: ttl=60 and ttl=600 are accepted', () {
      final cache = PresenceCache();
      expect(
        _upsert(
          cache,
          nodeNum: 0xA0,
          state: PresenceState.viewing,
          ttlSeconds: CanvasPresenceLimits.ttlSecondsMin,
        ),
        isTrue,
      );
      expect(
        _upsert(
          cache,
          nodeNum: 0xB1,
          state: PresenceState.viewing,
          ttlSeconds: CanvasPresenceLimits.ttlSecondsMax,
        ),
        isTrue,
      );
      expect(cache.debugEntryCount, 2);
    });

    test('clear() removes every entry across every canvas', () {
      final cache = PresenceCache();
      _upsert(cache, canvasLocalId: 1, state: PresenceState.viewing);
      _upsert(cache, canvasLocalId: 2, state: PresenceState.painting);
      _upsert(
        cache,
        canvasLocalId: 3,
        nodeNum: 0xCC,
        state: PresenceState.active,
      );
      expect(cache.debugEntryCount, 3);
      cache.clear();
      expect(cache.debugEntryCount, 0);
      expect(cache.debugTrackedCanvases, isEmpty);
      expect(cache.entriesForCanvas(1), isEmpty);
    });
  });

  group('PresenceCache.countsForCanvas', () {
    test('returns zeros on an empty canvas', () {
      final cache = PresenceCache();
      final c = cache.countsForCanvas(_defaultCanvas);
      expect(c.total, 0);
      expect(c.viewing, 0);
      expect(c.active, 0);
      expect(c.painting, 0);
    });

    test('breaks down counts by state across many nodes', () {
      final cache = PresenceCache();
      _upsert(cache, nodeNum: 0xA0, state: PresenceState.viewing);
      _upsert(cache, nodeNum: 0xA1, state: PresenceState.viewing);
      _upsert(cache, nodeNum: 0xA2, state: PresenceState.active);
      _upsert(cache, nodeNum: 0xA3, state: PresenceState.painting);
      _upsert(cache, nodeNum: 0xA4, state: PresenceState.painting);
      final c = cache.countsForCanvas(_defaultCanvas);
      expect(c.total, 5);
      expect(c.viewing, 2);
      expect(c.active, 1);
      expect(c.painting, 2);
    });
  });

  group('PresenceCache self-source protection (P3 hardening)', () {
    test('radio frame cannot overwrite an unexpired self entry for the '
        'same key', () {
      final cache = PresenceCache();
      // Local viewer seeds itself.
      expect(
        _upsert(
          cache,
          state: PresenceState.viewing,
          source: PresenceSource.self,
          emitTsSec: 100,
          ttlSeconds: 180,
          nowMs: 1000,
        ),
        isTrue,
      );

      // Even with a strictly-newer emit_ts AND an upgraded state, a
      // radio-source frame for the same (canvas, channel, node) MUST
      // NOT overwrite the self entry while it is unexpired.
      expect(
        _upsert(
          cache,
          state: PresenceState.painting,
          source: PresenceSource.radio,
          emitTsSec: 999,
          ttlSeconds: 180,
          nowMs: 2000,
        ),
        isFalse,
      );

      final entry = cache.entriesForCanvas(_defaultCanvas).single;
      expect(entry.source, PresenceSource.self);
      expect(entry.state, PresenceState.viewing);
      expect(entry.emitTsSec, 100);
      expect(entry.lastSeenMs, 1000);
    });

    test('self can refresh self (same key) without restriction', () {
      final cache = PresenceCache();
      _upsert(
        cache,
        state: PresenceState.viewing,
        source: PresenceSource.self,
        emitTsSec: 100,
        nowMs: 1000,
      );
      expect(
        _upsert(
          cache,
          state: PresenceState.active,
          source: PresenceSource.self,
          emitTsSec: 110,
          nowMs: 2000,
        ),
        isTrue,
      );
      final e = cache.entriesForCanvas(_defaultCanvas).single;
      expect(e.source, PresenceSource.self);
      expect(e.state, PresenceState.active);
      expect(e.lastSeenMs, 2000);
    });

    test('radio can overwrite self after the self entry expired', () {
      final cache = PresenceCache();
      _upsert(
        cache,
        state: PresenceState.viewing,
        source: PresenceSource.self,
        ttlSeconds: 60,
        emitTsSec: 100,
        nowMs: 1000,
      );
      // 60_001 ms later the self entry is past its TTL; radio is now
      // free to insert a fresh entry for the same key.
      expect(
        _upsert(
          cache,
          state: PresenceState.painting,
          source: PresenceSource.radio,
          emitTsSec: 200,
          nowMs: 61_001,
        ),
        isTrue,
      );
      final e = cache.entriesForCanvas(_defaultCanvas).single;
      expect(e.source, PresenceSource.radio);
      expect(e.state, PresenceState.painting);
    });

    test('radio frames from OTHER nodes are unaffected by self protection', () {
      final cache = PresenceCache();
      _upsert(
        cache,
        nodeNum: 0xA0,
        state: PresenceState.viewing,
        source: PresenceSource.self,
        nowMs: 1000,
      );
      // Different nodeNum so this is a different cache key. Radio
      // protection only applies key-for-key.
      expect(
        _upsert(
          cache,
          nodeNum: 0xB1,
          state: PresenceState.painting,
          source: PresenceSource.radio,
          nowMs: 1500,
        ),
        isTrue,
      );
      expect(cache.entriesForCanvas(_defaultCanvas), hasLength(2));
    });
  });

  group('PresenceCache.changeStream (P5 hook)', () {
    test('emits canvasLocalId on every successful upsert', () async {
      final cache = PresenceCache();
      final received = <int>[];
      final sub = cache.changeStream.listen(received.add);

      _upsert(cache, state: PresenceState.viewing, canvasLocalId: 7);
      _upsert(cache, state: PresenceState.painting, canvasLocalId: 9);
      await Future<void>.delayed(Duration.zero);

      expect(received, [7, 9]);
      await sub.cancel();
      await cache.dispose();
    });

    test('emits on eviction via leaving', () async {
      final cache = PresenceCache();
      _upsert(cache, state: PresenceState.viewing);
      final received = <int>[];
      final sub = cache.changeStream.listen(received.add);

      _upsert(cache, state: PresenceState.leaving);
      await Future<void>.delayed(Duration.zero);

      expect(received, [_defaultCanvas]);
      await sub.cancel();
      await cache.dispose();
    });

    test('emits on sweepExpired for canvases that lost entries', () async {
      final cache = PresenceCache();
      _upsert(
        cache,
        canvasLocalId: 1,
        state: PresenceState.viewing,
        ttlSeconds: 60,
        nowMs: 1000,
      );
      _upsert(
        cache,
        canvasLocalId: 2,
        state: PresenceState.viewing,
        ttlSeconds: 600,
        nowMs: 1000,
      );

      // Subscribe AFTER initial inserts so we observe sweep events only.
      final received = <int>[];
      final sub = cache.changeStream.listen(received.add);

      cache.sweepExpired(61_001);
      await Future<void>.delayed(Duration.zero);

      expect(received, [1]);
      await sub.cancel();
      await cache.dispose();
    });

    test('does not emit on no-op upserts (stale emit_ts, downgrade)', () async {
      final cache = PresenceCache();
      _upsert(
        cache,
        state: PresenceState.painting,
        emitTsSec: 100,
        nowMs: 1000,
      );
      final received = <int>[];
      final sub = cache.changeStream.listen(received.add);

      _upsert(cache, state: PresenceState.painting, emitTsSec: 50, nowMs: 2000);
      _upsert(cache, state: PresenceState.viewing, emitTsSec: 200, nowMs: 2000);
      await Future<void>.delayed(Duration.zero);

      expect(received, isEmpty);
      await sub.cancel();
      await cache.dispose();
    });

    test('dispose closes the stream and subsequent emits are no-ops', () async {
      final cache = PresenceCache();
      await cache.dispose();
      // Post-dispose upsert is silent and does not throw.
      expect(_upsert(cache, state: PresenceState.viewing), isTrue);
    });
  });

  group('PresenceCache architectural invariants (P1 + P2)', () {
    test('no disk/database/SharedPreferences imports in source', () {
      // The cache must remain memory-only. A static check for forbidden
      // import directives catches the most likely regression vector:
      // someone adding a "small SharedPreferences write" thinking it is
      // safe. Comments may legitimately mention these names to document
      // the invariant, so the check matches the actual `import ...`
      // syntax rather than free text.
      final cacheSrc = File(
        'lib/services/canvas/presence_cache.dart',
      ).readAsStringSync();
      final modelSrc = File(
        'lib/services/canvas/presence_models.dart',
      ).readAsStringSync();
      final banned = <Pattern>[
        "import 'package:sqflite",
        "import 'package:shared_preferences",
        "import 'package:path_provider",
        "import 'dart:io",
        "import 'canvas_repository",
        "import 'canvas_database",
      ];
      for (final src in [cacheSrc, modelSrc]) {
        for (final pattern in banned) {
          expect(
            src.contains(pattern),
            isFalse,
            reason: 'forbidden import "$pattern" found',
          );
        }
      }
    });
  });
}
