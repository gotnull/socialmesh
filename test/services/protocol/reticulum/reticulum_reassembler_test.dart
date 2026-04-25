// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_fragment_event.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_frame.dart';
import 'package:socialmesh/services/protocol/reticulum/reticulum_reassembler.dart';

/// Build a fragment-event whose payload is `[index, position, ...body]`.
/// `position` is a signed int8 — pass it directly; the helper handles
/// the byte-encoding.
ReticulumFragmentEvent _frag({
  required int fromNode,
  required int index,
  required int position,
  required List<int> body,
  int? timestampMs,
}) {
  final positionByte = position < 0 ? 256 + position : position;
  final payload = Uint8List.fromList([index, positionByte, ...body]);
  return ReticulumFragmentEvent(
    timestampMs: timestampMs ?? DateTime.now().millisecondsSinceEpoch,
    fromNode: fromNode,
    toNode: 0xFFFFFFFF,
    packetId: index * 100 + (position < 0 ? -position : position),
    channel: 1,
    rssi: -80,
    snr: 4.0,
    payload: payload,
  );
}

void main() {
  group('Single-fragment frame', () {
    test('emits immediately when N=1 fragment arrives (position=-1)', () async {
      final reasm = ReticulumReassembler();
      addTearDown(reasm.dispose);

      ReticulumFrame? captured;
      final sub = reasm.frames.listen((f) => captured = f);
      addTearDown(sub.cancel);

      reasm.onFragment(
        _frag(
          fromNode: 0xAABB,
          index: 7,
          position: -1,
          body: [0xDE, 0xAD, 0xBE, 0xEF],
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(captured, isNotNull);
      expect(captured!.fragmentCount, 1);
      expect(captured!.fromNode, 0xAABB);
      expect(captured!.index, 7);
      expect(captured!.body, [0xDE, 0xAD, 0xBE, 0xEF]);
      expect(reasm.activeBuffers, 0);
      expect(reasm.stats.framesEmitted, 1);
    });
  });

  group('Multi-fragment frame', () {
    test('emits when 1, 2, -3 arrive in order (N=3)', () async {
      final reasm = ReticulumReassembler();
      addTearDown(reasm.dispose);
      final received = <ReticulumFrame>[];
      final sub = reasm.frames.listen(received.add);
      addTearDown(sub.cancel);

      reasm.onFragment(
        _frag(fromNode: 1, index: 0, position: 1, body: [0xAA, 0xBB]),
      );
      reasm.onFragment(
        _frag(fromNode: 1, index: 0, position: 2, body: [0xCC, 0xDD]),
      );
      reasm.onFragment(
        _frag(fromNode: 1, index: 0, position: -3, body: [0xEE, 0xFF]),
      );
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      expect(received.single.fragmentCount, 3);
      // Concatenation respects position order 1..N (1-indexed).
      expect(received.single.body, [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]);
    });

    test('emits when fragments arrive out of order', () async {
      final reasm = ReticulumReassembler();
      addTearDown(reasm.dispose);
      final received = <ReticulumFrame>[];
      final sub = reasm.frames.listen(received.add);
      addTearDown(sub.cancel);

      reasm.onFragment(_frag(fromNode: 1, index: 0, position: 2, body: [0x22]));
      reasm.onFragment(
        _frag(fromNode: 1, index: 0, position: -3, body: [0x33]),
      );
      reasm.onFragment(_frag(fromNode: 1, index: 0, position: 1, body: [0x11]));
      await Future<void>.delayed(Duration.zero);

      expect(received, hasLength(1));
      // Reassembly order is positional, NOT arrival order.
      expect(received.single.body, [0x11, 0x22, 0x33]);
    });

    test(
      'does NOT emit when last fragment arrives but middle is missing',
      () async {
        final reasm = ReticulumReassembler();
        addTearDown(reasm.dispose);
        var emitCount = 0;
        final sub = reasm.frames.listen((_) => emitCount++);
        addTearDown(sub.cancel);

        reasm.onFragment(
          _frag(fromNode: 1, index: 0, position: 1, body: [0x11]),
        );
        // Missing position 2.
        reasm.onFragment(
          _frag(fromNode: 1, index: 0, position: -3, body: [0x33]),
        );
        await Future<void>.delayed(Duration.zero);
        expect(emitCount, 0);
        expect(reasm.activeBuffers, 1);
      },
    );

    test('two distinct frames keyed by different (fromNode, index) '
        'do not interfere', () async {
      final reasm = ReticulumReassembler();
      addTearDown(reasm.dispose);
      final received = <ReticulumFrame>[];
      final sub = reasm.frames.listen(received.add);
      addTearDown(sub.cancel);

      reasm.onFragment(
        _frag(fromNode: 1, index: 5, position: -1, body: [0xAA]),
      );
      reasm.onFragment(
        _frag(fromNode: 2, index: 5, position: -1, body: [0xBB]),
      );
      await Future<void>.delayed(Duration.zero);
      expect(received, hasLength(2));
      expect(received.map((f) => f.fromNode).toSet(), {1, 2});
    });
  });

  group('Duplicate fragments', () {
    test('overwrites + counts; does not double-count payload bytes', () async {
      final reasm = ReticulumReassembler();
      addTearDown(reasm.dispose);

      reasm.onFragment(
        _frag(fromNode: 1, index: 0, position: 1, body: [0x00, 0x00]),
      );
      // Same (from, index, position): duplicate.
      reasm.onFragment(
        _frag(fromNode: 1, index: 0, position: 1, body: [0xAA, 0xAA]),
      );
      expect(reasm.stats.duplicateFragments, 1);
      expect(reasm.globalBytes, 2);
    });
  });

  group('Decode errors', () {
    test(
      'short payload increments droppedDecodeError, no buffer created',
      () async {
        final reasm = ReticulumReassembler();
        addTearDown(reasm.dispose);
        reasm.onFragment(
          ReticulumFragmentEvent(
            timestampMs: 1,
            fromNode: 1,
            toNode: 1,
            packetId: 1,
            channel: 0,
            rssi: null,
            snr: null,
            payload: Uint8List.fromList([0x05]),
          ),
        );
        expect(reasm.stats.droppedDecodeError, 1);
        expect(reasm.activeBuffers, 0);
      },
    );

    test('zero position byte (invalid per spec) is rejected', () async {
      final reasm = ReticulumReassembler();
      addTearDown(reasm.dispose);
      reasm.onFragment(
        ReticulumFragmentEvent(
          timestampMs: 1,
          fromNode: 1,
          toNode: 1,
          packetId: 1,
          channel: 0,
          rssi: null,
          snr: null,
          payload: Uint8List.fromList([0x00, 0x00, 0xAA]),
        ),
      );
      expect(reasm.stats.droppedDecodeError, 1);
    });
  });

  group('Memory bounds', () {
    test(
      'exceeds maxConcurrentBuffers → drops oldest, increments counter',
      () async {
        final reasm = ReticulumReassembler(maxConcurrentBuffers: 4);
        addTearDown(reasm.dispose);
        // Create 4 incomplete buffers (different (from, index) keys).
        for (var i = 0; i < 4; i++) {
          reasm.onFragment(
            _frag(fromNode: i, index: 0, position: 1, body: [0x00]),
          );
        }
        expect(reasm.activeBuffers, 4);
        // Adding a 5th forces eviction of the oldest.
        reasm.onFragment(
          _frag(fromNode: 99, index: 0, position: 1, body: [0x00]),
        );
        expect(reasm.activeBuffers, 4);
        expect(reasm.stats.droppedOverflow, greaterThanOrEqualTo(1));
      },
    );

    test(
      '65th fragment in one buffer (when cap=64) drops the buffer',
      () async {
        final reasm = ReticulumReassembler(maxFragmentsPerBuffer: 4);
        addTearDown(reasm.dispose);
        // 4 distinct positions fill the buffer.
        for (var i = 1; i <= 4; i++) {
          reasm.onFragment(
            _frag(fromNode: 1, index: 0, position: i, body: [0x00]),
          );
        }
        expect(reasm.activeBuffers, 1);
        // 5th distinct position = over the cap.
        reasm.onFragment(
          _frag(fromNode: 1, index: 0, position: 5, body: [0x00]),
        );
        expect(reasm.activeBuffers, 0);
        expect(reasm.stats.droppedOverflow, 1);
      },
    );

    test('frame body that exceeds maxFrameSizeBytes is rejected', () async {
      final reasm = ReticulumReassembler(maxFrameSizeBytes: 100);
      addTearDown(reasm.dispose);
      reasm.onFragment(
        _frag(fromNode: 1, index: 0, position: 1, body: List.filled(60, 0)),
      );
      // Adding 60 + 60 = 120 > 100 → drops.
      reasm.onFragment(
        _frag(fromNode: 1, index: 0, position: 2, body: List.filled(60, 0)),
      );
      expect(reasm.stats.droppedOversize, 1);
      expect(reasm.activeBuffers, 0);
    });

    test(
      'global byte cap evicts oldest before accepting new fragment',
      () async {
        final reasm = ReticulumReassembler(globalMemoryCapBytes: 50);
        addTearDown(reasm.dispose);
        // Fill global with 40 bytes via one buffer.
        reasm.onFragment(
          _frag(fromNode: 1, index: 0, position: 1, body: List.filled(40, 0)),
        );
        expect(reasm.globalBytes, 40);
        // Adding 20 more (= 60 total) would exceed 50.
        // Oldest gets evicted, then the new buffer fits.
        reasm.onFragment(
          _frag(fromNode: 2, index: 0, position: 1, body: List.filled(20, 0)),
        );
        expect(reasm.globalBytes, 20);
        expect(reasm.stats.droppedOverflow, greaterThanOrEqualTo(1));
      },
    );
  });

  group('Timeouts', () {
    test('inactivity timeout drops stale buffer on tick', () async {
      var nowMs = 1000;
      final reasm = ReticulumReassembler(
        inactivityTimeout: const Duration(seconds: 5),
        clock: () => DateTime.fromMillisecondsSinceEpoch(nowMs),
      );
      addTearDown(reasm.dispose);
      reasm.onFragment(_frag(fromNode: 1, index: 0, position: 1, body: [0x00]));
      expect(reasm.activeBuffers, 1);
      // Advance clock past inactivity window.
      nowMs += 6000;
      reasm.tick();
      expect(reasm.activeBuffers, 0);
      expect(reasm.stats.droppedTimeoutInactivity, 1);
    });

    test(
      'absolute TTL drops buffer even when fragments keep arriving',
      () async {
        var nowMs = 1000;
        final reasm = ReticulumReassembler(
          inactivityTimeout: const Duration(seconds: 60),
          absoluteTtl: const Duration(seconds: 10),
          clock: () => DateTime.fromMillisecondsSinceEpoch(nowMs),
        );
        addTearDown(reasm.dispose);
        reasm.onFragment(
          _frag(fromNode: 1, index: 0, position: 1, body: [0x00]),
        );
        // Keep activity alive by sending more fragments.
        nowMs += 5000;
        reasm.onFragment(
          _frag(fromNode: 1, index: 0, position: 2, body: [0x00]),
        );
        expect(reasm.activeBuffers, 1);
        // Past absolute TTL since first fragment.
        nowMs += 6000;
        reasm.tick();
        expect(reasm.activeBuffers, 0);
        expect(reasm.stats.droppedTimeoutAbsolute, 1);
        // Should NOT be counted as inactivity-timeout.
        expect(reasm.stats.droppedTimeoutInactivity, 0);
      },
    );
  });

  group('Stats success rate', () {
    test('framesEmitted / totalAttempted', () async {
      final reasm = ReticulumReassembler();
      addTearDown(reasm.dispose);

      // 2 successful single-fragment frames.
      reasm.onFragment(
        _frag(fromNode: 1, index: 0, position: -1, body: [0x00]),
      );
      reasm.onFragment(
        _frag(fromNode: 2, index: 0, position: -1, body: [0x00]),
      );
      // 1 decode error.
      reasm.onFragment(
        ReticulumFragmentEvent(
          timestampMs: 1,
          fromNode: 1,
          toNode: 1,
          packetId: 1,
          channel: 0,
          rssi: null,
          snr: null,
          payload: Uint8List.fromList([0x05]),
        ),
      );
      expect(reasm.stats.framesEmitted, 2);
      expect(reasm.stats.totalAttempted, 3);
      expect(reasm.stats.successRate, closeTo(2 / 3, 0.001));
    });
  });
}
