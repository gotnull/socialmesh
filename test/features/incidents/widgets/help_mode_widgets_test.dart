// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/incidents/fixtures/incident_mode_fixtures.dart';
import 'package:socialmesh/features/incidents/models/incident_mode_models.dart';
import 'package:socialmesh/features/incidents/widgets/help_mode/help_inbound_alert_card.dart';
import 'package:socialmesh/features/incidents/widgets/help_mode/help_request_affordance.dart';
import 'package:socialmesh/features/incidents/widgets/help_mode/help_request_create_sheet.dart';
import 'package:socialmesh/features/incidents/widgets/help_mode/help_requester_active_view.dart';
import 'package:socialmesh/features/incidents/widgets/help_mode/help_responder_view.dart';
import 'package:socialmesh/features/incidents/widgets/help_mode/incident_global_banner.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

Widget _wrapStack(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Stack(children: [child])),
  );
}

void main() {
  group('HelpRequestAffordance feature gating', () {
    testWidgets('hidden when disabled', (tester) async {
      await tester.pumpWidget(
        _wrapStack(const HelpRequestAffordance(enabledOverride: false)),
      );
      expect(find.text('Need help'), findsNothing);
    });

    testWidgets('shown when enabled', (tester) async {
      await tester.pumpWidget(
        _wrapStack(const HelpRequestAffordance(enabledOverride: true)),
      );
      expect(find.text('Need help'), findsOneWidget);
    });

    testWidgets('tapping opens the creation sheet (no send)', (tester) async {
      await tester.pumpWidget(
        _wrapStack(const HelpRequestAffordance(enabledOverride: true)),
      );
      await tester.tap(find.text('Need help'));
      await tester.pumpAndSettle();
      // Creation sheet content is visible; nothing was sent.
      expect(find.text('Send help request'), findsOneWidget);
    });
  });

  group('Help request creation sheet', () {
    testWidgets('submit invokes callback and performs no transport', (
      tester,
    ) async {
      IncidentQuickUpdate? captured;
      var submitted = false;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showHelpRequestCreateSheet(
                context,
                onSubmit: (status) {
                  submitted = true;
                  captured = status;
                },
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Request help'), findsOneWidget);

      await tester.tap(find.text('Send help request'));
      await tester.pumpAndSettle();
      expect(submitted, isTrue);
      expect(captured, isNull); // no status selected
    });
  });

  group('Requester active view', () {
    testWidgets('broadcasting renders searching header', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HelpRequesterActiveView(
            projection: IncidentModeFixtures.broadcasting(),
          ),
        ),
      );
      expect(find.text('Searching for help'), findsOneWidget);
    });

    testWidgets('active with responder shows count and timeline', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HelpRequesterActiveView(
            projection: IncidentModeFixtures.activeWithResponder(),
          ),
        ),
      );
      expect(find.text('1 responders active'), findsOneWidget);
      expect(find.text('Help requested'), findsOneWidget); // timeline entry
      expect(find.text('Responder accepted'), findsOneWidget);
    });

    testWidgets('I\'m safe and Cancel request are distinct actions', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HelpRequesterActiveView(
            projection: IncidentModeFixtures.activeWithResponder(),
          ),
        ),
      );
      expect(find.text('I\'m safe'), findsOneWidget);
      expect(find.text('Cancel request'), findsOneWidget);
    });

    testWidgets('resolved renders All clear', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HelpRequesterActiveView(
            projection: IncidentModeFixtures.resolvedSafe(),
          ),
        ),
      );
      expect(find.text('All clear'), findsOneWidget);
      expect(find.text('I\'m safe'), findsNothing); // no actions when terminal
    });

    testWidgets('cancelled is distinct from resolved', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HelpRequesterActiveView(projection: IncidentModeFixtures.cancelled()),
        ),
      );
      expect(find.text('Request cancelled'), findsOneWidget);
      expect(find.text('All clear'), findsNothing);
    });

    testWidgets('expired renders expired header', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HelpRequesterActiveView(projection: IncidentModeFixtures.expired()),
        ),
      );
      expect(find.text('Request expired'), findsOneWidget);
    });
  });

  group('Inbound alert card', () {
    testWidgets('renders Acknowledge / Respond / Open map', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HelpInboundAlertCard(
            requesterName: IncidentModeFixtures.requesterName,
            onAcknowledge: () {},
            onRespond: () {},
            onOpenMap: () {},
            onDismiss: () {},
          ),
        ),
      );
      expect(find.text('Jordan needs help'), findsOneWidget);
      expect(find.text('Acknowledge'), findsOneWidget);
      expect(find.text('Respond'), findsOneWidget);
      expect(find.text('Open map'), findsOneWidget);
    });
  });

  group('Responder view', () {
    testWidgets('renders responder quick-status chips', (tester) async {
      await tester.pumpWidget(
        _wrap(
          HelpResponderView(
            projection: IncidentModeFixtures.responderArrived(),
            now: DateTime.now(),
          ),
        ),
      );
      expect(find.text('Responding'), findsOneWidget);
      // Chip options unique to the responder set (not also in the timeline).
      expect(find.text('Road blocked'), findsOneWidget);
      expect(find.text('Need backup'), findsOneWidget);
    });
  });

  group('Global banner', () {
    testWidgets('renders active title', (tester) async {
      await tester.pumpWidget(
        _wrap(
          IncidentGlobalBanner(
            projection: IncidentModeFixtures.activeWithResponder(),
            onView: () {},
          ),
        ),
      );
      expect(find.text('Help request active'), findsOneWidget);
    });
  });

  group('PR-8 location honesty', () {
    testWidgets(
      'requester active shows location-off copy, not "shared with responders"',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            HelpRequesterActiveView(
              projection: IncidentModeFixtures.activeWithResponder(),
            ),
          ),
        );
        expect(find.text('Location sharing off'), findsOneWidget);
        // The misleading "shared while active" copy must be gone.
        expect(
          find.text('Shared with responders while this request is active.'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'responder view with no location shows a calm not-shared state',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            HelpResponderView(
              projection:
                  IncidentModeFixtures.broadcasting(), // no location event
              now: DateTime.now(),
            ),
          ),
        );
        expect(find.text('Location not shared yet'), findsOneWidget);
      },
    );

    testWidgets('responder view with a location shows age + accuracy', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HelpResponderView(
            projection: IncidentModeFixtures.responderArrived(),
            now: DateTime.now(),
          ),
        ),
      );
      // Accuracy of the fixture location (12 m), metric, no raw coordinates.
      expect(find.text('Accurate to ~12 m'), findsOneWidget);
      expect(find.text('Location not shared yet'), findsNothing);
    });
  });
}
