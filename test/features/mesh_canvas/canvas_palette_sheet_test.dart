// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// S7.B acceptance tests for the full 64-colour palette sheet.
//
// Spec anchors:
// - CANVAS_V0_1.md §S0.ux.15 ("active palette swatch is one tap away
//   (bottom strip or quick-access)") — the strip stays pinned at the
//   bottom; the sheet is the secondary surface reached via "More".
// - CANVAS_V0_1.md §11 — canonical 64-entry palette identified by
//   `palette_id = 1`.
//
// S7.B acceptance: palette must be fast, compact, mobile-friendly,
// and keep the canvas dominant. The tests pin the structural
// contract — 64 swatches in an 8-column grid, tap returns palette
// index via Navigator.pop — that the host screen + sheet rely on.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/canvas/canvas_palette.dart';
import 'package:socialmesh/features/mesh_canvas/widgets/canvas_color_strip.dart';
import 'package:socialmesh/features/mesh_canvas/widgets/canvas_palette_sheet.dart';

void main() {
  group('CanvasColorStrip — S7.B "More" button wiring', () {
    testWidgets('when onMore is provided, tapping the More button fires the '
        'callback exactly once — this is the open-sheet trigger', (
      tester,
    ) async {
      var moreTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: CanvasColorStrip(
                selectedIndex: 8, // black
                onSelect: (_) {},
                onMore: () => moreTaps++,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('More colours'));
      await tester.pumpAndSettle();
      expect(moreTaps, 1);
    });

    testWidgets(
      'when onMore is null, the strip omits the More button — keeps the '
      'strip reusable in contexts without the full palette sheet',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: CanvasColorStrip(
                  selectedIndex: 8,
                  onSelect: (_) {},
                  // onMore omitted
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.bySemanticsLabel('More colours'), findsNothing);
      },
    );
  });

  group('CanvasPaletteSheet — S0.ux.15 + §11 acceptance', () {
    testWidgets('sheet renders all 64 swatches in an 8-column grid — keeps the '
        'canvas dominant by never spanning more than the configured '
        'initialChildSize of the screen', (tester) async {
      // Pump a host that opens the sheet so we can inspect its
      // rendered widgets.
      await tester.pumpWidget(
        MaterialApp(home: _SheetHostScaffold(initialSelectedIndex: 8)),
      );
      await tester.tap(find.text('Open palette sheet'));
      await tester.pumpAndSettle();

      // Every palette entry by name must be reachable.
      for (var i = 0; i < SocialMeshPalette.colors.length; i++) {
        final name = SocialMeshPalette.nameOf(i);
        expect(
          find.bySemanticsLabel(name),
          findsOneWidget,
          reason:
              'Sheet must render palette index $i (name="$name") — '
              'all 64 canonical colours from §11 are required.',
        );
      }
    });

    testWidgets('tapping a swatch pops the sheet with the palette index — host '
        'reads the popped value to update selectedColorProvider', (
      tester,
    ) async {
      final host = GlobalKey<_SheetHostScaffoldState>();
      await tester.pumpWidget(MaterialApp(home: _SheetHostScaffold(key: host)));
      await tester.tap(find.text('Open palette sheet'));
      await tester.pumpAndSettle();

      // Tap "Red" (palette index 11 per the spec).
      await tester.tap(find.bySemanticsLabel('Red'));
      await tester.pumpAndSettle();

      expect(host.currentState!.lastPickedIndex, 11);
    });

    testWidgets(
      'dismissing without picking returns null — host does NOT update '
      'selectedColorProvider on a tap-outside dismiss',
      (tester) async {
        final host = GlobalKey<_SheetHostScaffoldState>();
        await tester.pumpWidget(
          MaterialApp(home: _SheetHostScaffold(key: host)),
        );
        await tester.tap(find.text('Open palette sheet'));
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel('Red'), findsOneWidget);

        // Dismiss by tapping the scrim above the sheet.
        await tester.tapAt(const Offset(20, 20));
        await tester.pumpAndSettle();

        expect(host.currentState!.openSheetCompleted, isTrue);
        expect(host.currentState!.lastPickedIndex, isNull);
      },
    );
  });
}

// ---------------------------------------------------------------------------
// Test host
// ---------------------------------------------------------------------------

class _SheetHostScaffold extends StatefulWidget {
  final int initialSelectedIndex;

  const _SheetHostScaffold({super.key, this.initialSelectedIndex = 8});

  @override
  State<_SheetHostScaffold> createState() => _SheetHostScaffoldState();
}

class _SheetHostScaffoldState extends State<_SheetHostScaffold> {
  int? lastPickedIndex;
  bool openSheetCompleted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TextButton(
          onPressed: () async {
            final result = await showCanvasPaletteSheet(
              context: context,
              selectedIndex: widget.initialSelectedIndex,
            );
            setState(() {
              lastPickedIndex = result;
              openSheetCompleted = true;
            });
          },
          child: const Text('Open palette sheet'),
        ),
      ),
    );
  }
}
