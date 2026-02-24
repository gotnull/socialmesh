// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/incidents/models/incident.dart';
import 'package:socialmesh/features/incidents/models/incident_transition.dart';
import 'package:socialmesh/features/incidents/widgets/transition_timeline.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

IncidentTransition _transition({
  String id = 't-1',
  String incidentId = 'inc-1',
  IncidentState fromState = IncidentState.draft,
  IncidentState toState = IncidentState.open,
  String actorId = 'user-1',
  String? actorRole = 'operator',
  String? note,
  DateTime? timestamp,
  String? supersededBy,
}) {
  return IncidentTransition(
    id: id,
    incidentId: incidentId,
    fromState: fromState,
    toState: toState,
    actorId: actorId,
    actorRole: actorRole,
    note: note,
    timestamp: timestamp ?? DateTime(2026, 2, 24, 10, 0),
    supersededBy: supersededBy,
  );
}

Widget _testApp(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('TransitionTimeline', () {
    testWidgets('renders empty message when no transitions', (tester) async {
      await tester.pumpWidget(
        _testApp(const TransitionTimeline(transitions: [])),
      );

      expect(find.text('No transition history'), findsOneWidget);
    });

    testWidgets('renders transition entries', (tester) async {
      final transitions = [
        _transition(
          id: 't-1',
          fromState: IncidentState.draft,
          toState: IncidentState.draft,
          note: 'Incident created',
        ),
        _transition(
          id: 't-2',
          fromState: IncidentState.draft,
          toState: IncidentState.open,
          note: 'Submitted for review',
        ),
      ];

      await tester.pumpWidget(
        _testApp(TransitionTimeline(transitions: transitions)),
      );

      // Both transitions should render state badge texts
      expect(find.text('draft'), findsAtLeast(2));
      expect(find.text('open'), findsOneWidget);
      // Notes visible
      expect(find.text('Incident created'), findsOneWidget);
      expect(find.text('Submitted for review'), findsOneWidget);
    });

    testWidgets('shows terminal finality indicator', (tester) async {
      final transitions = [
        _transition(
          id: 't-1',
          fromState: IncidentState.resolved,
          toState: IncidentState.closed,
          actorRole: 'admin',
        ),
      ];

      await tester.pumpWidget(
        _testApp(TransitionTimeline(transitions: transitions)),
      );

      // Terminal state should show finality text
      expect(find.text('Final state — no further transitions'), findsOneWidget);
      // Lock icon
      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    });

    testWidgets('shows superseded label for superseded transitions', (
      tester,
    ) async {
      final transitions = [
        _transition(
          id: 't-1',
          fromState: IncidentState.open,
          toState: IncidentState.assigned,
          supersededBy: 't-2',
        ),
        _transition(
          id: 't-2',
          fromState: IncidentState.open,
          toState: IncidentState.escalated,
        ),
      ];

      await tester.pumpWidget(
        _testApp(TransitionTimeline(transitions: transitions)),
      );

      expect(find.text('superseded'), findsOneWidget);
    });

    testWidgets('displays actor role and truncated actor ID', (tester) async {
      final transitions = [
        _transition(
          id: 't-1',
          actorId: 'abcdefghijklmnop',
          actorRole: 'supervisor',
        ),
      ];

      await tester.pumpWidget(
        _testApp(TransitionTimeline(transitions: transitions)),
      );

      // Actor role visible
      expect(find.textContaining('supervisor'), findsOneWidget);
      // Truncated actor ID
      expect(find.textContaining('abcdefgh...'), findsOneWidget);
    });
  });
}
