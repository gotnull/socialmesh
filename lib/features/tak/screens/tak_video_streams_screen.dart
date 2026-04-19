// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../services/haptic_service.dart';
import '../models/video_stream.dart';
import '../models/video_stream_state.dart';
import '../providers/tak_video_providers.dart';
import 'tak_video_player_screen.dart';
import 'tak_video_publish_screen.dart';

/// Screen listing active video streams from the TAK Gateway.
class TakVideoStreamsScreen extends ConsumerStatefulWidget {
  const TakVideoStreamsScreen({super.key});

  @override
  ConsumerState<TakVideoStreamsScreen> createState() =>
      _TakVideoStreamsScreenState();
}

class _TakVideoStreamsScreenState extends ConsumerState<TakVideoStreamsScreen>
    with LifecycleSafeMixin {
  @override
  void initState() {
    super.initState();
    // Fetch streams on first load
    Future.microtask(() {
      ref.read(takVideoStreamBrowserProvider.notifier).fetch();
      ref.read(takVideoStreamBrowserProvider.notifier).startAutoRefresh();
    });
  }

  @override
  void dispose() {
    // Auto-refresh is cleaned up by the notifier's ref.onDispose
    super.dispose();
  }

  void _dismissKeyboard() => FocusScope.of(context).unfocus();

  @override
  Widget build(BuildContext context) {
    final browserState = ref.watch(takVideoStreamBrowserProvider);
    final l10n = context.l10n;

    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.opaque,
      child: GlassScaffold(
        title: l10n.takVideoTitle,
        resizeToAvoidBottomInset: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam),
            tooltip: l10n.takVideoGoLive,
            onPressed: () {
              ref.haptics.buttonTap();
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const TakVideoPublishScreen(),
                ),
              );
            },
          ),
        ],
        slivers: [
          SliverFillRemaining(
            hasScrollBody: true,
            child: _buildBody(context, browserState, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    VideoStreamBrowserState browserState,
    dynamic l10n,
  ) {
    return switch (browserState) {
      VideoStreamBrowserInitial() || VideoStreamBrowserLoading() => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              l10n.takVideoLoading,
              style: TextStyle(fontSize: 14, color: context.textSecondary),
            ),
          ],
        ),
      ),
      VideoStreamBrowserLoaded(streams: final streams) =>
        streams.isEmpty
            ? _buildEmptyState(context, l10n)
            : _buildStreamList(context, streams, l10n, isRefreshing: false),
      VideoStreamBrowserRefreshing(streams: final streams) => _buildStreamList(
        context,
        streams,
        l10n,
        isRefreshing: true,
      ),
      VideoStreamBrowserError(message: final message) => _buildErrorState(
        context,
        message,
        l10n,
      ),
    };
  }

  Widget _buildEmptyState(BuildContext context, dynamic l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius16),
            ),
            child: Icon(
              Icons.videocam_off,
              size: 40,
              color: context.textTertiary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Text(
            l10n.takVideoEmptyTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              l10n.takVideoEmptyDescription,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.textSecondary),
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          FilledButton.icon(
            onPressed: () {
              ref.haptics.buttonTap();
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (context) => const TakVideoPublishScreen(),
                ),
              );
            },
            icon: const Icon(Icons.videocam, size: 18),
            label: Text(l10n.takVideoNewStream),
          ),
        ],
      ),
    );
  }

  Widget _buildStreamList(
    BuildContext context,
    List<VideoStream> streams,
    dynamic l10n, {
    required bool isRefreshing,
  }) {
    return RefreshIndicator(
      onRefresh: () => ref.read(takVideoStreamBrowserProvider.notifier).fetch(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing16,
              AppTheme.spacing16,
              AppTheme.spacing8,
            ),
            child: Row(
              children: [
                Text(
                  l10n.takVideoStreamCount(streams.length),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: context.textSecondary,
                  ),
                ),
                if (isRefreshing) ...[
                  const SizedBox(width: AppTheme.spacing8),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: streams.length,
              itemBuilder: (context, index) {
                final stream = streams[index];
                return _StreamTile(
                  stream: stream,
                  onTap: () {
                    ref.haptics.buttonTap();
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (context) =>
                            TakVideoPlayerScreen(stream: stream),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message, dynamic l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius16),
            ),
            child: const Icon(
              Icons.error_outline,
              size: 40,
              color: SemanticColors.error,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: context.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacing16),
          FilledButton(
            onPressed: () {
              ref.haptics.buttonTap();
              ref.read(takVideoStreamBrowserProvider.notifier).fetch();
            },
            child: Text(l10n.takVideoRetry),
          ),
        ],
      ),
    );
  }
}

/// A single stream list tile.
class _StreamTile extends StatelessWidget {
  final VideoStream stream;
  final VoidCallback onTap;

  const _StreamTile({required this.stream, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: context.card,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        side: BorderSide(color: context.border, width: 0.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            children: [
              // Live indicator
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: stream.status == VideoStreamStatus.live
                      ? SemanticColors.error.withValues(alpha: 0.15)
                      : context.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
                ),
                child: Icon(
                  stream.status == VideoStreamStatus.live
                      ? Icons.fiber_manual_record
                      : Icons.videocam_off,
                  size: 20,
                  color: stream.status == VideoStreamStatus.live
                      ? SemanticColors.error
                      : context.textTertiary,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              // Stream info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stream.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      context.l10n.takVideoStreamBy(stream.ownerCallsign),
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Watch button
              Icon(
                Icons.play_circle_outline,
                color: context.accentColor,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
