// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/connecting_content.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

Widget _host(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

ConnectionStatusInfo _status() => const ConnectionStatusInfo(
  text: 'Connecting',
  icon: Icons.bluetooth_connected_rounded,
  color: Colors.green,
  showSpinner: true,
);

// The split-flap logo starts each letter from a delayed future; let them
// fire against a torn-down tree so no timer outlives the test.
Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  testWidgets('Cancel is shown when asked for and runs the callback', (
    tester,
  ) async {
    var cancelled = 0;
    await tester.pumpWidget(
      _host(
        ConnectingContent(
          statusInfo: _status(),
          showMeshNode: false,
          showCancel: true,
          onCancel: () => cancelled++,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Cancel'));
    await tester.pump();

    expect(cancelled, 1);
    await _finish(tester);
  });

  testWidgets('Cancel label follows the app locale', (tester) async {
    await tester.pumpWidget(
      _host(
        ConnectingContent(
          statusInfo: _status(),
          showMeshNode: false,
          showCancel: true,
          onCancel: () {},
        ),
        locale: const Locale('de'),
      ),
    );
    await tester.pump();

    expect(find.text('Abbrechen'), findsOneWidget);
    expect(find.text('Cancel'), findsNothing);
    await _finish(tester);
  });

  testWidgets('no Cancel when the caller does not offer one', (tester) async {
    await tester.pumpWidget(
      _host(ConnectingContent(statusInfo: _status(), showMeshNode: false)),
    );
    await tester.pump();

    expect(find.byType(TextButton), findsNothing);
    await _finish(tester);
  });
}
