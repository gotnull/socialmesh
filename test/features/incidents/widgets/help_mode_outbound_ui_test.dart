// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/features/incidents/fixtures/incident_mode_fixtures.dart';
import 'package:socialmesh/features/incidents/models/incident_mode_models.dart';
import 'package:socialmesh/features/incidents/providers/mesh_incident_providers.dart';
import 'package:socialmesh/features/incidents/services/incident_help_controller.dart';
import 'package:socialmesh/features/incidents/services/incident_mode_store.dart';
import 'package:socialmesh/features/incidents/widgets/help_mode/help_confirm_sheets.dart';
import 'package:socialmesh/features/incidents/widgets/help_mode/help_request_affordance.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/incident_help_providers.dart';

/// In-memory IncidentModeDatabase so the widget test's controller does pure
/// microtask async (no sqflite I/O, which pumpAndSettle cannot drive).
class _MemDb implements IncidentModeDatabase {
  final List<IncidentEvent> events = [];

  @override
  Future<bool> insertIncidentEvent(IncidentEvent e) async {
    if (events.any((x) => x.dedupeKey == e.dedupeKey)) return false;
    events.add(e);
    return true;
  }

  @override
  Future<List<IncidentEvent>> getIncidentEvents(int incidentId) async =>
      events.where((e) => e.incidentId == incidentId).toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  @override
  Future<List<int>> getActiveHelpRequestIds({int limit = 32}) async => const [];

  @override
  Future<int> getMaxIncidentId() async => events.isEmpty
      ? 0
      : events.map((e) => e.incidentId).reduce((a, b) => a > b ? a : b);
}

MaterialApp _mat(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

Widget _app(Widget home) => ProviderScope(child: _mat(home));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('creation sheet submit invokes the controller, never MRRP', (
    tester,
  ) async {
    final mem = _MemDb();
    final store = IncidentModeStore(db: mem);
    final sends = <(Uint8List, List<int>)>[];
    // No discovered peers -> no eligible recipients -> the broadcast path is
    // never taken. The recorder stands in for the transport; the real MRRP
    // dispatcher is never referenced.
    final controller = IncidentHelpController(
      store: store,
      ensureStoreReady: () async {},
      localNodeId: () => 1,
      discoveredPeers: () => const [],
      isTrusted: (_) => false,
      sendHelpEvent: (payload, recipients) async {
        sends.add((payload, recipients));
        return true;
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          incidentHelpControllerProvider.overrideWithValue(controller),
          // Render the pushed active screen from a fixture (no DB coupling);
          // a non-broadcasting state has no infinite loading spinner.
          incidentModeProjectionProvider.overrideWith(
            (ref, id) async => IncidentModeFixtures.activeWithResponder(),
          ),
        ],
        child: _mat(
          const Scaffold(
            body: Stack(
              children: [HelpRequestAffordance(enabledOverride: true)],
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Need help'));
    await tester.pumpAndSettle();
    expect(find.text('Send help request'), findsOneWidget);

    await tester.tap(find.text('Send help request'));
    await tester.pumpAndSettle();

    // The controller persisted a real local incident (createHelpRequest ran).
    expect(await mem.getMaxIncidentId(), greaterThan(0));
    // No eligible peers -> nothing was handed to the transport.
    expect(sends, isEmpty);
  });

  group('confirmation sheets are distinct', () {
    testWidgets('resolve sheet shows safe copy only; Keep request -> false', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showResolveConfirmSheet(context);
                  },
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(
        find.text('Mark yourself safe? Responders will stand down.'),
        findsOneWidget,
      );
      expect(find.text('Cancel this request as a false alarm?'), findsNothing);

      await tester.tap(find.text('Keep request'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('cancel sheet shows false-alarm copy only; confirm -> true', (
      tester,
    ) async {
      bool? result;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    result = await showCancelConfirmSheet(context);
                  },
                  child: const Text('go'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(
        find.text('Cancel this request as a false alarm?'),
        findsOneWidget,
      );
      expect(
        find.text('Mark yourself safe? Responders will stand down.'),
        findsNothing,
      );

      // Confirm via the primary action (button label; sheet title also matches).
      await tester.tap(find.text('Cancel request').last);
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });
  });
}
