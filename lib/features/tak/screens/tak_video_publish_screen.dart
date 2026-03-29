// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/auth_providers.dart';
import '../../../services/haptic_service.dart';
import '../../../utils/snackbar.dart';
import '../models/video_stream.dart';
import '../models/video_stream_state.dart';
import '../providers/tak_video_providers.dart';

/// Screen for setting up and starting a live video stream.
///
/// Flow: configure → prepare camera → register with backend → stream RTMP.
class TakVideoPublishScreen extends ConsumerStatefulWidget {
  const TakVideoPublishScreen({super.key});

  @override
  ConsumerState<TakVideoPublishScreen> createState() =>
      _TakVideoPublishScreenState();
}

class _TakVideoPublishScreenState extends ConsumerState<TakVideoPublishScreen>
    with LifecycleSafeMixin, WidgetsBindingObserver {
  static const int _maxStreamNameLength = 100;
  static const int _maxCallsignLength = 50;

  late final TextEditingController _nameController;
  late final TextEditingController _callsignController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _callsignController = TextEditingController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _nameController.dispose();
    _callsignController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Stop streaming when app goes to background to prevent resource leak
    if (state == AppLifecycleState.paused) {
      final publisherState = ref.read(takVideoPublisherProvider);
      if (publisherState is VideoPublisherLive) {
        ref.read(takVideoPublisherProvider.notifier).stop();
      }
    }
  }

  void _dismissKeyboard() => FocusScope.of(context).unfocus();

  Future<void> _startStream() async {
    _dismissKeyboard();
    final name = _nameController.text.trim();
    final callsign = _callsignController.text.trim();

    if (name.isEmpty || callsign.isEmpty) return;

    final isSignedIn = ref.read(isSignedInProvider);
    if (!isSignedIn) {
      if (!mounted) return;
      showWarningSnackBar(context, context.l10n.takVideoAuthRequired);
      return;
    }

    final notifier = ref.read(takVideoPublisherProvider.notifier);
    notifier.setPreparing();

    // Register stream with backend
    final request = VideoStreamCreateRequest(
      name: name,
      ownerCallsign: callsign,
    );
    await notifier.registerStream(request);
  }

  Future<void> _stopStream() async {
    ref.haptics.buttonTap();
    final notifier = ref.read(takVideoPublisherProvider.notifier);
    await notifier.stop();
  }

  @override
  Widget build(BuildContext context) {
    final publisherState = ref.watch(takVideoPublisherProvider);
    final l10n = context.l10n;

    return GestureDetector(
      onTap: _dismissKeyboard,
      behavior: HitTestBehavior.opaque,
      child: GlassScaffold(
        title: l10n.takVideoGoLive,
        resizeToAvoidBottomInset: false,
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: _buildBody(context, publisherState, l10n),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    VideoPublisherState publisherState,
    dynamic l10n,
  ) {
    return switch (publisherState) {
      VideoPublisherIdle() => _buildSetupForm(context, l10n),
      VideoPublisherPreparing() => _buildStatusView(
        context,
        l10n.takVideoPreparing,
        Icons.camera_alt,
        showProgress: true,
      ),
      VideoPublisherRegistering() => _buildStatusView(
        context,
        l10n.takVideoRegistering,
        Icons.cloud_upload,
        showProgress: true,
      ),
      VideoPublisherLive(stream: final stream, startedAt: final startedAt) =>
        _buildLiveView(context, stream, startedAt, l10n),
      VideoPublisherReconnecting(attempt: final attempt) => _buildStatusView(
        context,
        '${l10n.takVideoReconnecting} (#$attempt)',
        Icons.sync,
        showProgress: true,
      ),
      VideoPublisherFailed(reason: final reason) => _buildFailedView(
        context,
        reason,
        l10n,
      ),
      VideoPublisherEnded() => _buildEndedView(context, l10n),
    };
  }

  Widget _buildSetupForm(BuildContext context, dynamic l10n) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppTheme.spacing32),
          // Stream name
          TextField(
            controller: _nameController,
            maxLength: _maxStreamNameLength,
            decoration: InputDecoration(
              labelText: l10n.takVideoStreamName,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.label_outline),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppTheme.spacing16),
          // Callsign
          TextField(
            controller: _callsignController,
            maxLength: _maxCallsignLength,
            decoration: InputDecoration(
              labelText: l10n.takVideoCallsign,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.person_outline),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _startStream(),
          ),
          const Spacer(),
          // Start button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: FilledButton.icon(
                onPressed: () {
                  ref.haptics.buttonTap();
                  _startStream();
                },
                icon: const Icon(Icons.videocam),
                label: Text(l10n.takVideoStartStream),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusView(
    BuildContext context,
    String message,
    IconData icon, {
    bool showProgress = false,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: context.accentColor),
          const SizedBox(height: AppTheme.spacing24),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: context.textSecondary),
          ),
          if (showProgress) ...[
            const SizedBox(height: AppTheme.spacing24),
            const CircularProgressIndicator(),
          ],
        ],
      ),
    );
  }

  Widget _buildLiveView(
    BuildContext context,
    VideoStream stream,
    DateTime startedAt,
    dynamic l10n,
  ) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: Column(
        children: [
          const SizedBox(height: AppTheme.spacing32),
          // Live badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: SemanticColors.error,
              borderRadius: BorderRadius.circular(AppTheme.radius20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.fiber_manual_record,
                  size: 12,
                  color: SemanticColors.onAccent,
                ),
                const SizedBox(width: AppTheme.spacing6),
                Text(
                  l10n.takVideoLive,
                  style: const TextStyle(
                    color: SemanticColors.onAccent,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          // Stream info
          Text(
            stream.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            l10n.takVideoStreamBy(stream.ownerCallsign),
            style: TextStyle(fontSize: 14, color: context.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacing16),
          // RTMP URL for reference
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              border: Border.all(color: context.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RTMP',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                SelectableText(
                  stream.rtmpUrl,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'JetBrainsMono',
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: context.surface,
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              border: Border.all(color: context.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HLS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                SelectableText(
                  stream.url,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'JetBrainsMono',
                    color: context.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Stop button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _stopStream,
                  icon: const Icon(Icons.stop),
                  label: Text(l10n.takVideoStopStream),
                  style: FilledButton.styleFrom(
                    backgroundColor: SemanticColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailedView(BuildContext context, String reason, dynamic l10n) {
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
            l10n.takVideoFailed,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              reason,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.textSecondary),
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          FilledButton(
            onPressed: () {
              ref.haptics.buttonTap();
              ref.read(takVideoPublisherProvider.notifier).reset();
            },
            child: Text(l10n.takVideoRetry),
          ),
        ],
      ),
    );
  }

  Widget _buildEndedView(BuildContext context, dynamic l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: context.accentColor,
          ),
          const SizedBox(height: AppTheme.spacing24),
          Text(
            l10n.takVideoEnded,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing24),
          FilledButton(
            onPressed: () {
              ref.haptics.buttonTap();
              ref.read(takVideoPublisherProvider.notifier).reset();
            },
            child: Text(l10n.takVideoRetry),
          ),
        ],
      ),
    );
  }
}
