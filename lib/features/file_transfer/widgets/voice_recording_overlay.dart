// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../services/voice/voice_constants.dart';

/// A fullscreen overlay that is shown while a voice message is being recorded.
///
/// Displays a pulsing waveform icon, the "Recording..." label, a live timer,
/// a progress bar that fills over [VoiceConstants.maxRecordingDuration], and
/// a stop button. When the user taps stop (or the max duration is reached),
/// [onStop] is called so the caller can finalise the recording.
class VoiceRecordingOverlay extends StatefulWidget {
  const VoiceRecordingOverlay({super.key, required this.onStop});

  /// Called when the user taps the stop button to end the recording.
  final VoidCallback onStop;

  @override
  State<VoiceRecordingOverlay> createState() => _VoiceRecordingOverlayState();
}

class _VoiceRecordingOverlayState extends State<VoiceRecordingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  Timer? _timer;
  int _elapsedMs = 0;

  static const _tickMs = 100;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _timer = Timer.periodic(const Duration(milliseconds: _tickMs), (_) {
      if (!mounted) return;
      setState(() => _elapsedMs += _tickMs);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = VoiceConstants.maxRecordingDuration.inMilliseconds;
    final progress = (_elapsedMs / totalMs).clamp(0.0, 1.0);
    final elapsedSec = _elapsedMs ~/ 1000;

    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _pulse,
                child: Icon(Icons.mic, size: 72, color: AccentColors.cyan),
              ),
              const SizedBox(height: AppTheme.spacing20),
              Text(
                context.l10n.voiceMessageRecording,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              Text(
                context.l10n.voiceMessageDuration(elapsedSec),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 24,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: AppTheme.spacing20),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radius4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(AccentColors.cyan),
                ),
              ),
              const SizedBox(height: AppTheme.spacing32),
              // ── Stop button ─────────────────────────────────────────
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  widget.onStop();
                },
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.15),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.stop_rounded,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spacing12),
              Text(
                context.l10n.voiceRecordingTapToStop,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
