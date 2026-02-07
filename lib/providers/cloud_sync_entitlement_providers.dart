// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../../services/subscription/cloud_sync_entitlement_service.dart';

/// Provider for cloud sync entitlement service
final cloudSyncEntitlementServiceProvider =
    Provider<CloudSyncEntitlementService>((ref) {
      final service = CloudSyncEntitlementService();
      ref.onDispose(() => service.dispose());
      return service;
    });

/// Provider for current cloud sync entitlement state
final cloudSyncEntitlementProvider = StreamProvider<CloudSyncEntitlement>((
  ref,
) {
  final service = ref.watch(cloudSyncEntitlementServiceProvider);
  // Create a stream that starts with the current value, then listens for updates
  final controller = StreamController<CloudSyncEntitlement>();

  // Emit current value immediately
  controller.add(service.currentEntitlement);

  // Then forward all stream updates
  final subscription = service.entitlementStream.listen(
    controller.add,
    onError: controller.addError,
    onDone: controller.close,
  );

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
});

/// Provider for checking if cloud sync write is allowed
final canCloudSyncWriteProvider = Provider<bool>((ref) {
  final entitlement = ref.watch(cloudSyncEntitlementProvider);
  final canWrite = entitlement.whenOrNull(data: (e) => e.canWrite) ?? false;

  final stateDesc = entitlement.when(
    data: (e) =>
        'data(state=${e.state}, canWrite=${e.canWrite}, canRead=${e.canRead})',
    loading: () => 'LOADING',
    error: (e, _) => 'ERROR($e)',
  );

  AppLogging.sync(
    '[Entitlement] canCloudSyncWriteProvider evaluated: '
    'canWrite=$canWrite, entitlement=$stateDesc',
  );

  return canWrite;
});

/// Provider for checking if cloud sync read is allowed
final canCloudSyncReadProvider = Provider<bool>((ref) {
  final entitlement = ref.watch(cloudSyncEntitlementProvider);
  final canRead = entitlement.whenOrNull(data: (e) => e.canRead) ?? false;

  AppLogging.sync(
    '[Entitlement] canCloudSyncReadProvider evaluated: canRead=$canRead',
  );

  return canRead;
});

/// Provider for the current entitlement state
final cloudSyncStateProvider = Provider<CloudSyncEntitlementState>((ref) {
  final entitlement = ref.watch(cloudSyncEntitlementProvider);
  return entitlement.whenOrNull(data: (e) => e.state) ??
      CloudSyncEntitlementState.none;
});
