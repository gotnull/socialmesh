// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/auth/permission.dart';
import 'package:socialmesh/core/auth/permission_context.dart';
import 'package:socialmesh/core/auth/permission_matrix.dart';
import 'package:socialmesh/core/auth/permission_service.dart';
import 'package:socialmesh/core/auth/role.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  PermissionService buildService(Role? role, {bool readOnly = false}) {
    return PermissionService(
      role: role,
      orgId: role != null ? 'org-test-123' : null,
      isEntitlementReadOnly: readOnly,
    );
  }

  // ---------------------------------------------------------------------------
  // Role enum
  // ---------------------------------------------------------------------------

  group('Role', () {
    test('authority ordering', () {
      expect(Role.admin.hasAuthority(Role.supervisor), isTrue);
      expect(Role.supervisor.hasAuthority(Role.operator), isTrue);
      expect(Role.operator.hasAuthority(Role.observer), isTrue);
      expect(Role.observer.hasAuthority(Role.admin), isFalse);
    });

    test('fromString round-trip', () {
      for (final role in Role.values) {
        expect(Role.fromString(role.name), role);
      }
      expect(Role.fromString(null), isNull);
      expect(Role.fromString('unknown'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Matrix completeness
  // ---------------------------------------------------------------------------

  group('PermissionMatrix completeness', () {
    test('all 68 cells are populated', () {
      for (final action in Permission.values) {
        for (final role in Role.values) {
          final cell = PermissionMatrix.lookup(action, role);
          expect(
            cell,
            isNotNull,
            reason: '${action.name} x ${role.name} missing from matrix',
          );
        }
      }
      // 17 x 4 = 68
      expect(Permission.values.length, 17);
      expect(Role.values.length, 4);
    });
  });

  // ---------------------------------------------------------------------------
  // Full 68-cell matrix via PermissionService.can()
  // ---------------------------------------------------------------------------

  // Expected outcomes from RBAC.md table.
  // true = Y, false = N, null = Y* (ownerOnly -- can() without context => false)
  final Map<Permission, Map<Role, bool?>> expectedMatrix = {
    Permission.createIncident: {
      Role.admin: true,
      Role.supervisor: true,
      Role.operator: true,
      Role.observer: false,
    },
    Permission.submitIncident: {
      Role.admin: true,
      Role.supervisor: true,
      Role.operator: true,
      Role.observer: false,
    },
    Permission.assignIncident: {
      Role.admin: true,
      Role.supervisor: true,
      Role.operator: false,
      Role.observer: false,
    },
    Permission.escalateIncident: {
      Role.admin: true,
      Role.supervisor: true,
      Role.operator: true,
      Role.observer: false,
    },
    Permission.resolveIncident: {
      Role.admin: true,
      Role.supervisor: true,
      Role.operator: null, // Y*
      Role.observer: false,
    },
    Permission.closeIncident: {
      Role.admin: true,
      Role.supervisor: true,
      Role.operator: false,
      Role.observer: false,
    },
    Permission.cancelIncident: {
      Role.admin: true,
      Role.supervisor: true,
      Role.operator: false,
      Role.observer: false,
    },
    Permission.createFieldReport: {
      Role.admin: true,
      Role.supervisor: true,
      Role.operator: true,
      Role.observer: false,
    },
    Permission.createTask: {
      Role.admin: true,
      Role.supervisor: true,
      Role.operator: false,
      Role.observer: false,
    },
    Permission.assignTask: {
      Role.admin: true,
      Role.supervisor: true,
      Role.operator: false,
      Role.observer: false,
    },
    Permission.completeTask: {
      Role.admin: true,
      Role.supervisor: true,
      Role.operator: null, // Y*
      Role.observer: false,
    },
    Permission.viewTeamIncidents: {
      Role.admin: true,
      Role.supervisor: true,
      Role.operator: true,
      Role.observer: true,
    },
    Permission.viewTeamTasks: {
      Role.admin: true,
      Role.supervisor: true,
      Role.operator: true,
      Role.observer: true,
    },
    Permission.exportReports: {
      Role.admin: true,
      Role.supervisor: true,
      Role.operator: false,
      Role.observer: false,
    },
    Permission.manageUsers: {
      Role.admin: true,
      Role.supervisor: false,
      Role.operator: false,
      Role.observer: false,
    },
    Permission.manageDevices: {
      Role.admin: true,
      Role.supervisor: false,
      Role.operator: false,
      Role.observer: false,
    },
    Permission.configureOrgSettings: {
      Role.admin: true,
      Role.supervisor: false,
      Role.operator: false,
      Role.observer: false,
    },
  };

  group('PermissionService.can() -- 68-cell matrix', () {
    for (final action in Permission.values) {
      for (final role in Role.values) {
        final expected = expectedMatrix[action]![role];
        // null means Y* (ownerOnly) -- can() without context returns false.
        final expectedBool = expected ?? false;

        test('${action.name} x ${role.name} -> $expectedBool', () {
          final service = buildService(role);
          expect(service.can(action), expectedBool);
        });
      }
    }
  });

  // ---------------------------------------------------------------------------
  // Consumer user (no role) -- all 17 denied
  // ---------------------------------------------------------------------------

  group('Consumer user (no role)', () {
    test('all 17 permissions denied', () {
      final service = buildService(null);
      for (final action in Permission.values) {
        expect(
          service.can(action),
          isFalse,
          reason: '${action.name} should be denied for consumer user',
        );
      }
    });

    test('canWith also denied', () {
      final service = buildService(null);
      final ctx = const PermissionContext(currentUserId: 'uid-001');
      for (final action in Permission.values) {
        expect(service.canWith(action, ctx), isFalse);
      }
    });

    test('currentRole and currentOrgId are null', () {
      final service = buildService(null);
      expect(service.currentRole, isNull);
      expect(service.currentOrgId, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Y* owner-exception paths
  // ---------------------------------------------------------------------------

  group('Y* owner-exception: resolveIncident', () {
    test('operator resolving OWN incident -> allow', () {
      final service = buildService(Role.operator);
      final ctx = const PermissionContext(
        incidentAssigneeId: 'uid-op',
        currentUserId: 'uid-op',
      );
      expect(service.canWith(Permission.resolveIncident, ctx), isTrue);
    });

    test('operator resolving NON-OWN incident -> deny', () {
      final service = buildService(Role.operator);
      final ctx = const PermissionContext(
        incidentAssigneeId: 'uid-someone-else',
        currentUserId: 'uid-op',
      );
      expect(service.canWith(Permission.resolveIncident, ctx), isFalse);
    });

    test('supervisor resolving any incident -> allow (no ownership check)', () {
      final service = buildService(Role.supervisor);
      final ctx = const PermissionContext(
        incidentAssigneeId: 'uid-someone-else',
        currentUserId: 'uid-sup',
      );
      expect(service.canWith(Permission.resolveIncident, ctx), isTrue);
    });

    test('admin resolving any incident -> allow', () {
      final service = buildService(Role.admin);
      final ctx = const PermissionContext(
        incidentAssigneeId: 'uid-someone-else',
        currentUserId: 'uid-admin',
      );
      expect(service.canWith(Permission.resolveIncident, ctx), isTrue);
    });

    test('observer resolving own incident -> deny', () {
      final service = buildService(Role.observer);
      final ctx = const PermissionContext(
        incidentAssigneeId: 'uid-obs',
        currentUserId: 'uid-obs',
      );
      expect(service.canWith(Permission.resolveIncident, ctx), isFalse);
    });
  });

  group('Y* owner-exception: completeTask', () {
    test('operator completing OWN task -> allow', () {
      final service = buildService(Role.operator);
      final ctx = const PermissionContext(
        taskAssigneeId: 'uid-op',
        currentUserId: 'uid-op',
      );
      expect(service.canWith(Permission.completeTask, ctx), isTrue);
    });

    test('operator completing NON-OWN task -> deny', () {
      final service = buildService(Role.operator);
      final ctx = const PermissionContext(
        taskAssigneeId: 'uid-other',
        currentUserId: 'uid-op',
      );
      expect(service.canWith(Permission.completeTask, ctx), isFalse);
    });

    test('supervisor completing any task -> allow', () {
      final service = buildService(Role.supervisor);
      final ctx = const PermissionContext(
        taskAssigneeId: 'uid-other',
        currentUserId: 'uid-sup',
      );
      expect(service.canWith(Permission.completeTask, ctx), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Entitlement precedence
  // ---------------------------------------------------------------------------

  group('Entitlement precedence (readOnly)', () {
    test('supervisor with readOnly cannot perform any write action', () {
      final service = buildService(Role.supervisor, readOnly: true);
      for (final action in Permission.values) {
        final isRead = !PermissionMatrix.isWriteAction(action);
        expect(
          service.can(action),
          isRead,
          reason:
              '${action.name} expected ${isRead ? "allowed" : "denied"} '
              'under readOnly entitlement',
        );
      }
    });

    test('admin with readOnly cannot perform write actions', () {
      final service = buildService(Role.admin, readOnly: true);
      // Write actions denied
      expect(service.can(Permission.createIncident), isFalse);
      expect(service.can(Permission.assignIncident), isFalse);
      expect(service.can(Permission.manageUsers), isFalse);
      // Read actions allowed
      expect(service.can(Permission.viewTeamIncidents), isTrue);
      expect(service.can(Permission.viewTeamTasks), isTrue);
    });

    test('readOnly entitlement denies canWith for write actions', () {
      final service = buildService(Role.operator, readOnly: true);
      final ctx = const PermissionContext(
        incidentAssigneeId: 'uid-op',
        currentUserId: 'uid-op',
      );
      // Even though operator is the owner, readOnly blocks writes.
      expect(service.canWith(Permission.resolveIncident, ctx), isFalse);
    });

    test('non-readOnly entitlement does not block anything', () {
      final service = buildService(Role.supervisor, readOnly: false);
      expect(service.can(Permission.createIncident), isTrue);
      expect(service.can(Permission.assignIncident), isTrue);
      expect(service.can(Permission.viewTeamIncidents), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // requireRole
  // ---------------------------------------------------------------------------

  group('requireRole', () {
    test('throws for insufficient role', () {
      final service = buildService(Role.operator);
      expect(
        () => service.requireRole(Role.supervisor),
        throwsA(isA<InsufficientPermissionException>()),
      );
    });

    test('does not throw for sufficient role', () {
      final service = buildService(Role.supervisor);
      expect(() => service.requireRole(Role.supervisor), returnsNormally);
      expect(() => service.requireRole(Role.operator), returnsNormally);
    });

    test('admin satisfies all roles', () {
      final service = buildService(Role.admin);
      for (final role in Role.values) {
        expect(() => service.requireRole(role), returnsNormally);
      }
    });

    test('throws for consumer user', () {
      final service = buildService(null);
      expect(
        () => service.requireRole(Role.observer),
        throwsA(isA<InsufficientPermissionException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // require(action)
  // ---------------------------------------------------------------------------

  group('require(action)', () {
    test('throws when can() returns false', () {
      final service = buildService(Role.operator);
      expect(
        () => service.require(Permission.manageUsers),
        throwsA(isA<InsufficientPermissionException>()),
      );
    });

    test('does not throw when can() returns true', () {
      final service = buildService(Role.admin);
      expect(() => service.require(Permission.manageUsers), returnsNormally);
    });

    test('throws for observer on write action', () {
      final service = buildService(Role.observer);
      expect(
        () => service.require(Permission.createIncident),
        throwsA(isA<InsufficientPermissionException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // PermissionMatrix.isWriteAction
  // ---------------------------------------------------------------------------

  group('PermissionMatrix.isWriteAction', () {
    test('view permissions are read-only', () {
      expect(
        PermissionMatrix.isWriteAction(Permission.viewTeamIncidents),
        isFalse,
      );
      expect(PermissionMatrix.isWriteAction(Permission.viewTeamTasks), isFalse);
    });

    test('all other permissions are write actions', () {
      final writeActions = Permission.values
          .where(
            (p) =>
                p != Permission.viewTeamIncidents &&
                p != Permission.viewTeamTasks,
          )
          .toList();
      for (final action in writeActions) {
        expect(
          PermissionMatrix.isWriteAction(action),
          isTrue,
          reason: '${action.name} should be a write action',
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // PermissionContext
  // ---------------------------------------------------------------------------

  group('PermissionContext', () {
    test('isIncidentOwner matches', () {
      const ctx = PermissionContext(
        incidentAssigneeId: 'uid-001',
        currentUserId: 'uid-001',
      );
      expect(ctx.isIncidentOwner, isTrue);
    });

    test('isIncidentOwner mismatch', () {
      const ctx = PermissionContext(
        incidentAssigneeId: 'uid-002',
        currentUserId: 'uid-001',
      );
      expect(ctx.isIncidentOwner, isFalse);
    });

    test('isIncidentOwner null assignee', () {
      const ctx = PermissionContext(currentUserId: 'uid-001');
      expect(ctx.isIncidentOwner, isFalse);
    });

    test('isTaskOwner matches', () {
      const ctx = PermissionContext(
        taskAssigneeId: 'uid-001',
        currentUserId: 'uid-001',
      );
      expect(ctx.isTaskOwner, isTrue);
    });

    test('isTaskOwner mismatch', () {
      const ctx = PermissionContext(
        taskAssigneeId: 'uid-002',
        currentUserId: 'uid-001',
      );
      expect(ctx.isTaskOwner, isFalse);
    });
  });
}
