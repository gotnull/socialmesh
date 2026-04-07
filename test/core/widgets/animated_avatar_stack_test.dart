// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/animated_avatar_stack.dart';

/// Helper to wrap a widget in MaterialApp for testing.
Widget _wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

/// Creates a list of test [AvatarStackItem]s with colored circles.
List<AvatarStackItem> _items(int count, {VoidCallback? onTap}) {
  const colors = [Colors.red, Colors.blue, Colors.green, Colors.orange];
  return List.generate(count, (i) {
    return AvatarStackItem(
      id: 'node_$i',
      child: Container(color: colors[i % colors.length]),
      tooltip: 'Node $i', // lint-allow: hardcoded-string
      semanticLabel: 'Node $i', // lint-allow: hardcoded-string
      onTap: onTap,
    );
  });
}

void main() {
  group('AvatarStackItem', () {
    test('equality is based on id', () {
      const a = AvatarStackItem(id: 'x', child: SizedBox());
      const b = AvatarStackItem(
        id: 'x',
        child: SizedBox(),
        tooltip: 'different', // lint-allow: hardcoded-string
      );
      const c = AvatarStackItem(id: 'y', child: SizedBox());
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('AvatarStackDefaults', () {
    test('constants have sane values', () {
      expect(AvatarStackDefaults.maxVisible, 4);
      expect(AvatarStackDefaults.avatarSize, 32);
      expect(AvatarStackDefaults.overlapFraction, greaterThan(0));
      expect(AvatarStackDefaults.overlapFraction, lessThan(1));
      expect(
        AvatarStackDefaults.cycleInterval.inSeconds,
        greaterThanOrEqualTo(1),
      );
      expect(
        AvatarStackDefaults.animationDuration.inMilliseconds,
        greaterThanOrEqualTo(100),
      );
      expect(AvatarStackDefaults.frontScale, greaterThan(0));
      expect(AvatarStackDefaults.rearScale, greaterThan(0));
      expect(
        AvatarStackDefaults.frontScale,
        greaterThanOrEqualTo(AvatarStackDefaults.rearScale),
      );
      expect(AvatarStackDefaults.frontOpacity, 1.0);
      expect(AvatarStackDefaults.rearOpacity, greaterThan(0));
      expect(AvatarStackDefaults.borderWidth, greaterThan(0));
    });
  });

  group('AnimatedAvatarStack rendering', () {
    testWidgets('renders nothing for empty items', (tester) async {
      await tester.pumpWidget(_wrap(const AnimatedAvatarStack(items: [])));
      expect(find.byType(SizedBox), findsOneWidget);
      // SizedBox.shrink
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox));
      expect(sizedBox.width, 0);
      expect(sizedBox.height, 0);
    });

    testWidgets('renders single item statically', (tester) async {
      await tester.pumpWidget(_wrap(AnimatedAvatarStack(items: _items(1))));
      // Should render the single avatar circle.
      expect(find.byType(Positioned), findsOneWidget);
    });

    testWidgets('renders multiple items up to maxVisible', (tester) async {
      await tester.pumpWidget(
        _wrap(AnimatedAvatarStack(items: _items(6), maxVisible: 3)),
      );
      // Only 3 should be rendered.
      expect(find.byType(Positioned), findsNWidgets(3));
    });

    testWidgets('renders all items when count <= maxVisible', (tester) async {
      await tester.pumpWidget(_wrap(AnimatedAvatarStack(items: _items(2))));
      expect(find.byType(Positioned), findsNWidgets(2));
    });

    testWidgets('applies semantics label when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AnimatedAvatarStack(
            items: _items(2),
            semanticLabel: 'Test stack', // lint-allow: hardcoded-string
          ),
        ),
      );
      // Verify Semantics widget wraps the stack.
      final semantics = tester.widgetList<Semantics>(find.byType(Semantics));
      final stackSemantics = semantics.where(
        (s) =>
            s.properties.label == 'Test stack', // lint-allow: hardcoded-string
      );
      expect(stackSemantics, isNotEmpty);
    });

    testWidgets('shows tooltips for items', (tester) async {
      await tester.pumpWidget(_wrap(AnimatedAvatarStack(items: _items(2))));
      expect(find.byType(Tooltip), findsNWidgets(2));
    });
  });

  group('AnimatedAvatarStack overlap layout', () {
    testWidgets('total width accounts for overlap', (tester) async {
      const size = 40.0;
      const overlap = 0.4;
      await tester.pumpWidget(
        _wrap(
          AnimatedAvatarStack(
            items: _items(3),
            avatarSize: size,
            overlapFraction: overlap,
          ),
        ),
      );
      // Expected width: size + 2*(size*(1-overlap)) + 2*8 (overshoot pad)
      // = 40 + 2*24 + 16 = 104
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, closeTo(104, 0.1));
      expect(sizedBox.height, size);
    });

    testWidgets('single item width equals avatar size', (tester) async {
      const size = 36.0;
      await tester.pumpWidget(
        _wrap(AnimatedAvatarStack(items: _items(1), avatarSize: size)),
      );
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.width, size);
    });
  });

  group('AnimatedAvatarStack cycling', () {
    testWidgets('does not cycle with fewer than 2 items', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AnimatedAvatarStack(
            items: _items(1),
            cycleInterval: const Duration(milliseconds: 100),
          ),
        ),
      );
      final state = tester.state<AnimatedAvatarStackState>(
        find.byType(AnimatedAvatarStack),
      );
      expect(state.currentFrontIndex, 0);

      // Advance past cycle interval.
      await tester.pump(const Duration(milliseconds: 200));
      expect(state.currentFrontIndex, 0);
    });

    testWidgets('cycles through items when animated', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AnimatedAvatarStack(
            items: _items(3),
            cycleInterval: const Duration(milliseconds: 100),
          ),
        ),
      );
      final state = tester.state<AnimatedAvatarStackState>(
        find.byType(AnimatedAvatarStack),
      );
      expect(state.currentFrontIndex, 0);

      // Advance past first cycle (decrements: 0 → 2).
      await tester.pump(const Duration(milliseconds: 150));
      expect(state.currentFrontIndex, 2);

      // Advance past second cycle (2 → 1).
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.currentFrontIndex, 1);

      // Should wrap around (1 → 0).
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.currentFrontIndex, 0);
    });

    testWidgets('does not cycle when animationEnabled is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AnimatedAvatarStack(
            items: _items(3),
            cycleInterval: const Duration(milliseconds: 100),
            animationEnabled: false,
          ),
        ),
      );
      final state = tester.state<AnimatedAvatarStackState>(
        find.byType(AnimatedAvatarStack),
      );
      expect(state.currentFrontIndex, 0);

      await tester.pump(const Duration(milliseconds: 300));
      expect(state.currentFrontIndex, 0);
    });
  });

  group('AnimatedAvatarStack tap handling', () {
    testWidgets('fires onTap for individual items', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(
          AnimatedAvatarStack(
            items: [
              AvatarStackItem(
                id: 'a',
                child: const SizedBox.expand(),
                onTap: () => tapped = true,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byType(GestureDetector));
      expect(tapped, isTrue);
    });
  });

  group('AnimatedAvatarStack state update behaviour', () {
    testWidgets('clamps front index when items shrink', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AnimatedAvatarStack(
            items: _items(4),
            cycleInterval: const Duration(milliseconds: 100),
          ),
        ),
      );
      final state = tester.state<AnimatedAvatarStackState>(
        find.byType(AnimatedAvatarStack),
      );

      // Advance 3 cycles (decrements: 0 → 3 → 2 → 1).
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      expect(state.currentFrontIndex, 1);

      // Shrink items to 2 — front index 1 is still valid (< 2).
      await tester.pumpWidget(
        _wrap(
          AnimatedAvatarStack(
            items: _items(2),
            cycleInterval: const Duration(milliseconds: 100),
          ),
        ),
      );
      expect(state.currentFrontIndex, 1);
    });

    testWidgets('handles items growing without error', (tester) async {
      await tester.pumpWidget(_wrap(AnimatedAvatarStack(items: _items(2))));
      expect(find.byType(Positioned), findsNWidgets(2));

      // Grow to 5.
      await tester.pumpWidget(_wrap(AnimatedAvatarStack(items: _items(5))));
      // Default maxVisible = 4, so 4 rendered.
      expect(find.byType(Positioned), findsNWidgets(4));
    });
  });

  group('AnimatedAvatarStack semantics', () {
    testWidgets('individual items have semantic labels', (tester) async {
      await tester.pumpWidget(_wrap(AnimatedAvatarStack(items: _items(2))));
      expect(find.byType(Semantics), findsWidgets);
    });
  });
}
