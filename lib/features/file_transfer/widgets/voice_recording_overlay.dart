// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../services/voice/voice_constants.dart';
import '../../../services/voice/voice_player.dart';

/// Full-screen recording overlay with a four-phase flow:
///
/// 1. **Idle** — big red record button, quality picker. Tap to start.
/// 2. **Recording** — live waveform, elapsed timer, pause & stop buttons.
/// 3. **Paused** — frozen waveform, resume & stop buttons.
/// 4. **Reviewing** — preview playback, send/retake/cancel.
class VoiceRecordingOverlay extends StatefulWidget {
  const VoiceRecordingOverlay({
    super.key,
    required this.onStartRecording,
    required this.onRecordingStopped,
    required this.onSend,
    required this.onCancel,
    required this.onRestart,
    this.onPauseRecording,
    this.onResumeRecording,
    this.onGetPreviewPayload,
    this.autoStopNotifier,
    this.maxRecordingDuration,
    this.qualityNotifier,
  });

  /// Called when the user taps the record button to begin capturing audio.
  /// Should start the microphone session and return the amplitude stream.
  final Future<Stream<double>?> Function() onStartRecording;

  /// Called when the user taps stop. The caller should stop the recording.
  final VoidCallback onRecordingStopped;

  /// Called when the user confirms "Send" in the review phase.
  final VoidCallback onSend;

  /// Discard: cancel the recording with no output.
  final VoidCallback onCancel;

  /// Retake: cancels the current session and restarts a fresh recording.
  final Future<Stream<double>?> Function() onRestart;

  /// Called when the user taps pause during recording.
  final VoidCallback? onPauseRecording;

  /// Called when the user taps resume after pausing.
  final VoidCallback? onResumeRecording;

  /// Called when the overlay enters review mode to obtain the encoded `.c2`
  /// payload for in-place playback.
  final Future<Uint8List?> Function()? onGetPreviewPayload;

  /// When set to `true` by the caller the overlay transitions to reviewing.
  final ValueNotifier<bool>? autoStopNotifier;

  /// Maximum recording time for the selected quality mode.
  final Duration? maxRecordingDuration;

  /// Notifier for the selected voice quality.
  final ValueNotifier<VoiceQuality>? qualityNotifier;

  @override
  State<VoiceRecordingOverlay> createState() => _VoiceRecordingOverlayState();
}

