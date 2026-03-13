// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../services/voice/voice_player.dart';

/// Inline widget that plays a Codec2 voice message from raw `.c2` payload bytes.
///
/// Shows a play/stop toggle with a duration label. Manages its own [VoicePlayer]
/// lifecycle — the player is disposed when the widget is removed from the tree.
class VoiceMessagePlayer extends StatefulWidget {
  const VoiceMessagePlayer({super.key, required this.c2Payload});

  final Uint8List c2Payload;

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  late final VoicePlayer _player;
  int? _durationSec;

  @override
  void initState() {
    super.initState();
    _player = VoicePlayer();
    _player.isPlaying.addListener(_onPlayingChanged);
    _computeDuration();
  }

  void _onPlayingChanged() {
    if (mounted) setState(() {});
  }

  void _computeDuration() {
    // Estimate duration from `.c2` frame count without full decode.
    // Header bytes: [0xC2, mode, frameLow, frameHigh], 6 bytes per frame.
    if (widget.c2Payload.length < 4) return;
    if (widget.c2Payload[0] != 0xC2) return;
    final frames = widget.c2Payload[2] | (widget.c2Payload[3] << 8);
    // 320 samples per frame @ 8000 Hz → 40 ms/frame.
    final ms = frames * 40;
    setState(() => _durationSec = (ms / 1000).ceil());
  }

  Future<void> _toggle() async {
    if (_player.isPlaying.value) {
      await _player.stop();
    } else {
      await _player.playC2(widget.c2Payload);
    }
  }

  @override
  void dispose() {
    _player.isPlaying.removeListener(_onPlayingChanged);
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _player.isPlaying.value;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _toggle,
          tooltip: playing
              ? context.l10n.voiceMessageStop
              : context.l10n.voiceMessagePlay,
          icon: Icon(
            playing ? Icons.stop_circle_outlined : Icons.play_circle_outline,
            color: AccentColors.cyan,
            size: 32,
          ),
        ),
        if (_durationSec != null)
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(
              context.l10n.voiceMessageDuration(_durationSec!),
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 13,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
      ],
    );
  }
}
