// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/theme.dart';
import 'package:socialmesh/core/widgets/app_scrollbar.dart';

void main() {
  testWidgets('drives the bar from the list it wraps, with the app metrics', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme(AccentColors.magenta),
        home: AppScrollbar(
          controller: controller,
          padding: const EdgeInsets.only(top: 40),
          child: ListView.builder(
            controller: controller,
            itemCount: 200,
            itemBuilder: (_, i) => SizedBox(height: 48, child: Text('$i')),
          ),
        ),
      ),
    );

    final bar = tester.widget<RawScrollbar>(find.byType(RawScrollbar));
    expect(bar.controller, same(controller));
    expect(bar.interactive, isTrue);
    expect(bar.thickness, AppTheme.scrollbarThickness);
    expect(bar.padding, const EdgeInsets.only(top: 40));

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pump();
    expect(controller.offset, greaterThan(0));
  });
}
