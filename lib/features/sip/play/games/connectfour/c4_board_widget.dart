// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Renders a Connect Four board for one [SipPlayInstanceState].
///
/// Pure renderer — every column tap dispatches up to a supplied
/// `onColumnTap(column)` callback. The widget itself never sends a
/// frame or mutates engine state; the parent [_C4BoardSection] is
/// responsible for the optimistic-pending overlay, the interaction
/// lock, and the router dispatch.
///
/// Ship-grade visual choices:
///   - Custom-painted disc circles → consistent radius and pixel-
///     perfect rendering at every device scale.
///   - Column press feedback: 0.96 → 1.0 scale with 120 ms easeOut
///     when a legal column is tapped.
///   - Drop animation: 250 ms easeOutCubic from the top of the
///     column down to the landing row, mimicking gravity.
///   - Pending disc overlay: ghost disc at the targeted column's
///     landing row, gently pulsing while the engine catches up.
///   - Theme-driven colours: accent for the local player's discs,
///     muted text-primary for the peer (no hard-coded red / yellow
///     in render code — the wire enum names are spec-only).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../core/logging.dart';
import '../../../../../core/theme.dart';
import '../../../../../services/protocol/sip/play/games/connectfour/c4_payload.dart';
import '../../../../../services/protocol/sip/play/games/connectfour/c4_rules.dart';

/// Animation tuning for the board. Centralised so tests + manual QA
/// can find every duration in one place.
abstract final class _Tuning {
  /// Time for a freshly-placed disc to fall from the top of its
  /// column down to its landing row.
  static const Duration drop = Duration(milliseconds: 250);

  /// Press scale dip for column-tap feedback.
  static const Duration columnPress = Duration(milliseconds: 120);

  /// Slow pulse rate for the optimistic-pending ghost disc.
  static const Duration pendingPulse = Duration(milliseconds: 1400);
}

class C4BoardWidget extends StatefulWidget {
  /// Current 6×7 state derived from the entry log.
  final C4Board board;

  /// Local user's disc colour. Null until the offer is accepted (the
  /// parent hides the board widget in that window so this is
  /// `null`-safe).
  final C4Disc? localDisc;

  /// True when local taps should produce a move. False during the
  /// peer's turn, after a terminal state, when the peer is blocked,
  /// or when an optimistic move is in flight (interaction lock).
  final bool enabled;

  /// Optimistic-move overlay. The parent sets this the moment the
  /// user taps a legal column; once the engine state catches up the
  /// parent clears it. While set, the targeted column renders the
  /// ghost disc at the landing row and all other columns are
  /// non-interactive — UI consistency without touching the
  /// authoritative state.
  final C4Move? pendingMove;

  /// Called with column index 0..6 when the local user taps a
  /// non-full, legal column. Caller is responsible for sending the
  /// move envelope through the router and tracking the pending
  /// overlay.
  final void Function(int column) onColumnTap;

  const C4BoardWidget({
    super.key,
    required this.board,
    required this.localDisc,
    required this.enabled,
    required this.onColumnTap,
    this.pendingMove,
  });

  @override
  State<C4BoardWidget> createState() => _C4BoardWidgetState();
}

