// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Verifies the pet.v1 ingest path that runs when the MrrpEngine's
// onResponseObserved callback fires: a peer's broadcast RESPONSE is
// decoded and written to the remote_pet_cache keyed by the sender's
// Meshtastic nodeNum (not by any requester-side target).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/pet/models/pet_enums.dart';
import 'package:socialmesh/features/pet/models/pet_public_state.dart';
import 'package:socialmesh/features/pet/services/pet_public_state_codec.dart';
import 'package:socialmesh/features/pet/services/pet_repository.dart';
import 'package:socialmesh/features/pet/storage/pet_database.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_constants.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_frame.dart';
import 'package:socialmesh/services/protocol/sip/mrrp_types.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Pure function mirroring the pet.v1 observer wired in mrrp_providers.dart.
/// Kept here for unit testing without spinning up the full provider graph.
Future<void> observePetV1Response({
  required MrrpFrame frame,
  required int senderNodeId,
  required PetRepository repository,
  DateTime? at,
}) async {
  if (frame.serviceId != MrrpServiceId.petV1) return;
  if (frame.actionId != PetAction.getSummary) return;
  if ((frame.flags & MrrpFlags.isError) != 0) return;
  if (frame.payload.isEmpty) return;
  final decoded = PetPublicStateCodec.tryDecode(
    Uint8List.fromList(frame.payload),
  );
  if (decoded == null) return;
  await repository.saveRemotePet(
    nodeNum: senderNodeId,
    state: decoded,
    observedAt: at ?? DateTime.now(),
  );
}

MrrpFrame buildPetResponse({required PetPublicState state, int requestId = 1}) {
  final payload = PetPublicStateCodec.encode(state);
  return MrrpFrame(
    versionMajor: MrrpConstants.mrrpVersionMajor,
    versionMinor: MrrpConstants.mrrpVersionMinor,
    msgType: MrrpMessageType.response,
    flags: MrrpFlags.isResponse,
    headerLen: MrrpConstants.mrrpHeaderMin,
    requestId: requestId,
    serviceId: MrrpServiceId.petV1,
    actionId: PetAction.getSummary,
    payloadLen: payload.length,
    payload: payload,
  );
}

MrrpFrame buildPetError({int requestId = 2}) {
  return MrrpFrame(
    versionMajor: MrrpConstants.mrrpVersionMajor,
    versionMinor: MrrpConstants.mrrpVersionMinor,
    msgType: MrrpMessageType.error,
    flags: MrrpFlags.isResponse | MrrpFlags.isError,
    headerLen: MrrpConstants.mrrpHeaderMin,
    requestId: requestId,
    serviceId: MrrpServiceId.petV1,
    actionId: PetAction.getSummary,
    payloadLen: 1,
    payload: Uint8List.fromList([MrrpStatusCode.unauthorized.code]),
  );
}

