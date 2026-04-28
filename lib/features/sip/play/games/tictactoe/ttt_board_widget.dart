// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Renders a Tic-Tac-Toe board for one [SipPlayInstanceState].
///
/// Pure renderer — every tap dispatches up to a supplied
/// `onCellTap(cell)` callback. The widget itself never sends a frame
/// or mutates engine state; the parent [_BoardSection] is responsible
/// for the optimistic-pending overlay, the interaction lock, and the
/// router dispatch.
///
/// Ship-grade visual choices:
///   - Custom-painted X / O strokes (no font glyph) → consistent
///     stroke weight and rounded caps, scales cleanly on every device.
///   - Cell press feedback: 0.96 → 1.0 scale with 120 ms easeOut
///     when a legal cell is tapped.
///   - Draw-in animation: 180 ms easeOutCubic on first appearance
///     of a confirmed mark.
///   - Pending mark overlay: same painter at 50% alpha, gently
///     pulsing while the engine catches up.
///   - Layered depth: outer card with soft shadow, inner cells with
///     a subtle inset ring.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/logging.dart';
import '../../../../../core/theme.dart';
import '../../../../../services/protocol/sip/play/games/tictactoe/ttt_payload.dart';
import '../../../../../services/protocol/sip/play/games/tictactoe/ttt_rules.dart';

/// Animation tuning for the board. Centralised so tests + manual QA
/// can find every duration in one place.
abstract final class _Tuning {
  /// Mark "place" animation. Drives the scale-pop + fade-in + halo
  /// flash. Long enough that the halo decay reads as a beat of
  /// feedback, short enough that the mark feels snappy.
  static const Duration drawIn = Duration(milliseconds: 320);
  static const Duration cellPress = Duration(milliseconds: 120);
  static const Duration pendingPulse = Duration(milliseconds: 1400);
}

class TttBoardWidget extends StatefulWidget {
  /// Current 9-cell state derived from the entry log.
  final TttBoard board;

  /// Local user's mark. Null until the offer is accepted (the parent
  /// hides the board widget in that window so this is `null`-safe).
  final TttMark? localMark;

  /// True when local taps should produce a move. False during the
  /// peer's turn, after a terminal state, when the peer is blocked,
  /// or when an optimistic move is in flight (interaction lock).
  final bool enabled;

  /// Optimistic-move overlay. The parent sets this the moment the
  /// user taps a legal cell; once the engine state catches up
  /// (board.cells[cell] == mark) the parent clears it. While set,
  /// the indicated cell renders the ghost mark and all other cells
  /// are non-interactive — UI consistency without touching the
  /// authoritative state.
  final TttMove? pendingMove;

  /// Called with cell index 0..8 when the local user taps an empty,
  /// legal cell. Caller is responsible for sending the move envelope
  /// through the router and tracking the pending overlay.
  final void Function(int cell) onCellTap;

  const TttBoardWidget({
    super.key,
    required this.board,
    required this.localMark,
    required this.enabled,
    required this.onCellTap,
    this.pendingMove,
  });

  @override
  State<TttBoardWidget> createState() => _TttBoardWidgetState();
}

