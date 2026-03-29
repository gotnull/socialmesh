// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../services/haptic_service.dart';
import '../models/video_stream.dart';

/// Screen for watching an HLS live video stream.
class TakVideoPlayerScreen extends ConsumerStatefulWidget {
  final VideoStream stream;

  const TakVideoPlayerScreen({super.key, required this.stream});

  @override
  ConsumerState<TakVideoPlayerScreen> createState() =>
      _TakVideoPlayerScreenState();
}

class _TakVideoPlayerScreenState extends ConsumerState<TakVideoPlayerScreen>
    with LifecycleSafeMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  String? _error;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(widget.stream.url),
    );
    _controller = controller;

    controller.addListener(_onPlayerUpdate);

    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.play();
      safeSetState(() {
        _isInitialized = true;
      });
    } catch (e) {
      if (!mounted) return;
      safeSetState(() {
        _error = '$e';
      });
    }
  }

  void _onPlayerUpdate() {
    if (!mounted || _controller == null) return;
    final controller = _controller!;

    if (controller.value.hasError) {
      safeSetState(() {
        _error = controller.value.errorDescription;
      });
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onPlayerUpdate);
    _controller?.dispose();
    super.dispose();
  }

  void _toggleControls() {
    safeSetState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return GlassScaffold(
      title: widget.stream.name,
      resizeToAvoidBottomInset: false,
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _buildBody(context, l10n),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, dynamic l10n) {
    if (_error != null) {
      return _buildErrorView(context, l10n);
    }

    if (!_isInitialized) {
      return _buildLoadingView(context, l10n);
    }

    return _buildPlayerView(context, l10n);
  }

  Widget _buildLoadingView(BuildContext context, dynamic l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppTheme.spacing16),
          Text(
            l10n.takVideoPlayerLoading,
            style: TextStyle(fontSize: 14, color: context.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerView(BuildContext context, dynamic l10n) {
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _toggleControls,
      child: Stack(
        children: [
          // Video
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: VideoPlayer(controller),
            ),
          ),
          // Overlay controls
          if (_showControls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Live badge
                      if (widget.stream.status == VideoStreamStatus.live)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: SemanticColors.error,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius4,
                            ),
                          ),
                          child: Text(
                            l10n.takVideoLive,
                            style: const TextStyle(
                              color: SemanticColors.onAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      const SizedBox(height: AppTheme.spacing8),
                      // Stream info
                      Text(
                        widget.stream.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        l10n.takVideoStreamBy(widget.stream.ownerCallsign),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                      // Playback controls
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed: () {
                              ref.haptics.buttonTap();
                              if (controller.value.isPlaying) {
                                controller.pause();
                              } else {
                                controller.play();
                              }
                              safeSetState(() {});
                            },
                            icon: Icon(
                              controller.value.isPlaying
                                  ? Icons.pause_circle_filled
                                  : Icons.play_circle_filled,
                              size: 44,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorView(BuildContext context, dynamic l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: SemanticColors.error,
          ),
          const SizedBox(height: AppTheme.spacing24),
          Text(
            l10n.takVideoPlayerError,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: context.textSecondary),
              ),
            ),
          const SizedBox(height: AppTheme.spacing24),
          FilledButton(
            onPressed: () {
              ref.haptics.buttonTap();
              safeSetState(() {
                _error = null;
                _isInitialized = false;
              });
              _initPlayer();
            },
            child: Text(l10n.takVideoRetry),
          ),
        ],
      ),
    );
  }
}
