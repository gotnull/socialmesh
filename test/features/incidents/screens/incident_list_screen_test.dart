// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/auth/permission_provider.dart';
import 'package:socialmesh/core/auth/permission_service.dart';
import 'package:socialmesh/core/auth/role.dart';
import 'package:socialmesh/features/incidents/models/incident.dart';
import 'package:socialmesh/features/incidents/providers/incident_providers.dart';
import 'package:socialmesh/features/incidents/screens/incident_list_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a [PermissionService] with the given [role] and [orgId].
PermissionService _permissionService({Role? role, String? orgId}) {
  return PermissionService(role: role, orgId: orgId);
}

List<Incident> _sampleIncidents() {
  return [
    Incident(
      id: 'inc-1',
      orgId: 'org-1',
      title: 'Fire alarm triggered in building A',
      state: IncidentState.open,
      priority: IncidentPriority.immediate,
      classification: IncidentClassification.safety,
      ownerId: 'user-1',
      createdAt: DateTime(2026, 2, 24, 10, 0),
      updatedAt: DateTime(2026, 2, 24, 10, 0),
    ),
    Incident(
      id: 'inc-2',
      orgId: 'org-1',
      title: 'Network outage in sector 7',
      state: IncidentState.draft,
      priority: IncidentPriority.routine,
      classification: IncidentClassification.comms,
      ownerId: 'user-2',
      assigneeId: 'user-1',
      createdAt: DateTime(2026, 2, 24, 9, 30),
      updatedAt: DateTime(2026, 2, 24, 9, 30),
    ),
  ];
}

void main() {
  group('IncidentListScreen', () {
    testWidgets('shows empty state when no incidents', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            incidentListProvider.overrideWith(
              (ref) => Future.value(<Incident>[]),
            ),
            permissionServiceProvider.overrideWithValue(
              _permissionService(role: Role.operator, orgId: 'org-1'),
            ),
          ],
          child: const MaterialApp(home: IncidentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Empty state elements
      expect(find.text('No incidents'), findsOneWidget);
      expect(
        find.text(
          'Incidents track operational events from creation '
          'through resolution. Create one to get started.',
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    });

    testWidgets('empty state create button visible for operator', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            incidentListProvider.overrideWith(
              (ref) => Future.value(<Incident>[]),
            ),
            permissionServiceProvider.overrideWithValue(
              _permissionService(role: Role.operator, orgId: 'org-1'),
            ),
          ],
          child: const MaterialApp(home: IncidentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Operator can create incidents
      expect(find.text('Create Incident'), findsOneWidget);
    });

    testWidgets('empty state create button hidden for observer (RBAC)', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            incidentListProvider.overrideWith(
              (ref) => Future.value(<Incident>[]),
            ),
            permissionServiceProvider.overrideWithValue(
              _permissionService(role: Role.observer, orgId: 'org-1'),
            ),
          ],
          child: const MaterialApp(home: IncidentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Observer cannot create incidents
      expect(find.text('Create Incident'), findsNothing);
    });

    testWidgets('shows incident tiles when data present', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            incidentListProvider.overrideWith(
              (ref) => Future.value(_sampleIncidents()),
            ),
            permissionServiceProvider.overrideWithValue(
              _permissionService(role: Role.operator, orgId: 'org-1'),
            ),
          ],
          child: const MaterialApp(home: IncidentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fire alarm triggered in building A'), findsOneWidget);
      expect(find.text('Network outage in sector 7'), findsOneWidget);
    });

    testWidgets('app bar create button hidden for observer', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            incidentListProvider.overrideWith(
              (ref) => Future.value(_sampleIncidents()),
            ),
            permissionServiceProvider.overrideWithValue(
              _permissionService(role: Role.observer, orgId: 'org-1'),
            ),
          ],
          child: const MaterialApp(home: IncidentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // App bar add button should be hidden for observer
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets('app bar create button visible for admin', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            incidentListProvider.overrideWith(
              (ref) => Future.value(_sampleIncidents()),
            ),
            permissionServiceProvider.overrideWithValue(
              _permissionService(role: Role.admin, orgId: 'org-1'),
            ),
          ],
          child: const MaterialApp(home: IncidentListScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Admin can see the add button
      expect(find.byIcon(Icons.add), findsOneWidget);
    });
  });
}
