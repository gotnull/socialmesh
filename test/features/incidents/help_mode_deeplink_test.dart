// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PR-10B: notification tap deep-link safety + responder inbox robustness.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/incidents/fixtures/incident_mode_fixtures.dart';
import 'package:socialmesh/features/incidents/models/incident_mode_models.dart';
import 'package:socialmesh/features/incidents/providers/mesh_incident_providers.dart';
import 'package:socialmesh/features/incidents/screens/help_responder_inbox_screen.dart';
import 'package:socialmesh/features/incidents/services/help_location_policy.dart';
import 'package:socialmesh/features/incidents/widgets/help_mode/help_inbound_alert_card.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/services/notifications/notification_service.dart';

MaterialApp _mat(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

void main() {
  group('notification tap payload safety', () {
    test('carries only the routing type and incident id', () {
      final payload = NotificationService.incidentHelpPayload(0xABCD);
      expect(payload, 'incident_help_request:43981');
      // Routing metadata only: no body/coords/name -> no spaces or separators
      // beyond the single type:id colon.
      expect(payload.split(':'), hasLength(2));
      expect(payload.contains(' '), isFalse);
      expect(payload.contains(','), isFalse);
    });

    test('parses to the route type + id the dispatcher expects', () {
      final payload = NotificationService.incidentHelpPayload(7);
      // Mirrors main.dart's `type:targetId` split convention.
      final parts = payload.split(':');
      expect(parts.first, 'incident_help_request');
      expect(parts.sublist(1).join(':'), '7');
    });
  });

  group('responder inbox robustness', () {
    testWidgets('empty / resolved-only -> calm empty state, no crash', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // Resolved/cancelled/expired are already filtered out upstream, so
            // a stale deep-link lands here as an empty list.
            activeHelpRequestsProvider.overrideWith(
              (ref) async => const <IncidentProjection>[],
            ),
          ],
          child: _mat(const HelpResponderInboxScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No active help requests'), findsOneWidget);
    });

    testWidgets('active requests render and are tappable', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            activeHelpRequestsProvider.overrideWith(
              (ref) async => [IncidentModeFixtures.activeWithResponder()],
            ),
          ],
          child: _mat(const HelpResponderInboxScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Help requests'), findsOneWidget); // title
      expect(find.text('Help request active'), findsOneWidget); // tile
    });
  });

  group('Open Map remains deferred (no location implied)', () {
    test('precise location is policy-blocked', () {
      expect(HelpLocationPolicy.canSendPreciseLocation, isFalse);
    });

    testWidgets('Open Map button is disabled when no target is available', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: _mat(
            const HelpInboundAlertCard(
              requesterName: 'peer',
              // Mirrors HelpResponderScreen: Open Map deferred (no incident map
              // deep-link, precise location blocked) -> null -> disabled.
              onOpenMap: null,
            ),
          ),
        ),
      );
      final button = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Open map'),
      );
      expect(button.onPressed, isNull); // disabled, implies no location target
    });
  });
}
