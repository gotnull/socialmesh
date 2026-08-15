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
import '../../../utils/text_sanitizer.dart';
import '../models/mesh_service_instance.dart';
import '../models/mesh_service_template.dart';
import '../services/mesh_service_engine.dart';
import '../services/mesh_service_store.dart';
import '../services/mrrp_delivery_tracker.dart';
import '../../../services/protocol/sip/mrrp_advert_engine.dart';
import '../../../services/protocol/sip/mrrp_constants.dart';
import '../../../services/protocol/sip/mrrp_service_registry.dart';
import '../../../services/protocol/sip/mrrp_types.dart';
import '../../../providers/mrrp_providers.dart';
import '../../../providers/radio_scope_providers.dart';

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

  ref.watch(radioScopeProvider);
  final store = MeshServiceStore();
  // Open is async — callers must await ensureOpen before operating.
  bindStoreToRadioScope(ref, store, store.close);
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
    // Update SERVICE_ADVERT descriptors with current active instance titles
    // so remote peers see individual service entries in Mesh Explorer.
    _updateServiceDescriptors(store, registry, advertEngine);
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

  // Populate initial SERVICE_ADVERT descriptors with any existing active
  // instance titles. Runs async — doesn't block provider build.
  _updateServiceDescriptors(store, registry, advertEngine);

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

/// Update the SERVICE_ADVERT instance descriptors for user-created mesh
/// services so each active instance is advertised as a separate entry.
///
/// Each descriptor carries structured metadata: canonical type, optional
/// preset, and title. Remote peers use this to render truthful capability
/// labels instead of guessing from cosmetic names.
void _updateServiceDescriptors(
  MeshServiceStore store,
  MrrpServiceRegistry registry,
  MrrpAdvertEngine? advertEngine,
) {
  // Fire-and-forget: async but doesn't block the provider build.
  Future<void>.microtask(() async {
    try {
      await store.open();
      final active = await store.getActive();

      const flags =
          MrrpServiceFlags.supportsRequest |
          MrrpServiceFlags.supportsResponse |
          MrrpServiceFlags.ephemeralOnly |
          MrrpServiceFlags.userVisible;

      if (active.isEmpty) {
        // No active instances — clear instance descriptors and suppress
        // userVisible on the base descriptor so the service disappears
        // from Mesh Explorer on remote peers. The handler remains
        // registered for inbound requests (e.g. LIST_INSTANCES returns 0).
        registry.setInstanceDescriptors(
          kMeshServicesInstanceServiceId,
          const [],
        );
        registry.updateDescriptor(
          MrrpServiceDescriptor(
            serviceId: kMeshServicesInstanceServiceId,
            serviceType: MrrpServiceType.app,
            serviceFlags: flags & ~MrrpServiceFlags.userVisible,
          ),
        );
        await advertEngine?.broadcastNow();
        return;
      }

      // Build one descriptor per active instance, each with its own title.
      final descriptors = <MrrpServiceDescriptor>[
        for (final instance in active)
          MrrpServiceDescriptor(
            serviceId: kMeshServicesInstanceServiceId,
            serviceType: MrrpServiceType.app,
            serviceFlags: flags,
            metadata: _encodeAdvertMetadata(instance),
          ),
      ];

      // Restore userVisible on the base descriptor (in case it was
      // previously suppressed when instances went to zero).
      registry.updateDescriptor(
        MrrpServiceDescriptor(
          serviceId: kMeshServicesInstanceServiceId,
          serviceType: MrrpServiceType.app,
          serviceFlags: flags,
        ),
      );

      registry.setInstanceDescriptors(
        kMeshServicesInstanceServiceId,
        descriptors,
      );

      // Re-broadcast so remote peers see the updated descriptors.
      await advertEngine?.broadcastNow();
    } catch (e) {
      AppLogging.mrrp(
        'MESH_SERVICE_ENGINE: descriptor update failed: $e', // lint-allow: hardcoded-string
      );
    }
  });
}

/// Encode structured advert metadata and truncate the title payload to fit the
/// SERVICE_ADVERT metadata budget.
Uint8List _encodeAdvertMetadata(MeshServiceInstance instance) {
  const maxLen = MrrpConstants.mrrpServiceMetadataMaxLen;
  final availableTitleBytes = maxLen - 5;
  final title = _truncateUtf8(instance.title, availableTitleBytes);
  return MeshServiceAdvertMetadata.encode(
    canonicalType: instance.canonicalType,
    presetId: instance.presetId,
    title: sanitizeExternalText(utf8.decode(title, allowMalformed: true)),
  );
}

/// UTF-8 encode and truncate [text] to [maxLen] bytes, respecting multi-byte
/// character boundaries.
Uint8List _truncateUtf8(String text, int maxLen) {
  var bytes = utf8.encode(text);
  if (bytes.length <= maxLen) return Uint8List.fromList(bytes);

  bytes = bytes.sublist(0, maxLen);
  // Walk backwards past continuation bytes (10xxxxxx).
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
  return Uint8List.fromList(bytes);
}
