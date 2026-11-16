// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/settings/widgets/stale_node_days_slider.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/services/nodes/stale_node_cleanup.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData.dark(),
    home: Material(child: child),
  );

  testWidgets('shows the label, the range ends and a one-day-step slider', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        StaleNodeDaysSlider(label: 'After 7 Days', days: 7, onChanged: (_) {}),
      ),
    );

    expect(find.text('After 7 Days'), findsOneWidget);
    expect(find.text('$kStaleNodeMinDays'), findsOneWidget);
    expect(find.text('$kStaleNodeMaxDays'), findsOneWidget);
    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, kStaleNodeMinDays);
    expect(slider.max, kStaleNodeMaxDays);
    expect(slider.divisions, kStaleNodeMaxDays - kStaleNodeMinDays);
    expect(slider.value, 7);
  });

  testWidgets('dragging reports whole days within the range', (tester) async {
    final reported = <int>[];
    await tester.pumpWidget(
      wrap(StaleNodeDaysSlider(label: 'x', days: 7, onChanged: reported.add)),
    );

    await tester.drag(find.byType(Slider), const Offset(2000, 0));
    await tester.pump();

    expect(reported, isNotEmpty);
    expect(reported.last, kStaleNodeMaxDays);
  });
}
