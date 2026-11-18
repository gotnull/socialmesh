// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/telemetry/traceroute_log_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/telemetry_log.dart';
import 'package:socialmesh/providers/telemetry_providers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a completed traceroute card shows the round trip time', (
    tester,
  ) async {
    final sentAt = DateTime(2026, 11, 18, 10, 0, 0);
    final timed = TraceRouteLog(
      id: 'timed',
      nodeNum: 0x11111111,
      targetNode: 0x11111111,
      response: true,
      hopsTowards: 1,
      hopsBack: 1,
      sentAt: sentAt,
      timestamp: sentAt.add(const Duration(milliseconds: 3420)),
    );
    final untimed = TraceRouteLog(
      id: 'untimed',
      nodeNum: 0x22222222,
      targetNode: 0x22222222,
      response: true,
      timestamp: sentAt.subtract(const Duration(minutes: 5)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          traceRouteLogsProvider.overrideWith((ref) async => [timed, untimed]),
        ],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: TraceRouteLogScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Round trip 3.4 s'), findsOneWidget);
    expect(find.textContaining('Round trip'), findsOneWidget);

    // Let the loading indicator's 5 s config timeout fire before teardown.
    await tester.pump(const Duration(seconds: 6));
  });
}
