// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Participation-gate regression tests for PresenceEmitCoordinator.
//
// Spec: docs/canvas/CANVAS_PARTICIPATION_V0_1.md §5.4 + §8 (I3
// presence hard-gated).
//
// Invariants pinned here:
//   - When canEmit() returns false, every public method is a no-op:
//     attachViewer does NOT seed self in the cache, does NOT create
//     a session, does NOT send any wire frame.
//   - notifyInteraction / notifyPaintEnqueued / tick / detachViewer
//     are also no-ops while gated.
//   - Flipping canEmit() from false → true is NOT sufficient to make
//     a previously-skipped attachViewer suddenly take effect; the
//     viewer host must re-attach. (Confirms session is not lazily
//     created.)
//   - Default canEmit (no callback) preserves pre-S5 behaviour.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/services/canvas/canvas_outbound_governor.dart';
import 'package:socialmesh/services/canvas/canvas_send_coordinator.dart';
import 'package:socialmesh/services/canvas/presence_cache.dart';
import 'package:socialmesh/services/canvas/presence_emit_coordinator.dart';

class _Sent {
  final Uint8List payload;
  final int channelIndex;
  const _Sent({required this.payload, required this.channelIndex});
}

class _FakeChannel implements CanvasOutboundChannel {
  final List<_Sent> sent = <_Sent>[];

  @override
  Future<CanvasSendResult> sendCanvasPayload({
    required Uint8List canvasPayload,
    required int channelIndex,
  }) async {
    sent.add(_Sent(payload: canvasPayload, channelIndex: channelIndex));
    return CanvasSendResult.sent(wireBytes: canvasPayload.length + 22);
  }
}

const int _kCanvasLocalId = 1;
const int _kChannel = 0;
const int _kCanvasId = 0x1122334455667788;
const int _kLocalNode = 0xAABBCCDD;

