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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/l10n/l10n_extension.dart';
import '../../../../../core/logging.dart';
import '../../../../../core/theme.dart';
import '../../../../../services/protocol/sip/play/games/tictactoe/ttt_payload.dart';
import '../../../../../services/protocol/sip/play/games/tictactoe/ttt_rules.dart';

/// Animation tuning for the board. Centralised so tests + manual QA
/// can find every duration in one place.
abstract final class _Tuning {
  static const Duration drawIn = Duration(milliseconds: 180);
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
                  if (widget.isPending && widget.pendingMark != null) {
                    // Ghost overlay: same painter at reduced alpha,
                    // gently pulsing.
                    final pulseT = 0.6 + (widget.pulse.value * 0.4);
                    return Semantics(
                      label: _semanticsLabel(
                        widget.pendingMark!,
                        pending: true,
                      ),
                      child: CustomPaint(
                        painter: _TttMarkPainter(
                          mark: widget.pendingMark!,
                          progress: 1.0,
                          color: widget.accent.withValues(alpha: 0.5 * pulseT),
                        ),
                      ),
                    );
                  }
                  if (mark == null) return const SizedBox.shrink();
                  return Semantics(
                    label: _semanticsLabel(mark, pending: false),
                    child: CustomPaint(
                      painter: _TttMarkPainter(
                        mark: mark,
                        progress: Curves.easeOutCubic.transform(_drawIn.value),
                        color: markColor,
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

/// Custom painter for X / O strokes. Rounded caps. Progress 0..1 ramps
/// up the stroke length so the mark "draws in" rather than popping.
class _TttMarkPainter extends CustomPainter {
  final TttMark mark;
  final double progress;
  final Color color;

  _TttMarkPainter({
    required this.mark,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final shorter = math.min(size.width, size.height);
    final stroke = shorter * 0.16;
    final paint = Paint()
      ..color = color
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (mark == TttMark.x) {
      _paintX(canvas, size, paint, progress);
    } else {
      _paintO(canvas, size, paint, progress);
    }
  }

  void _paintX(Canvas canvas, Size size, Paint paint, double t) {
    // Two diagonals. Animate first stroke for the first half of t,
    // second stroke for the second half — gives a writing feel.
    final pad = size.shortestSide * 0.18;
    final start1 = Offset(pad, pad);
    final end1 = Offset(size.width - pad, size.height - pad);
    final start2 = Offset(size.width - pad, pad);
    final end2 = Offset(pad, size.height - pad);

    final t1 = (t * 2).clamp(0.0, 1.0);
    final t2 = ((t - 0.5) * 2).clamp(0.0, 1.0);
    canvas.drawLine(start1, Offset.lerp(start1, end1, t1)!, paint);
    if (t2 > 0) {
      canvas.drawLine(start2, Offset.lerp(start2, end2, t2)!, paint);
    }
  }

  void _paintO(Canvas canvas, Size size, Paint paint, double t) {
    final pad = size.shortestSide * 0.18;
    final rect = Rect.fromLTRB(pad, pad, size.width - pad, size.height - pad);
    final centre = rect.center;
    final radius = rect.shortestSide / 2;
    // Sweep starts from top (-pi/2) and goes clockwise.
    final sweep = 2 * math.pi * t;
    final path = Path()
      ..addArc(
        Rect.fromCircle(center: centre, radius: radius),
        -math.pi / 2,
        sweep,
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TttMarkPainter old) {
    return old.mark != mark || old.progress != progress || old.color != color;
  }
}

/// Build the user-facing status caption for an active or terminal
/// TTT instance. Pure helper — no localization context needed at the
/// call site beyond a [BuildContext].
String tttStatusCaption({
  required BuildContext context,
  required bool isLocalTurn,
  required bool localWon,
  required bool remoteWon,
  required bool draw,
  required bool localResigned,
  required bool remoteResigned,
  required bool localDeclined,
  required bool remoteDeclined,
}) {
  final l10n = context.l10n;
  if (localWon) return l10n.sipPlayStatusYouWon;
  if (remoteWon) return l10n.sipPlayStatusTheyWon;
  if (draw) return l10n.sipPlayStatusDraw;
  if (localResigned) return l10n.sipPlayStatusYouResigned;
  if (remoteResigned) return l10n.sipPlayStatusTheyResigned;
  if (localDeclined) return l10n.sipPlayStatusYouDeclined;
  if (remoteDeclined) return l10n.sipPlayStatusTheyDeclined;
  return isLocalTurn ? l10n.sipPlayStatusYourTurn : l10n.sipPlayStatusTheirTurn;
}

/// Small dot that pulses when it's the local user's turn — a subtle
/// "your move" cue placed inline with the status caption. Pure
/// presentation; no business logic.
class TttTurnPulseDot extends StatefulWidget {
  final Color color;
  final double size;

  const TttTurnPulseDot({super.key, required this.color, this.size = 8});

  @override
  State<TttTurnPulseDot> createState() => _TttTurnPulseDotState();
}

class _TttTurnPulseDotState extends State<TttTurnPulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctl,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_ctl.value);
        return SizedBox(
          width: widget.size + 6,
          height: widget.size + 6,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size + 4 * t,
                height: widget.size + 4 * t,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.25 * (1.0 - t)),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
