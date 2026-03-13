// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../services/voice/voice_constants.dart';

/// Full-screen recording overlay with a two-phase flow:
///
/// 1. **Recording** — live waveform, elapsed timer, stop circle.
/// 2. **Reviewing** — frozen waveform, "Send" CTA, after the user taps stop.
///
/// Callbacks:
/// - [onRecordingStopped]: circle tapped — caller should stop the mic/recording.
/// - [onSend]: "Send" tapped in review — caller should encode and send.
/// - [onCancel]: discard with no output.
/// - [onRestart]: discard and begin a fresh recording.
///
/// [autoStopNotifier] can be set to `true` by the caller (e.g. max-duration
/// auto-stop) to transition the overlay from recording → reviewing.
class VoiceRecordingOverlay extends StatefulWidget {
  const VoiceRecordingOverlay({
    super.key,
    required this.onRecordingStopped,
    required this.onSend,
    required this.onCancel,
    required this.onRestart,
    this.amplitudeStream,
    this.autoStopNotifier,
  });

  /// Called when the user taps the stop circle. The caller should stop the
  /// recording device; the overlay transitions to reviewing automatically.
  final VoidCallback onRecordingStopped;

  /// Called when the user confirms "Send" in the review phase.
  final VoidCallback onSend;

  /// Discard: cancel the recording with no output.
  final VoidCallback onCancel;

  /// Retake: cancels the current session and restarts a fresh recording.
  /// The callback should cancel/dispose the old session, start a new one,
  /// and return the new amplitude stream (or null if start failed).
  final Future<Stream<double>?> Function() onRestart;

  /// Live normalised amplitude stream (0.0 = silence, 1.0 = full scale).
  final Stream<double>? amplitudeStream;

  /// When set to `true` by the caller (e.g. auto-stop on max duration), the
  /// overlay transitions from recording to reviewing mode automatically.
  final ValueNotifier<bool>? autoStopNotifier;

  @override
  State<VoiceRecordingOverlay> createState() => _VoiceRecordingOverlayState();
}

