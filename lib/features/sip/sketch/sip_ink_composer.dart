// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Sketch-mode composer for SIP DM threads.
///
/// Owns the local stroke buffer (the sketch draft) and the in-progress
/// active stroke. On every gesture tick, runs the simplifier to find
/// the largest prefix of the active stroke that still fits the
/// airtime budget — anything past that point is the "overflow" tail
/// rendered as a dashed red cue and discarded on stroke end.
///
/// Counters reflect the committed (sendable) state. Crossing into
/// overflow triggers a single medium-impact haptic and turns the
/// counters / canvas border red, then reverts when the user lifts and
/// the overflow tail is dropped.
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

  /// Raw float points of the in-progress stroke.
  List<({double x, double y})> _activeRaw = const [];

  /// Index of the last point in [_activeRaw] that still fits the
  /// budget. -1 means "no committed prefix yet".
  int _committedBoundary = -1;

  /// Set on the first overflow event of a stroke so the haptic only
  /// fires once per stroke.
  bool _overflowHapticFiredThisStroke = false;

  /// Cached simplifier output for whatever is currently committed
  /// (completed strokes + active prefix up to [_committedBoundary]).
  SipInkSketch? _simplifiedSketch;
  Uint8List? _encodedBytes;

  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _resimplifyCommitted();
  }

  // ---------------------------------------------------------------
  // Simplifier evaluation
  // ---------------------------------------------------------------

  /// Re-run the simplifier on whatever is currently committed.
  /// Drives the live byte/point counters between strokes.
  void _resimplifyCommitted() {
    final committedStrokes = _committedRawStrokes();
    if (committedStrokes.isEmpty) {
      _simplifiedSketch = null;
      _encodedBytes = null;
      return;
    }
    final result = SipInkSimplifier.simplify(
      rawStrokes: committedStrokes,
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

  /// Build the raw stroke list that's currently committed: the
  /// finalised draft plus the active stroke's committed prefix (when
  /// it has at least 2 points).
  List<SipInkRawStroke> _committedRawStrokes() {
    final committedActiveLen = _committedBoundary + 1;
    if (committedActiveLen < SipInkConstants.minPointsPerStroke) {
      return widget.draft;
    }
    return [
      ...widget.draft,
      SipInkRawStroke(
        width: _strokeWidth,
        points: _activeRaw.sublist(0, committedActiveLen),
      ),
    ];
  }

  /// Try to extend the committed prefix to include all of [_activeRaw].
  /// Updates [_committedBoundary] and the cached simplified state.
  ///
  /// Only `budgetExceeded` / `tooManyStrokes` keep the boundary
  /// pinned — those are the real overflow cases. Every other path
  /// (candidate accepted, candidate dropped as too-short, or `empty`
  /// because nothing survived the gesture-start window) advances the
  /// boundary so [_isOverBudget] does not false-positive on the first
  /// point of a fresh stroke.
  void _evaluateActiveStroke() {
    final candidate = SipInkRawStroke(width: _strokeWidth, points: _activeRaw);
    final fullResult = SipInkSimplifier.simplify(
      rawStrokes: [...widget.draft, candidate],
      canvasSize: _canvasSize,
    );

    final error = fullResult.error;
    final isRealOverflow =
        error == SipInkSimplifyError.budgetExceeded ||
        error == SipInkSimplifyError.tooManyStrokes;

    if (isRealOverflow) {
      if (!_overflowHapticFiredThisStroke) {
        _overflowHapticFiredThisStroke = true;
        HapticFeedback.mediumImpact();
        AppLogging.sipInk(
          'overflow_started raw_points=${_activeRaw.length} '
          'committed_boundary=$_committedBoundary error=${error?.name}',
        );
      }
      _resimplifyCommitted();
      return;
    }

    // Every active point fits the budget — advance the boundary even
    // if the simplifier dropped the candidate as degenerate (`empty`
    // error on a fresh sketch, or sub-`minPointsPerStroke` candidate).
    _committedBoundary = _activeRaw.length - 1;
    if (fullResult.isOk) {
      _simplifiedSketch = fullResult.sketch;
      _encodedBytes = SipInkEncoder.encode(fullResult.sketch!).bytes;
    } else {
      _resimplifyCommitted();
    }
  }

  // ---------------------------------------------------------------
  // Stroke gesture handlers (called by SipInkCanvas)
  // ---------------------------------------------------------------

  void _onStrokeStart(({double x, double y}) p) {
    if (widget.draft.length >= SipInkConstants.maxStrokes) {
      // Already at max strokes — gesture is consumed but produces no
      // committed output. Visualise immediately as overflow.
      setState(() {
        _activeRaw = [p];
        _committedBoundary = -1;
        _overflowHapticFiredThisStroke = true;
        HapticFeedback.mediumImpact();
      });
      return;
    }
    setState(() {
      _activeRaw = [p];
      _committedBoundary = -1;
      _overflowHapticFiredThisStroke = false;
      _evaluateActiveStroke();
    });
  }

  void _onStrokeUpdate(({double x, double y}) p) {
    if (_activeRaw.isEmpty) return;
    if (widget.draft.length >= SipInkConstants.maxStrokes) {
      setState(() {
        _activeRaw = [..._activeRaw, p];
      });
      return;
    }
    setState(() {
      _activeRaw = [..._activeRaw, p];
      _evaluateActiveStroke();
    });
  }

  void _onStrokeEnd() {
    setState(() {
      // Single-tap dot: only one raw point was captured. Synthesize a
      // 1-pixel companion so the simplifier (which requires
      // [SipInkConstants.minPointsPerStroke]) keeps it as a 2-point
      // stroke. The painter draws a 2-point near-zero-length line as
      // a small dot via its rounded stroke caps.
      if (_activeRaw.length == 1 &&
          widget.draft.length < SipInkConstants.maxStrokes) {
        final p = _activeRaw.first;
        final canvasMax = (_canvasSize - 1).toDouble();
        final companion = (x: p.x + 1 <= canvasMax ? p.x + 1 : p.x - 1, y: p.y);
        _activeRaw = [..._activeRaw, companion];
        _evaluateActiveStroke();
      }
      final commitLen = _committedBoundary + 1;
      if (commitLen >= SipInkConstants.minPointsPerStroke &&
          widget.draft.length < SipInkConstants.maxStrokes) {
        widget.draft.add(
          SipInkRawStroke(
            width: _strokeWidth,
            points: List.of(_activeRaw.sublist(0, commitLen)),
          ),
        );
      }
      _activeRaw = const [];
      _committedBoundary = -1;
      _overflowHapticFiredThisStroke = false;
      _resimplifyCommitted();
    });
    widget.onDraftChanged();
  }

  // ---------------------------------------------------------------
  // Toolbar handlers
  // ---------------------------------------------------------------

  void _onUndo() {
    if (widget.draft.isEmpty) return;
    ref.read(hapticServiceProvider).trigger(HapticType.light);
    setState(() {
      widget.draft.removeLast();
      _resimplifyCommitted();
    });
    widget.onDraftChanged();
  }

  void _onClear() {
    if (widget.draft.isEmpty && _activeRaw.isEmpty) return;
    ref.read(hapticServiceProvider).trigger(HapticType.medium);
    setState(() {
      widget.draft.clear();
      _activeRaw = const [];
      _committedBoundary = -1;
      _overflowHapticFiredThisStroke = false;
      _resimplifyCommitted();
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
      _activeRaw = const [];
      _committedBoundary = -1;
      _overflowHapticFiredThisStroke = false;
      _resimplifyCommitted();
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
      // T+S: same mapping as text DM — sketch-specific text would
      // confuse users who muted/blocked once and now hit the same
      // gate here.
      SipDmSendError.peerBlocked => l10n.sipDmPeerBlocked,
      SipDmSendError.peerRateLimited => l10n.sipDmPeerRateLimited,
      SipDmSendError.budgetExhausted => l10n.sipDmBudgetExhausted,
      SipDmSendError.sessionClosed => l10n.sipDmSessionClosed,
      SipDmSendError.sessionNotFound => l10n.sipDmSessionClosed,
      _ => l10n.sipInkBlocked,
    };
    showErrorSnackBar(context, message);
  }

  // ---------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------

  /// Slice of the active stroke that doesn't fit — drawn dashed in
  /// red. Includes the boundary point so the line stays connected.
  /// The committed prefix lives in `_simplifiedSketch` (already
  /// rendered by the canvas) so we no longer paint it as raw points.
  List<({double x, double y})> get _activeOverflowSlice {
    if (_committedBoundary >= _activeRaw.length - 1) return const [];
    final start = _committedBoundary < 0 ? 0 : _committedBoundary;
    return _activeRaw.sublist(start);
  }

  bool get _isOverBudget =>
      _committedBoundary < _activeRaw.length - 1 && _activeRaw.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final hasDraft = widget.draft.isNotEmpty;
    final canSend = widget.enabled && _encodedBytes != null && !_sending;
    final pointCount = _simplifiedSketch?.totalPointCount ?? 0;
    final byteCount = _encodedBytes?.length ?? 0;
    final overBudget = _isOverBudget;
    final errorColor = Theme.of(context).colorScheme.error;
    final hintText = overBudget
        ? l10n.sipInkComposerHintOver
        : l10n.sipInkComposerHint;
    final hintColor = overBudget
        ? errorColor.withValues(alpha: 0.9)
        : context.textTertiary;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 150),
            style: TextStyle(
              fontSize: 11,
              color: hintColor,
              fontFamily: AppTheme.fontFamily,
            ),
            child: Text(hintText),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280, maxHeight: 280),
              child: AspectRatio(
                aspectRatio: 1,
                child: SipInkCanvas(
                  simplifiedSketch: _simplifiedSketch,
                  activeOverflow: _activeOverflowSlice,
                  isOverBudget: overBudget,
                  enabled: widget.enabled && !_sending,
                  strokeWidth: _strokeWidth,
                  canvasSize: _canvasSize,
                  onStrokeStart: _onStrokeStart,
                  onStrokeUpdate: _onStrokeUpdate,
                  onStrokeEnd: _onStrokeEnd,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  spacing: AppTheme.spacing6,
                  runSpacing: AppTheme.spacing4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _BudgetChip(
                      icon: Icons.gesture,
                      label: l10n.sipInkPointBudget(
                        pointCount,
                        SipInkConstants.maxTotalPoints,
                      ),
                      isOver: overBudget,
                    ),
                    _BudgetChip(
                      icon: Icons.data_usage,
                      label: l10n.sipInkPayloadUsage(
                        byteCount,
                        SipInkConstants.maxPayloadBytes,
                      ),
                      isOver: overBudget,
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
                onTap: (hasDraft || _activeRaw.isNotEmpty) && !_sending
                    ? _onClear
                    : null,
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

/// Pill-shaped chip showing one budget counter (points or bytes).
///
/// Compact, icon + small label, subtle card background, soft border.
/// Tints to the theme's error color (and bumps weight) when the
/// composer is over the airtime budget.
class _BudgetChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isOver;

  const _BudgetChip({
    required this.icon,
    required this.label,
    required this.isOver,
  });

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    final fg = isOver ? errorColor : context.textSecondary;
    final bg = isOver
        ? errorColor.withValues(alpha: 0.10)
        : context.card.withValues(alpha: 0.6);
    final borderColor = isOver
        ? errorColor.withValues(alpha: 0.45)
        : context.border.withValues(alpha: 0.45);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isOver ? FontWeight.w600 : FontWeight.w500,
              color: fg,
              fontFamily: AppTheme.fontFamily,
            ),
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