void main() {
  group('PresenceEmitCoordinator participation gate', () {
    test('canEmit=false → attachViewer is a full no-op: no cache seed, no '
        'session, no wire emit', () async {
      final cache = PresenceCache();
      final channel = _FakeChannel();
      final coordinator = PresenceEmitCoordinator(
        cache: cache,
        governor: CanvasOutboundGovernor(),
        outbound: channel,
        localNodeNumProvider: () => _kLocalNode,
        canEmit: () => false,
      );

      await coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );

      // No session was created.
      expect(coordinator.debugSessionCount, 0);
      expect(coordinator.debugHasSession(_kCanvasLocalId), isFalse);

      // No cache entry for self was seeded.
      final entry = cache.entryFor(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        nodeNum: _kLocalNode,
      );
      expect(entry, isNull);

      // No wire frame.
      expect(channel.sent, isEmpty);
    });

    test(
      'canEmit=false → notifyInteraction returns false and is silent',
      () async {
        final channel = _FakeChannel();
        final coordinator = PresenceEmitCoordinator(
          cache: PresenceCache(),
          governor: CanvasOutboundGovernor(),
          outbound: channel,
          localNodeNumProvider: () => _kLocalNode,
          canEmit: () => false,
        );

        final ok = await coordinator.notifyInteraction(_kCanvasLocalId);
        expect(ok, isFalse);
        expect(channel.sent, isEmpty);
      },
    );

    test(
      'canEmit=false → notifyPaintEnqueued returns false and is silent',
      () async {
        final channel = _FakeChannel();
        final coordinator = PresenceEmitCoordinator(
          cache: PresenceCache(),
          governor: CanvasOutboundGovernor(),
          outbound: channel,
          localNodeNumProvider: () => _kLocalNode,
          canEmit: () => false,
        );

        final ok = await coordinator.notifyPaintEnqueued(_kCanvasLocalId);
        expect(ok, isFalse);
        expect(channel.sent, isEmpty);
      },
    );

    test(
      'canEmit=false → tick returns 0 and does NOT touch the wire even if '
      'sessions exist from a prior (canEmit=true) session lifecycle',
      () async {
        final cache = PresenceCache();
        final channel = _FakeChannel();
        var canEmit = true;
        final coordinator = PresenceEmitCoordinator(
          cache: cache,
          governor: CanvasOutboundGovernor(),
          outbound: channel,
          localNodeNumProvider: () => _kLocalNode,
          canEmit: () => canEmit,
        );

        // Attach a session while sharing is on.
        await coordinator.attachViewer(
          canvasLocalId: _kCanvasLocalId,
          channelIndex: _kChannel,
          canvasId: _kCanvasId,
        );
        expect(coordinator.debugSessionCount, 1);
        final framesBefore = channel.sent.length;

        // User toggles sharing off mid-session.
        canEmit = false;

        // Heartbeat tick MUST NOT emit, even though a session exists.
        final framesSent = await coordinator.tick();
        expect(framesSent, 0);
        expect(channel.sent, hasLength(framesBefore));
      },
    );

    test('canEmit=false → detachViewer is a no-op: session NOT removed, no '
        'leaving frame, cache entry untouched', () async {
      final cache = PresenceCache();
      final channel = _FakeChannel();
      var canEmit = true;
      final coordinator = PresenceEmitCoordinator(
        cache: cache,
        governor: CanvasOutboundGovernor(),
        outbound: channel,
        localNodeNumProvider: () => _kLocalNode,
        canEmit: () => canEmit,
      );

      await coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      final framesAfterAttach = channel.sent.length;
      expect(coordinator.debugSessionCount, 1);

      // User toggles sharing off. detachViewer becomes a no-op so we
      // never emit a leaving frame for a user who is currently
      // un-sharing.
      canEmit = false;
      await coordinator.detachViewer(_kCanvasLocalId);

      // Session still there (host will re-attach on next viewer
      // mount once sharing flips back on).
      expect(coordinator.debugSessionCount, 1);
      // No new wire frames.
      expect(channel.sent, hasLength(framesAfterAttach));
    });

    test('gate flipping false → true does NOT lazily create a session that '
        'attachViewer previously skipped — host must re-attach', () async {
      final cache = PresenceCache();
      final channel = _FakeChannel();
      var canEmit = false;
      final coordinator = PresenceEmitCoordinator(
        cache: cache,
        governor: CanvasOutboundGovernor(),
        outbound: channel,
        localNodeNumProvider: () => _kLocalNode,
        canEmit: () => canEmit,
      );

      await coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      expect(coordinator.debugSessionCount, 0);

      // User toggles sharing on.
      canEmit = true;

      // notifyInteraction without an active session is a no-op (the
      // attachViewer was previously skipped, so there's no session
      // to refresh).
      final ok = await coordinator.notifyInteraction(_kCanvasLocalId);
      expect(ok, isFalse);
      expect(channel.sent, isEmpty);

      // Once the host re-attaches, the session is created and a
      // wire emit attempt happens (subject to governor + sip gate).
      await coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );
      expect(coordinator.debugSessionCount, 1);
      expect(channel.sent, isNotEmpty);
    });

    test('default canEmit (no callback) preserves pre-S5 behaviour — '
        'attachViewer seeds + emits as before', () async {
      final cache = PresenceCache();
      final channel = _FakeChannel();
      // No canEmit passed → defaults to `() => true`.
      final coordinator = PresenceEmitCoordinator(
        cache: cache,
        governor: CanvasOutboundGovernor(),
        outbound: channel,
        localNodeNumProvider: () => _kLocalNode,
      );

      await coordinator.attachViewer(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        canvasId: _kCanvasId,
      );

      expect(coordinator.debugSessionCount, 1);
      final entry = cache.entryFor(
        canvasLocalId: _kCanvasLocalId,
        channelIndex: _kChannel,
        nodeNum: _kLocalNode,
      );
      expect(entry, isNotNull);
      expect(channel.sent, isNotEmpty);
    });
  });
}
