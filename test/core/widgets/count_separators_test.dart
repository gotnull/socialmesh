// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Counts drawn by the shared chip and header primitives group their digits
// the same way the translated count strings do, in the app's locale.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/section_header.dart';
import 'package:socialmesh/core/widgets/status_filter_chip.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

Widget _app(Locale locale, Widget child) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Material(child: child),
);

Widget _counts() => Column(
  children: [
    StatusFilterChip(
      label: 'All',
      count: 20004,
      isSelected: true,
      onTap: () {},
    ),
    SectionFilterChip(
      label: 'Client',
      count: 20003,
      isSelected: false,
      onTap: () {},
    ),
    const SectionHeader(title: 'Active', count: 20002),
  ],
);

void main() {
  testWidgets('English counts use a comma', (tester) async {
    await tester.pumpWidget(_app(const Locale('en'), _counts()));
    await tester.pumpAndSettle();
    expect(find.text('20,004'), findsOneWidget);
    expect(find.text('20,003'), findsOneWidget);
    expect(find.text('20,002'), findsOneWidget);
  });

  testWidgets('German counts use a full stop', (tester) async {
    await tester.pumpWidget(_app(const Locale('de'), _counts()));
    await tester.pumpAndSettle();
    expect(find.text('20.004'), findsOneWidget);
    expect(find.text('20.003'), findsOneWidget);
    expect(find.text('20.002'), findsOneWidget);
  });
}
