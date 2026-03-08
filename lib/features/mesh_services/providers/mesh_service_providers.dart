// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Riverpod providers for the Mesh Services feature.
///
/// Exposes store, engine, active instances, and lifecycle operations.
/// Gated behind [AppFeatureFlags.isMeshServicesEnabled].
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../models/mesh_service_instance.dart';
import '../services/mesh_service_engine.dart';
import '../services/mesh_service_store.dart';
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
/// Null when feature is disabled or MRRP registry unavailable.
final meshServiceEngineProvider = Provider<MeshServiceEngine?>((ref) {
  final enabled = ref.watch(meshServicesEnabledProvider);
  if (!enabled) return null;

  final store = ref.watch(meshServiceStoreProvider);
  if (store == null) return null;

  final registry = ref.watch(mrrpServiceRegistryProvider);

  final engine = MeshServiceEngine(store: store);
  engine.onChanged = () {
    ref.read(meshServicesEpochProvider.notifier).bump();
  };

  // Register the mesh-services instance handler in the MRRP registry.
  if (registry != null) {
    final handler = MeshServicesHandler(store: store, engine: engine);
    registry.register(
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
  }

  engine.start();

  ref.onDispose(() {
    engine.dispose();
    if (registry != null) {
      registry.unregister(kMeshServicesInstanceServiceId);
    }
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
