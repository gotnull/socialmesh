// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/core/widgets/floating_icons_background.dart';

void main() {
  testWidgets('background follows changes to the selected accent', (
    tester,
  ) async {
    for (final accent in [AccentColors.green, AccentColors.cyan]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme(accent),
          home: const FloatingIconsBackground(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final gradient = tester
          .widgetList<Container>(find.byType(Container))
          .map((container) => container.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.gradient)
          .whereType<RadialGradient>()
          .single;
      expect(gradient.colors.first, accent.withValues(alpha: 0.12));
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('an explicit background accent takes precedence', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme(AccentColors.green),
        home: const FloatingIconsBackground(accentColor: AccentColors.cyan),
      ),
    );
    final gradient = tester
        .widgetList<Container>(find.byType(Container))
        .map((container) => container.decoration)
        .whereType<BoxDecoration>()
        .map((decoration) => decoration.gradient)
        .whereType<RadialGradient>()
        .single;
    expect(gradient.colors.first, AccentColors.cyan.withValues(alpha: 0.12));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
