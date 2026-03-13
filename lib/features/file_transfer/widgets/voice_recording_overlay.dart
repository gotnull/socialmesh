// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../services/voice/voice_constants.dart';
import 'live_waveform_painter.dart';

// Number of amplitude samples in the rolling buffer (50 ms intervals → 50 = 2.5 s).
const int _kBufferSize = 50;

/// Full-screen premium recording overlay shown while a voice message is captured.
///
/// Displays a live waveform driven by [amplitudeStream], an elapsed timer,
/// and a stop button. When the user taps stop (or the max duration fires),
/// [onStop] is called so the caller can finalise the recording.
class VoiceRecordingOverlay extends StatefulWidget {
  const VoiceRecordingOverlay({
    super.key,
    required this.onStop,
    this.amplitudeStream,
  });

  /// Called when the user taps the stop button to end the recording.
  final VoidCallback onStop;

  /// Live normalised amplitude stream (0.0 = silence, 1.0 = full scale).
  /// If null the waveform shows a flat idle animation.
  final Stream<double>? amplitudeStream;

  @override
  State<VoiceRecordingOverlay> createState() => _VoiceRecordingOverlayState();
}

class _VoiceRecordingOverlayState extends State<VoiceRecordingOverlay>
    with SingleTickerProviderStateMixin {
  // ── pulse for the REC dot ─────────────────────────────────────────────────
  late final AnimationController _pulse;

  // ── timer ─────────────────────────────────────────────────────────────────
  Timer? _timer;
  int _elapsedMs = 0;
  static const _tickMs = 100;

  // ── waveform buffer ───────────────────────────────────────────────────────
  // Kept as a ValueNotifier so only the CustomPaint rebuilds on each sample,
  // not the whole overlay widget tree.
  final _waveBuffer = ValueNotifier<List<double>>(
    List<double>.filled(_kBufferSize, 0.0),
  );
  StreamSubscription<double>? _amplitudeSub;
  double _lastSmoothed = 0.0;

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
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    _amplitudeSub?.cancel();
    _waveBuffer.dispose();
    super.dispose();
  }

  void _onAmplitude(double level) {
    if (!mounted) return;
    // Exponential smoothing: retains 60 % of the previous value so fast
    // transients are softened while speech onset is still clearly visible.
    _lastSmoothed = _lastSmoothed * 0.60 + level * 0.40;
    final next = List<double>.of(_waveBuffer.value);
    next.removeAt(0);
    next.add(_lastSmoothed);
    _waveBuffer.value = next;
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
            // ── Top bar: REC indicator ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing24,
                AppTheme.spacing20,
                AppTheme.spacing24,
                AppTheme.spacing16,
              ),
              child: Row(
                children: [
                  _RecPill(pulseController: _pulse, color: _recColor),
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
                    // Live waveform
                    RepaintBoundary(
                      child: ValueListenableBuilder<List<double>>(
                        valueListenable: _waveBuffer,
                        builder: (context, buffer, _) {
                          return SizedBox(
                            height: 120,
                            child: CustomPaint(
                              size: const Size(double.infinity, 120),
                              painter: LiveWaveformPainter(
                                amplitudes: buffer,
                                color: AccentColors.cyan,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing40),

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
                      context.l10n.voiceRecordingMaxSeconds(
                        _maxSeconds.toString(),
                      ),
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

            // ── Stop button ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing24,
                AppTheme.spacing32,
                AppTheme.spacing24,
                AppTheme.spacing40,
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      widget.onStop();
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
                            spreadRadius: 0,
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
                  ),
                  const SizedBox(height: AppTheme.spacing14),
                  Text(
                    context.l10n.voiceRecordingTapToStop,
                    style: const TextStyle(
                      color: Color(0x55FFFFFF),
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
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