PetPublicState samplePublic({
  int seed = 0xA5A5A5A5,
  PetStage stage = PetStage.adult,
  PetBranch branch = PetBranch.luminous,
  int age = 9,
}) {
  return PetPublicState(
    dnaSeed: seed,
    stage: stage,
    branch: branch,
    mood: PetMood.content,
    ageInDays: age,
    isAsleep: false,
    isSick: false,
    isCalling: false,
    isEvolving: false,
  );
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  PetRepository newRepo() =>
      PetRepository(PetDatabase(dbPathOverride: inMemoryDatabasePath));

  group('pet.v1 response observer ingest', () {
    test('successful response is cached under sender nodeNum', () async {
      final repo = newRepo();
      await repo.init();
      final expected = samplePublic(seed: 0x12345678);
      await observePetV1Response(
        frame: buildPetResponse(state: expected),
        senderNodeId: 0xBEEF,
        repository: repo,
      );
      final obs = await repo.loadRemotePet(0xBEEF);
      expect(obs, isNotNull);
      expect(obs!.state, expected);
      expect(obs.nodeNum, 0xBEEF);
      await repo.close();
    });

    test('empty payload (peer has no pet) is NOT cached', () async {
      final repo = newRepo();
      await repo.init();
      final frame = MrrpFrame(
        versionMajor: MrrpConstants.mrrpVersionMajor,
        versionMinor: MrrpConstants.mrrpVersionMinor,
        msgType: MrrpMessageType.response,
        flags: MrrpFlags.isResponse,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 99,
        serviceId: MrrpServiceId.petV1,
        actionId: PetAction.getSummary,
        payloadLen: 0,
        payload: Uint8List(0),
      );
      await observePetV1Response(
        frame: frame,
        senderNodeId: 0x1234,
        repository: repo,
      );
      expect(await repo.loadRemotePet(0x1234), isNull);
      await repo.close();
    });

    test('ERROR frame (sharing disabled) is NOT cached', () async {
      final repo = newRepo();
      await repo.init();
      await observePetV1Response(
        frame: buildPetError(),
        senderNodeId: 0xCAFE,
        repository: repo,
      );
      expect(await repo.loadRemotePet(0xCAFE), isNull);
      await repo.close();
    });

    test('non-pet service IDs are ignored', () async {
      final repo = newRepo();
      await repo.init();
      final frame = MrrpFrame(
        versionMajor: MrrpConstants.mrrpVersionMajor,
        versionMinor: MrrpConstants.mrrpVersionMinor,
        msgType: MrrpMessageType.response,
        flags: MrrpFlags.isResponse,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 3,
        serviceId: MrrpServiceId.profileV1,
        actionId: ProfileAction.getSummary,
        payloadLen: 2,
        payload: Uint8List.fromList([0, 0]),
      );
      await observePetV1Response(
        frame: frame,
        senderNodeId: 0x999,
        repository: repo,
      );
      expect(await repo.loadRemotePet(0x999), isNull);
      await repo.close();
    });

    test('malformed payload (wrong schema tag) is silently ignored', () async {
      final repo = newRepo();
      await repo.init();
      final frame = MrrpFrame(
        versionMajor: MrrpConstants.mrrpVersionMajor,
        versionMinor: MrrpConstants.mrrpVersionMinor,
        msgType: MrrpMessageType.response,
        flags: MrrpFlags.isResponse,
        headerLen: MrrpConstants.mrrpHeaderMin,
        requestId: 4,
        serviceId: MrrpServiceId.petV1,
        actionId: PetAction.getSummary,
        payloadLen: 8,
        payload: Uint8List.fromList([0xFF, 0, 0, 0, 0, 0, 0, 0]),
      );
      await observePetV1Response(
        frame: frame,
        senderNodeId: 0x777,
        repository: repo,
      );
      expect(await repo.loadRemotePet(0x777), isNull);
      await repo.close();
    });

    test('two peers ingested in succession both appear in the cache', () async {
      final repo = newRepo();
      await repo.init();
      final a = samplePublic(seed: 1, branch: PetBranch.steady);
      final b = samplePublic(seed: 2, branch: PetBranch.volatile);
      await observePetV1Response(
        frame: buildPetResponse(state: a, requestId: 10),
        senderNodeId: 0xAA,
        repository: repo,
        at: DateTime(2026, 4, 22, 10),
      );
      await observePetV1Response(
        frame: buildPetResponse(state: b, requestId: 11),
        senderNodeId: 0xBB,
        repository: repo,
        at: DateTime(2026, 4, 22, 11),
      );
      final obsA = await repo.loadRemotePet(0xAA);
      final obsB = await repo.loadRemotePet(0xBB);
      expect(obsA!.state.branch, PetBranch.steady);
      expect(obsB!.state.branch, PetBranch.volatile);
      await repo.close();
    });

    test('same peer overwrites prior observation', () async {
      final repo = newRepo();
      await repo.init();
      final older = samplePublic(seed: 1, stage: PetStage.juvenile);
      final newer = samplePublic(seed: 2, stage: PetStage.adult);
      await observePetV1Response(
        frame: buildPetResponse(state: older),
        senderNodeId: 0x55,
        repository: repo,
        at: DateTime(2026, 4, 1),
      );
      await observePetV1Response(
        frame: buildPetResponse(state: newer),
        senderNodeId: 0x55,
        repository: repo,
        at: DateTime(2026, 4, 22),
      );
      final obs = await repo.loadRemotePet(0x55);
      expect(obs!.state.stage, PetStage.adult);
      await repo.close();
    });
  });
}
