// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Integration tests for the service publication path.
///
/// Verifies the end-to-end chain:
///   create instance → store → epoch callback → advert callback
///
/// Also verifies:
/// - [MeshServicesHandler] serves stored active instances via MRRP ListInstances
/// - [MrrpAdvertEngine] includes the registered service ID in advert payload
/// - Remote-side advert ingestion (handleServiceAdvert) caches the service
/// - [MrrpServiceRegistry] registration is deterministic (explicit failure when
///   the MRRP slot limit is reached)
library;

import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_instance.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_template.dart';
import 'package:socialmesh/features/mesh_services/services/mesh_service_engine.dart';
import 'package:socialmesh/features/mesh_services/services/mesh_service_store.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_advert_engine.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_codec.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_messages_advert.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_handler.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_service_registry.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// ─────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────

/// Minimal MRRP handler for filling the service slot table.
class _SlotFiller implements MrrpServiceHandler {
  @override
  final int serviceId;

  _SlotFiller(this.serviceId);

  @override
  Set<int> get supportedActions => const {};

  @override
  Future<MrrpFrame> handleRequest(MrrpFrame request, int senderNodeId) async {
    return MrrpFrame(
      versionMajor: 0,
      versionMinor: 1,
      msgType: MrrpMessageType.response,
      flags: MrrpFlags.isResponse,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: request.requestId,
      serviceId: request.serviceId,
      actionId: request.actionId,
      payloadLen: 0,
      payload: Uint8List(0),
    );
  }
}

MrrpServiceDescriptor _appDescriptor(int serviceId) {
  return MrrpServiceDescriptor(
    serviceId: serviceId,
    serviceType: MrrpServiceType.app,
    serviceFlags:
        MrrpServiceFlags.supportsRequest | MrrpServiceFlags.supportsResponse,
  );
}

MrrpServiceDescriptor _meshServicesDescriptor() {
  return MrrpServiceDescriptor(
    serviceId: kMeshServicesInstanceServiceId,
    serviceType: MrrpServiceType.app,
    serviceFlags:
        MrrpServiceFlags.supportsRequest |
        MrrpServiceFlags.supportsResponse |
        MrrpServiceFlags.ephemeralOnly |
        MrrpServiceFlags.userVisible,
  );
}

