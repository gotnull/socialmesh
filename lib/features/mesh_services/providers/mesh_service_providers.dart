// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Riverpod providers for the Mesh Services feature.
///
/// Exposes store, engine, active instances, and lifecycle operations.
/// Gated behind [AppFeatureFlags.isMeshServicesEnabled].
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/logging.dart';
import '../models/mesh_service_instance.dart';
import '../services/mesh_service_engine.dart';
import '../services/mesh_service_store.dart';
import '../services/mrrp_delivery_tracker.dart';
import '../../../services/protocol/sip/mrrp_advert_engine.dart';
import '../../../services/protocol/sip/mrrp_constants.dart';
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

  // Force mrrpEngineProvider to build so that:
  //   1. advertEngine.onSend is wired (sendViaSip callback)
  //   2. advertEngine.start() is called (_started = true)
  // Without this, broadcastNow() called from onInstancePublished is a
  // silent no-op — _started is false and onSend is null — which is
  // exactly why no SERVICE_ADVERT log appears after service creation.
  // This mirrors the identical guard in mrrpCachedServicesProvider.
  ref.watch(mrrpEngineProvider);

  // Advert engine for forced immediate broadcast on instance publish.
  final advertEngine = ref.watch(mrrpAdvertEngineProvider);

  final engine = MeshServiceEngine(store: store);
  engine.onChanged = () {
    ref.read(meshServicesEpochProvider.notifier).bump();
    // Update SERVICE_ADVERT metadata with current active instance titles
    // so remote peers see meaningful service names in Mesh Explorer.
    _updateServiceMetadata(store, registry, advertEngine);
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

  // Populate initial SERVICE_ADVERT metadata with any existing active
  // instance titles. Runs async — doesn't block provider build.
  _updateServiceMetadata(store, registry, advertEngine);

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

/// Update the SERVICE_ADVERT descriptor metadata for user-created mesh
/// services with the titles of active instances.
///
/// Metadata format: UTF-8 encoded, truncated to 32 bytes. Contains up to
/// the first active instance title that fits. Remote peers decode this to
/// show the actual service name (e.g. "Android bbs title") instead of the
/// generic "Mesh Services" category label.
void _updateServiceMetadata(
  MeshServiceStore store,
  MrrpServiceRegistry registry,
  MrrpAdvertEngine? advertEngine,
) {
  // Fire-and-forget: async but doesn't block the provider build.
  Future<void>.microtask(() async {
    try {
      await store.open();
      final active = await store.getActive();

      // Build metadata: first active title, UTF-8, truncated to max.
      final metadata = _buildInstanceMetadata(active);

      final updated = registry.updateDescriptor(
        MrrpServiceDescriptor(
          serviceId: kMeshServicesInstanceServiceId,
          serviceType: MrrpServiceType.app,
          serviceFlags:
              MrrpServiceFlags.supportsRequest |
              MrrpServiceFlags.supportsResponse |
              MrrpServiceFlags.ephemeralOnly |
              MrrpServiceFlags.userVisible,
          metadata: metadata,
        ),
      );

      if (updated) {
        // Re-broadcast so remote peers see the updated metadata.
        await advertEngine?.broadcastNow();
      }
    } catch (e) {
      AppLogging.mrrp(
        'MESH_SERVICE_ENGINE: metadata update failed: $e', // lint-allow: hardcoded-string
      );
    }
  });
}

/// Build SERVICE_ADVERT metadata bytes from active instances.
///
/// Format: UTF-8 string of the first active instance title, truncated to
/// [MrrpConstants.mrrpServiceMetadataMaxLen] bytes. If multiple instances
/// are active, appends " +N" count suffix when it fits.
Uint8List _buildInstanceMetadata(List<MeshServiceInstance> active) {
  if (active.isEmpty) return Uint8List(0);

  const maxLen = MrrpConstants.mrrpServiceMetadataMaxLen;
  final first = active.first;
  var text = first.title;

  // Append count suffix for multiple instances.
  if (active.length > 1) {
    final suffix = ' +${active.length - 1}'; // lint-allow: hardcoded-string
    // Only add suffix if the title + suffix fits. Otherwise, just truncate
    // the title to fill the space.
    final fullText = '$text$suffix';
    final fullBytes = utf8.encode(fullText);
    if (fullBytes.length <= maxLen) {
      text = fullText;
    }
  }

  // UTF-8 encode and truncate to maxLen bytes (not chars — wire limit).
  var bytes = utf8.encode(text);
  if (bytes.length > maxLen) {
    // Truncate at a valid UTF-8 boundary.
    bytes = bytes.sublist(0, maxLen);
    // Walk backwards to find a valid UTF-8 start byte.
    while (bytes.isNotEmpty && (bytes.last & 0xC0) == 0x80) {
      bytes = bytes.sublist(0, bytes.length - 1);
    }
    // If the last byte is a multi-byte start but incomplete, remove it.
    if (bytes.isNotEmpty && bytes.last >= 0xC0) {
      final startByte = bytes.last;
      final expectedLen = startByte >= 0xF0
          ? 4
          : startByte >= 0xE0
          ? 3
          : 2;
      if (bytes.length < expectedLen) {
        bytes = bytes.sublist(0, bytes.length - 1);
      }
    }
  }

  return Uint8List.fromList(bytes);
}
