// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/core/widgets/positioned_list_scrollbar.dart';

const double _viewport = 600;
const double _itemHeight = 60;

class _Harness {
  final positions = ItemPositionsListener.create();
  final controller = ItemScrollController();
  int dragToEndCalls = 0;

  Widget build(int itemCount) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            height: _viewport,
            child: PositionedListScrollbar(
              itemCount: itemCount,
              itemPositionsListener: positions,
              itemScrollController: controller,
              onDragToEnd: () => dragToEndCalls++,
              child: ScrollablePositionedList.builder(
                itemCount: itemCount,
                itemPositionsListener: positions,
                itemScrollController: controller,
                itemBuilder: (context, index) =>
                    SizedBox(height: _itemHeight, child: Text('Item $index')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int get firstVisibleIndex => positions.itemPositions.value
      .where((p) => p.itemTrailingEdge > 0)
      .map((p) => p.index)
      .reduce((a, b) => a < b ? a : b);
}

Finder get _thumb => find.descendant(
  of: find.byType(PositionedListScrollbar),
  matching: find.byType(AnimatedOpacity),
);

// The thumb joins the tree once the list has reported positions and the bar
// has been shown, so "not in the tree" counts as hidden.
double _thumbOpacity(WidgetTester tester) => _thumb.evaluate().isEmpty
    ? 0
    : tester.widget<AnimatedOpacity>(_thumb).opacity;

Future<void> _scrollList(WidgetTester tester) async {
  await tester.drag(find.text('Item 2'), const Offset(0, -120));
  await tester.pump();
}

void main() {
  group('PositionedListScrollMetrics.from', () {
    test('returns null before anything is laid out', () {
      expect(PositionedListScrollMetrics.from(const []), isNull);
    });

    test('counts the hidden part of the top item and partial items', () {
      final metrics = PositionedListScrollMetrics.from(const [
        ItemPosition(index: 10, itemLeadingEdge: -0.05, itemTrailingEdge: 0.05),
        ItemPosition(index: 11, itemLeadingEdge: 0.05, itemTrailingEdge: 0.95),
        ItemPosition(index: 12, itemLeadingEdge: 0.95, itemTrailingEdge: 1.05),
      ])!;
      expect(metrics.offsetItems, closeTo(10.5, 1e-9));
      expect(metrics.visibleItems, closeTo(2.0, 1e-9));
    });

    test('ignores items entirely outside the viewport', () {
      final metrics = PositionedListScrollMetrics.from(const [
        ItemPosition(index: 3, itemLeadingEdge: -0.3, itemTrailingEdge: -0.1),
        ItemPosition(index: 4, itemLeadingEdge: 0, itemTrailingEdge: 1),
      ])!;
      expect(metrics.offsetItems, 4);
      expect(metrics.visibleItems, 1);
    });
  });

  group('PositionedListScrollbar', () {
    testWidgets('draws no thumb when the list fits', (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.build(5));
      await tester.pump();
      expect(_thumb, findsNothing);
    });

    testWidgets('appears while the list scrolls and fades afterwards', (
      tester,
    ) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.build(200));
      await tester.pump();
      expect(_thumbOpacity(tester), 0);

      await _scrollList(tester);
      expect(_thumbOpacity(tester), 1);

      await tester.pump(AppTheme.scrollbarTimeToFade);
      await tester.pump(AppTheme.scrollbarFadeDuration);
      expect(_thumbOpacity(tester), 0);
    });

    testWidgets('dragging the thumb jumps through the list', (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.build(200));
      await tester.pump();
      await _scrollList(tester);

      final start = tester.getCenter(_thumb);
      final gesture = await tester.startGesture(start);
      await gesture.moveBy(const Offset(0, 20));
      await gesture.moveBy(const Offset(0, _viewport / 2 - 20));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      // Half the track maps to roughly half of the 190 scrollable items.
      expect(harness.firstVisibleIndex, inInclusiveRange(80, 110));
      expect(harness.dragToEndCalls, 0);
    });

    testWidgets('dragging to the bottom hands off to onDragToEnd once', (
      tester,
    ) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.build(200));
      await tester.pump();
      await _scrollList(tester);

      final gesture = await tester.startGesture(tester.getCenter(_thumb));
      await gesture.moveBy(const Offset(0, 20));
      await gesture.moveBy(const Offset(0, _viewport));
      await tester.pump();
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(harness.dragToEndCalls, 1);
    });

    testWidgets('ignores touches once faded', (tester) async {
      final harness = _Harness();
      await tester.pumpWidget(harness.build(200));
      await tester.pump();
      await _scrollList(tester);
      await tester.pump(AppTheme.scrollbarTimeToFade);
      await tester.pump(AppTheme.scrollbarFadeDuration);

      final ignore = tester.widget<IgnorePointer>(
        find.ancestor(of: _thumb, matching: find.byType(IgnorePointer)).first,
      );
      expect(ignore.ignoring, isTrue);
    });
  });
}
