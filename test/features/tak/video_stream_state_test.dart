// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/tak/models/video_stream.dart';
import 'package:socialmesh/features/tak/models/video_stream_state.dart';

void main() {
  final sampleStream = VideoStream.fromJson({
    'id': 'vs-abcd1234',
    'streamKey': 'aabbccdd' * 4,
    'name': 'Test',
    'owner': 'uid-1',
    'ownerCallsign': 'ALPHA',
    'status': 'live',
    'url': 'https://example.com/hls/test.m3u8',
    'rtspUrl': '',
    'rtmpUrl': '',
    'createdAt': 1700000000000,
    'lastHeartbeat': 1700000015000,
    'expiresAt': 1700000060000,
  });

  group('VideoPublisherState', () {
    test('all states are subTypes of VideoPublisherState', () {
      const states = <VideoPublisherState>[
        VideoPublisherIdle(),
        VideoPublisherPreparing(),
        VideoPublisherRegistering(),
        VideoPublisherFailed('reason'),
        VideoPublisherEnded(),
      ];

      for (final state in states) {
        expect(state, isA<VideoPublisherState>());
      }
    });

    test('VideoPublisherIdle is constructable', () {
      const state = VideoPublisherIdle();
      expect(state, isA<VideoPublisherIdle>());
    });

    test('VideoPublisherPreparing is constructable', () {
      const state = VideoPublisherPreparing();
      expect(state, isA<VideoPublisherPreparing>());
    });

    test('VideoPublisherRegistering is constructable', () {
      const state = VideoPublisherRegistering();
      expect(state, isA<VideoPublisherRegistering>());
    });

    test('VideoPublisherLive carries stream and startedAt', () {
      final now = DateTime.now();
      final state = VideoPublisherLive(stream: sampleStream, startedAt: now);

      expect(state.stream.id, 'vs-abcd1234');
      expect(state.startedAt, now);
    });

    test('VideoPublisherReconnecting carries stream and attempt', () {
      final state = VideoPublisherReconnecting(
        stream: sampleStream,
        attempt: 3,
      );

      expect(state.stream.id, 'vs-abcd1234');
      expect(state.attempt, 3);
    });

    test('VideoPublisherFailed carries reason', () {
      const state = VideoPublisherFailed('network error');
      expect(state.reason, 'network error');
    });

    test('exhaustive switch covers all states', () {
      const states = <VideoPublisherState>[
        VideoPublisherIdle(),
        VideoPublisherPreparing(),
        VideoPublisherRegistering(),
        VideoPublisherFailed('x'),
        VideoPublisherEnded(),
      ];

      for (final state in states) {
        final label = switch (state) {
          VideoPublisherIdle() => 'idle',
          VideoPublisherPreparing() => 'preparing',
          VideoPublisherRegistering() => 'registering',
          VideoPublisherLive() => 'live',
          VideoPublisherReconnecting() => 'reconnecting',
          VideoPublisherFailed() => 'failed',
          VideoPublisherEnded() => 'ended',
        };
        expect(label, isNotEmpty);
      }
    });
  });

  group('VideoStreamBrowserState', () {
    test('all states are subtypes of VideoStreamBrowserState', () {
      final states = <VideoStreamBrowserState>[
        const VideoStreamBrowserInitial(),
        const VideoStreamBrowserLoading(),
        VideoStreamBrowserLoaded([sampleStream]),
        VideoStreamBrowserRefreshing([sampleStream]),
        const VideoStreamBrowserError('fail'),
      ];

      for (final state in states) {
        expect(state, isA<VideoStreamBrowserState>());
      }
    });

    test('VideoStreamBrowserLoaded isEmpty is correct', () {
      const emptyState = VideoStreamBrowserLoaded([]);
      expect(emptyState.isEmpty, isTrue);

      final nonEmpty = VideoStreamBrowserLoaded([sampleStream]);
      expect(nonEmpty.isEmpty, isFalse);
    });

    test('VideoStreamBrowserRefreshing carries streams', () {
      final state = VideoStreamBrowserRefreshing([sampleStream]);
      expect(state.streams, hasLength(1));
    });

    test('VideoStreamBrowserError carries message', () {
      const state = VideoStreamBrowserError('timeout');
      expect(state.message, 'timeout');
    });

    test('exhaustive switch covers all states', () {
      final states = <VideoStreamBrowserState>[
        const VideoStreamBrowserInitial(),
        const VideoStreamBrowserLoading(),
        const VideoStreamBrowserLoaded([]),
        const VideoStreamBrowserRefreshing([]),
        const VideoStreamBrowserError('err'),
      ];

      for (final state in states) {
        final label = switch (state) {
          VideoStreamBrowserInitial() => 'initial',
          VideoStreamBrowserLoading() => 'loading',
          VideoStreamBrowserLoaded() => 'loaded',
          VideoStreamBrowserRefreshing() => 'refreshing',
          VideoStreamBrowserError() => 'error',
        };
        expect(label, isNotEmpty);
      }
    });
  });
}