class _C4BoardWidgetState extends State<C4BoardWidget>
    with TickerProviderStateMixin {
  /// Ghost-disc pulse (0..1 sine) used to gently breathe the
  /// optimistic overlay. Repeats while the pending move is
  /// unresolved.
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
    AppLogging.sipPlay(
      'C4_BOARD_BUILD enabled=${widget.enabled} '
      'localDisc=${widget.localDisc?.name ?? "null"} '
      'pendingColumn=${widget.pendingMove?.column ?? "null"} '
      'pendingDisc=${widget.pendingMove?.disc.name ?? "null"} '
      'moveCount=${widget.board.moveCount}',
    );
    return AspectRatio(
      aspectRatio: C4Board.cols / C4Board.rows,
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
          child: Row(
            children: [
              for (var col = 0; col < C4Board.cols; col += 1)
                Expanded(
                  child: _Column(
                    // Stable key so widget tests can target a specific
                    // column deterministically.
                    key: ValueKey<String>('c4_col_$col'),
                    column: col,
                    board: widget.board,
                    localDisc: widget.localDisc,
                    enabled: widget.enabled,
                    isPending: widget.pendingMove?.column == col,
                    pendingDisc: widget.pendingMove?.column == col
                        ? widget.pendingMove!.disc
                        : null,
                    accent: accent,
                    pulse: _pulse,
                    onTap: () => widget.onColumnTap(col),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Column extends StatefulWidget {
  final int column;
  final C4Board board;
  final C4Disc? localDisc;
  final bool enabled;
  final bool isPending;
  final C4Disc? pendingDisc;
  final Color accent;
  final Animation<double> pulse;
  final VoidCallback onTap;

  const _Column({
    super.key,
    required this.column,
    required this.board,
    required this.localDisc,
    required this.enabled,
    required this.isPending,
    required this.pendingDisc,
    required this.accent,
    required this.pulse,
    required this.onTap,
  });

  @override
  State<_Column> createState() => _ColumnState();
}

class _ColumnState extends State<_Column> with TickerProviderStateMixin {
  /// Press scale 1.0 → 0.96 → 1.0 on a legal column tap.
  late final AnimationController _press;

  /// Drop animation 0 → 1 the first time a disc resolves into a new
  /// row in this column. The animation is keyed off `_lastSettledRow`
  /// — when the column gains a disc at a new row, we re-trigger.
  late final AnimationController _drop;

  /// Last row that has a disc in this column (snapshotted between
  /// rebuilds so we can detect a new placement).
  int? _lastSettledTopRow;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: _Tuning.columnPress,
      value: 0,
    );
    _drop = AnimationController(vsync: this, duration: _Tuning.drop, value: 1);
    _lastSettledTopRow = _topFilledRow(widget.board, widget.column);
  }

  @override
  void didUpdateWidget(covariant _Column oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newTop = _topFilledRow(widget.board, widget.column);
    if (newTop != _lastSettledTopRow) {
      _lastSettledTopRow = newTop;
      if (newTop != null) {
        _drop.forward(from: 0.0);
      } else {
        _drop.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _press.dispose();
    _drop.dispose();
    super.dispose();
  }

  Future<void> _animateTap() async {
    await _press.animateTo(1.0, curve: Curves.easeOut);
    if (!mounted) return;
    await _press.animateBack(0.0, curve: Curves.easeOut);
  }

  bool get _canTap =>
      widget.enabled &&
      !widget.isPending &&
      widget.board.isLegalMove(widget.column);

  /// Top-filled row index in [column], or null for empty column.
  /// Used to detect "a new disc just landed at a higher row" so we
  /// can trigger the drop animation only on transitions.
  int? _topFilledRow(C4Board board, int column) {
    for (var r = 0; r < C4Board.rows; r += 1) {
      if (board.cellAt(r, column) != null) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final pendingLandingRow = widget.isPending
        ? widget.board.landingRowFor(widget.column)
        : null;
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing2),
      child: Listener(
        // Raw pointer-down observer — fires regardless of _canTap.
        // Lets us prove a tap physically reached the column even when
        // the gesture detector below has its callbacks nulled out.
        // Behaviour-neutral: Listener does not consume the event.
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          AppLogging.sipPlay(
            'C4_COLUMN_POINTER_DOWN col=${widget.column} '
            'isPending=${widget.isPending} '
            'enabled=${widget.enabled} '
            'columnFull=${!widget.board.isLegalMove(widget.column)} '
            'canTap=$_canTap',
          );
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _canTap ? (_) => _press.forward() : null,
          onTapCancel: _canTap ? () => _press.reverse() : null,
          onTap: _canTap
              ? () {
                  AppLogging.sipPlay(
                    'C4_COLUMN_TAP_FIRED col=${widget.column}',
                  );
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
            child: AnimatedBuilder(
              animation: Listenable.merge([_drop, widget.pulse]),
              builder: (context, _) {
                return SizedBox.expand(
                  child: CustomPaint(
                    painter: _C4ColumnPainter(
                      column: widget.column,
                      board: widget.board,
                      localDisc: widget.localDisc,
                      pendingDisc: widget.pendingDisc,
                      pendingLandingRow: pendingLandingRow,
                      pulseValue: widget.pulse.value,
                      dropProgress: Curves.easeOutCubic.transform(_drop.value),
                      topSettledRow: _lastSettledTopRow,
                      accent: widget.accent,
                      mutedDisc: Theme.of(
                        context,
                      ).textTheme.bodyMedium!.color!.withValues(alpha: 0.85),
                      cellBg: context.card,
                      gridLine: context.border.withValues(alpha: 0.5),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Custom painter for one Connect Four column. Draws the cell-hole
/// lattice (rounded rectangle outer + 6 stacked circular cell
/// backgrounds), the settled discs, the actively-dropping disc, and
/// the pending ghost overlay. Does NOT draw across columns — each
/// column is its own painter so the drop animation can be targeted
/// to one column without re-painting the whole board.
class _C4ColumnPainter extends CustomPainter {
  final int column;
  final C4Board board;
  final C4Disc? localDisc;
  final C4Disc? pendingDisc;
  final int? pendingLandingRow;
  final double pulseValue;
  final double dropProgress;
  final int? topSettledRow;
  final Color accent;
  final Color mutedDisc;
  final Color cellBg;
  final Color gridLine;

  _C4ColumnPainter({
    required this.column,
    required this.board,
    required this.localDisc,
    required this.pendingDisc,
    required this.pendingLandingRow,
    required this.pulseValue,
    required this.dropProgress,
    required this.topSettledRow,
    required this.accent,
    required this.mutedDisc,
    required this.cellBg,
    required this.gridLine,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cellHeight = size.height / C4Board.rows;
    final cellWidth = size.width;
    // Disc radius: padded inside the cell so adjacent discs don't
    // touch and the lattice can show through.
    final radius = (cellWidth.clamp(0.0, cellHeight) * 0.85) / 2;

    // 1. Paint the column background (cell-hole lattice). Each row's
    //    cell shows as a circle in the cell-bg colour against the
    //    column's outer surface.
    final holePaint = Paint()..color = cellBg;
    for (var row = 0; row < C4Board.rows; row += 1) {
      final centre = Offset(cellWidth / 2, (row + 0.5) * cellHeight);
      canvas.drawCircle(centre, radius, holePaint);
    }

    // 2. Paint settled discs. The TOP-most settled row gets the drop
    //    animation: when dropProgress < 1, render it at its current
    //    falling y-offset instead of its final row position. All
    //    other settled discs render in place.
    for (var row = 0; row < C4Board.rows; row += 1) {
      final disc = board.cellAt(row, column);
      if (disc == null) continue;
      final colour = _discColour(disc);
      final discPaint = Paint()..color = colour;

      double cy;
      if (row == topSettledRow && dropProgress < 1.0) {
        // Falling disc: animate from y above the column down to
        // its final row centre.
        final finalY = (row + 0.5) * cellHeight;
        // Start from y=0 (above the visible column) so the disc
        // appears to drop in from outside.
        final startY = -cellHeight * 0.5;
        cy = startY + (finalY - startY) * dropProgress;
      } else {
        cy = (row + 0.5) * cellHeight;
      }
      canvas.drawCircle(Offset(cellWidth / 2, cy), radius, discPaint);
    }

    // 3. Pending overlay: ghost disc at the targeted column's
    //    landing row, gently pulsing.
    if (pendingDisc != null && pendingLandingRow != null) {
      final pulseT = 0.6 + (pulseValue * 0.4);
      final ghostColour = _discColour(
        pendingDisc!,
      ).withValues(alpha: 0.5 * pulseT);
      final ghostPaint = Paint()..color = ghostColour;
      final cy = (pendingLandingRow! + 0.5) * cellHeight;
      canvas.drawCircle(Offset(cellWidth / 2, cy), radius, ghostPaint);
    }

    // 4. Subtle grid divider on the LEFT edge of the column (skipped
    //    on column 0 so the leftmost edge isn't double-bordered).
    if (column > 0) {
      final linePaint = Paint()
        ..color = gridLine
        ..strokeWidth = 0.5;
      canvas.drawLine(Offset.zero, Offset(0, size.height), linePaint);
    }
  }

  /// Theme the disc colour by local-vs-peer, NOT by the wire-side
  /// red/yellow naming. Mirrors how TTT picks the X/O colours.
  Color _discColour(C4Disc disc) {
    final isLocal = localDisc != null && disc == localDisc;
    return isLocal ? accent : mutedDisc;
  }

  @override
  bool shouldRepaint(covariant _C4ColumnPainter old) {
    return old.column != column ||
        old.board != board ||
        old.localDisc != localDisc ||
        old.pendingDisc != pendingDisc ||
        old.pendingLandingRow != pendingLandingRow ||
        old.pulseValue != pulseValue ||
        old.dropProgress != dropProgress ||
        old.topSettledRow != topSettledRow ||
        old.accent != accent ||
        old.mutedDisc != mutedDisc ||
        old.cellBg != cellBg ||
        old.gridLine != gridLine;
  }
}