class _VoiceRecordingOverlayState extends State<VoiceRecordingOverlay>
    with TickerProviderStateMixin {
  // ── Animations ───────────────────────────────────────────────────────────
  late final AnimationController _pulse;
  late final AnimationController _ringPulse;

  // ── Phase ────────────────────────────────────────────────────────────────
  _OverlayPhase _phase = _OverlayPhase.idle;

  // ── Timer ────────────────────────────────────────────────────────────────
  Timer? _timer;
  int _elapsedMs = 0;
  static const _tickMs = 100;

  // ── Waveform ─────────────────────────────────────────────────────────────
  final _samples = <double>[];
  int _waveGeneration = 0;
  StreamSubscription<double>? _amplitudeSub;

  // ── Preview playback ─────────────────────────────────────────────────────
  VoicePlayer? _player;
  Uint8List? _previewPayload;
  bool _previewLoading = false;
  bool _previewLoaded = false;
  double _playbackProgress = 0.0;
  Duration _playbackPosition = Duration.zero;
  Duration _playbackDuration = Duration.zero;
  StreamSubscription<Duration>? _positionSub;

  // ── Preview seek drag ────────────────────────────────────────────────────
  bool _previewDragging = false;
  double _previewDragProgress = 0.0;

  static final double _defaultMaxMs = VoiceConstants
      .maxRecordingDuration
      .inMilliseconds
      .toDouble();

  // iOS system red
  static const _recColor = Color(0xFFFF3B30);
  static const _pausedColor = Color(0xFFFF9F0A); // amber
  static const _sendColor = Color(0xFF30D158); // green
  static const _waveformHeight = 120.0;
  static const _actionButtonSize = 80.0;
  static const _stopSquareSize = 26.0;
  static const _spacerWidth = 72.0;

  double get _maxMs {
    if (widget.qualityNotifier != null) {
      return widget.qualityNotifier!.value.maxRecordingDuration.inMilliseconds
          .toDouble();
    }
    return widget.maxRecordingDuration?.inMilliseconds.toDouble() ??
        _defaultMaxMs;
  }

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _ringPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();

    widget.autoStopNotifier?.addListener(_onAutoStopNotified);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _ringPulse.dispose();
    _amplitudeSub?.cancel();
    _positionSub?.cancel();
    // Defer player disposal so ValueListenableBuilder listeners detach first.
    final player = _player;
    if (player != null) {
      player.stop();
      Future.microtask(() => player.dispose());
    }
    widget.autoStopNotifier?.removeListener(_onAutoStopNotified);
    super.dispose();
  }

  void _onAutoStopNotified() {
    if (!mounted) return;
    if (widget.autoStopNotifier?.value == true) _enterReview();
  }

  Future<void> _startRecording() async {
    HapticFeedback.heavyImpact();
    final stream = await widget.onStartRecording();
    if (!mounted) return;
    setState(() {
      _phase = _OverlayPhase.recording;
      _elapsedMs = 0;
      _samples.clear();
      _waveGeneration = 0;
    });
    _amplitudeSub = stream?.listen(_onAmplitude);
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (_) {
      if (!mounted) return;
      setState(() => _elapsedMs += _tickMs);
    });
  }

  void _pauseRecording() {
    HapticFeedback.mediumImpact();
    _timer?.cancel();
    _timer = null;
    widget.onPauseRecording?.call();
    setState(() => _phase = _OverlayPhase.paused);
  }

  void _resumeRecording() {
    HapticFeedback.mediumImpact();
    widget.onResumeRecording?.call();
    setState(() => _phase = _OverlayPhase.recording);
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (_) {
      if (!mounted) return;
      setState(() => _elapsedMs += _tickMs);
    });
  }

  void _enterReview() {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _timer?.cancel();
    _timer = null;
    // Create player eagerly so ValueListenableBuilder always binds to the
    // real isPlaying notifier instead of a throwaway ValueNotifier(false).
    _player ??= VoicePlayer();
    _positionSub?.cancel();
    _positionSub = _player!.positionStream.listen(_onPlaybackPosition);
    setState(() {
      _phase = _OverlayPhase.reviewing;
      _playbackProgress = 0.0;
    });
    _loadPreviewPayload();
  }

  Future<void> _handleRetake() async {
    HapticFeedback.mediumImpact();
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.voiceRecordingDiscardTitle,
      message: context.l10n.voiceRecordingDiscardMessage,
      confirmLabel: context.l10n.voiceRecordingDiscardConfirm,
      isDestructive: true,
    );
    if (confirmed != true || !mounted) return;

    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _positionSub?.cancel();
    _positionSub = null;
    _timer?.cancel();
    _timer = null;
    final player = _player;
    _player = null;
    if (player != null) {
      player.pause();
      Future.microtask(() => player.dispose());
    }
    if (!mounted) return;
    setState(() {
      _phase = _OverlayPhase.idle;
      _elapsedMs = 0;
      _samples.clear();
      _waveGeneration = 0;
      _previewPayload = null;
      _previewLoading = false;
      _previewLoaded = false;
      _playbackProgress = 0.0;
      _playbackPosition = Duration.zero;
      _playbackDuration = Duration.zero;
      _previewDragging = false;
      _previewDragProgress = 0.0;
    });
    // Don't auto-start — user taps record again from idle.
  }

  Future<void> _loadPreviewPayload() async {
    if (widget.onGetPreviewPayload == null) return;
    setState(() => _previewLoading = true);
    final payload = await widget.onGetPreviewPayload!();
    if (!mounted) return;
    setState(() {
      _previewPayload = payload;
      _previewLoading = false;
    });
  }

  Future<void> _togglePreviewPlayback() async {
    if (_previewPayload == null || _player == null) return;

    if (_player!.isPlaying.value) {
      // Pause — keeps position so resume and seek both work.
      await _player!.pause();
      if (mounted) setState(() {});
      return;
    }

    if (_previewLoaded) {
      // Already loaded — resume from current (possibly seeked) position.
      await _player!.resume();
      if (mounted) setState(() {});
      return;
    }

    // First play: load + start.
    final ok = await _player!.playC2(_previewPayload!);
    if (ok && mounted) setState(() => _previewLoaded = true);
  }

  void _onPlaybackPosition(Duration position) {
    if (!mounted) return;
    if (_previewDragging) return;
    final total = _player?.currentDuration;
    if (total == null || total.inMilliseconds == 0) return;
    final fraction = (position.inMilliseconds / total.inMilliseconds).clamp(
      0.0,
      1.0,
    );
    setState(() {
      _playbackProgress = fraction;
      _playbackPosition = position;
      _playbackDuration = total;
    });
  }

  void _onPreviewDragStart(DragStartDetails details, double width) {
    HapticFeedback.selectionClick();
    final x = details.localPosition.dx;
    setState(() {
      _previewDragging = true;
      _previewDragProgress = (x / width).clamp(0.0, 1.0);
    });
  }

  void _onPreviewDragUpdate(DragUpdateDetails details, double width) {
    final x = details.localPosition.dx;
    setState(() {
      _previewDragProgress = (x / width).clamp(0.0, 1.0);
    });
  }

  Future<void> _onPreviewDragEnd(DragEndDetails _) async {
    if (_player == null || !_previewLoaded) {
      setState(() => _previewDragging = false);
      return;
    }
    final total = _player!.currentDuration ?? _playbackDuration;
    final targetMs = (_previewDragProgress * total.inMilliseconds).round();
    final target = Duration(milliseconds: targetMs);
    await _player!.seekTo(target);
    if (!mounted) return;
    setState(() {
      _previewDragging = false;
      _playbackProgress = _previewDragProgress;
      _playbackPosition = target;
    });
  }

  void _onAmplitude(double level) {
    if (!mounted) return;
    if (_phase != _OverlayPhase.recording) return;
    setState(() {
      _samples.add(level);
      _waveGeneration++;
    });
  }

  /// In idle state, cancel immediately (nothing to lose). In any other
  /// phase the user has recorded audio, so ask for confirmation first.
  Future<void> _cancelWithConfirmation() async {
    HapticFeedback.mediumImpact();

    if (_phase == _OverlayPhase.idle) {
      widget.onCancel();
      return;
    }

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.voiceRecordingDiscardTitle,
      message: context.l10n.voiceRecordingDiscardMessage,
      confirmLabel: context.l10n.voiceRecordingDiscardConfirm,
      isDestructive: true,
    );

    if (confirmed != true || !mounted) return;
    _player?.stop();
    widget.onCancel();
  }

  String get _formattedTime {
    final totalSec = _elapsedMs ~/ 1000;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  int get _maxSeconds {
    if (widget.qualityNotifier != null) {
      return widget.qualityNotifier!.value.maxRecordingDuration.inSeconds;
    }
    return (widget.maxRecordingDuration ?? VoiceConstants.maxRecordingDuration)
        .inSeconds;
  }

  String _qualityLabel(BuildContext context, VoiceQuality quality) {
    return switch (quality) {
      VoiceQuality.extended => context.l10n.voiceQualityExtended,
      VoiceQuality.standard => context.l10n.voiceQualityStandard,
      VoiceQuality.high => context.l10n.voiceQualityHigh,
    };
  }

  Future<void> _showQualityPicker(BuildContext context) async {
    final notifier = widget.qualityNotifier;
    if (notifier == null) return;

    final current = notifier.value;
    final picked = await showModalBottomSheet<VoiceQuality>(
      context: context,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radius20),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing24,
            vertical: AppTheme.spacing16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(AppTheme.radius2),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              Text(
                ctx.l10n.voiceQualityPickerTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacing16),
              for (final q in VoiceQuality.values)
                _QualityOption(
                  quality: q,
                  label: _qualityLabel(ctx, q),
                  isSelected: q == current,
                  onTap: () => Navigator.of(ctx).pop(q),
                ),
              const SizedBox(height: AppTheme.spacing8),
            ],
          ),
        ),
      ),
    );

    if (picked == null || picked == current || !mounted) return;

    HapticFeedback.mediumImpact();
    notifier.value = picked;
    // Reset to idle — user must tap record again with the new quality.
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _positionSub?.cancel();
    _positionSub = null;
    _timer?.cancel();
    _timer = null;
    await _player?.stop();
    await _player?.dispose();
    _player = null;
    if (!mounted) return;
    setState(() {
      _phase = _OverlayPhase.idle;
      _elapsedMs = 0;
      _samples.clear();
      _waveGeneration = 0;
      _previewPayload = null;
      _previewLoading = false;
      _previewLoaded = false;
      _playbackProgress = 0.0;
      _playbackPosition = Duration.zero;
      _playbackDuration = Duration.zero;
      _previewDragging = false;
      _previewDragProgress = 0.0;
    });
  }

  Widget _buildQualityBadge(BuildContext context) {
    final notifier = widget.qualityNotifier;
    if (notifier == null) return const SizedBox.shrink();

    return ValueListenableBuilder<VoiceQuality>(
      valueListenable: notifier,
      builder: (context, quality, _) {
        final label = _qualityLabel(context, quality);
        final maxSec = quality.maxRecordingDuration.inSeconds.toString();
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _showQualityPicker(context);
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing10,
              vertical: AppTheme.spacing5,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppTheme.radius20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.tune_rounded, color: Colors.white54, size: 12),
                const SizedBox(width: AppTheme.spacing4),
                Text(
                  '$label · ${context.l10n.voiceQualityDuration(maxSec)}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPreviewButton(BuildContext context) {
    if (_previewLoading) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AccentColors.cyan.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    if (_previewPayload == null) {
      return const SizedBox(height: AppTheme.spacing16);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
      child: ValueListenableBuilder<bool>(
        valueListenable: _player!.isPlaying,
        builder: (context, playing, _) {
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _togglePreviewPlayback();
            },
            behavior: HitTestBehavior.opaque,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.08),
                    border: Border.all(
                      color: AccentColors.cyan.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 28,
                    color: AccentColors.cyan,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing6),
                Text(
                  playing
                      ? context.l10n.voiceMessagePause
                      : context.l10n.voiceRecordingTapToPreview,
                  style: TextStyle(
                    color: AccentColors.cyan.withValues(alpha: 0.7),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _subtitleText(BuildContext context) {
    return switch (_phase) {
      _OverlayPhase.idle => context.l10n.voiceRecordingTapToRecord,
      _OverlayPhase.recording => context.l10n.voiceRecordingMaxSeconds(
        _maxSeconds.toString(),
      ),
      _OverlayPhase.paused => context.l10n.voiceRecordingPaused,
      _OverlayPhase.reviewing => context.l10n.voiceRecordingReadyToSend,
    };
  }

  Widget _buildStatusPill(BuildContext context) {
    return switch (_phase) {
      _OverlayPhase.idle => const SizedBox.shrink(),
      _OverlayPhase.recording => _RecPill(
        pulseController: _pulse,
        color: _recColor,
      ),
      _OverlayPhase.paused => _PausedPill(color: _pausedColor),
      _OverlayPhase.reviewing => const _ReadyPill(),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isActive =
        _phase == _OverlayPhase.recording || _phase == _OverlayPhase.paused;
    final progress = isActive ? (_elapsedMs / _maxMs).clamp(0.0, 1.0) : 0.0;

    return Material(
      color: const Color(0xFF08080E),
      child: SafeArea(
        child: Column(
          children: [
            // ── Top bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing24,
                AppTheme.spacing20,
                AppTheme.spacing24,
                AppTheme.spacing16,
              ),
              child: Row(
                children: [
                  _buildStatusPill(context),
                  const Spacer(),
                  if (_phase == _OverlayPhase.idle ||
                      _phase == _OverlayPhase.recording)
                    _buildQualityBadge(context),
                ],
              ),
            ),

            // ── Hero area ──────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Waveform (hidden in idle)
                    if (_phase != _OverlayPhase.idle)
                      RepaintBoundary(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final waveWidth = constraints.maxWidth;
                            final effectiveProgress = _previewDragging
                                ? _previewDragProgress
                                : _playbackProgress;
                            final waveWidget = SizedBox(
                              height: _waveformHeight,
                              width: double.infinity,
                              child: CustomPaint(
                                painter: _WaveformPainter(
                                  samples: _samples,
                                  generation: _waveGeneration,
                                  color: _phase == _OverlayPhase.paused
                                      ? _pausedColor
                                      : const Color(0xFF00E5FF),
                                  playbackProgress:
                                      _phase == _OverlayPhase.reviewing
                                      ? effectiveProgress
                                      : null,
                                ),
                              ),
                            );
                            if (_phase != _OverlayPhase.reviewing) {
                              return waveWidget;
                            }
                            // In review phase: wrap with drag-to-seek gesture.
                            return GestureDetector(
                              onHorizontalDragStart: (d) =>
                                  _onPreviewDragStart(d, waveWidth),
                              onHorizontalDragUpdate: (d) =>
                                  _onPreviewDragUpdate(d, waveWidth),
                              onHorizontalDragEnd: _onPreviewDragEnd,
                              child: waveWidget,
                            );
                          },
                        ),
                      )
                    else
                      SizedBox(height: _waveformHeight),
                    const SizedBox(height: AppTheme.spacing24),

                    // Preview playback (review only)
                    if (_phase == _OverlayPhase.reviewing)
                      _buildPreviewButton(context),

                    // Elapsed time (recording/paused) or playback position (reviewing)
                    if (_phase == _OverlayPhase.reviewing)
                      _PlaybackTimeDisplay(
                        position: _previewDragging
                            ? Duration(
                                milliseconds:
                                    (_previewDragProgress *
                                            _playbackDuration.inMilliseconds)
                                        .round(),
                              )
                            : _playbackPosition,
                        total: _playbackDuration,
                      )
                    else if (_phase != _OverlayPhase.idle)
                      Text(
                        _formattedTime,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 52,
                          fontWeight: FontWeight.w200,
                          fontFeatures: [FontFeature.tabularFigures()],
                          letterSpacing: 2,
                        ),
                      ),
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      _subtitleText(context),
                      style: TextStyle(
                        color: _phase == _OverlayPhase.paused
                            ? _pausedColor.withValues(alpha: 0.7)
                            : const Color(0x55FFFFFF),
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing32),

                    // Progress track
                    if (isActive)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppTheme.radius4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 2,
                          backgroundColor: Colors.white.withValues(alpha: 0.10),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            _phase == _OverlayPhase.paused
                                ? _pausedColor.withValues(alpha: 0.5)
                                : AccentColors.cyan.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Bottom actions ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing24,
                AppTheme.spacing24,
                AppTheme.spacing24,
                AppTheme.spacing40,
              ),
              child: _buildBottomActions(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return switch (_phase) {
      _OverlayPhase.idle => _buildIdleActions(context),
      _OverlayPhase.recording => _buildRecordingActions(context),
      _OverlayPhase.paused => _buildPausedActions(context),
      _OverlayPhase.reviewing => _buildReviewActions(context),
    };
  }

  /// Large coloured circle button used for Stop (red) and Send (green).
  Widget _buildActionCircle({
    required Color color,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _actionButtonSize,
        height: _actionButtonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: AppTheme.spacing28,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }

  /// Red stop-circle with a white rounded square in the centre.
  Widget _buildStopCircle() {
    return _buildActionCircle(
      color: _recColor,
      onTap: () {
        HapticFeedback.mediumImpact();
        _enterReview();
        widget.onRecordingStopped();
      },
      child: Container(
        width: _stopSquareSize,
        height: _stopSquareSize,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.radius5),
        ),
      ),
    );
  }

  Widget _buildIdleActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _SideActionButton(
          label: context.l10n.voiceRecordingCancelButton,
          color: Colors.white54,
          onTap: _cancelWithConfirmation,
        ),
        // Big red record button with pulsating ring
        _RecordButton(ringController: _ringPulse, onTap: _startRecording),
        const SizedBox(width: _spacerWidth), // spacer to balance layout
      ],
    );
  }

  Widget _buildRecordingActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Pause
        _SideActionButton(
          label: context.l10n.voiceRecordingPauseButton,
          icon: Icons.pause_rounded,
          color: Colors.white70,
          onTap: _pauseRecording,
        ),
        // Stop (red circle with white square)
        _buildStopCircle(),
        // Cancel
        _SideActionButton(
          label: context.l10n.voiceRecordingCancelButton,
          color: const Color(0xFFFF3B30),
          onTap: _cancelWithConfirmation,
        ),
      ],
    );
  }

  Widget _buildPausedActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Resume
        _SideActionButton(
          label: context.l10n.voiceRecordingResumeButton,
          icon: Icons.play_arrow_rounded,
          color: Colors.white70,
          onTap: _resumeRecording,
        ),
        // Done / Stop — same as recording stop
        _buildStopCircle(),
        // Cancel
        _SideActionButton(
          label: context.l10n.voiceRecordingCancelButton,
          color: const Color(0xFFFF3B30),
          onTap: _cancelWithConfirmation,
        ),
      ],
    );
  }

  Widget _buildReviewActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _SideActionButton(
          label: context.l10n.voiceRecordingCancelButton,
          color: const Color(0xFFFF3B30),
          onTap: _cancelWithConfirmation,
        ),
        // Send
        _buildActionCircle(
          color: _sendColor,
          onTap: () {
            HapticFeedback.mediumImpact();
            _player?.stop();
            widget.onSend();
          },
          child: const Icon(
            Icons.arrow_upward_rounded,
            size: AppTheme.spacing40,
            color: Colors.white,
          ),
        ),
        _SideActionButton(
          label: context.l10n.voiceRecordingRetakeButton,
          icon: Icons.refresh_rounded,
          color: Colors.white54,
          onTap: () {
            HapticFeedback.mediumImpact();
            _handleRetake();
          },
        ),
      ],
    );
  }
}

