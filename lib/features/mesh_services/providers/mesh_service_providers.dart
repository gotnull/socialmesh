// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Riverpod providers for the Mesh Services feature.
///
/// Exposes store, engine, active instances, and lifecycle operations.
/// Gated behind [AppFeatureFlags.isMeshServicesEnabled].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../models/mesh_service_instance.dart';
import '../services/mesh_service_engine.dart';
import '../services/mesh_service_store.dart';
import '../services/mrrp_delivery_tracker.dart';
import '../../../services/protocol/sip/mrrp_service_registry.dart';
import '../../../services/protocol/sip/mrrp_types.dart';
import '../../../providers/mrrp_providers.dart';

/// Whether the Mesh Services feature is enabled.
final meshServicesEnabledProvider = Provider<bool>((ref) {
  return AppFeatureFlags.isMeshServicesEnabled;
});

/// Mesh services store — SQLite persistence layer.
///
/// Opens the database on first access. Null when feature is disabled.
final meshServiceStoreProvider = Provider<MeshServiceStore?>((ref) {
  final enabled = ref.watch(meshServicesEnabledProvider);
  if (!enabled) return null;

  final store = MeshServiceStore();
  // Open is async — callers must await ensureOpen before operating.
  ref.onDispose(() {
    store.close();
  });
  return store;
});

/// Epoch counter bumped whenever instance state changes.
final meshServicesEpochProvider = NotifierProvider<_MeshServicesEpoch, int>(
  _MeshServicesEpoch.new,
);

class _MeshServicesEpoch extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Mesh service engine — lifecycle management + MRRP handler.
///
/// Registration is deterministic: if the MRRP service registry is not
/// available (feature flags, initialization order), this provider returns
/// null instead of silently starting an unregistered engine. This eliminates
/// the race where inbound requests to [kMeshServicesInstanceServiceId] would
/// go unrouted without any diagnostic log.
///
/// The advert engine (if available) is wired so that publishing a new
/// instance triggers an immediate SERVICE_ADVERT broadcast, allowing remote
/// peers to discover the service without waiting for the next scheduled cycle.
final meshServiceEngineProvider = Provider<MeshServiceEngine?>((ref) {
  final enabled = ref.watch(meshServicesEnabledProvider);
  if (!enabled) return null;

  final store = ref.watch(meshServiceStoreProvider);
  if (store == null) return null;

  // Deterministic gate: no registry → no engine.
  // If MRRP or SIP is disabled, the registry is null and the engine must not
  // start without a registered handler. Returning null here surfaces the
  // failure explicitly rather than silently dropping inbound requests.
  final registry = ref.watch(mrrpServiceRegistryProvider);
  if (registry == null) return null;

  // Advert engine for forced immediate broadcast on instance publish.
  final advertEngine = ref.watch(mrrpAdvertEngineProvider);

  final engine = MeshServiceEngine(store: store);
  engine.onChanged = () {
    ref.read(meshServicesEpochProvider.notifier).bump();
  };

  // Wire immediate advert so remote peers discover newly-published
  // instances without waiting for the next periodic timer cycle.
  if (advertEngine != null) {
    engine.onInstancePublished = advertEngine.broadcastNow;
  }

  // Register handler — fail explicitly if the MRRP service slot limit
  // is reached. An unregistered engine must not start.
  final handler = MeshServicesHandler(store: store, engine: engine);
  final registered = registry.register(
    handler,
    MrrpServiceDescriptor(
      serviceId: kMeshServicesInstanceServiceId,
      serviceType: MrrpServiceType.app,
      serviceFlags:
          MrrpServiceFlags.supportsRequest |
          MrrpServiceFlags.supportsResponse |
          MrrpServiceFlags.ephemeralOnly |
          MrrpServiceFlags.userVisible,
    ),
  );

  if (!registered) {
    AppLogging.mrrp(
      'MESH_SERVICE_ENGINE: registration rejected — '
      'MRRP service slot limit reached', // lint-allow: hardcoded-string
    );
    return null;
  }

  engine.start();

  ref.onDispose(() {
    engine.dispose();
    registry.unregister(kMeshServicesInstanceServiceId);
  });

  return engine;
});

/// All local service instances (all statuses).
final meshServiceInstancesProvider = FutureProvider<List<MeshServiceInstance>>((
  ref,
) async {
  ref.watch(meshServicesEpochProvider);

  final store = ref.watch(meshServiceStoreProvider);
  if (store == null) return const [];

  await store.open();
  return store.getAll();
});

/// Active local service instances only.
final meshServiceActiveInstancesProvider =
    FutureProvider<List<MeshServiceInstance>>((ref) async {
      ref.watch(meshServicesEpochProvider);

      final store = ref.watch(meshServiceStoreProvider);
      if (store == null) return const [];

      await store.open();
      return store.getActive();
    });

/// Count of active instances.
final meshServiceActiveCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref
      .watch(meshServiceActiveInstancesProvider)
      .whenData((list) => list.length);
});

/// MRRP delivery tracker — maps engine request lifecycle to [DeliveryPhase].
///
/// Null when the MRRP engine is not available (feature flags, SIP disabled).
final mrrpDeliveryTrackerProvider = Provider<MrrpDeliveryTracker?>((ref) {
  final engine = ref.watch(mrrpEngineProvider);
  if (engine == null) return null;

  final tracker = MrrpDeliveryTracker(engine);
  ref.onDispose(tracker.dispose);
  return tracker;
});
