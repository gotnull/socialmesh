// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Minimal coverage for the operational health badge: each state renders its
// localized operational label.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/health/node_health.dart';
import 'package:socialmesh/features/nodes/widgets/node_health_badge.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

Future<void> _pump(WidgetTester tester, NodeHealthState state) {
  return tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(child: NodeHealthBadge(state: state)),
      ),
    ),
  );
}

void main() {
  const cases = {
    NodeHealthState.fresh: 'Fresh',
    NodeHealthState.stale: 'Stale',
    NodeHealthState.offline: 'Offline',
    NodeHealthState.unknown: 'Unknown',
  };

  cases.forEach((state, label) {
    testWidgets('renders "$label" for $state', (tester) async {
      await _pump(tester, state);
      expect(find.text(label), findsOneWidget);
    });
  });
}
