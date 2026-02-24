// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/auth/permission_provider.dart';
import 'package:socialmesh/core/auth/permission_service.dart';
import 'package:socialmesh/core/auth/role.dart';
import 'package:socialmesh/features/incidents/screens/create_incident_screen.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

PermissionService _permissionService({Role? role, String? orgId}) {
  return PermissionService(role: role, orgId: orgId);
}

void main() {
  group('CreateIncidentScreen', () {
    testWidgets('title field enforces maxLength 200', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            permissionServiceProvider.overrideWithValue(
              _permissionService(role: Role.operator, orgId: 'org-1'),
            ),
          ],
          child: const MaterialApp(home: CreateIncidentScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Find the title TextField (inside the first TextFormField).
      final allTextFields = find.byType(TextField);
      expect(allTextFields, findsAtLeastNWidgets(1));

      // The first TextField corresponds to the title field.
      final TextField titleField = tester.widget<TextField>(
        allTextFields.first,
      );
      expect(titleField.maxLength, 200);
    });

    testWidgets('description field enforces maxLength 2000', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            permissionServiceProvider.overrideWithValue(
              _permissionService(role: Role.operator, orgId: 'org-1'),
            ),
          ],
          child: const MaterialApp(home: CreateIncidentScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Second TextField is description (inside the second TextFormField).
      final allTextFields = find.byType(TextField);
      expect(allTextFields, findsNWidgets(2));

      final TextField descField = tester.widget<TextField>(allTextFields.at(1));
      expect(descField.maxLength, 2000);
    });

    testWidgets('defaults to routine priority', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            permissionServiceProvider.overrideWithValue(
              _permissionService(role: Role.operator, orgId: 'org-1'),
            ),
          ],
          child: const MaterialApp(home: CreateIncidentScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Routine chip should be selected by default
      final routineChip = find.widgetWithText(ChoiceChip, 'Routine');
      expect(routineChip, findsOneWidget);

      final ChoiceChip chip = tester.widget<ChoiceChip>(routineChip);
      expect(chip.selected, isTrue);
    });

    testWidgets('defaults to operational classification', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            permissionServiceProvider.overrideWithValue(
              _permissionService(role: Role.operator, orgId: 'org-1'),
            ),
          ],
          child: const MaterialApp(home: CreateIncidentScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Operational chip should be selected by default
      final operationalChip = find.widgetWithText(ChoiceChip, 'Operational');
      expect(operationalChip, findsOneWidget);

      final ChoiceChip chip = tester.widget<ChoiceChip>(operationalChip);
      expect(chip.selected, isTrue);
    });

    testWidgets('location capture button shown (optional)', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            permissionServiceProvider.overrideWithValue(
              _permissionService(role: Role.operator, orgId: 'org-1'),
            ),
          ],
          child: const MaterialApp(home: CreateIncidentScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Location capture button present
      expect(find.text('Capture Location'), findsOneWidget);
    });

    testWidgets('title validation rejects empty input', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            permissionServiceProvider.overrideWithValue(
              _permissionService(role: Role.operator, orgId: 'org-1'),
            ),
          ],
          child: const MaterialApp(home: CreateIncidentScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap submit button text inside BouncyTap
      final submitButton = find.text('Create Incident');
      expect(submitButton, findsAtLeastNWidgets(1));

      // Tap on the GestureDetector/BouncyTap containing "Create Incident"
      // The bottomNavigationBar has the submit button.
      // Tapping it with empty title should show validation error.
      await tester.tap(submitButton.last);
      await tester.pumpAndSettle();

      expect(find.text('Title is required'), findsOneWidget);
    });
  });
}