class _TttBoardWidgetState extends State<TttBoardWidget>
    with TickerProviderStateMixin {
  /// Ghost-mark pulse (0..1 sine) used to gently breathe the
  /// optimistic overlay. Repeats while the pending move is unresolved.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: _Tuning.pendingPulse)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    final cellsStr = widget.board.cells
        .map((m) => m == null ? '_' : (m == TttMark.x ? 'X' : 'O'))
        .join('');
    AppLogging.sipPlay(
      'TTT_BOARD_BUILD enabled=${widget.enabled} '
      'localMark=${widget.localMark?.name ?? "null"} '
      'pendingCell=${widget.pendingMove?.cell ?? "null"} '
      'pendingMark=${widget.pendingMove?.mark.name ?? "null"} '
      'cells=$cellsStr',
    );
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.background,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing4),
          child: Column(
            children: [
              for (var row = 0; row < 3; row += 1)
                Expanded(
                  child: Row(
                    children: [
                      for (var col = 0; col < 3; col += 1)
                        Expanded(
                          child: _Cell(
                            // Stable key so widget tests can target a
                            // specific cell deterministically without
                            // relying on render-tree search heuristics.
                            key: ValueKey<String>('ttt_cell_${row * 3 + col}'),
                            index: row * 3 + col,
                            mark: widget.board.cells[row * 3 + col],
                            isPending:
                                widget.pendingMove?.cell == row * 3 + col,
                            pendingMark:
                                widget.pendingMove?.cell == row * 3 + col
                                ? widget.pendingMove!.mark
                                : null,
                            localMark: widget.localMark,
                            enabled: widget.enabled,
                            accent: accent,
                            pulse: _pulse,
                            onTap: () => widget.onCellTap(row * 3 + col),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cell extends StatefulWidget {
  final int index;
  final TttMark? mark;
  final bool isPending;
  final TttMark? pendingMark;
  final TttMark? localMark;
  final bool enabled;
  final Color accent;
  final Animation<double> pulse;
  final VoidCallback onTap;

  const _Cell({
    super.key,
    required this.index,
    required this.mark,
    required this.isPending,
    required this.pendingMark,
    required this.localMark,
    required this.enabled,
    required this.accent,
    required this.pulse,
    required this.onTap,
  });

  @override
  State<_Cell> createState() => _CellState();
}

class _CellState extends State<_Cell> with TickerProviderStateMixin {
  /// Press scale 1.0 → 0.96 → 1.0 on a legal tap.
  late final AnimationController _press;

  /// Draw-in 0 → 1 the first time a mark resolves into this cell.
  /// Reset whenever the mark changes (rare — only on engine resets).
  late final AnimationController _drawIn;

  TttMark? _renderedMark;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: _Tuning.cellPress,
      lowerBound: 0,
      upperBound: 1,
      value: 0,
    );
    _drawIn = AnimationController(
      vsync: this,
      duration: _Tuning.drawIn,
      value: widget.mark != null ? 1.0 : 0.0,
    );
    _renderedMark = widget.mark;
  }

  @override
  void didUpdateWidget(covariant _Cell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.mark != _renderedMark) {
      _renderedMark = widget.mark;
      if (widget.mark != null) {
        _drawIn.forward(from: 0.0);
      } else {
        _drawIn.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _drawIn.dispose();
    super.dispose();
  }

  Future<void> _animateTap() async {
    // 1.0 → 0.96 → 1.0 with eased return.
    await _press.animateTo(1.0, curve: Curves.easeOut);
    if (!mounted) return;
    await _press.animateBack(0.0, curve: Curves.easeOut);
  }

  bool get _canTap =>
      widget.enabled && widget.mark == null && !widget.isPending;

  /// Stable semantics label so widget tests + screen readers can
  /// identify a placed mark without relying on the rendered glyph.
  /// Format: `'X'` / `'O'` for confirmed marks, `'X (pending)'` /
  /// `'O (pending)'` for the optimistic overlay.
  String _semanticsLabel(TttMark mark, {required bool pending}) {
    final base = mark == TttMark.x ? 'X' : 'O';
    return pending ? '$base (pending)' : base;
  }

  @override
  Widget build(BuildContext context) {
    final mark = widget.mark;
    final isLocal =
        mark != null && widget.localMark != null && mark == widget.localMark;
    final markColor = isLocal
        ? widget.accent
        : context.textPrimary.withValues(alpha: 0.85);

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing2),
      child: Listener(
        // Raw pointer-down observer — fires regardless of _canTap.
        // Lets us prove a tap physically reached the cell even when
        // the gesture detector below has its callbacks nulled out.
        // Behaviour-neutral: Listener does not consume the event.
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          AppLogging.sipPlay(
            'TTT_CELL_POINTER_DOWN idx=${widget.index} '
            'mark=${widget.mark?.name ?? "null"} '
            'isPending=${widget.isPending} '
            'enabled=${widget.enabled} canTap=$_canTap',
          );
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _canTap ? (_) => _press.forward() : null,
          onTapCancel: _canTap ? () => _press.reverse() : null,
          onTap: _canTap
              ? () {
                  AppLogging.sipPlay('TTT_CELL_TAP_FIRED idx=${widget.index}');
                  // Press feedback first, then propagate. The parent
                  // owns the actual send + pending overlay.
                  HapticFeedback.lightImpact();
                  _animateTap();
                  widget.onTap();
                }
              : null,
          child: AnimatedBuilder(
            animation: _press,
            builder: (context, child) {
              // Map 0..1 → 1.0..0.96 for the press dip.
              final scale = 1.0 - (_press.value * 0.04);
              return Transform.scale(scale: scale, child: child);
            },
            child: _CellSurface(
              isInteractive: _canTap,
              child: AnimatedBuilder(
                animation: Listenable.merge([_drawIn, widget.pulse]),
                builder: (context, _) {
                  // CustomPaint with no child takes Size.zero by default
                  // and the parent Container's `alignment: center` hands
                  // it loose constraints — without a SizedBox.expand the
                  // painter renders at 0×0 and the X/O strokes are
                  // invisible. Wrapping forces it to fill the cell's
                  // padded inner box.
                  if (widget.isPending && widget.pendingMark != null) {
                    // Ghost overlay: same painter at reduced alpha,
                    // gently pulsing.
                    final pulseT = 0.6 + (widget.pulse.value * 0.4);
                    return Semantics(
                      label: _semanticsLabel(
                        widget.pendingMark!,
                        pending: true,
                      ),
                      child: SizedBox.expand(
                        child: CustomPaint(
                          painter: _TttMarkPainter(
                            mark: widget.pendingMark!,
                            // t = 1.0 → static fully-formed ghost
                            // (no scale-pop / no halo). The pulse
                            // controller already drives the alpha
                            // shimmer for the pending overlay.
                            t: 1.0,
                            color: widget.accent.withValues(
                              alpha: 0.5 * pulseT,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  if (mark == null) return const SizedBox.shrink();
                  // Pass the raw 0..1 timeline — the painter owns the
                  // scale / alpha / halo envelopes so the curves stay
                  // co-located with the rendering.
                  return Semantics(
                    label: _semanticsLabel(mark, pending: false),
                    child: SizedBox.expand(
                      child: CustomPaint(
                        painter: _TttMarkPainter(
                          mark: mark,
                          t: _drawIn.value,
                          color: markColor,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CellSurface extends StatelessWidget {
  final Widget child;
  final bool isInteractive;
  const _CellSurface({required this.child, required this.isInteractive});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(
          color: isInteractive
              ? context.border.withValues(alpha: 0.5)
              : context.border.withValues(alpha: 0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing8),
        child: child,
      ),
    );
  }
}

/// Custom painter for X / O. Renders the mark fully-formed and uses
/// `t` (0..1) to drive a scale-pop + fade-in plus a brief radial
/// halo behind the mark. The halo peaks early (~25%) and decays out
/// by `t = 1`, giving a single clean "placed" beat instead of the
/// older per-frame stroke-lerp which felt mechanical and was costly
/// (saveLayer was running on every animation tick).
///
/// Pass `t = 1.0` for a static rendered mark with no animation
/// (used by the pending-overlay branch — the parent's pulse
/// controller modulates alpha on the mark colour itself).
class _TttMarkPainter extends CustomPainter {
  final TttMark mark;
  final double t;
  final Color color;

  _TttMarkPainter({required this.mark, required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;

    // ── Halo behind the mark ──
    // Triangle envelope: rise 0..0.25 → peak → decay 0.25..1. Skipped
    // when t == 1 (static state) so the pending overlay and any
    // post-animation rebuild don't paint a phantom glow.
    final centre = Offset(size.width / 2, size.height / 2);
    if (t < 1.0) {
      const peakAt = 0.25;
      final haloAlpha = t < peakAt
          ? (t / peakAt)
          : ((1 - t) / (1 - peakAt)).clamp(0.0, 1.0);
      if (haloAlpha > 0.01) {
        final r = size.shortestSide * (0.32 + 0.18 * t);
        final haloPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.55 * haloAlpha),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromCircle(center: centre, radius: r));
        canvas.drawCircle(centre, r, haloPaint);
      }
    }

    // ── Scale-pop + fade for the mark ──
    // Fade reaches full alpha at ~70% of t so the mark is solid by
    // the time the halo has decayed; scale uses easeOutBack for a
    // small overshoot ("pop"), then settles to 1.0.
    final alpha = (t / 0.7).clamp(0.0, 1.0);
    final scale = 0.6 + 0.4 * Curves.easeOutBack.transform(t.clamp(0.0, 1.0));

    canvas.save();
    canvas.translate(centre.dx, centre.dy);
    canvas.scale(scale);
    canvas.translate(-centre.dx, -centre.dy);

    final stroke = size.shortestSide * 0.16;
    final paintColor = color.withValues(alpha: alpha * color.a);
    final markPaint = Paint()
      ..color = paintColor
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (mark == TttMark.x) {
      _paintX(canvas, size, markPaint);
    } else {
      _paintO(canvas, size, markPaint);
    }

    canvas.restore();
  }

  void _paintX(Canvas canvas, Size size, Paint paint) {
    final pad = size.shortestSide * 0.18;
    final start1 = Offset(pad, pad);
    final end1 = Offset(size.width - pad, size.height - pad);
    final start2 = Offset(size.width - pad, pad);
    final end2 = Offset(pad, size.height - pad);

    // Composite both diagonals through a transient layer so the
    // crossing point doesn't double-blend the stroke alpha. Two
    // overlapping translucent strokes at alpha=0.85 would otherwise
    // composite to ~0.978 alpha at the intersection — visibly darker
    // than the surrounding strokes. Inside the layer we draw at full
    // opacity, then the layer composites onto the canvas once at the
    // original alpha. Cheap now that we're not lerp'ing endpoints
    // per frame — saveLayer runs at most ~10 times across the whole
    // animation instead of every frame.
    final layerRect = Offset.zero & size;
    final compositePaint = Paint()
      ..color = Color.fromARGB((paint.color.a * 255).round(), 0, 0, 0);
    canvas.saveLayer(layerRect, compositePaint);
    final innerPaint = Paint()
      ..color = paint.color.withAlpha(255)
      ..strokeWidth = paint.strokeWidth
      ..strokeCap = paint.strokeCap
      ..strokeJoin = paint.strokeJoin
      ..style = paint.style;
    canvas.drawLine(start1, end1, innerPaint);
    canvas.drawLine(start2, end2, innerPaint);
    canvas.restore();
  }

  void _paintO(Canvas canvas, Size size, Paint paint) {
    final pad = size.shortestSide * 0.18;
    final rect = Rect.fromLTRB(pad, pad, size.width - pad, size.height - pad);
    final centre = rect.center;
    final radius = rect.shortestSide / 2;
    canvas.drawCircle(centre, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _TttMarkPainter old) {
    return old.mark != mark || old.t != t || old.color != color;
  }
}

// Game-agnostic status caption + turn pulse helpers moved to
// `lib/features/sip/play/play_status_caption.dart` so Connect Four
// and any future game can reuse them without importing the TTT
// widget file.
