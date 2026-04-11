// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Provider-level integration tests for the mesh service publication chain.
///
/// Verifies:
/// 1. [meshServicesEpochProvider] bump triggers [meshServiceInstancesProvider]
///    rebuild (My Services data source).
/// 2. [mrrpCachedServicesProvider] changes propagate to
///    [meshExplorerServicesProvider] and [meshExplorerSummaryProvider].
/// 3. [meshExplorerSummaryProvider] correctly reflects service counts from
///    the advert cache.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_services/providers/mesh_service_providers.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_template.dart';
import 'package:socialmesh/features/mesh_services/services/mesh_service_engine.dart';
import 'package:socialmesh/features/mesh_services/services/mesh_service_store.dart';
import 'package:socialmesh/providers/mesh_explorer_providers.dart';
import 'package:socialmesh/providers/mrrp_providers.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_advert_engine.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_registry.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ─────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────

/// Build a raw SERVICE_ADVERT payload for [serviceId].
///
/// Wire layout (per MRRP_V0_1.md):
///   [0]       count (uint8)
///   [1..4]    service_id (uint32 LE)
///   [5]       service_type (uint8)   0x00 = app
///   [6]       version_major (uint8)
///   [7]       version_minor (uint8)
///   [8..9]    service_flags (uint16 LE)
///   [10]      metadata_len (uint8)  0 = no metadata
Uint8List _advertPayload(int serviceId) {
  return _multiAdvertPayload([serviceId]);
}

/// Build a raw SERVICE_ADVERT payload containing multiple descriptors.
Uint8List _multiAdvertPayload(List<int> serviceIds) {
  final flags =
      MrrpServiceFlags.supportsRequest |
      MrrpServiceFlags.supportsResponse |
      MrrpServiceFlags.ephemeralOnly |
      MrrpServiceFlags.userVisible;
  // count(1) + N × descriptor_min(10 bytes: 4+1+1+1+2+1 with metaLen=0).
  const descriptorSize = MrrpConstants.mrrpServiceDescriptorMin; // 10
  final buf = Uint8List(1 + serviceIds.length * descriptorSize);
  buf[0] = serviceIds.length;
  for (var i = 0; i < serviceIds.length; i++) {
    final offset = 1 + i * descriptorSize;
    ByteData.sublistView(
      buf,
      offset,
    ).setUint32(0, serviceIds[i], Endian.little);
    buf[offset + 4] = 0x00; // service_type = app
    buf[offset + 5] = 0x00; // version_major
    buf[offset + 6] = 0x01; // version_minor
    ByteData.sublistView(buf, offset + 7).setUint16(0, flags, Endian.little);
    buf[offset + 9] = 0; // metadata_len
  }
  return buf;
}

MrrpFrame _advertFrame(int serviceId) {
  final payload = _advertPayload(serviceId);
  return MrrpFrame(
    versionMajor: 0,
    versionMinor: 1,
    msgType: MrrpMessageType.serviceAdvert,
    flags: 0,
    headerLen: MrrpConstants.mrrpHeaderMin,
    requestId: 0,
    serviceId: 0,
    actionId: 0,
    payloadLen: payload.length,
    payload: payload,
  );
}

/// Creates a [ProviderContainer] scoped to the explorer/activity tests.
///
/// Overrides:
/// - [meshServicesEnabledProvider] → true
/// - [meshExplorerEnabledProvider] → true
/// - [mrrpServiceRegistryProvider] → real [MrrpServiceRegistry] (in-memory)
/// - [mrrpAdvertEngineProvider]    → real [MrrpAdvertEngine] (no send wired)
/// - [mrrpCachedServicesProvider]  → derived directly from the test engine,
///   watching [mrrpAdvertEpochProvider] so that a bump triggers a rebuild.
///
/// SIP-dependent providers ([sipDiscoveredPeersProvider], etc.) are NOT
/// overridden. In tests, [AppFeatureFlags.isSipEnabled] evaluates to false
/// (no SIP_ENABLED=true in env), so the SIP provider chain returns null/[]
/// harmlessly, giving [meshExplorerPeersProvider] an empty peer list.
({
  ProviderContainer container,
  MrrpServiceRegistry registry,
  MrrpAdvertEngine advertEngine,
})
_createContainer() {
  final registry = MrrpServiceRegistry();
  final advertEngine = MrrpAdvertEngine(registry: registry);

  final container = ProviderContainer(
    overrides: [
      meshServicesEnabledProvider.overrideWithValue(true),
      meshExplorerEnabledProvider.overrideWithValue(true),
      mrrpServiceRegistryProvider.overrideWithValue(registry),
      mrrpAdvertEngineProvider.overrideWithValue(advertEngine),
      // Override the cached-services provider to read directly from the test
      // advert engine. Watching the epoch ensures this rebuilds whenever
      // mrrpAdvertEpochProvider is bumped (e.g. after injecting test adverts).
      mrrpCachedServicesProvider.overrideWith((ref) {
        ref.watch(mrrpAdvertEpochProvider);
        return advertEngine.getAllCachedServices();
      }),
    ],
  );

  return (container: container, registry: registry, advertEngine: advertEngine);
}

