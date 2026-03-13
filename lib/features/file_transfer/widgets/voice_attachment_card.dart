// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../services/haptic_service.dart';
import '../../../services/voice/voice_constants.dart';
import '../../../services/voice/voice_player.dart';
import '../../../services/voice/waveform_analysis.dart';
import 'waveform_painter.dart';

/// Premium, waveform-driven voice attachment card.
///
/// Replaces the old tiny [VoiceMessagePlayer] row with a rich media object
/// showing: header label + timestamp, real-amplitude waveform, play/pause
/// control, elapsed/total time, progress scrubbing, and a metadata row.
///
/// Architecture:
/// ```
/// VoiceAttachmentCard (ConsumerStatefulWidget + LifecycleSafeMixin)
///   └─ _player:  VoicePlayer (manages just_audio lifecycle)
///   └─ _analysis: WaveformAnalysis (from WaveformAnalyser, in-memory cached)
///   └─ _shimmer: AnimationController (skeleton while analysing)
///   └─ _positionSub: StreamSubscription<Duration> (player position)
/// ```
class VoiceAttachmentCard extends ConsumerStatefulWidget {
  const VoiceAttachmentCard({
    super.key,
    required this.c2Payload,
    required this.cacheKey,
    this.filename,
    this.receivedAt,
    this.totalBytes,
  });

  final Uint8List c2Payload;

  /// Stable cache key used for waveform analysis memoisation.
  /// Should be a unique identifier like `"${transferId}"` or
  /// `"${filename}_${payload.length}"`.
  final String cacheKey;

  final String? filename;
  final DateTime? receivedAt;
  final int? totalBytes;

  @override
  ConsumerState<VoiceAttachmentCard> createState() =>
      _VoiceAttachmentCardState();
}

