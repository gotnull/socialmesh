// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/auth/permission.dart';
import 'package:socialmesh/core/auth/permission_provider.dart';
import 'package:socialmesh/core/auth/permission_service.dart';
import 'package:socialmesh/core/auth/role.dart';
import 'package:socialmesh/core/widgets/permission_gate.dart';
import 'package:socialmesh/core/widgets/role_gate.dart';

/// Builds a [PermissionService] for a given [role].
/// Consumer users are represented by null role.
PermissionService _buildService(Role? role, {bool readOnly = false}) {
  return PermissionService(
    role: role,
    orgId: role != null ? 'org-test-123' : null,
    isEntitlementReadOnly: readOnly,
  );
}

/// Wraps [child] in a [ProviderScope] that overrides
/// [permissionServiceProvider] with the given [service].
Widget _harness(PermissionService service, Widget child) {
  return ProviderScope(
    overrides: [permissionServiceProvider.overrideWithValue(service)],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  // -------------------------------------------------------------------
  // PermissionGate — hidden mode
  // -------------------------------------------------------------------
  group('PermissionGate (hidden mode)', () {
    testWidgets('shows child when admin has createIncident', (tester) async {
      final service = _buildService(Role.admin);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.createIncident,
            child: Text('Create'),
          ),
        ),
      );
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('shows child when operator has createIncident', (tester) async {
      final service = _buildService(Role.operator);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.createIncident,
            child: Text('Create'),
          ),
        ),
      );
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('hides child when operator lacks assignIncident', (
      tester,
    ) async {
      final service = _buildService(Role.operator);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.assignIncident,
            child: Text('Assign'),
          ),
        ),
      );
      expect(find.text('Assign'), findsNothing);
      expect(find.byType(SizedBox), findsOneWidget);
    });

    testWidgets('shows assignIncident for supervisor', (tester) async {
      final service = _buildService(Role.supervisor);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.assignIncident,
            child: Text('Assign'),
          ),
        ),
      );
      expect(find.text('Assign'), findsOneWidget);
    });

    testWidgets('shows assignIncident for admin', (tester) async {
      final service = _buildService(Role.admin);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.assignIncident,
            child: Text('Assign'),
          ),
        ),
      );
      expect(find.text('Assign'), findsOneWidget);
    });

    testWidgets('hides child when observer lacks createIncident', (
      tester,
    ) async {
      final service = _buildService(Role.observer);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.createIncident,
            child: Text('Create'),
          ),
        ),
      );
      expect(find.text('Create'), findsNothing);
    });

    testWidgets('hides child for consumer user (null role)', (tester) async {
      final service = _buildService(null);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.createIncident,
            child: Text('Create'),
          ),
        ),
      );
      expect(find.text('Create'), findsNothing);
    });

    testWidgets('consumer user hides all enterprise permissions', (
      tester,
    ) async {
      final service = _buildService(null);
      for (final perm in Permission.values) {
        await tester.pumpWidget(
          _harness(
            service,
            PermissionGate(permission: perm, child: Text(perm.name)),
          ),
        );
        expect(
          find.text(perm.name),
          findsNothing,
          reason: '${perm.name} should be hidden for consumer user',
        );
      }
    });

    testWidgets('manageUsers hidden for supervisor', (tester) async {
      final service = _buildService(Role.supervisor);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.manageUsers,
            child: Text('Manage Users'),
          ),
        ),
      );
      expect(find.text('Manage Users'), findsNothing);
    });

    testWidgets('manageUsers visible for admin', (tester) async {
      final service = _buildService(Role.admin);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.manageUsers,
            child: Text('Manage Users'),
          ),
        ),
      );
      expect(find.text('Manage Users'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------
  // PermissionGate — disabled mode
  // -------------------------------------------------------------------
  group('PermissionGate (disabled mode)', () {
    testWidgets('renders disabled control when permission denied', (
      tester,
    ) async {
      final service = _buildService(Role.operator);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.manageUsers,
            mode: PermissionGateMode.disabled,
            child: Text('Manage Users'),
          ),
        ),
      );
      // Child is rendered (visible but disabled)
      expect(find.text('Manage Users'), findsOneWidget);
      // Wrapped in IgnorePointer(ignoring: true)
      final ignorePointer = tester.widget<IgnorePointer>(
        find
            .ancestor(
              of: find.text('Manage Users'),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      expect(ignorePointer.ignoring, isTrue);
      // Wrapped in Opacity
      final opacity = tester.widget<Opacity>(
        find
            .ancestor(
              of: find.text('Manage Users'),
              matching: find.byType(Opacity),
            )
            .first,
      );
      expect(opacity.opacity, 0.38);
      // Wrapped in Tooltip
      expect(
        find.ancestor(
          of: find.text('Manage Users'),
          matching: find.byType(Tooltip),
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows custom tooltip message', (tester) async {
      final service = _buildService(Role.operator);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.manageUsers,
            mode: PermissionGateMode.disabled,
            deniedTooltip: 'Admin only feature',
            child: Text('Manage'),
          ),
        ),
      );
      final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
      expect(tooltip.message, 'Admin only feature');
    });

    testWidgets('disabled mode renders normally when permission granted', (
      tester,
    ) async {
      final service = _buildService(Role.admin);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.manageUsers,
            mode: PermissionGateMode.disabled,
            child: Text('Manage Users'),
          ),
        ),
      );
      expect(find.text('Manage Users'), findsOneWidget);
      // No IgnorePointer wrapping our child when granted
      final ignorePointers = tester.widgetList<IgnorePointer>(
        find.ancestor(
          of: find.text('Manage Users'),
          matching: find.byType(IgnorePointer),
        ),
      );
      expect(ignorePointers.every((w) => !w.ignoring), isTrue);
      expect(
        find.ancestor(
          of: find.text('Manage Users'),
          matching: find.byType(Tooltip),
        ),
        findsNothing,
      );
    });
  });

  // -------------------------------------------------------------------
  // RoleGate
  // -------------------------------------------------------------------
  group('RoleGate', () {
    testWidgets('shows child when role meets threshold', (tester) async {
      final service = _buildService(Role.admin);
      await tester.pumpWidget(
        _harness(
          service,
          const RoleGate(minRole: Role.admin, child: Text('Admin Panel')),
        ),
      );
      expect(find.text('Admin Panel'), findsOneWidget);
    });

    testWidgets('hides child when role below threshold', (tester) async {
      final service = _buildService(Role.supervisor);
      await tester.pumpWidget(
        _harness(
          service,
          const RoleGate(minRole: Role.admin, child: Text('Admin Panel')),
        ),
      );
      expect(find.text('Admin Panel'), findsNothing);
    });

    testWidgets('hides child for consumer user', (tester) async {
      final service = _buildService(null);
      await tester.pumpWidget(
        _harness(
          service,
          const RoleGate(
            minRole: Role.observer,
            child: Text('Enterprise Content'),
          ),
        ),
      );
      expect(find.text('Enterprise Content'), findsNothing);
    });

    testWidgets('supervisor meets supervisor threshold', (tester) async {
      final service = _buildService(Role.supervisor);
      await tester.pumpWidget(
        _harness(
          service,
          const RoleGate(
            minRole: Role.supervisor,
            child: Text('Supervisor Content'),
          ),
        ),
      );
      expect(find.text('Supervisor Content'), findsOneWidget);
    });

    testWidgets('admin meets supervisor threshold', (tester) async {
      final service = _buildService(Role.admin);
      await tester.pumpWidget(
        _harness(
          service,
          const RoleGate(
            minRole: Role.supervisor,
            child: Text('Supervisor Content'),
          ),
        ),
      );
      expect(find.text('Supervisor Content'), findsOneWidget);
    });

    testWidgets('operator below supervisor threshold', (tester) async {
      final service = _buildService(Role.operator);
      await tester.pumpWidget(
        _harness(
          service,
          const RoleGate(
            minRole: Role.supervisor,
            child: Text('Supervisor Content'),
          ),
        ),
      );
      expect(find.text('Supervisor Content'), findsNothing);
    });

    testWidgets('observer meets observer threshold', (tester) async {
      final service = _buildService(Role.observer);
      await tester.pumpWidget(
        _harness(
          service,
          const RoleGate(minRole: Role.observer, child: Text('Read Only')),
        ),
      );
      expect(find.text('Read Only'), findsOneWidget);
    });
  });

  // -------------------------------------------------------------------
  // Gates react to provider changes
  // -------------------------------------------------------------------
  group('Gates react to claims changes', () {
    testWidgets('PermissionGate updates when role changes', (tester) async {
      // Start as operator — assignIncident denied
      final container = ProviderContainer(
        overrides: [
          permissionServiceProvider.overrideWithValue(
            _buildService(Role.operator),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: PermissionGate(
                permission: Permission.assignIncident,
                child: Text('Assign'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Assign'), findsNothing);

      // Upgrade to supervisor — assignIncident allowed
      container.updateOverrides([
        permissionServiceProvider.overrideWithValue(
          _buildService(Role.supervisor),
        ),
      ]);
      await tester.pump();
      expect(find.text('Assign'), findsOneWidget);

      container.dispose();
    });

    testWidgets('RoleGate updates when role changes', (tester) async {
      final container = ProviderContainer(
        overrides: [
          permissionServiceProvider.overrideWithValue(
            _buildService(Role.operator),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: RoleGate(
                minRole: Role.supervisor,
                child: Text('Supervisor Only'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Supervisor Only'), findsNothing);

      // Upgrade to admin — above supervisor threshold
      container.updateOverrides([
        permissionServiceProvider.overrideWithValue(_buildService(Role.admin)),
      ]);
      await tester.pump();
      expect(find.text('Supervisor Only'), findsOneWidget);

      container.dispose();
    });
  });

  // -------------------------------------------------------------------
  // Observer role — sees data, no actions
  // -------------------------------------------------------------------
  group('Observer sees data but not actions', () {
    testWidgets('observer can view team incidents', (tester) async {
      final service = _buildService(Role.observer);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.viewTeamIncidents,
            child: Text('View Incidents'),
          ),
        ),
      );
      expect(find.text('View Incidents'), findsOneWidget);
    });

    testWidgets('observer can view team tasks', (tester) async {
      final service = _buildService(Role.observer);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.viewTeamTasks,
            child: Text('View Tasks'),
          ),
        ),
      );
      expect(find.text('View Tasks'), findsOneWidget);
    });

    testWidgets('observer cannot create incident', (tester) async {
      final service = _buildService(Role.observer);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.createIncident,
            child: Text('Create Incident'),
          ),
        ),
      );
      expect(find.text('Create Incident'), findsNothing);
    });

    testWidgets('observer cannot export reports', (tester) async {
      final service = _buildService(Role.observer);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.exportReports,
            child: Text('Export'),
          ),
        ),
      );
      expect(find.text('Export'), findsNothing);
    });

    testWidgets('observer denied all 15 write actions', (tester) async {
      final service = _buildService(Role.observer);
      const writeActions = [
        Permission.createIncident,
        Permission.submitIncident,
        Permission.assignIncident,
        Permission.escalateIncident,
        Permission.resolveIncident,
        Permission.closeIncident,
        Permission.cancelIncident,
        Permission.createFieldReport,
        Permission.createTask,
        Permission.assignTask,
        Permission.completeTask,
        Permission.exportReports,
        Permission.manageUsers,
        Permission.manageDevices,
        Permission.configureOrgSettings,
      ];

      for (final perm in writeActions) {
        await tester.pumpWidget(
          _harness(
            service,
            PermissionGate(permission: perm, child: Text(perm.name)),
          ),
        );
        expect(
          find.text(perm.name),
          findsNothing,
          reason: '${perm.name} should be hidden for observer',
        );
      }
    });
  });

  // -------------------------------------------------------------------
  // Operator visibility — create/escalate yes, assign/close no
  // -------------------------------------------------------------------
  group('Operator visibility', () {
    testWidgets('operator sees createIncident', (tester) async {
      final service = _buildService(Role.operator);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.createIncident,
            child: Text('Create'),
          ),
        ),
      );
      expect(find.text('Create'), findsOneWidget);
    });

    testWidgets('operator sees escalateIncident', (tester) async {
      final service = _buildService(Role.operator);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.escalateIncident,
            child: Text('Escalate'),
          ),
        ),
      );
      expect(find.text('Escalate'), findsOneWidget);
    });

    testWidgets('operator hidden from assignIncident', (tester) async {
      final service = _buildService(Role.operator);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.assignIncident,
            child: Text('Assign'),
          ),
        ),
      );
      expect(find.text('Assign'), findsNothing);
    });

    testWidgets('operator hidden from closeIncident', (tester) async {
      final service = _buildService(Role.operator);
      await tester.pumpWidget(
        _harness(
          service,
          const PermissionGate(
            permission: Permission.closeIncident,
            child: Text('Close'),
          ),
        ),
      );
      expect(find.text('Close'), findsNothing);
    });
  });
}
