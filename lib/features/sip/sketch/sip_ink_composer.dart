// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Sketch-mode composer for SIP DM threads.
///
/// Owns the local stroke buffer (the sketch draft), runs the
/// simplifier on every change so the live point/byte counters reflect
/// what would actually go on the wire, and routes the encoded payload
/// through `SipDmRouter.sendSketch`.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../providers/sip_dm_secure_router.dart';
import '../../../services/haptic_service.dart';
import '../../../services/protocol/sip/sip_dm.dart';
import '../../../services/protocol/sip/sip_ink_constants.dart';
import '../../../services/protocol/sip/sip_ink_encoder.dart';
import '../../../services/protocol/sip/sip_ink_payload.dart';
import '../../../services/protocol/sip/sip_ink_simplifier.dart';
import '../../../utils/snackbar.dart';
import 'sip_ink_canvas.dart';

/// Composer mode body for the sketch tab. Used inside a parent that
/// owns the [Text|Sketch] mode-switcher and stitches this widget in
/// place of the text composer when the user is drawing.
class SipInkComposer extends ConsumerStatefulWidget {
  /// Active SIP DM session this sketch will be sent to.
  final int sessionTag;

  /// Whether the underlying session is in a state that accepts sends.
  final bool enabled;

  /// Hoisted stroke buffer — the parent passes the same list across
  /// rebuilds and across composer-mode toggles so the sketch draft
  /// survives a switch back to the text tab.
  final List<SipInkRawStroke> draft;

  /// Called whenever [draft] is mutated so the parent re-renders.
  final void Function() onDraftChanged;

  /// Called once a sketch has been successfully sent — the parent
  /// usually scrolls to the latest message.
  final VoidCallback onSent;

  const SipInkComposer({
    super.key,
    required this.sessionTag,
    required this.enabled,
    required this.draft,
    required this.onDraftChanged,
    required this.onSent,
  });

  @override
  ConsumerState<SipInkComposer> createState() => _SipInkComposerState();
}

class _SipInkComposerState extends ConsumerState<SipInkComposer>
    with LifecycleSafeMixin {
  static const int _strokeWidth = 2;
  static const int _canvasSize = SipInkConstants.canvas64;

  /// Cached simplifier output for the current draft. Re-computed on
  /// every stroke change.
  SipInkSketch? _simplifiedSketch;

  /// Cached encoded bytes; null when the sketch is empty or didn't
  /// fit the airtime budget at any tolerance.
  Uint8List? _encodedBytes;

  /// True while a send is in progress. Disables further input.
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _resimplify();
  }

  void _resimplify() {
    if (widget.draft.isEmpty) {
      _simplifiedSketch = null;
      _encodedBytes = null;
      return;
    }
    final result = SipInkSimplifier.simplify(
      rawStrokes: widget.draft,
      canvasSize: _canvasSize,
    );
    if (result.isOk) {
      _simplifiedSketch = result.sketch;
      _encodedBytes = SipInkEncoder.encode(result.sketch!).bytes;
    } else {
      _simplifiedSketch = null;
      _encodedBytes = null;
    }
  }

  void _onStrokeFinished(SipInkRawStroke stroke) {
    if (widget.draft.length >= SipInkConstants.maxStrokes) return;
    setState(() {
      widget.draft.add(stroke);
      _resimplify();
    });
    widget.onDraftChanged();
  }

  void _onUndo() {
    if (widget.draft.isEmpty) return;
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    setState(() {
      widget.draft.removeLast();
      _resimplify();
    });
    widget.onDraftChanged();
  }

  void _onClear() {
    if (widget.draft.isEmpty) return;
    ref.read(hapticServiceProvider).trigger(HapticType.medium);
    setState(() {
      widget.draft.clear();
      _resimplify();
    });
    widget.onDraftChanged();
  }

  Future<void> _onSend() async {
    final bytes = _encodedBytes;
    if (bytes == null || _sending) return;

    setState(() => _sending = true);
    AppLogging.sipInk(
      'composer_send_attempt tag=0x${widget.sessionTag.toRadixString(16)} '
      'strokes=${_simplifiedSketch?.strokes.length ?? 0} '
      'points=${_simplifiedSketch?.totalPointCount ?? 0} '
      'bytes=${bytes.length}',
    );

    final outcome = await ref
        .read(sipDmRouterProvider)
        .sendSketch(sessionTag: widget.sessionTag, inkPayload: bytes);

    if (!mounted) return;
    setState(() => _sending = false);

    if (!outcome.isOk) {
      ref.read(hapticServiceProvider).trigger(HapticType.error);
      _showSendError(outcome);
      return;
    }

    ref.read(hapticServiceProvider).trigger(HapticType.light);
    setState(() {
      widget.draft.clear();
      _resimplify();
    });
    widget.onDraftChanged();
    widget.onSent();
  }

  void _showSendError(SipDmRouterOutcome outcome) {
    final l10n = context.l10n;
    if (outcome.inkBlockReason != null) {
      showErrorSnackBar(context, l10n.sipInkUnsupportedPeer);
      return;
    }
    final message = switch (outcome.error) {
      SipDmSendError.budgetExhausted => l10n.sipDmBudgetExhausted,
      SipDmSendError.sessionClosed => l10n.sipDmSessionClosed,
      SipDmSendError.sessionNotFound => l10n.sipDmSessionClosed,
      _ => l10n.sipInkBlocked,
    };
    showErrorSnackBar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasDraft = widget.draft.isNotEmpty;
    final canSend = widget.enabled && _encodedBytes != null && !_sending;
    final pointCount = _simplifiedSketch?.totalPointCount ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            l10n.sipInkComposerHint,
            style: TextStyle(fontSize: 11, color: context.textTertiary),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280, maxHeight: 280),
              child: AspectRatio(
                aspectRatio: 1,
                child: SipInkCanvas(
                  strokes: widget.draft,
                  enabled: widget.enabled && !_sending,
                  strokeWidth: _strokeWidth,
                  canvasSize: _canvasSize,
                  onStrokeFinished: _onStrokeFinished,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      l10n.sipInkPointBudget(
                        pointCount,
                        SipInkConstants.maxTotalPoints,
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textSecondary,
                      ),
                    ),
                    Text(
                      _encodedBytes != null
                          ? l10n.sipInkPayloadBytes(_encodedBytes!.length)
                          : l10n.sipInkPayloadPending,
                      style: TextStyle(
                        fontSize: 11,
                        color: _encodedBytes != null || !hasDraft
                            ? context.textTertiary
                            : Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ),
              ),
              _ToolbarButton(
                icon: Icons.undo,
                tooltip: l10n.sipInkUndo,
                onTap: hasDraft && !_sending ? _onUndo : null,
              ),
              const SizedBox(width: AppTheme.spacing4),
              _ToolbarButton(
                icon: Icons.delete_outline,
                tooltip: l10n.sipInkClear,
                onTap: hasDraft && !_sending ? _onClear : null,
              ),
              const SizedBox(width: AppTheme.spacing8),
              _SendButton(onTap: canSend ? _onSend : null),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _ToolbarButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: isEnabled
            ? () {
                HapticFeedback.lightImpact();
                onTap!();
              }
            : null,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: context.card.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            border: Border.all(color: context.border.withValues(alpha: 0.5)),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isEnabled
                ? context.textPrimary
                : context.textTertiary.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback? onTap;
  const _SendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final enabled = onTap != null;
    return GestureDetector(
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              onTap!();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: enabled ? accent : accent.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.send,
          size: 20,
          color: enabled ? Colors.white : Colors.white.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}
