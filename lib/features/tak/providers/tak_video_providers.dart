// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../../../providers/auth_providers.dart';
import '../models/video_stream.dart';
import '../models/video_stream_state.dart';
import '../services/tak_video_stream_service.dart';
import 'tak_providers.dart';

// ---------------------------------------------------------------------------
// Feature flag
// ---------------------------------------------------------------------------

/// Whether the TAK video streaming feature is enabled.
final isTakVideoEnabledProvider = Provider<bool>((ref) {
  final enabled = AppFeatureFlags.isTakVideoEnabled;
  AppLogging.tak('isTakVideoEnabledProvider: $enabled');
  return enabled;
});

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// TAK video stream service instance.
///
/// Reuses the same gateway URL and auth token source as the main TAK client.
final takVideoStreamServiceProvider = Provider<TakVideoStreamService>((ref) {
  final gatewayUrl = ref.watch(takGatewayClientProvider).gatewayUrl;
  final authService = ref.read(authServiceProvider);

  final service = TakVideoStreamService(
    gatewayUrl: gatewayUrl,
    getAuthToken: () => authService.getIdToken(),
  );

  ref.onDispose(() {
    AppLogging.tak('Disposing TakVideoStreamService');
    service.dispose();
  });

  return service;
});

// ---------------------------------------------------------------------------
// Stream browser
// ---------------------------------------------------------------------------

/// Manages the list of active video streams from the TAK Gateway.
final takVideoStreamBrowserProvider =
    NotifierProvider<TakVideoStreamBrowserNotifier, VideoStreamBrowserState>(
      TakVideoStreamBrowserNotifier.new,
    );

/// Notifier for the stream browser state machine.
class TakVideoStreamBrowserNotifier extends Notifier<VideoStreamBrowserState> {
  Timer? _autoRefreshTimer;

  @override
  VideoStreamBrowserState build() {
    ref.onDispose(() {
      _autoRefreshTimer?.cancel();
    });
    return const VideoStreamBrowserInitial();
  }

  /// Fetch streams from the backend.
  Future<void> fetch() async {
    final current = state;
    if (current is VideoStreamBrowserLoaded) {
      state = VideoStreamBrowserRefreshing(current.streams);
    } else {
      state = const VideoStreamBrowserLoading();
    }

    try {
      final service = ref.read(takVideoStreamServiceProvider);
      final streams = await service.listStreams(status: 'live');
      state = VideoStreamBrowserLoaded(streams);
    } on TakVideoServiceException catch (e) {
      AppLogging.tak('TakVideoStreamBrowser: fetch failed: ${e.message}');
      state = VideoStreamBrowserError(e.message);
    } catch (e) {
      AppLogging.tak('TakVideoStreamBrowser: unexpected error: $e');
      state = VideoStreamBrowserError('$e');
    }
  }

  /// Start auto-refreshing every [interval].
  void startAutoRefresh({Duration interval = const Duration(seconds: 30)}) {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(interval, (_) => fetch());
  }

  /// Stop auto-refreshing.
  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }
}

// ---------------------------------------------------------------------------
// Publisher
// ---------------------------------------------------------------------------

/// Manages the video publisher state machine.
final takVideoPublisherProvider =
    NotifierProvider<TakVideoPublisherNotifier, VideoPublisherState>(
      TakVideoPublisherNotifier.new,
    );

/// Notifier for the publisher flow state machine.
///
/// Handles: register → heartbeat loop → cleanup on stop/error.
class TakVideoPublisherNotifier extends Notifier<VideoPublisherState> {
  Timer? _heartbeatTimer;
  String? _activeStreamId;

  @override
  VideoPublisherState build() {
    ref.onDispose(() {
      _heartbeatTimer?.cancel();
      // Best-effort cleanup on provider dispose
      _cleanupStream();
    });
    return const VideoPublisherIdle();
  }

  /// Register a stream with the backend and start heartbeating.
  Future<void> registerStream(VideoStreamCreateRequest request) async {
    state = const VideoPublisherRegistering();
    try {
      final service = ref.read(takVideoStreamServiceProvider);
      final stream = await service.register(request);
      _activeStreamId = stream.id;
      _startHeartbeat(stream.id);
      state = VideoPublisherLive(stream: stream, startedAt: DateTime.now());
    } on TakVideoServiceException catch (e) {
      state = VideoPublisherFailed(e.message);
    } catch (e) {
      state = VideoPublisherFailed('$e');
    }
  }

  /// Transition to preparing state (camera/mic init).
  void setPreparing() {
    state = const VideoPublisherPreparing();
  }

  /// Transition to live state with the given stream.
  void setLive(VideoStream stream) {
    _activeStreamId = stream.id;
    _startHeartbeat(stream.id);
    state = VideoPublisherLive(stream: stream, startedAt: DateTime.now());
  }

  /// Stop streaming and clean up.
  Future<void> stop() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    await _cleanupStream();
    state = const VideoPublisherEnded();
  }

  /// Reset back to idle.
  void reset() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _activeStreamId = null;
    state = const VideoPublisherIdle();
  }

  void _startHeartbeat(String streamId) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _sendHeartbeat(streamId),
    );
  }

  Future<void> _sendHeartbeat(String streamId) async {
    try {
      final service = ref.read(takVideoStreamServiceProvider);
      await service.heartbeat(streamId);
    } on TakVideoServiceException catch (e) {
      AppLogging.tak(
        'TakVideoPublisher: heartbeat failed for $streamId: ${e.message}',
      );
    } catch (e) {
      AppLogging.tak('TakVideoPublisher: heartbeat error for $streamId: $e');
    }
  }

  Future<void> _cleanupStream() async {
    final streamId = _activeStreamId;
    if (streamId == null) return;
    _activeStreamId = null;
    try {
      final service = ref.read(takVideoStreamServiceProvider);
      await service.deleteStream(streamId);
      AppLogging.tak('TakVideoPublisher: cleaned up stream $streamId');
    } catch (e) {
      AppLogging.tak('TakVideoPublisher: cleanup failed for $streamId: $e');
    }
  }
}