// =============================================================================
// _RecordButton — big red circle with pulsating ring (idle state)
// =============================================================================

class _RecordButton extends StatelessWidget {
  const _RecordButton({required this.ringController, required this.onTap});

  final AnimationController ringController;
  final VoidCallback onTap;

  static const _size = 96.0;
  static const _red = Color(0xFFFF3B30);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: _size + 24,
        height: _size + 24,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Pulsating ring
            AnimatedBuilder(
              animation: ringController,
              builder: (context, _) {
                final scale = 1.0 + ringController.value * 0.15;
                final opacity = (1.0 - ringController.value) * 0.3;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: _size + 8,
                    height: _size + 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _red.withValues(alpha: opacity),
                        width: 3,
                      ),
                    ),
                  ),
                );
              },
            ),
            // Solid circle
            Container(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _red,
                boxShadow: [
                  BoxShadow(
                    color: _red.withValues(alpha: 0.4),
                    blurRadius: 32,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(
                Icons.mic_rounded,
                size: 44,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _ReadyPill — static badge shown in review phase
// =============================================================================

class _ReadyPill extends StatelessWidget {
  const _ReadyPill();

  static const _green = Color(0xFF30D158);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_rounded, color: _green, size: 10),
          const SizedBox(width: AppTheme.spacing6),
          Text(
            context.l10n.voiceRecordingReadyToSend.toUpperCase(),
            style: const TextStyle(
              color: _green,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _PausedPill — amber badge shown when recording is paused
// =============================================================================

class _PausedPill extends StatelessWidget {
  const _PausedPill({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.pause_rounded, color: color, size: 10),
          const SizedBox(width: AppTheme.spacing6),
          Text(
            context.l10n.voiceRecordingPaused,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _SideActionButton — flanking ghost buttons
// =============================================================================

class _SideActionButton extends StatelessWidget {
  const _SideActionButton({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, color: color, size: 22),
              SizedBox(height: AppTheme.spacing4),
            ],
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _RecPill — live recording indicator
// =============================================================================

class _RecPill extends StatelessWidget {
  const _RecPill({required this.pulseController, required this.color});

  final AnimationController pulseController;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: pulseController,
            builder: (context, _) => Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(
                  alpha: 0.55 + pulseController.value * 0.45,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing6),
          Text(
            context.l10n.voiceRecordingLive,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.8,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// _WaveformPainter — scrolling amplitude bars driven directly by mic samples
// =============================================================================

class _WaveformPainter extends CustomPainter {
  const _WaveformPainter({
    required this.samples,
    required this.generation,
    this.color = const Color(0xFF00E5FF),
    this.playbackProgress,
  });

  final List<double> samples;
  final int generation;
  final Color color;

  /// When non-null (0.0–1.0), bars left of this fraction are painted bright
  /// while bars to the right are dimmed, giving a sweep-progress effect.
  final double? playbackProgress;

  static const double _barWidth = 2.5;
  static const double _gap = 1.5;
  static const double _stride = _barWidth + _gap;
  static const double _minFraction = 0.05;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final centerY = size.height / 2;
    final maxHalf = size.height / 2;
    final barCount = (size.width / _stride).floor();
    final progressBar = playbackProgress != null
        ? (playbackProgress! * barCount).round()
        : -1;

    for (var i = 0; i < barCount; i++) {
      final sampleIdx = samples.length - barCount + i;
      final amplitude = (sampleIdx >= 0 && sampleIdx < samples.length)
          ? samples[sampleIdx]
          : 0.0;

      final bool played = progressBar >= 0 && i <= progressBar;
      final double barOpacity;
      if (playbackProgress != null) {
        // During playback: played bars are bright, unplayed bars are dim.
        barOpacity = played ? 0.9 : 0.15;
      } else {
        barOpacity = (0.25 + amplitude * 0.75).clamp(0.0, 1.0);
      }

      paint.color = color.withValues(alpha: barOpacity);
      final half = (_minFraction + amplitude * (1.0 - _minFraction)) * maxHalf;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(i * _stride + _barWidth / 2, centerY),
            width: _barWidth,
            height: half * 2.0,
          ),
          const Radius.circular(1.0),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.generation != generation ||
      old.color != color ||
      old.playbackProgress != playbackProgress;
}

enum _OverlayPhase { idle, recording, paused, reviewing }

// =============================================================================
// _QualityOption — row in the voice quality picker bottom sheet
// =============================================================================

class _QualityOption extends StatelessWidget {
  const _QualityOption({
    required this.quality,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final VoiceQuality quality;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final maxSec = quality.maxRecordingDuration.inSeconds;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected ? AccentColors.cyan : Colors.white38,
              size: 20,
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    '${quality.bitRate} bps · ${context.l10n.voiceQualityDuration(maxSec.toString())}',
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_rounded,
                color: AccentColors.cyan,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Playback time display shown in the reviewing phase
// ---------------------------------------------------------------------------

class _PlaybackTimeDisplay extends StatelessWidget {
  const _PlaybackTimeDisplay({required this.position, required this.total});

  final Duration position;
  final Duration total;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s'; // lint-allow: hardcoded-string
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _fmt(position),
          style: const TextStyle(
            color: AccentColors.cyan,
            fontSize: 36,
            fontWeight: FontWeight.w200,
            fontFeatures: [FontFeature.tabularFigures()],
            letterSpacing: 2,
          ),
        ),
        Text(
          ' / ', // lint-allow: hardcoded-string
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.3),
            fontSize: 24,
            fontWeight: FontWeight.w200,
          ),
        ),
        Text(
          _fmt(total),
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 36,
            fontWeight: FontWeight.w200,
            fontFeatures: [FontFeature.tabularFigures()],
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}