class _VoiceAttachmentCardState extends ConsumerState<VoiceAttachmentCard>
    with LifecycleSafeMixin<VoiceAttachmentCard>, TickerProviderStateMixin {
  // --- Playback ---------------------------------------------------------
  late final VoicePlayer _player;
  StreamSubscription<Duration>? _positionSub;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _failed = false;

  // --- Waveform analysis ------------------------------------------------
  WaveformAnalysis? _analysis;
  bool _analysing = true;

  // --- Shimmer animation ------------------------------------------------
  late final AnimationController _shimmer;

  // --- Drag state (seek) ------------------------------------------------
  bool _dragging = false;
  double _dragProgress = 0;

  // --- Header metrics ---------------------------------------------------
  late final int _frameCount;
  late final int _durationMs;

  @override
  void initState() {
    super.initState();
    _player = VoicePlayer();

    // Parse frame count from header — fast, no decode needed.
    if (widget.c2Payload.length >= 4 &&
        widget.c2Payload[0] == VoiceConstants.magicByte) {
      _frameCount = widget.c2Payload[2] | (widget.c2Payload[3] << 8);
      _durationMs =
          _frameCount *
          VoiceConstants.samplesPerFrame *
          1000 ~/
          VoiceConstants.sampleRate;
      _duration = Duration(milliseconds: _durationMs);
    } else {
      _frameCount = 0;
      _durationMs = 0;
    }

    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // Subscribe to position updates.
    _positionSub = _player.positionStream.listen((pos) {
      if (!_dragging) {
        safeSetState(() => _position = pos);
      }
    });

    _analyse();
  }

  Future<void> _analyse() async {
    final analysis = await WaveformAnalyser.analyse(
      widget.c2Payload,
      cacheKey: widget.cacheKey,
    );
    safeSetState(() {
      _analysis = analysis;
      _analysing = false;
    });
  }

  Future<void> _togglePlayback() async {
    final haptics = ref.haptics;
    haptics.buttonTap();
    if (_player.isPlaying.value) {
      await _player.stop();
      safeSetState(() {});
    } else {
      safeSetState(() {
        _failed = false;
        _position = Duration.zero;
      });
      final ok = await _player.playC2(widget.c2Payload);
      if (!ok) {
        safeSetState(() => _failed = true);
      }
    }
  }

  void _onDragStart(double relativeX, double width) {
    ref.haptics.sliderTick();
    setState(() {
      _dragging = true;
      _dragProgress = (relativeX / width).clamp(0.0, 1.0);
    });
  }

  void _onDragUpdate(double relativeX, double width) {
    setState(() {
      _dragProgress = (relativeX / width).clamp(0.0, 1.0);
    });
  }

  Future<void> _onDragEnd() async {
    final target = Duration(
      milliseconds: (_dragProgress * _duration.inMilliseconds).round(),
    );
    await _player.seekTo(target);
    safeSetState(() {
      _position = target;
      _dragging = false;
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _shimmer.dispose();
    _player.isPlaying.removeListener(_onPlayingChanged);
    _player.dispose();
    super.dispose();
  }

  void _onPlayingChanged() => safeSetState(() {});

  // --- Formatting -------------------------------------------------------

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s'; // lint-allow: hardcoded-string
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B'; // lint-allow: hardcoded-string
    final kb = bytes / 1024.0;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB'; // lint-allow: hardcoded-string
    }
    return '${(kb / 1024).toStringAsFixed(1)} MB'; // lint-allow: hardcoded-string
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _player.isPlaying.addListener(_onPlayingChanged);
  }

  // --- Build ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool playing = _player.isPlaying.value;
    final double progress = _dragging
        ? _dragProgress
        : (_duration.inMilliseconds > 0
              ? (_position.inMilliseconds / _duration.inMilliseconds).clamp(
                  0.0,
                  1.0,
                )
              : 0.0);

    final accent = context.accentColor;
    final cardBg = context.card;
    final textSecondary = context.textSecondary;
    final textTertiary = context.textTertiary;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(
          color: playing
              ? accent.withValues(alpha: 0.35)
              : context.border.withValues(alpha: 0.4),
          width: 1,
        ),
        boxShadow: playing
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.12),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- Header ---
          _CardHeader(
            label: context.l10n.voiceAttachmentCardTitle,
            receivedAt: widget.receivedAt,
            isPlaying: playing,
            accent: accent,
            textSecondary: textSecondary,
            textTertiary: textTertiary,
          ),
          const SizedBox(height: AppTheme.spacing12),

          // --- Controls + Waveform row ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Play/Pause button
              GestureDetector(
                onTap: _failed ? null : _togglePlayback,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _failed
                        ? SemanticColors.error.withValues(alpha: 0.15)
                        : playing
                        ? accent
                        : accent.withValues(alpha: 0.15),
                  ),
                  child: Icon(
                    _failed
                        ? Icons.error_outline
                        : playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: _failed
                        ? SemanticColors.error
                        : playing
                        ? SemanticColors.onAccent
                        : accent,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),

              // Waveform + time
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Waveform
                    SizedBox(
                      height: 40,
                      child: _WaveformWidget(
                        analysis: _analysis,
                        analysing: _analysing,
                        progress: progress,
                        shimmer: _shimmer,
                        accent: accent,
                        onDragStart: _onDragStart,
                        onDragUpdate: _onDragUpdate,
                        onDragEnd: _onDragEnd,
                        failed: _failed,
                        textTertiary: textTertiary,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing4),

                    // Time row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(
                            _dragging
                                ? Duration(
                                    milliseconds:
                                        (_dragProgress *
                                                _duration.inMilliseconds)
                                            .round(),
                                  )
                                : _position,
                          ),
                          style: TextStyle(
                            color: playing ? accent : textSecondary,
                            fontSize: 11,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: TextStyle(
                            color: textTertiary,
                            fontSize: 11,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // --- Error label ---
          if (_failed) ...[
            const SizedBox(height: AppTheme.spacing8),
            Text(
              context.l10n.voiceAttachmentPlaybackFailed,
              style: TextStyle(color: SemanticColors.error, fontSize: 12),
            ),
          ],

          const SizedBox(height: AppTheme.spacing12),
          const Divider(height: 1, thickness: 0.5),
          const SizedBox(height: AppTheme.spacing8),

          // --- Metadata row ---
          _MetadataRow(
            totalBytes: widget.totalBytes ?? widget.c2Payload.length,
            formatBytes: _formatBytes,
            analysis: _analysis,
            textTertiary: textTertiary,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card header
// ---------------------------------------------------------------------------

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.label,
    required this.receivedAt,
    required this.isPlaying,
    required this.accent,
    required this.textSecondary,
    required this.textTertiary,
  });

  final String label;
  final DateTime? receivedAt;
  final bool isPlaying;
  final Color accent;
  final Color textSecondary;
  final Color textTertiary;

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(
      2,
      '0',
    ); // lint-allow: hardcoded-string
    final m = dt.minute.toString().padLeft(
      2,
      '0',
    ); // lint-allow: hardcoded-string
    return '$h:$m'; // lint-allow: hardcoded-string
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isPlaying ? accent : SemanticColors.muted,
          ),
        ),
        const SizedBox(width: AppTheme.spacing8),
        Text(
          label,
          style: TextStyle(
            color: textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const Spacer(),
        if (receivedAt != null)
          Text(
            _formatTime(receivedAt!),
            style: TextStyle(
              color: textTertiary,
              fontSize: 11,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Waveform widget (interactive)
// ---------------------------------------------------------------------------

class _WaveformWidget extends StatelessWidget {
  const _WaveformWidget({
    required this.analysis,
    required this.analysing,
    required this.progress,
    required this.shimmer,
    required this.accent,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.failed,
    required this.textTertiary,
  });

  final WaveformAnalysis? analysis;
  final bool analysing;
  final double progress;
  final AnimationController shimmer;
  final Color accent;
  final void Function(double relX, double width) onDragStart;
  final void Function(double relX, double width) onDragUpdate;
  final Future<void> Function() onDragEnd;
  final bool failed;
  final Color textTertiary;

  @override
  Widget build(BuildContext context) {
    if (failed) {
      return Center(
        child: Text(
          '— — —', // lint-allow: hardcoded-string
          style: TextStyle(color: SemanticColors.error, fontSize: 13),
        ),
      );
    }

    if (analysing || analysis == null) {
      return AnimatedBuilder(
        animation: shimmer,
        builder: (context, child) => CustomPaint(
          painter: WaveformSkeletonPainter(
            shimmerProgress: shimmer.value,
            baseColor: SemanticColors.placeholder,
            highlightColor: textTertiary.withValues(alpha: 0.6),
            borderRadius: AppTheme.radius2,
          ),
          child: const SizedBox.expand(),
        ),
      );
    }

    final peaks = analysis!.peaks;

    return GestureDetector(
      onHorizontalDragStart: (d) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        onDragStart(d.localPosition.dx, box.size.width);
      },
      onHorizontalDragUpdate: (d) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        onDragUpdate(d.localPosition.dx, box.size.width);
      },
      onHorizontalDragEnd: (_) => onDragEnd(),
      onTapDown: (d) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        onDragStart(d.localPosition.dx, box.size.width);
      },
      onTapUp: (_) => onDragEnd(),
      child: CustomPaint(
        painter: WaveformPainter(
          peaks: peaks,
          progress: progress,
          playedColor: accent,
          unplayedColor: textTertiary.withValues(alpha: 0.35),
          borderRadius: AppTheme.radius2,
          playheadColor: accent,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metadata row
// ---------------------------------------------------------------------------

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({
    required this.totalBytes,
    required this.formatBytes,
    required this.analysis,
    required this.textTertiary,
  });

  final int totalBytes;
  final String Function(int) formatBytes;
  final WaveformAnalysis? analysis;
  final Color textTertiary;

  @override
  Widget build(BuildContext context) {
    final chips = <String>[];

    chips.add(formatBytes(totalBytes));
    chips.add(VoiceConstants.mimeType);

    if (analysis != null) {
      chips.add(
        '${analysis!.sampleRate ~/ 1000} kHz',
      ); // lint-allow: hardcoded-string
      chips.add(context.l10n.voiceAttachmentMono);
    } else {
      chips.add(
        '${VoiceConstants.sampleRate ~/ 1000} kHz',
      ); // lint-allow: hardcoded-string
    }

    // Bitrate: (bytesPerFrame * 8 bits) / (samplesPerFrame / sampleRate seconds)
    // = 6*8 / (320/8000) = 48 / 0.04 = 1200 bps
    chips.add('1200 bps'); // lint-allow: hardcoded-string

    return Wrap(
      spacing: AppTheme.spacing8,
      runSpacing: AppTheme.spacing4,
      children: chips
          .map(
            (c) => Text(
              c,
              style: TextStyle(
                color: textTertiary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          )
          .toList(),
    );
  }
}
