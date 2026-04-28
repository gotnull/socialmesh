// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Widget tests for [TttBoardWidget].
///
/// Pinned behaviour:
///   - 9 cells render with stable `ttt_cell_<i>` keys,
///   - tapping an empty cell when `enabled: true` invokes onCellTap
///     with the right cell index,
///   - tapping an occupied cell never invokes onCellTap,
///   - tapping any cell when `enabled: false` (peer's turn /
///     terminal / mid-game block) never invokes onCellTap,
///   - X / O marks render as semantically-labelled custom paints,
///   - the optimistic pending overlay renders the ghost mark
///     immediately and locks the cell against re-taps.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/sip/play/games/tictactoe/ttt_board_widget.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/services/protocol/sip/play/games/tictactoe/ttt_payload.dart';
import 'package:socialmesh/services/protocol/sip/play/games/tictactoe/ttt_rules.dart';

MaterialApp _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SizedBox(width: 240, height: 240, child: child)),
);

Finder _cell(int index) => find.byKey(ValueKey<String>('ttt_cell_$index'));

void main() {
  group('TttBoardWidget', () {
    testWidgets('renders 9 cells with stable keys', (tester) async {
      await tester.pumpWidget(
        _wrap(
          TttBoardWidget(
            board: TttBoard.empty(),
            localMark: TttMark.x,
            enabled: true,
            onCellTap: (_) {},
          ),
        ),
      );
      for (var i = 0; i < 9; i += 1) {
        expect(_cell(i), findsOneWidget, reason: 'cell $i must exist');
      }
    });

    testWidgets('tap on empty cell when enabled fires onCellTap with index', (
      tester,
    ) async {
      var lastTapped = -1;
      await tester.pumpWidget(
        _wrap(
          TttBoardWidget(
            board: TttBoard.empty(),
            localMark: TttMark.x,
            enabled: true,
            onCellTap: (cell) => lastTapped = cell,
          ),
        ),
      );
      await tester.tap(_cell(2));
      // Bounded pump — the parent's pulse animation runs forever
      // by design (overlay breathing) so pumpAndSettle would deadlock.
      await tester.pump(const Duration(milliseconds: 50));
      expect(lastTapped, equals(2));
    });

    testWidgets('tap on occupied cell does NOT fire onCellTap', (tester) async {
      var taps = 0;
      final board = TttBoard.empty().apply(0, TttMark.x);
      await tester.pumpWidget(
        _wrap(
          TttBoardWidget(
            board: board,
            localMark: TttMark.x,
            enabled: true,
            onCellTap: (_) => taps += 1,
          ),
        ),
      );
      await tester.tap(_cell(0));
      // Bounded pump — the parent's pulse animation runs forever
      // by design (overlay breathing) so pumpAndSettle would deadlock.
      await tester.pump(const Duration(milliseconds: 50));
      expect(taps, equals(0));
    });

    testWidgets('tap on any cell when enabled=false does NOT fire onCellTap', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          TttBoardWidget(
            board: TttBoard.empty(),
            localMark: TttMark.x,
            enabled: false,
            onCellTap: (_) => taps += 1,
          ),
        ),
      );
      for (var i = 0; i < 9; i += 1) {
        await tester.tap(_cell(i));
      }
      // Bounded pump — the parent's pulse animation runs forever
      // by design (overlay breathing) so pumpAndSettle would deadlock.
      await tester.pump(const Duration(milliseconds: 50));
      expect(taps, equals(0));
    });

    testWidgets('confirmed X / O marks render with semantic labels', (
      tester,
    ) async {
      final board = TttBoard.empty().apply(0, TttMark.x).apply(4, TttMark.o);
      await tester.pumpWidget(
        _wrap(
          TttBoardWidget(
            board: board,
            localMark: TttMark.x,
            enabled: true,
            onCellTap: (_) {},
          ),
        ),
      );
      // Pump past the draw-in animation so the painter is fully drawn.
      // Bounded pump — the parent's pulse animation runs forever
      // by design (overlay breathing) so pumpAndSettle would deadlock.
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.bySemanticsLabel('X'), findsOneWidget);
      expect(find.bySemanticsLabel('O'), findsOneWidget);
    });

    testWidgets('pending move renders the ghost overlay immediately', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          TttBoardWidget(
            board: TttBoard.empty(),
            localMark: TttMark.x,
            enabled: false, // parent locks input while pending
            pendingMove: TttMove(cell: 4, mark: TttMark.x),
            onCellTap: (_) {},
          ),
        ),
      );
      await tester.pump();
      // Pending overlay surfaces a distinct semantics label so screen
      // readers + tests can tell it apart from a confirmed mark.
      expect(find.bySemanticsLabel('X (pending)'), findsOneWidget);
      // No confirmed X has been placed on the board yet.
      expect(find.bySemanticsLabel('X'), findsNothing);
    });

    testWidgets('tapping a cell while pendingMove is set does NOT fire '
        'onCellTap on that cell (interaction lock)', (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _wrap(
          TttBoardWidget(
            board: TttBoard.empty(),
            localMark: TttMark.x,
            enabled: false, // parent passes false while pending in-flight
            pendingMove: TttMove(cell: 4, mark: TttMark.x),
            onCellTap: (_) => taps += 1,
          ),
        ),
      );
      // Tap the pending cell.
      await tester.tap(_cell(4));
      // Tap a different empty cell.
      await tester.tap(_cell(0));
      // The pending overlay's pulse animation never finishes by
      // design — use bounded pumps instead of pumpAndSettle to
      // process the tap callbacks.
      await tester.pump(const Duration(milliseconds: 50));
      expect(
        taps,
        equals(0),
        reason:
            'while a pending overlay is active the parent passes '
            'enabled:false; no taps should propagate to onCellTap',
      );
    });
  });
}
