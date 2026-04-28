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
  /// Three outcomes:
  /// 1. Candidate accepted — simplifier kept the in-progress stroke
  ///    in its output. Advance the boundary; cache the sketch.
  /// 2. Candidate dropped (typically a 1-point gesture-start that
  ///    fails the simplifier's `minPointsPerStroke` check) but the
  ///    simplifier otherwise succeeded — boundary stays put, sketch
  ///    is cached. Crucially we do NOT advance the boundary here:
  ///    the dropped candidate's points are NOT in the cached sketch,
  ///    so claiming they're committed would let `_resimplifyCommitted`
  ///    feed them back into the simplifier on the next over-budget
  ///    frame, where they can fail and null out the sketch.
  /// 3. Real failure (`budgetExceeded` / `tooManyStrokes`) — fire
  ///    the medium-impact haptic once per stroke and re-derive the
  ///    simplified state from completed-only strokes. The
  ///    `_overflowHapticFiredThisStroke` flag is the single source of
  ///    truth for "user crossed the budget on this stroke" — both the
  ///    haptic and the red-state UI gate on it, so a candidate drop
  ///    on the first frame can't falsely trip the red banner.
  void _evaluateActiveStroke() {
    final candidate = SipInkRawStroke(width: _strokeWidth, points: _activeRaw);
    final fullResult = SipInkSimplifier.simplify(
      rawStrokes: [...widget.draft, candidate],
      canvasSize: _canvasSize,
    );

    final expectedStrokeCount = widget.draft.length + 1;
    final candidateAccepted =
        fullResult.isOk &&
        fullResult.sketch!.strokes.length == expectedStrokeCount;

    if (candidateAccepted) {
      _committedBoundary = _activeRaw.length - 1;
      _simplifiedSketch = fullResult.sketch;
      _encodedBytes = SipInkEncoder.encode(fullResult.sketch!).bytes;
      return;
    }

    if (fullResult.isOk) {
      // Candidate dropped (too short / degenerate). Boundary stays.
      // Counters reflect the completed-only state.
      _simplifiedSketch = fullResult.sketch;
      _encodedBytes = SipInkEncoder.encode(fullResult.sketch!).bytes;
      return;
    }

    final error = fullResult.error;
    final isRealOverflow =
        error == SipInkSimplifyError.budgetExceeded ||
        error == SipInkSimplifyError.tooManyStrokes;

    if (isRealOverflow && !_overflowHapticFiredThisStroke) {
      _overflowHapticFiredThisStroke = true;
      HapticFeedback.mediumImpact();
      AppLogging.sipInk(
        'overflow_started raw_points=${_activeRaw.length} '
        'committed_boundary=$_committedBoundary error=${error?.name}',
      );
    }
    _resimplifyCommitted();
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

    // Capture the navigator BEFORE the await — needed to dismiss
    // the compose sheet on success without tripping the
    // `use_build_context_synchronously` lint or risking the context
    // having been deactivated by the time the future resolves.
    final navigator = Navigator.of(context);

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
    // Auto-dismiss the compose sheet on success — matches the
    // SIP Play offer flow. `maybePop` is a no-op if the topmost
    // route isn't the compose sheet, so this is safe to call
    // unconditionally.
    navigator.maybePop();
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

  /// True only when the simplifier has explicitly rejected the active
  /// stroke for budget reasons on this gesture (`budgetExceeded` /
  /// `tooManyStrokes` — see `_evaluateActiveStroke`). Tracking this
  /// via the haptic flag avoids a false-positive that the geometric
  /// `boundary < activeRaw.length - 1` predicate trips on the first
  /// point of a fresh stroke: the simplifier needs at least
  /// [SipInkConstants.minPointsPerStroke] before it can decide either
  /// way, so during gesture-start the boundary lags behind activeRaw
  /// purely by definition — that's not "over budget".
  bool get _isOverBudget =>
      _overflowHapticFiredThisStroke && _activeRaw.isNotEmpty;

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

    // Body (scrollable) + sticky full-width action bar at the
    // bottom — mirrors the Signal composer panel for consistency.
    // Action bar pinned to the BOTTOM of the available area, body
    // fills everything above. `Expanded` (not `Flexible`) so the
    // body always fills its slot — `Flexible` would let the body
    // shrink to its natural size, which leaves dead space between
    // the canvas and the action row when the parent sheet is
    // taller than the canvas needs.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.max,
      children: [
        Expanded(
          // Centre the canvas in BOTH axes inside the available
          // vertical slot. The body still scrolls if the parent sheet
          // is dragged smaller than the canvas needs (`SingleChild
          // ScrollView` outer), but `LayoutBuilder` + a
          // `ConstrainedBox(minHeight: viewport)` lets the inner
          // `Column` grow to the full viewport height when there's
          // headroom — only then does `mainAxisAlignment.center`
          // visually centre the hint + canvas as a group rather than
          // hugging the top edge. This is the canonical Flutter
          // recipe for "centre inside a scroll view".
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing16,
                  AppTheme.spacing8,
                  AppTheme.spacing16,
                  AppTheme.spacing8,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    // Subtract the vertical padding above so the
                    // intrinsic Column matches the visible viewport
                    // exactly — otherwise the centring would float
                    // slightly off-axis by spacing16.
                    minHeight: constraints.maxHeight - AppTheme.spacing8 * 2,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                        child: Text(hintText, textAlign: TextAlign.center),
                      ),
                      const SizedBox(height: AppTheme.spacing8),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 280,
                            maxHeight: 280,
                          ),
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
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        _buildStickyActionBar(
          context: context,
          pointCount: pointCount,
          byteCount: byteCount,
          overBudget: overBudget,
          hasDraft: hasDraft,
          canSend: canSend,
        ),
      ],
    );
  }

  /// Sticky bottom action bar — pinned to the bottom of the compose
  /// panel so Undo / Clear / Send are always reachable regardless of
  /// the canvas / chip-row vertical footprint. Mirrors the Signal
  /// composer's `_buildStickyActionBar` so the two composer modes
  /// read in the same visual language.
  Widget _buildStickyActionBar({
    required BuildContext context,
    required int pointCount,
    required int byteCount,
    required bool overBudget,
    required bool hasDraft,
    required bool canSend,
  }) {
    final l10n = context.l10n;
    // No BoxDecoration — earlier we drew a tinted background +
    // top-divider here to visually anchor the action row to the
    // sheet's bottom edge. In a DraggableScrollableSheet the row
    // moves with the sheet on drag, and the tinted rectangle reads
    // as a stranded box rather than a fixed bar — uglier than just
    // letting the buttons sit transparently on the sheet's own
    // surface. Padding is symmetric and tight; the sheet's
    // safe-area inset provides the visual gap below.
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Budget chips (points + bytes) above the buttons.
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
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
          Row(
            children: [
              Expanded(
                child: _StickyActionButton(
                  icon: Icons.undo,
                  tooltip: l10n.sipInkUndo,
                  onPressed: hasDraft && !_sending ? _onUndo : null,
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: _StickyActionButton(
                  icon: Icons.delete_outline,
                  tooltip: l10n.sipInkClear,
                  onPressed: (hasDraft || _activeRaw.isNotEmpty) && !_sending
                      ? _onClear
                      : null,
                  tone: _StickyActionTone.destructive,
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Expanded(
                child: _StickyActionButton(
                  icon: Icons.send_rounded,
                  tooltip: l10n.sipInkSend,
                  onPressed: canSend ? _onSend : null,
                  tone: _StickyActionTone.primary,
                  showProgress: _sending,
                ),
              ),
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

/// Action-bar button tone — mirrors the Signal composer's
/// `_IconActionTone` so the two composer panels render the same
/// visual language (neutral / destructive / primary).
enum _StickyActionTone { neutral, destructive, primary }

/// Full-width sticky-bottom-bar action button — used by the sketch
/// composer's bottom action row. Equivalent to the same-named widget
/// in `sip_signal_composer_panel.dart`; both composers use the same
/// shape so Sketch and Signal feel identical when the user taps
/// between them. Each button fills its parent (via the wrapping
/// [Expanded]) and is fixed at 44 pt height.
class _StickyActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final _StickyActionTone tone;
  final bool showProgress;

  const _StickyActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.tone = _StickyActionTone.neutral,
    this.showProgress = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final accent = context.accentColor;
    final (bg, border, fg) = switch (tone) {
      _StickyActionTone.neutral => (
        Colors.transparent,
        context.border.withValues(alpha: 0.5),
        context.textPrimary,
      ),
      _StickyActionTone.destructive => (
        Colors.transparent,
        AccentColors.red.withValues(alpha: 0.55),
        AccentColors.red,
      ),
      _StickyActionTone.primary => (accent, accent, Colors.white),
    };
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        height: 44,
        child: Material(
          color: disabled ? bg.withValues(alpha: 0.4) : bg,
          borderRadius: BorderRadius.circular(AppTheme.radius10),
          child: InkWell(
            onTap: onPressed == null
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    onPressed!();
                  },
            borderRadius: BorderRadius.circular(AppTheme.radius10),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radius10),
                border: Border.all(
                  color: disabled ? border.withValues(alpha: 0.4) : border,
                ),
              ),
              child: Center(
                child: showProgress
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            disabled ? fg.withValues(alpha: 0.4) : fg,
                          ),
                        ),
                      )
                    : Icon(
                        icon,
                        size: 22,
                        color: disabled ? fg.withValues(alpha: 0.4) : fg,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
