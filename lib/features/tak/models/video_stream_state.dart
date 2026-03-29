// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'video_stream.dart';

// ---------------------------------------------------------------------------
// Publisher state machine
// ---------------------------------------------------------------------------

/// State machine for the video publisher flow.
///
/// Flow: idle → preparing → registering → live → ended
///       ↓ (error at any point)
///       failed
///       live → reconnecting → live (on transient errors)
sealed class VideoPublisherState {
  const VideoPublisherState();
}

/// No streaming activity.
final class VideoPublisherIdle extends VideoPublisherState {
  const VideoPublisherIdle();
}

/// Camera/mic are being initialized.
final class VideoPublisherPreparing extends VideoPublisherState {
  const VideoPublisherPreparing();
}

/// Stream is being registered with the backend.
final class VideoPublisherRegistering extends VideoPublisherState {
  const VideoPublisherRegistering();
}

/// Actively streaming.
final class VideoPublisherLive extends VideoPublisherState {
  final VideoStream stream;
  final DateTime startedAt;
  const VideoPublisherLive({required this.stream, required this.startedAt});
}

/// Attempting to reconnect after a transient error.
final class VideoPublisherReconnecting extends VideoPublisherState {
  final VideoStream stream;
  final int attempt;
  const VideoPublisherReconnecting({
    required this.stream,
    required this.attempt,
  });
}

/// Streaming failed permanently.
final class VideoPublisherFailed extends VideoPublisherState {
  final String reason;
  const VideoPublisherFailed(this.reason);
}

/// Streaming ended normally.
final class VideoPublisherEnded extends VideoPublisherState {
  const VideoPublisherEnded();
}

// ---------------------------------------------------------------------------
// Browser state machine
// ---------------------------------------------------------------------------

/// State machine for the stream browser.
sealed class VideoStreamBrowserState {
  const VideoStreamBrowserState();
}

/// Initial state before any fetch.
final class VideoStreamBrowserInitial extends VideoStreamBrowserState {
  const VideoStreamBrowserInitial();
}

/// Loading streams for the first time.
final class VideoStreamBrowserLoading extends VideoStreamBrowserState {
  const VideoStreamBrowserLoading();
}

/// Streams loaded successfully.
final class VideoStreamBrowserLoaded extends VideoStreamBrowserState {
  final List<VideoStream> streams;
  const VideoStreamBrowserLoaded(this.streams);
  bool get isEmpty => streams.isEmpty;
}

/// Refreshing while showing existing data.
final class VideoStreamBrowserRefreshing extends VideoStreamBrowserState {
  final List<VideoStream> streams;
  const VideoStreamBrowserRefreshing(this.streams);
}

/// Error loading streams.
final class VideoStreamBrowserError extends VideoStreamBrowserState {
  final String message;
  const VideoStreamBrowserError(this.message);
}

// ---------------------------------------------------------------------------
// Player state machine
// ---------------------------------------------------------------------------

/// State machine for the HLS video player.
sealed class VideoPlayerState {
  const VideoPlayerState();
}

/// Player is loading the stream.
final class VideoPlayerLoading extends VideoPlayerState {
  const VideoPlayerLoading();
}

/// Stream is playing.
final class VideoPlayerPlaying extends VideoPlayerState {
  const VideoPlayerPlaying();
}

/// Stream is buffering.
final class VideoPlayerBuffering extends VideoPlayerState {
  const VideoPlayerBuffering();
}

/// Stream playback ended.
final class VideoPlayerEnded extends VideoPlayerState {
  const VideoPlayerEnded();
}

/// Player encountered an error.
final class VideoPlayerFailed extends VideoPlayerState {
  final String reason;
  const VideoPlayerFailed(this.reason);
}
