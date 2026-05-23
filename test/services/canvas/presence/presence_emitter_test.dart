// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PresenceEmitCoordinator tests (P3).
//
// Source of truth: docs/canvas/CANVAS_PRESENCE_V0_1.md §3 + §4.4.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/canvas/canvas_codec.dart';
import 'package:socialmesh/services/canvas/canvas_constants.dart';
import 'package:socialmesh/services/canvas/canvas_outbound_governor.dart';
import 'package:socialmesh/services/canvas/canvas_send_coordinator.dart';
import 'package:socialmesh/services/canvas/presence_cache.dart';
import 'package:socialmesh/services/canvas/presence_emit_coordinator.dart';
import 'package:socialmesh/services/canvas/presence_models.dart';

class _Sent {
  final Uint8List payload;
  final int channelIndex;
  const _Sent({required this.payload, required this.channelIndex});
}

class _FakeChannel implements CanvasOutboundChannel {
  final List<_Sent> sent = <_Sent>[];

  CanvasSendResult _defaultOutcome = CanvasSendResult.sent(wireBytes: 0);
  final List<CanvasSendResult> _queued = <CanvasSendResult>[];

  void setDefault(CanvasSendResult outcome) => _defaultOutcome = outcome;

  void enqueueOutcome(CanvasSendResult outcome) => _queued.add(outcome);

  @override
  Future<CanvasSendResult> sendCanvasPayload({
    required Uint8List canvasPayload,
    required int channelIndex,
  }) async {
    sent.add(_Sent(payload: canvasPayload, channelIndex: channelIndex));
    if (_queued.isNotEmpty) return _queued.removeAt(0);
    if (_defaultOutcome.outcome == CanvasSendOutcome.sent) {
      return CanvasSendResult.sent(wireBytes: canvasPayload.length + 22);
    }
    return _defaultOutcome;
  }
}

class _FakeClock {
  int _nowMs;
  _FakeClock(this._nowMs);
  int now() => _nowMs;
  void advance(Duration d) => _nowMs += d.inMilliseconds;
  void set(int ms) => _nowMs = ms;
}

const int _kCanvasLocalId = 1;
const int _kChannel = 0;
const int _kCanvasId = 0x1122334455667788;
const int _kLocalNode = 0xAABBCCDD;

({
  PresenceEmitCoordinator coordinator,
  PresenceCache cache,
  CanvasOutboundGovernor governor,
  _FakeChannel channel,
  _FakeClock clock,
})
_buildHarness({int? localNodeNum = _kLocalNode, int initialNowMs = 1_000_000}) {
  final clock = _FakeClock(initialNowMs);
  final governor = CanvasOutboundGovernor(nowMs: clock.now);
  final channel = _FakeChannel();
  final cache = PresenceCache();
  final coordinator = PresenceEmitCoordinator(
    cache: cache,
    governor: governor,
    outbound: channel,
    localNodeNumProvider: () => localNodeNum,
    nowMs: clock.now,
  );
  return (
    coordinator: coordinator,
    cache: cache,
    governor: governor,
    channel: channel,
    clock: clock,
  );
}

