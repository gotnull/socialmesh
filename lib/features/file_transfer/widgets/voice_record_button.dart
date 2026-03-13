// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';

/// A press-and-hold "Push To Talk" button for recording a voice message.
///
/// [onRecordStart] is called when the user presses and holds.
/// [onRecordEnd] is called when the user lifts the finger, signalling
/// that the recording should be stopped and the result processed.
/// [onCancel] is called when the user drags away from the button to discard.
class VoiceRecordButton extends StatefulWidget {
  const VoiceRecordButton({
    super.key,
    required this.onRecordStart,
    required this.onRecordEnd,
    required this.onCancel,
  });

  final VoidCallback onRecordStart;
  final VoidCallback onRecordEnd;
  final VoidCallback onCancel;

  @override
  State<VoiceRecordButton> createState() => _VoiceRecordButtonState();
}

class _VoiceRecordButtonState extends State<VoiceRecordButton> {
  bool _pressed = false;
  bool _draggingAway = false;

  // Threshold in logical pixels to detect "slide to cancel" gesture.
  static const double _cancelThreshold = 60.0;

  void _onPanStart(DragStartDetails _) {
    if (!_pressed) {
      setState(() {
        _pressed = true;
        _draggingAway = false;
      });
      widget.onRecordStart();
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_pressed && !_draggingAway) {
      final dx = details.localPosition.dx;
      if (dx.abs() > _cancelThreshold ||
          details.localPosition.dy < -_cancelThreshold) {
        setState(() => _draggingAway = true);
      }
    }
  }

  void _onPanEnd(DragEndDetails _) {
    if (!_pressed) return;
    setState(() => _pressed = false);
    if (_draggingAway) {
      setState(() => _draggingAway = false);
      widget.onCancel();
    } else {
      widget.onRecordEnd();
    }
  }

  void _onPanCancel() {
    if (!_pressed) return;
    setState(() {
      _pressed = false;
      _draggingAway = false;
    });
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final active = _pressed && !_draggingAway;

    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      onPanCancel: _onPanCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        height: 48,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          color: active
              ? AccentColors.cyan.withValues(alpha: 0.25)
              : AppTheme.primaryBlue.withValues(alpha: 0.12),
          border: Border.all(
            color: active ? AccentColors.cyan : AppTheme.primaryBlue,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              active ? Icons.mic : Icons.mic_none,
              size: 18,
              color: active ? AccentColors.cyan : AppTheme.primaryBlue,
            ),
            const SizedBox(width: 6),
            Text(
              _draggingAway
                  ? context.l10n.voiceMessageRecordingHint
                  : context.l10n.fileTransferContactsSendVoice,
              style: TextStyle(
                color: active ? AccentColors.cyan : AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
