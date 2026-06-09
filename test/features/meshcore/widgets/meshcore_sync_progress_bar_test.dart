// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MO-4: MeshCoreSyncProgressBar rendering.
//
// Pinned invariants:
//   - Collapses to a zero-size box when no sync is active.
//   - Renders a determinate LinearProgressIndicator (value set) when a
//     sync with a known total is active.
//   - Renders an indeterminate bar (null value) when active without a total.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/meshcore/widgets/meshcore_sync_progress_bar.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

Widget _wrap(MeshCoreSyncProgress progress) {
  return ProviderScope(
    overrides: [meshCoreSyncProgressProvider.overrideWithValue(progress)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: MeshCoreSyncProgressBar()),
    ),
  );
}

void main() {
  testWidgets('collapses when no sync is active', (tester) async {
    await tester.pumpWidget(_wrap(const MeshCoreSyncProgress(active: false)));
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsNothing);
    final box = tester.widget<SizedBox>(find.byType(SizedBox).first);
    expect(box.width == 0.0 || box.height == 0.0, isTrue);
  });

  testWidgets('shows determinate bar with value when total known', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const MeshCoreSyncProgress(active: true, value: 0.4)),
    );
    await tester.pump();

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(0.4, 1e-9));
  });

  testWidgets('shows indeterminate bar when active without total', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(const MeshCoreSyncProgress(active: true, value: null)),
    );
    await tester.pump();

    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, isNull);
  });
}
