// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:socialmesh/features/mesh_services/rns_companion_services_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/providers/rns_companion_providers.dart';
import 'package:socialmesh/services/rns_companion/rns_companion_client.dart';

final _l10n = AppLocalizationsEn();

const String _healthOk =
    '{"ok":true,"service":"rns_companion","version":"0.1","mode":"stub"}';

typedef _PathHandler = Future<http.Response> Function(http.BaseRequest);

/// Builds a MockClient that pre-handles `/health` with a successful
/// payload (so the screen's health-probe short-circuit does not
/// fire) and forwards every other path to [servicesHandler].
MockClient _mock(_PathHandler servicesHandler) {
  return MockClient((req) async {
    if (req.url.path == '/health') {
      return http.Response(_healthOk, 200);
    }
    return servicesHandler(req);
  });
}

Widget _wrap(MockClient mock) {
  final client = RnsCompanionClient(httpClient: mock);
  return ProviderScope(
    overrides: [rnsCompanionClientProvider.overrideWithValue(client)],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: const RnsCompanionServicesScreen(),
    ),
  );
}

void main() {
  testWidgets('renders title, experimental header, and connection hint', (
    tester,
  ) async {
    final mock = _mock((_) async => http.Response('[]', 200));
    await tester.pumpWidget(_wrap(mock));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(_l10n.rnsCompanionServicesTitle), findsWidgets);
    expect(find.text(_l10n.rnsCompanionExperimental), findsOneWidget);
    expect(find.text(_l10n.rnsCompanionConnectionHint), findsOneWidget);
  });

  testWidgets('renders empty state when companion returns no services', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mock = _mock((_) async => http.Response('[]', 200));
    await tester.pumpWidget(_wrap(mock));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    // The "Reload" action label is part of the AnimatedEmptyState
    // so its presence indirectly confirms the empty branch fired.
    expect(find.text(_l10n.rnsCompanionEmptyAction), findsOneWidget);
  });

  testWidgets('renders one tile per service from the stub response', (
    tester,
  ) async {
    final mock = _mock(
      (_) async => http.Response(
        jsonEncode([
          <String, dynamic>{
            'destination': '8f3ac21bdeadbeef0001',
            'name': 'Field Ops Board',
            'type': 'nomadnet',
            'lastSeen': 1714040000,
          },
          <String, dynamic>{
            'destination': '8f3ac21bdeadbeef0002',
            'name': 'Local Notes',
            'type': 'nomadnet',
            'lastSeen': 1714039000,
          },
        ]),
        200,
      ),
    );
    await tester.pumpWidget(_wrap(mock));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Field Ops Board'), findsOneWidget);
    expect(find.text('Local Notes'), findsOneWidget);
  });

  // The end-to-end error-rendering path is verified at two seams:
  //   * the provider test confirms the FutureProvider emits the
  //     typed error;
  //   * the test below pins the friendly-error string mapper.
  // Driving the full FutureProvider error transition through the
  // widget tester is flaky on this Riverpod version (the AsyncError
  // transition is lost across pump/runAsync boundaries); the two
  // seams above prove the same behavior reliably.
  testWidgets('rnsCompanionFriendlyError maps each typed error', (
    tester,
  ) async {
    String? captured;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            captured = [
              rnsCompanionFriendlyError(
                context,
                const RnsCompanionConnectionError('x'),
              ),
              rnsCompanionFriendlyError(
                context,
                const RnsCompanionTimeoutError('x'),
              ),
              rnsCompanionFriendlyError(
                context,
                const RnsCompanionParseError('x'),
              ),
              rnsCompanionFriendlyError(
                context,
                const RnsCompanionNotFoundError('x'),
              ),
              rnsCompanionFriendlyError(context, Exception('boom')),
            ].join('|');
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(captured, isNotNull);
    final parts = captured!.split('|');
    expect(parts[0], _l10n.rnsCompanionErrorConnection);
    expect(parts[1], _l10n.rnsCompanionErrorTimeout);
    expect(parts[2], _l10n.rnsCompanionErrorParse);
    expect(parts[3], _l10n.rnsCompanionErrorNotFound);
    expect(parts[4], _l10n.rnsCompanionErrorGeneric);
  });

  testWidgets('shows loading indicator before the future resolves', (
    tester,
  ) async {
    // Use a short delay rather than a never-completer so no timers
    // leak past the test body.
    final mock = _mock((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return http.Response('[]', 200);
    });
    await tester.pumpWidget(_wrap(mock));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    // Drain the pending future so the test exits cleanly.
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 50));
  });
}
