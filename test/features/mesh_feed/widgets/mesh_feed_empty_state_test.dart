// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/widgets/animated_empty_state.dart';
import 'package:socialmesh/features/mesh_feed/widgets/mesh_feed_empty_state.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(body: child),
    ),
  );
}

void main() {
  group('MeshFeedEmptyState', () {
    testWidgets('renders Signals-style two-line empty state', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        _wrap(MeshFeedEmptyState(onCompose: () => tapped = true)),
      );
      await tester.pump();

      expect(find.byType(AnimatedEmptyState), findsOneWidget);
      expect(find.text('Create Post'), findsOneWidget);
      expect(
        find.text('Be the first to broadcast\nShare something with the mesh'),
        findsOneWidget,
      );

      await tester.tap(find.text('Create Post'));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('filtered mode uses animated empty state and clears filters', (
      tester,
    ) async {
      var cleared = false;

      await tester.pumpWidget(
        _wrap(MeshFeedEmptyState.filtered(onShowAll: () => cleared = true)),
      );
      await tester.pump();

      expect(find.byType(AnimatedEmptyState), findsOneWidget);
      expect(find.text('All'), findsOneWidget);

      await tester.tap(find.text('All'));
      await tester.pump();

      expect(cleared, isTrue);
    });
  });
}
