// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_detail_payload.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_template.dart';
import 'package:socialmesh/features/mesh_services/services/mesh_service_engine.dart';
import 'package:socialmesh/features/mesh_services/services/mesh_service_store.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('mesh service interactions', () {
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

    MrrpFrame makeRequest(int actionId, Uint8List payload) {
      return MrrpFrame(
        versionMajor: 0,
        versionMinor: 1,
        msgType: MrrpMessageType.request,
        flags: 0,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 0x42,
        serviceId: kMeshServicesInstanceServiceId,
        actionId: actionId,
        payloadLen: payload.length,
        payload: payload,
      );
    }

    MeshServiceRemoteDetailExtension decodeExtension(
      MeshServiceType type,
      Uint8List payload,
    ) {
      var offset = 3;
      final titleLength = payload[offset++];
      offset += titleLength;
      final descriptionLength = payload[offset++];
      offset += descriptionLength;
      offset += 4;

      return MeshServiceDetailPayloadCodec.decode(
        type,
        Uint8List.sublistView(payload, offset),
      );
    }

    List<int> decodePollCounts(Uint8List payload) {
      final optionCount = payload[0];
      final counts = <int>[];
      var offset = 1;

      for (var index = 0; index < optionCount; index++) {
        counts.add(
          ByteData.sublistView(
            payload,
            offset,
            offset + 2,
          ).getUint16(0, Endian.little),
        );
        offset += 2;
      }

      return counts;
    }

    List<bool> decodeChecklistStates(Uint8List payload) {
      final itemCount = payload[0];
      return [
        for (var index = 0; index < itemCount; index++) payload[index + 1] != 0,
      ];
    }

    test(
      'poll voting updates counts and requester-specific selection',
      () async {
        final instance = await engine.createInstance(
          canonicalType: MeshServiceType.poll,
          title: 'Best route?',
          ttlMinutes: 60,
          config: const {
            'options': ['North', 'South', 'Stay put'],
          },
        );

        final firstVote = await engine.handleInteraction(
          instance!,
          0xAA,
          Uint8List.fromList([1]),
        );
        expect(decodePollCounts(firstVote!), [0, 1, 0]);

        await engine.handleInteraction(instance, 0xBB, Uint8List.fromList([1]));
        final movedVote = await engine.handleInteraction(
          instance,
          0xAA,
          Uint8List.fromList([2]),
        );
        expect(decodePollCounts(movedVote!), [0, 1, 1]);

        final response = await handler.handleRequest(
          makeRequest(
            MeshServicesAction.getInstance,
            MeshServicesHandler.encodeInstanceId(instance.instanceId),
          ),
          0xAA,
        );
        final extension = decodeExtension(
          MeshServiceType.poll,
          response.payload,
        );

        expect(extension.pollOptions, ['North', 'South', 'Stay put']);
        expect(extension.pollVoteCounts, [0, 1, 1]);
        expect(extension.selectedPollOption, 2);
      },
    );

    test(
      'checklist toggles update shared state and getInstance detail',
      () async {
        final instance = await engine.createInstance(
          canonicalType: MeshServiceType.list,
          presetId: MeshServicePresetId.sharedChecklist,
          title: 'Camp setup',
          ttlMinutes: 60,
          config: const {
            'items': ['Filter water', 'Pitch tent', 'Check radio'],
          },
        );

        final firstToggle = await engine.handleInteraction(
          instance!,
          0xAA,
          Uint8List.fromList([1, 1]),
        );
        expect(decodeChecklistStates(firstToggle!), [false, true, false]);

        final secondToggle = await engine.handleInteraction(
          instance,
          0xBB,
          Uint8List.fromList([2, 1]),
        );
        expect(decodeChecklistStates(secondToggle!), [false, true, true]);

        final response = await handler.handleRequest(
          makeRequest(
            MeshServicesAction.getInstance,
            MeshServicesHandler.encodeInstanceId(instance.instanceId),
          ),
          0xAA,
        );
        final extension = decodeExtension(
          MeshServiceType.list,
          response.payload,
        );

        expect(extension.listItems, [
          'Filter water',
          'Pitch tent',
          'Check radio',
        ]);
        expect(extension.listItemStates, [false, true, true]);
        expect(extension.listTotalItems, 3);
      },
    );
  });
}