void main() {
  group('PresenceEmitCoordinator attachViewer pre-flight', () {
    test('local canvas (canvas_id=0) never attaches a session and never '
        'seeds cache', () async {
      final h = _buildHarness();
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: kLocalCanvasIdSentinel,
      );
      expect(h.coordinator.debugSessionCount, 0);
      expect(h.cache.debugEntryCount, 0);
      expect(h.channel.sent, isEmpty);
    });

    test('out-of-range channelIndex (-1) is rejected', () async {
      final h = _buildHarness();
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: -1,
        canvasId: _kCanvasId,
      );
      expect(h.coordinator.debugSessionCount, 0);
      expect(h.cache.debugEntryCount, 0);
      expect(h.channel.sent, isEmpty);
    });

    test('out-of-range channelIndex (8) is rejected', () async {
      final h = _buildHarness();
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: CanvasLimits.channelIndexMax + 1,
        canvasId: _kCanvasId,
      );
      expect(h.coordinator.debugSessionCount, 0);
      expect(h.cache.debugEntryCount, 0);
      expect(h.channel.sent, isEmpty);
    });

    test('unknown local node num skips attach', () async {
      final h = _buildHarness(localNodeNum: null);
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      expect(h.coordinator.debugSessionCount, 0);
      expect(h.cache.debugEntryCount, 0);
      expect(h.channel.sent, isEmpty);
    });
  });

  group('PresenceEmitCoordinator attachViewer happy path', () {
    test(
      'synchronously seeds self cache entry BEFORE awaiting wire emit',
      () async {
        final h = _buildHarness();
        // Capture cache state mid-call by not awaiting the future yet.
        final pending = h.coordinator.attachViewer(
          canvasLocalId: _kCanvasLocalId,
          channelIndex: _kChannel,
          canvasId: _kCanvasId,
        );
        // Synchronous seed already ran.
        expect(h.cache.debugEntryCount, 1);
        final seeded = h.cache.entriesForCanvas(_kCanvasLocalId).single;
        expect(seeded.source, PresenceSource.self);
        expect(seeded.state, PresenceState.viewing);
        expect(seeded.nodeNum, _kLocalNode);
        expect(seeded.canvasLocalId, _kCanvasLocalId);
        expect(seeded.channelIndex, _kChannel);
        await pending;
      },
    );

    test('emits a viewing frame whose payload decodes correctly', () async {
      final h = _buildHarness();
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      expect(h.channel.sent, hasLength(1));
      final sent = h.channel.sent.single;
      expect(sent.channelIndex, _kChannel);
      final decoded = CanvasCodec.decodePresence(sent.payload);
      expect(decoded, isNotNull);
      expect(decoded!.state, PresenceState.viewing);
      expect(decoded.canvasId, _kCanvasId);
      expect(decoded.authorId, _kLocalNode);
      expect(decoded.ttlSeconds, CanvasPresenceLimits.ttlSecondsDefault);
    });

    test(
      'charges the canvas governor for exactly 24 bytes per success',
      () async {
        final h = _buildHarness();
        await h.coordinator.attachViewer(
          canvasLocalId: _kCanvasLocalId,
          channelIndex: _kChannel,
          canvasId: _kCanvasId,
        );
        expect(
          h.governor.budgetBytesPerWindow - h.governor.remainingBytes,
          PresenceEmitTiming.presenceFrameBytes,
        );
      },
    );
  });

  group('PresenceEmitCoordinator heartbeat (tick)', () {
    test('emits a heartbeat after 90 s', () async {
      final h = _buildHarness();
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      expect(h.channel.sent, hasLength(1));

      h.clock.advance(const Duration(seconds: 90));
      final sent = await h.coordinator.tick();
      expect(sent, 1);
      expect(h.channel.sent, hasLength(2));
      final second = CanvasCodec.decodePresence(h.channel.sent[1].payload);
      expect(second!.state, PresenceState.viewing);
    });

    test('heartbeat re-emits painting when self cache is painting and '
        'the 30 s throttle has cleared', () async {
      final h = _buildHarness();
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      // notifyPaintEnqueued at +6 s (clears the 5 s duplicate window
      // vs the initial viewing) → cache flips to painting, wire emits
      // painting, lastPaintingSuccessMs = nowMs at that point.
      h.clock.advance(const Duration(seconds: 6));
      expect(await h.coordinator.notifyPaintEnqueued(_kCanvasLocalId), isTrue);
      expect(h.channel.sent, hasLength(2));

      // Heartbeat due at lastAnyEmitMs (6 s) + 90 s = 96 s. The 30 s
      // painting throttle ran out at 36 s, so by 96 s the heartbeat
      // can re-emit painting.
      h.clock.advance(const Duration(seconds: 90));
      final sent = await h.coordinator.tick();
      expect(sent, 1);
      expect(h.channel.sent, hasLength(3));

      final decoded = CanvasCodec.decodePresence(h.channel.sent[2].payload);
      expect(decoded, isNotNull);
      expect(decoded!.state, PresenceState.painting);

      // Cache also still reads as painting (TTL = 180 s from the
      // notify upsert at +6 s expires at +186 s; we are at +96 s).
      final entry = h.cache.entriesForCanvas(_kCanvasLocalId).single;
      expect(entry.state, PresenceState.painting);
    });

    test('heartbeat re-emits active when self cache is active and '
        'the 30 s throttle has cleared', () async {
      final h = _buildHarness();
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      h.clock.advance(const Duration(seconds: 6));
      expect(await h.coordinator.notifyInteraction(_kCanvasLocalId), isTrue);
      expect(h.channel.sent, hasLength(2));

      h.clock.advance(const Duration(seconds: 90));
      final sent = await h.coordinator.tick();
      expect(sent, 1);
      expect(h.channel.sent, hasLength(3));

      final decoded = CanvasCodec.decodePresence(h.channel.sent[2].payload);
      expect(decoded, isNotNull);
      expect(decoded!.state, PresenceState.active);
    });

    test('heartbeat falls back to viewing after a higher cache state '
        'expires', () async {
      final h = _buildHarness();
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      h.clock.advance(const Duration(seconds: 6));
      expect(await h.coordinator.notifyPaintEnqueued(_kCanvasLocalId), isTrue);
      // Cache says painting, expiresAtMs = nowAtNotify + 180 s. Jump
      // 194 s further (so 200 s after attach) to land past expiry.
      // Heartbeat is also due (lastAnyEmitMs is now 6 s into the
      // session; 200 - 6 = 194 >= 90).
      h.clock.advance(const Duration(seconds: 194));
      // Confirm cache entry is expired but still in the map (no
      // sweep ran).
      final stale = h.cache.entryFor(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        nodeNum: _kLocalNode,
      );
      expect(stale, isNotNull);
      expect(stale!.state, PresenceState.painting);
      expect(stale.isExpiredAt(h.clock.now()), isTrue);

      final sent = await h.coordinator.tick();
      expect(sent, 1);
      expect(h.channel.sent, hasLength(3));
      final decoded = CanvasCodec.decodePresence(h.channel.sent[2].payload);
      expect(decoded, isNotNull);
      expect(decoded!.state, PresenceState.viewing);
    });

    test('does not emit a heartbeat before 90 s', () async {
      final h = _buildHarness();
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      h.clock.advance(const Duration(seconds: 89));
      final sent = await h.coordinator.tick();
      expect(sent, 0);
      expect(h.channel.sent, hasLength(1));
    });
  });

  group('PresenceEmitCoordinator throttling', () {
    test(
      'duplicate viewing within 5 s of the initial attach is suppressed',
      () async {
        final h = _buildHarness();
        await h.coordinator.attachViewer(
          canvasLocalId: _kCanvasLocalId,
          channelIndex: _kChannel,
          canvasId: _kCanvasId,
        );
        // tick() at +4s — heartbeat NOT due, also same-state duplicate.
        h.clock.advance(const Duration(seconds: 4));
        expect(await h.coordinator.tick(), 0);
        expect(h.channel.sent, hasLength(1));
      },
    );

    test('active emits once then throttles for 30 s', () async {
      final h = _buildHarness();
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      // First active at +6 s (clears 5 s duplicate suppression vs the
      // initial viewing).
      h.clock.advance(const Duration(seconds: 6));
      expect(await h.coordinator.notifyInteraction(_kCanvasLocalId), isTrue);
      expect(h.channel.sent, hasLength(2));
      final decoded = CanvasCodec.decodePresence(h.channel.sent[1].payload);
      expect(decoded!.state, PresenceState.active);

      // Second active at +29 s after the first active (29 < 30) is
      // throttled.
      h.clock.advance(const Duration(seconds: 29));
      expect(await h.coordinator.notifyInteraction(_kCanvasLocalId), isFalse);
      expect(h.channel.sent, hasLength(2));

      // Third active at +31 s after the first is allowed again.
      h.clock.advance(const Duration(seconds: 2));
      expect(await h.coordinator.notifyInteraction(_kCanvasLocalId), isTrue);
      expect(h.channel.sent, hasLength(3));
    });

    test('painting emits once then throttles for 30 s', () async {
      final h = _buildHarness();
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      h.clock.advance(const Duration(seconds: 6));
      expect(await h.coordinator.notifyPaintEnqueued(_kCanvasLocalId), isTrue);
      expect(h.channel.sent, hasLength(2));
      final decoded = CanvasCodec.decodePresence(h.channel.sent[1].payload);
      expect(decoded!.state, PresenceState.painting);

      h.clock.advance(const Duration(seconds: 29));
      expect(await h.coordinator.notifyPaintEnqueued(_kCanvasLocalId), isFalse);
      expect(h.channel.sent, hasLength(2));
    });

    test('hard ceiling of 4 frames / 60 s is enforced', () async {
      final h = _buildHarness();
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      // 1 frame already sent. Drive the next three at +6, +37, +43,
      // alternating active/painting to dodge the 30 s per-state
      // throttle, all within the 60 s ceiling window.
      h.clock.advance(const Duration(seconds: 6));
      expect(await h.coordinator.notifyPaintEnqueued(_kCanvasLocalId), isTrue);
      h.clock.advance(const Duration(seconds: 31));
      expect(await h.coordinator.notifyInteraction(_kCanvasLocalId), isTrue);
      h.clock.advance(const Duration(seconds: 6));
      expect(await h.coordinator.notifyPaintEnqueued(_kCanvasLocalId), isTrue);
      // 4 frames sent in the trailing 60 s window. A fifth attempt
      // (active at +6 s later, throttle clear) MUST be ceiling-blocked.
      expect(h.channel.sent, hasLength(4));
      h.clock.advance(const Duration(seconds: 6));
      expect(await h.coordinator.notifyInteraction(_kCanvasLocalId), isFalse);
      expect(h.channel.sent, hasLength(4));
    });
  });

  group('PresenceEmitCoordinator anti-starvation', () {
    // Note: an earlier "pending paint queue blocks the emit" test was
    // removed at P5 sim verification. The gate it pinned was broken
    // in practice: presence notify is triggered BY a paint enqueue,
    // so the queue is always non-empty at notify time and presence
    // would never broadcast. The byte-level gates (canvas governor +
    // SIP limiter) already enforce anti-starvation: presence is 24 B
    // per frame, capped at 4 / 60 s = 96 B / 60 s, leaving paint at
    // least 154 B / 60 s of governor headroom in every window.

    test('canvas governor headroom < 96 B blocks the emit', () async {
      final h = _buildHarness();
      // Burn down the governor to leave 95 bytes of headroom.
      h.governor.recordSend(CanvasOutboundGovernor.budgetBytes - 95);
      expect(h.governor.remainingBytes, 95);

      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      expect(h.channel.sent, isEmpty);
      // Cache seed still happened.
      expect(h.cache.debugEntryCount, 1);
    });

    test('SIP limiter denial (sipRateLimited outcome) drops the emit '
        'and never queues a backlog', () async {
      final h = _buildHarness();
      h.channel.setDefault(CanvasSendResult.sipRateLimited);

      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      // The channel was called once (the gate let us try) but the
      // outcome was sipRateLimited so the coordinator did not charge
      // the governor and did not advance session timestamps.
      expect(h.channel.sent, hasLength(1));
      expect(h.governor.remainingBytes, CanvasOutboundGovernor.budgetBytes);

      // No backlog: heartbeat at +90 s tries fresh, NOT a replay of
      // the failed frame.
      h.channel.setDefault(CanvasSendResult.sent(wireBytes: 0));
      h.clock.advance(const Duration(seconds: 90));
      expect(await h.coordinator.tick(), 1);
      expect(h.channel.sent, hasLength(2));
    });

    test('transient failure also drops without retry', () async {
      final h = _buildHarness();
      h.channel.setDefault(CanvasSendResult.failure('transport-down'));
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      expect(h.governor.remainingBytes, CanvasOutboundGovernor.budgetBytes);
      // No retry queue: a subsequent tick at +1 s does nothing
      // (heartbeat not due, last emit never succeeded so
      // lastAnyEmitMs is still null and heartbeat condition fires
      // again — let's actually verify).
      h.clock.advance(const Duration(seconds: 1));
      h.channel.setDefault(CanvasSendResult.sent(wireBytes: 0));
      // Heartbeat condition: lastAnyEmitMs == null counts as
      // "due forever" so the next tick WILL retry. That is the
      // correct behaviour: the failure is not durably remembered as
      // "queued," it is simply absent from history.
      expect(await h.coordinator.tick(), 1);
    });
  });

  group('PresenceEmitCoordinator detachViewer + leaving', () {
    test('detach emits leaving when a prior emit succeeded', () async {
      final h = _buildHarness();
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      expect(h.channel.sent, hasLength(1));

      await h.coordinator.detachViewer(_kCanvasLocalId);
      expect(h.channel.sent, hasLength(2));
      final decoded = CanvasCodec.decodePresence(h.channel.sent[1].payload);
      expect(decoded!.state, PresenceState.leaving);
      expect(h.coordinator.debugSessionCount, 0);
      expect(h.cache.debugEntryCount, 0);
    });

    test('detach does NOT emit leaving when no prior emit succeeded', () async {
      final h = _buildHarness();
      h.channel.setDefault(CanvasSendResult.sipRateLimited);
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      // The attach attempted but sipRateLimited — no successful emit.
      expect(h.channel.sent, hasLength(1));
      final before = h.channel.sent.length;

      // Detach must not produce a leaving frame.
      await h.coordinator.detachViewer(_kCanvasLocalId);
      expect(h.channel.sent.length, before);
      expect(h.coordinator.debugSessionCount, 0);
      expect(h.cache.debugEntryCount, 0);
    });

    test('detach on unknown canvas is a no-op', () async {
      final h = _buildHarness();
      await h.coordinator.detachViewer(_kCanvasLocalId);
      expect(h.channel.sent, isEmpty);
    });
  });

  group('PresenceEmitCoordinator dispose', () {
    test('dispose clears every session and removes self entries', () async {
      final h = _buildHarness();
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      await h.coordinator.attachViewer(
        canvasLocalId: 2,
        channelIndex: 1,
        canvasId: 0x99,
      );
      expect(h.coordinator.debugSessionCount, 2);
      expect(h.cache.debugEntryCount, 2);

      h.coordinator.dispose();
      expect(h.coordinator.debugSessionCount, 0);
      expect(h.cache.debugEntryCount, 0);
    });

    test('post-dispose attach is a no-op', () async {
      final h = _buildHarness();
      h.coordinator.dispose();
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      expect(h.coordinator.debugSessionCount, 0);
      expect(h.cache.debugEntryCount, 0);
      expect(h.channel.sent, isEmpty);
    });

    test('post-dispose tick / notify are no-ops', () async {
      final h = _buildHarness();
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      h.coordinator.dispose();
      expect(await h.coordinator.tick(), 0);
      expect(await h.coordinator.notifyInteraction(_kCanvasLocalId), isFalse);
      expect(await h.coordinator.notifyPaintEnqueued(_kCanvasLocalId), isFalse);
    });
  });

  group('PresenceEmitCoordinator cache interaction', () {
    test(
      'attachViewer seeds cache with self state=viewing and TTL=180s',
      () async {
        final h = _buildHarness();
        await h.coordinator.attachViewer(
          canvasLocalId: _kCanvasLocalId,
          channelIndex: _kChannel,
          canvasId: _kCanvasId,
        );
        final entry = h.cache.entriesForCanvas(_kCanvasLocalId).single;
        expect(entry.source, PresenceSource.self);
        expect(entry.state, PresenceState.viewing);
        expect(
          entry.expiresAtMs - entry.lastSeenMs,
          CanvasPresenceLimits.ttlSecondsDefault * 1000,
        );
      },
    );

    test('notifyPaintEnqueued upgrades local self cache to painting', () async {
      final h = _buildHarness();
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      h.clock.advance(const Duration(seconds: 6));
      await h.coordinator.notifyPaintEnqueued(_kCanvasLocalId);
      final entry = h.cache.entriesForCanvas(_kCanvasLocalId).single;
      expect(entry.state, PresenceState.painting);
      expect(entry.source, PresenceSource.self);
    });

    test('notifyInteraction does NOT downgrade an existing painting state '
        'in the cache (cache no-downgrade rule + self-protect)', () async {
      final h = _buildHarness();
      await h.coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      h.clock.advance(const Duration(seconds: 6));
      await h.coordinator.notifyPaintEnqueued(_kCanvasLocalId);
      // Now interact: the cache must NOT downgrade painting -> active.
      h.clock.advance(const Duration(seconds: 1));
      await h.coordinator.notifyInteraction(_kCanvasLocalId);
      final entry = h.cache.entriesForCanvas(_kCanvasLocalId).single;
      expect(entry.state, PresenceState.painting);
    });
  });

  group('PresenceEmitCoordinator notify after detach', () {
    test('notifyInteraction returns false when no session attached', () async {
      final h = _buildHarness();
      expect(await h.coordinator.notifyInteraction(_kCanvasLocalId), isFalse);
      expect(h.channel.sent, isEmpty);
    });

    test(
      'notifyPaintEnqueued returns false when no session attached',
      () async {
        final h = _buildHarness();
        expect(
          await h.coordinator.notifyPaintEnqueued(_kCanvasLocalId),
          isFalse,
        );
        expect(h.channel.sent, isEmpty);
      },
    );
  });
}