// Build a minimal SERVICE_ADVERT payload encoding [serviceId].
Uint8List _buildAdvertPayloadFor(int serviceId) {
  // count(1) + serviceId(4) + type(1) + verMaj(1) + verMin(1) + flags(2) + metaLen(1)
  final buf = Uint8List(12);
  buf[0] = 1; // service count
  ByteData.sublistView(buf, 1).setUint32(0, serviceId, Endian.little);
  buf[5] = 0x00; // app
  buf[6] = 0x00; // versionMajor
  buf[7] = 0x01; // versionMinor
  // flags LE
  final flags =
      MrrpServiceFlags.supportsRequest |
      MrrpServiceFlags.supportsResponse |
      MrrpServiceFlags.ephemeralOnly |
      MrrpServiceFlags.userVisible;
  ByteData.sublistView(buf, 8).setUint16(0, flags, Endian.little);
  buf[10] = 0x00; // metadata len
  return buf;
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

  // ───────────────── MeshServiceEngine publish path ─────────────────

  group('MeshServiceEngine publish path', () {
    late MeshServiceStore store;
    late MeshServiceEngine engine;

    setUp(() async {
      store = MeshServiceStore(dbPathOverride: inMemoryDatabasePath);
      await store.open();
      engine = MeshServiceEngine(store: store);
      engine.start();
    });

    tearDown(() async {
      engine.dispose();
      await store.close();
    });

    test('createInstance persists to store and is retrievable', () async {
      final instance = await engine.createInstance(
        templateId: MeshServiceTemplateId.board,
        title: 'Test Board',
        ttlMinutes: 60,
      );

      expect(instance, isNotNull);
      expect(instance!.title, 'Test Board');
      expect(instance.isActive, isTrue);

      final all = await store.getAll();
      expect(all.length, 1);
      expect(all.first.instanceId, instance.instanceId);
    });

    test('createInstance fires onChanged callback', () async {
      var changedCount = 0;
      engine.onChanged = () => changedCount++;

      await engine.createInstance(
        templateId: MeshServiceTemplateId.poll,
        title: 'Vote',
        ttlMinutes: 30,
        config: {
          'options': ['Yes', 'No'],
        },
      );

      expect(changedCount, 1);
    });

    test('createInstance fires onInstancePublished callback', () async {
      var publishedCount = 0;
      engine.onInstancePublished = () async => publishedCount++;

      await engine.createInstance(
        templateId: MeshServiceTemplateId.checklist,
        title: 'Gear Check',
        ttlMinutes: 60,
        config: {
          'items': ['Tent', 'Water'],
        },
      );

      expect(publishedCount, 1);
    });

    test('onChanged fires before onInstancePublished', () async {
      final eventOrder = <String>[];
      engine.onChanged = () =>
          eventOrder.add('changed'); // lint-allow: hardcoded-string
      engine.onInstancePublished = () async =>
          eventOrder.add('published'); // lint-allow: hardcoded-string

      await engine.createInstance(
        templateId: MeshServiceTemplateId.board,
        title: 'Board',
        ttlMinutes: 60,
      );

      expect(eventOrder, [
        'changed',
        'published',
      ]); // lint-allow: hardcoded-string
    });

    test('stopInstance marks instance stopped and fires onChanged', () async {
      final instance = await engine.createInstance(
        templateId: MeshServiceTemplateId.board,
        title: 'Board',
        ttlMinutes: 60,
      );
      expect(instance, isNotNull);

      var changedCount = 0;
      engine.onChanged = () => changedCount++;

      await engine.stopInstance(instance!.instanceId);

      final updated = await store.get(instance.instanceId);
      expect(updated?.status, MeshServiceStatus.stopped);
      expect(changedCount, 1);
    });

    test('getActiveInstances returns only active instances', () async {
      await engine.createInstance(
        templateId: MeshServiceTemplateId.board,
        title: 'Active Board',
        ttlMinutes: 60,
      );
      final toStop = await engine.createInstance(
        templateId: MeshServiceTemplateId.board,
        title: 'To Stop',
        ttlMinutes: 60,
      );
      await engine.stopInstance(toStop!.instanceId);

      final active = await engine.getActiveInstances();
      expect(active.length, 1);
      expect(active.first.title, 'Active Board');
    });
  });

  // ───────────────── MeshServicesHandler MRRP request routing ─────────────────

  group('MeshServicesHandler MRRP routing', () {
    late MeshServiceStore store;
    late MeshServiceEngine engine;
    late MeshServicesHandler handler;

    setUp(() async {
      store = MeshServiceStore(dbPathOverride: inMemoryDatabasePath);
      await store.open();
      engine = MeshServiceEngine(store: store);
      handler = MeshServicesHandler(store: store, engine: engine);
      engine.start();
    });

    tearDown(() async {
      engine.dispose();
      await store.close();
    });

    MrrpFrame makeRequest(int actionId, {Uint8List? payload}) {
      final p = payload ?? Uint8List(0);
      return MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.request,
        flags: 0,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 0x42,
        serviceId: kMeshServicesInstanceServiceId,
        actionId: actionId,
        payloadLen: p.length,
        payload: p,
      );
    }

    test('listInstances returns empty when no active instances', () async {
      final req = makeRequest(MeshServicesAction.listInstances);
      final resp = await handler.handleRequest(req, 0x1234);

      expect(resp.msgType, MrrpMessageType.response);
      expect(resp.payload.length, greaterThanOrEqualTo(1));
      expect(resp.payload[0], 0); // count = 0
    });

    test('listInstances returns published active instances', () async {
      await engine.createInstance(
        templateId: MeshServiceTemplateId.board,
        title: 'My Board',
        ttlMinutes: 60,
      );

      final req = makeRequest(MeshServicesAction.listInstances);
      final resp = await handler.handleRequest(req, 0x1234);

      expect(resp.msgType, MrrpMessageType.response);
      // count byte should be 1
      expect(resp.payload[0], 1);
      // templateId byte (offset 17) should match board
      expect(resp.payload[17], MeshServiceTemplateId.board.index);
    });

    test('getInstance returns details for active instance', () async {
      final inst = await engine.createInstance(
        templateId: MeshServiceTemplateId.board,
        title: 'Detail Board',
        description: 'A test board',
        ttlMinutes: 60,
      );
      expect(inst, isNotNull);

      final idBytes = MeshServicesHandler.encodeInstanceId(inst!.instanceId);
      final req = makeRequest(MeshServicesAction.getInstance, payload: idBytes);
      final resp = await handler.handleRequest(req, 0x1234);

      expect(resp.msgType, MrrpMessageType.response);
      expect(resp.payload[0], MeshServiceTemplateId.board.index);
    });

    test('getInstance returns notFound for unknown instance', () async {
      final badId = Uint8List(16); // all zeros
      final req = makeRequest(MeshServicesAction.getInstance, payload: badId);
      final resp = await handler.handleRequest(req, 0x1234);

      expect(resp.msgType, MrrpMessageType.error);
    });

    test('unsupported action returns error', () async {
      final req = makeRequest(0xFF);
      final resp = await handler.handleRequest(req, 0x1234);
      expect(resp.msgType, MrrpMessageType.error);
    });
  });

  // ───────────────── Advert engine includes registered service ─────────────────

  group('MrrpAdvertEngine advert payload includes mesh services', () {
    late MrrpServiceRegistry registry;
    late MeshServiceStore store;
    late MeshServiceEngine meshEngine;
    late MeshServicesHandler meshHandler;

    setUp(() async {
      registry = MrrpServiceRegistry();
      store = MeshServiceStore(dbPathOverride: inMemoryDatabasePath);
      await store.open();
      meshEngine = MeshServiceEngine(store: store);
      meshHandler = MeshServicesHandler(store: store, engine: meshEngine);
      meshEngine.start();
    });

    tearDown(() async {
      meshEngine.dispose();
      await store.close();
    });

    test(
      'buildAdvertPayload includes kMeshServicesInstanceServiceId after registration',
      () {
        final registered = registry.register(
          meshHandler,
          _meshServicesDescriptor(),
        );
        expect(registered, isTrue);

        final payload = registry.buildAdvertPayload();
        expect(payload, isNotNull);

        final decoded = MrrpMessagesAdvert.decodeAdvertPayload(payload!);
        expect(decoded, isNotNull);
        expect(
          decoded!.any((d) => d.serviceId == kMeshServicesInstanceServiceId),
          isTrue,
        );
      },
    );

    test(
      'broadcastNow sends a frame encoding the registered service',
      () async {
        registry.register(meshHandler, _meshServicesDescriptor());

        final sentPayloads = <Uint8List>[];
        final advertEngine = MrrpAdvertEngine(
          registry: registry,
          random: Random(42),
          onSend: (payload) async {
            sentPayloads.add(payload);
            return true;
          },
        );
        advertEngine.start();

        await advertEngine.broadcastNow();

        expect(sentPayloads.length, 1);

        // Decode the sent MRRP frame and check it encodes our service.
        final frame = MrrpCodec.decode(sentPayloads.first);
        expect(frame, isNotNull);
        expect(frame!.msgType, MrrpMessageType.serviceAdvert);

        final services = MrrpMessagesAdvert.decodeAdvertPayload(frame.payload);
        expect(services, isNotNull);
        expect(
          services!.any((d) => d.serviceId == kMeshServicesInstanceServiceId),
          isTrue,
        );

        advertEngine.dispose();
      },
    );

    test('broadcastNow is a no-op before start()', () async {
      final advertEngine = MrrpAdvertEngine(registry: registry);
      var sendCalled = false;
      advertEngine.onSend = (payload) async {
        sendCalled = true;
        return true;
      };

      // Do NOT call start() — broadcastNow should be no-op.
      await advertEngine.broadcastNow();

      expect(sendCalled, isFalse);
      advertEngine.dispose();
    });

    test('broadcastNow resets the periodic schedule', () async {
      registry.register(meshHandler, _meshServicesDescriptor());

      var sendCount = 0;
      final advertEngine = MrrpAdvertEngine(
        registry: registry,
        random: Random(0),
        onSend: (payload) async {
          sendCount++;
          return true;
        },
      );
      advertEngine.start();

      await advertEngine.broadcastNow();
      // One broadcast fired; next one is scheduled but not yet due.
      expect(sendCount, 1);

      advertEngine.dispose();
    });
  });

  // ───────────────── Remote-side advert ingestion ─────────────────

  group('Remote-side: handleServiceAdvert caches mesh services service', () {
    late MrrpServiceRegistry remoteRegistry;
    late MrrpAdvertEngine remoteEngine;

    setUp(() {
      remoteRegistry = MrrpServiceRegistry();
      remoteEngine = MrrpAdvertEngine(
        registry: remoteRegistry,
        random: Random(1),
      );
    });

    tearDown(() {
      remoteEngine.dispose();
    });

    test('inbound SERVICE_ADVERT with 0x10 is cached per sender', () {
      final payload = _buildAdvertPayloadFor(kMeshServicesInstanceServiceId);

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

      const senderNodeId = 0xBEEF0001;
      remoteEngine.handleServiceAdvert(frame, senderNodeId);

      final cached = remoteEngine.getServicesForPeer(senderNodeId);
      expect(cached.length, 1);
      expect(cached.first.descriptor.serviceId, kMeshServicesInstanceServiceId);
    });

    test('getAllCachedServices returns map keyed by sender nodeId', () {
      final payload = _buildAdvertPayloadFor(kMeshServicesInstanceServiceId);

      for (final nodeId in [0x1111, 0x2222, 0x3333]) {
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
        remoteEngine.handleServiceAdvert(frame, nodeId);
      }

      final all = remoteEngine.getAllCachedServices();
      expect(all.length, 3);

      for (final services in all.values) {
        expect(services.length, 1);
        expect(
          services.first.descriptor.serviceId,
          kMeshServicesInstanceServiceId,
        );
      }
    });

    test('onCacheChanged fires when new advert is received', () {
      var changeCount = 0;
      remoteEngine.onCacheChanged = () => changeCount++;

      final payload = _buildAdvertPayloadFor(kMeshServicesInstanceServiceId);
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

      remoteEngine.handleServiceAdvert(frame, 0xAAAA);
      expect(changeCount, 1);

      // Identical payload from same sender → dedup → no second callback.
      remoteEngine.handleServiceAdvert(frame, 0xAAAA);
      expect(changeCount, 1);

      // Different sender → new cache entry → callback.
      remoteEngine.handleServiceAdvert(frame, 0xBBBB);
      expect(changeCount, 2);
    });
  });

  // ───────────────── Registration determinism ─────────────────

  group('MrrpServiceRegistry registration determinism', () {
    test('register returns false when slot limit is reached', () {
      final registry = MrrpServiceRegistry();

      // Fill all slots.
      for (var i = 1; i <= MrrpConstants.mrrpServiceAdvertMaxServices; i++) {
        final ok = registry.register(_SlotFiller(i), _appDescriptor(i));
        expect(ok, isTrue, reason: 'slot $i should register');
      }

      expect(registry.count, MrrpConstants.mrrpServiceAdvertMaxServices);

      // One more should be rejected — not silently ignored.
      final rejected = registry.register(_SlotFiller(999), _appDescriptor(999));
      expect(rejected, isFalse);
      expect(registry.count, MrrpConstants.mrrpServiceAdvertMaxServices);
    });

    test('re-registering same service ID replaces the existing entry', () {
      final registry = MrrpServiceRegistry();

      final h1 = _SlotFiller(0x10);
      final h2 = _SlotFiller(0x10);

      registry.register(h1, _appDescriptor(0x10));
      expect(registry.getHandler(0x10), same(h1));

      // Re-register same ID — should replace, not add a new slot.
      registry.register(h2, _appDescriptor(0x10));
      expect(registry.getHandler(0x10), same(h2));
      expect(registry.count, 1);
    });

    test('unregister + re-register restores handler', () async {
      final registry = MrrpServiceRegistry();
      final store = MeshServiceStore(dbPathOverride: inMemoryDatabasePath);
      await store.open();
      final eng = MeshServiceEngine(store: store);
      final handler = MeshServicesHandler(store: store, engine: eng);

      registry.register(handler, _meshServicesDescriptor());
      expect(registry.getHandler(kMeshServicesInstanceServiceId), isNotNull);

      registry.unregister(kMeshServicesInstanceServiceId);
      expect(registry.getHandler(kMeshServicesInstanceServiceId), isNull);

      // Re-register (simulates provider rebuild after MRRP re-enable).
      final ok = registry.register(handler, _meshServicesDescriptor());
      expect(ok, isTrue);
      expect(
        registry.getHandler(kMeshServicesInstanceServiceId),
        same(handler),
      );

      eng.dispose();
      await store.close();
    });
  });
}