class _VoiceRecordingOverlayState extends State<VoiceRecordingOverlay>
    with SingleTickerProviderStateMixin {
  // ── REC dot pulse ─────────────────────────────────────────────────────────
  late final AnimationController _pulse;

  // ── phase ─────────────────────────────────────────────────────────────────
  _OverlayPhase _phase = _OverlayPhase.recording;

  // ── timer ─────────────────────────────────────────────────────────────────
  Timer? _timer;
  int _elapsedMs = 0;
  static const _tickMs = 100;

  // ── waveform samples ──────────────────────────────────────────────────────
  final _samples = <double>[];
  int _waveGeneration = 0;
  StreamSubscription<double>? _amplitudeSub;

  static final double _maxMs = VoiceConstants
      .maxRecordingDuration
      .inMilliseconds
      .toDouble();

  static const _recColor = Color(0xFFFF3B30); // iOS system red — "live" energy

  @override
  void initState() {
    super.initState();

    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (_) {
      if (!mounted) return;
      setState(() => _elapsedMs += _tickMs);
    });

    _amplitudeSub = widget.amplitudeStream?.listen(_onAmplitude);
    widget.autoStopNotifier?.addListener(_onAutoStopNotified);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _amplitudeSub?.cancel();
    widget.autoStopNotifier?.removeListener(_onAutoStopNotified);
    super.dispose();
  }

  void _onAutoStopNotified() {
    if (!mounted) return;
    if (widget.autoStopNotifier?.value == true) _enterReview();
  }

  Future<void> _handleRetake() async {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _timer?.cancel();
    _timer = null;
    setState(() {
      _phase = _OverlayPhase.recording;
      _elapsedMs = 0;
      _samples.clear();
      _waveGeneration = 0;
    });
    final stream = await widget.onRestart();
    if (!mounted) return;
    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (_) {
      if (!mounted) return;
      setState(() => _elapsedMs += _tickMs);
    });
    _amplitudeSub = stream?.listen(_onAmplitude);
  }

  void _enterReview() {
    _amplitudeSub?.cancel();
    _amplitudeSub = null;
    _timer?.cancel();
    _timer = null;
    setState(() => _phase = _OverlayPhase.reviewing);
  }

  void _onAmplitude(double level) {
    if (!mounted) return;
    // Only accumulate during recording; waveform freezes in review phase.
    if (_phase != _OverlayPhase.recording) return;
    setState(() {
      _samples.add(level);
      _waveGeneration++;
    });
  }

  String get _formattedTime {
    final totalSec = _elapsedMs ~/ 1000;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  int get _maxSeconds => VoiceConstants.maxRecordingDuration.inSeconds;

  @override
  Widget build(BuildContext context) {
    final progress = (_elapsedMs / _maxMs).clamp(0.0, 1.0);

    return Material(
      color: const Color(0xFF08080E),
      child: SafeArea(
        child: Column(
          children: [
            // ── Top bar: REC / READY badge ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing24,
                AppTheme.spacing20,
                AppTheme.spacing24,
                AppTheme.spacing16,
              ),
              child: Row(
                children: [
                  if (_phase == _OverlayPhase.recording)
                    _RecPill(pulseController: _pulse, color: _recColor)
                  else
                    _ReadyPill(),
                  const Spacer(),
                ],
              ),
            ),

            // ── Hero area ─────────────────────────────────────────────────
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Live scrolling waveform — each bar is a real amplitude sample.
                    RepaintBoundary(
                      child: SizedBox(
                        height: 120,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _WaveformPainter(
                            samples: _samples,
                            generation: _waveGeneration,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing24),

                    // Elapsed time — large tabular numerals
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
                      _phase == _OverlayPhase.recording
                          ? context.l10n.voiceRecordingMaxSeconds(
                              _maxSeconds.toString(),
                            )
                          : context.l10n.voiceRecordingReadyToSend,
                      style: const TextStyle(
                        color: Color(0x55FFFFFF),
                        fontSize: 13,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing32),

                    // Time-remaining track
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppTheme.radius4),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 2,
                        backgroundColor: Colors.white.withValues(alpha: 0.10),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AccentColors.cyan.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Bottom actions: Cancel | [Stop / Send] | Retake ──────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing24,
                AppTheme.spacing24,
                AppTheme.spacing24,
                AppTheme.spacing40,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Cancel — destructive ghost
                  _SideActionButton(
                    label: context.l10n.voiceRecordingCancelButton,
                    color: const Color(0xFFFF3B30),
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onCancel();
                    },
                  ),

                  // Centre CTA: Stop (recording) / Send (reviewing)
                  if (_phase == _OverlayPhase.recording)
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _enterReview();
                        widget.onRecordingStopped();
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AccentColors.cyan,
                          boxShadow: [
                            BoxShadow(
                              color: AccentColors.cyan.withValues(alpha: 0.35),
                              blurRadius: 28,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.stop_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        widget.onSend();
                      },
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF30D158),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF30D158,
                              ).withValues(alpha: 0.35),
                              blurRadius: 28,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          size: 40,
                          color: Colors.white,
                        ),
                      ),
                    ),

                  // Retake — discard and restart
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
// _SideActionButton — flanking ghost buttons (Cancel / Retake)
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
  const _WaveformPainter({required this.samples, required this.generation});

  final List<double> samples;
  final int generation;

  static const double _barWidth = 2.5;
  static const double _gap = 1.5;
  static const double _stride = _barWidth + _gap;

  // 5% floor — silence shows as a short stub, not an invisible dot.
  static const double _minFraction = 0.05;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    final centerY = size.height / 2;
    final maxHalf = size.height / 2;
    final barCount = (size.width / _stride).floor();

    for (var i = 0; i < barCount; i++) {
      final sampleIdx = samples.length - barCount + i;
      final amplitude = (sampleIdx >= 0 && sampleIdx < samples.length)
          ? samples[sampleIdx]
          : 0.0;
      // Dim quiet bars; loud bars are fully opaque — matches iOS Voice Memos.
      final opacity = (0.25 + amplitude * 0.75).clamp(0.0, 1.0);
      paint.color = const Color(0xFF00E5FF).withValues(alpha: opacity);
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
  bool shouldRepaint(_WaveformPainter old) => old.generation != generation;
}

enum _OverlayPhase { recording, reviewing }
