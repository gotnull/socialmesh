// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/cloud_sync_entitlement_providers.dart';
import '../../services/subscription/cloud_sync_entitlement_service.dart';
import 'claims_provider.dart';
import 'permission_service.dart';
import 'role.dart';

/// Riverpod provider exposing a reactive [PermissionService].
///
/// Watches [claimsProvider] for role/orgId and
/// [cloudSyncEntitlementProvider] for entitlement state.
/// Rebuilds automatically when any dependency changes.
///
/// Consumer users (null role) receive a service that denies everything.
///
/// Spec: RBAC.md (Sprint 007/W2.2), Sprint 008/W2.1.
final permissionServiceProvider = Provider<PermissionService>((ref) {
  final claims = ref.watch(claimsProvider);
  final entitlement = ref.watch(cloudSyncEntitlementProvider);

  final role = Role.fromString(claims.role);
  final orgId = claims.orgId;

  // Entitlement readOnly: expired state with read access, or any state
  // where canWrite is false but canRead is true.
  final isReadOnly = entitlement.maybeWhen(
    data: (e) =>
        e.state == CloudSyncEntitlementState.expired ||
        (!e.canWrite && e.canRead),
    orElse: () => false,
  );

  return PermissionService(
    role: role,
    orgId: orgId,
    isEntitlementReadOnly: isReadOnly,
  );
});