// ─────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // ── 1. Epoch bump → meshServiceInstancesProvider rebuilds ─────────────────

  group('meshServicesEpochProvider → meshServiceInstancesProvider', () {
    test('bumping epoch causes FutureProvider to re-execute', () async {
      final store = MeshServiceStore(dbPathOverride: inMemoryDatabasePath);
      await store.open();

      final container = ProviderContainer(
        overrides: [
          meshServicesEnabledProvider.overrideWithValue(true),
          meshServiceStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await store.close();
      });

      // Initially empty.
      final initial = await container.read(meshServiceInstancesProvider.future);
      expect(initial, isEmpty);

      // Insert an instance via the engine and bump the epoch.
      final engine = MeshServiceEngine(store: store);
      engine.start();
      addTearDown(engine.dispose);

      await engine.createInstance(
        templateId: MeshServiceTemplateId.board,
        title: 'Provider Test Board',
        ttlMinutes: 60,
      );
      // createInstance does not automatically wire the provider's epoch bump
      // in this isolated test — simulate it manually.
      container.read(meshServicesEpochProvider.notifier).bump();

      final updated = await container.read(meshServiceInstancesProvider.future);
      expect(updated.length, 1);
      expect(updated.first.title, 'Provider Test Board');
    });

    test('multiple bumps result in consistent data', () async {
      final store = MeshServiceStore(dbPathOverride: inMemoryDatabasePath);
      await store.open();

      final container = ProviderContainer(
        overrides: [
          meshServicesEnabledProvider.overrideWithValue(true),
          meshServiceStoreProvider.overrideWithValue(store),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await store.close();
      });

      final engine = MeshServiceEngine(store: store);
      engine.start();
      addTearDown(engine.dispose);

      for (var i = 1; i <= 3; i++) {
        await engine.createInstance(
          templateId: MeshServiceTemplateId.board,
          title: 'Board $i',
          ttlMinutes: 30,
        );
        container.read(meshServicesEpochProvider.notifier).bump();
      }

      final instances = await container.read(
        meshServiceInstancesProvider.future,
      );
      expect(instances.length, 3);
    });
  });

  // ── 2. meshExplorerServicesProvider from advert cache ─────────────────────

  group('meshExplorerServicesProvider reflects advert cache', () {
    test('returns empty map before any adverts', () {
      final (:container, :registry, :advertEngine) = _createContainer();
      addTearDown(() {
        container.dispose();
        advertEngine.dispose();
      });

      final services = container.read(meshExplorerServicesProvider);
      expect(services, isEmpty);
    });

    test('reflects mesh services service ID after advert injection', () {
      final (:container, :registry, :advertEngine) = _createContainer();
      addTearDown(() {
        container.dispose();
        advertEngine.dispose();
      });

      // Inject before first read → fresh data on first build.
      advertEngine.handleServiceAdvert(
        _advertFrame(kMeshServicesInstanceServiceId),
        0xBEEF0001,
      );

      final services = container.read(meshExplorerServicesProvider);
      expect(
        services.any((s) => s.serviceId == kMeshServicesInstanceServiceId),
        isTrue,
      );
      expect(services.length, 1);
    });

    test('counts multiple peers advertising the same service', () {
      final (:container, :registry, :advertEngine) = _createContainer();
      addTearDown(() {
        container.dispose();
        advertEngine.dispose();
      });

      // Inject both before first read.
      advertEngine.handleServiceAdvert(
        _advertFrame(kMeshServicesInstanceServiceId),
        0x1111,
      );
      advertEngine.handleServiceAdvert(
        _advertFrame(kMeshServicesInstanceServiceId),
        0x2222,
      );

      final services = container.read(meshExplorerServicesProvider);
      // Two peers × one instance each = 2 entries.
      expect(
        services
            .where((s) => s.serviceId == kMeshServicesInstanceServiceId)
            .length,
        2,
      );
    });

    test('excludes test-only services from count', () {
      final (:container, :registry, :advertEngine) = _createContainer();
      addTearDown(() {
        container.dispose();
        advertEngine.dispose();
      });

      // Build a SERVICE_ADVERT payload with testOnly flag set.
      final testPayload = Uint8List(12);
      testPayload[0] = 1; // count
      ByteData.sublistView(
        testPayload,
        1,
      ).setUint32(0, MrrpServiceId.echoTest, Endian.little);
      testPayload[5] = 0x02; // service_type = test
      testPayload[6] = 0x00; // version_major
      testPayload[7] = 0x01; // version_minor
      ByteData.sublistView(
        testPayload,
        8,
      ).setUint16(0, MrrpServiceFlags.testOnly, Endian.little);
      testPayload[10] = 0; // metadata_len

      final testFrame = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.serviceAdvert,
        flags: 0,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 0,
        serviceId: 0,
        actionId: 0,
        payloadLen: testPayload.length,
        payload: testPayload,
      );
      advertEngine.handleServiceAdvert(testFrame, 0x9999);

      final services = container.read(meshExplorerServicesProvider);
      expect(
        services.any((s) => s.serviceId == MrrpServiceId.echoTest),
        isFalse,
      );
    });
  });

  // ── 3. meshExplorerSummaryProvider service count ──────────────────────────

  group('meshExplorerSummaryProvider activeServices count', () {
    test('is 0 before any adverts', () {
      final (:container, :registry, :advertEngine) = _createContainer();
      addTearDown(() {
        container.dispose();
        advertEngine.dispose();
      });

      final summary = container.read(meshExplorerSummaryProvider);
      expect(summary.activeServices, 0);
    });

    test('increments when a new service type is seen in cache', () {
      final (:container, :registry, :advertEngine) = _createContainer();
      addTearDown(() {
        container.dispose();
        advertEngine.dispose();
      });

      // Inject before first read.
      advertEngine.handleServiceAdvert(
        _advertFrame(kMeshServicesInstanceServiceId),
        0x1234,
      );

      final summary = container.read(meshExplorerSummaryProvider);
      expect(summary.activeServices, greaterThanOrEqualTo(1));
    });

    test('two distinct service IDs from same peer count as 2', () {
      final (:container, :registry, :advertEngine) = _createContainer();
      addTearDown(() {
        container.dispose();
        advertEngine.dispose();
      });

      // A single SERVICE_ADVERT payload with two descriptors from one peer.
      // Each advert replaces the full set for that peer, so both descriptors
      // must arrive in the same payload.
      final payload = _multiAdvertPayload([
        kMeshServicesInstanceServiceId,
        MrrpServiceId.boardV1,
      ]);
      final frame = MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.serviceAdvert,
        flags: 0,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 0,
        serviceId: 0,
        actionId: 0,
        payloadLen: payload.length,
        payload: payload,
      );
      advertEngine.handleServiceAdvert(frame, 0x5555);

      final services = container.read(meshExplorerServicesProvider);
      expect(services.length, 2);
      expect(
        services.any((s) => s.serviceId == kMeshServicesInstanceServiceId),
        isTrue,
      );
      expect(services.any((s) => s.serviceId == MrrpServiceId.boardV1), isTrue);

      final summary = container.read(meshExplorerSummaryProvider);
      expect(summary.activeServices, 2);
    });
  });

  // ── 4. meshServiceInstancesProvider is empty when store is disabled ────────

  group('meshServiceInstancesProvider feature gate', () {
    test('returns empty list when mesh services disabled', () async {
      final container = ProviderContainer(
        overrides: [meshServicesEnabledProvider.overrideWithValue(false)],
      );
      addTearDown(container.dispose);

      final instances = await container.read(
        meshServiceInstancesProvider.future,
      );
      expect(instances, isEmpty);
    });
  });
}
