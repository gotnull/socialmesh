// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_games/models/mesh_game_type.dart';
import 'package:socialmesh/features/mesh_games/transport/mesh_game_codec.dart';

void main() {
  group('MeshGameCodec header', () {
    test('magic + version/opcode pack correctly', () {
      final bytes = MeshGameCodec.encodeMove(
        revision: 1,
        moveData: Uint8List.fromList([0x00]),
      );
      expect(bytes[0], kMeshGameMagicByte);
      expect((bytes[1] >> 4) & 0x0F, kMeshGameProtocolVersion);
      expect(bytes[1] & 0x0F, MeshGameOpcode.move.code);
    });

    test('decode rejects wrong magic', () {
      expect(
        () => MeshGameCodec.decode(Uint8List.fromList([0x00, 0x13])),
        throwsA(isA<FormatException>()),
      );
    });

    test('decode rejects unsupported version', () {
      final bytes = Uint8List.fromList([
        kMeshGameMagicByte,
        (2 << 4) | MeshGameOpcode.move.code, // version 2
      ]);
      expect(
        () => MeshGameCodec.decode(bytes),
        throwsA(isA<FormatException>()),
      );
    });

    test('decode rejects unknown opcode', () {
      final bytes = Uint8List.fromList([
        kMeshGameMagicByte,
        (kMeshGameProtocolVersion << 4) | 0x0F, // opcode 15
      ]);
      expect(
        () => MeshGameCodec.decode(bytes),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('CREATE round-trip', () {
    test('rps create', () {
      final encoded = MeshGameCodec.encodeCreate(
        gameType: MeshGameType.rpsV1,
        revision: 0,
        stateBlob: Uint8List.fromList([0xFF, 0xFF]),
      );
      final frame = MeshGameCodec.decode(encoded);
      expect(frame.opcode, MeshGameOpcode.create);
      final body = MeshGameCodec.decodeCreate(frame.body);
      expect(body.gameType, MeshGameType.rpsV1);
      expect(body.revision, 0);
      expect(body.config, isEmpty);
      expect(body.stateBlob, [0xFF, 0xFF]);
    });

    test('ttt create with full state blob', () {
      final initialState = Uint8List.fromList([0, ...List.filled(9, 0)]);
      final encoded = MeshGameCodec.encodeCreate(
        gameType: MeshGameType.ticTacToeV1,
        revision: 0,
        stateBlob: initialState,
      );
      final body = MeshGameCodec.decodeCreate(
        MeshGameCodec.decode(encoded).body,
      );
      expect(body.gameType, MeshGameType.ticTacToeV1);
      expect(body.stateBlob, initialState);
    });

    test('create enforces state blob limit', () {
      expect(
        () => MeshGameCodec.encodeCreate(
          gameType: MeshGameType.rpsV1,
          revision: 0,
          stateBlob: Uint8List(9),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('MOVE round-trip', () {
    test('tiny move encodes and decodes', () {
      final encoded = MeshGameCodec.encodeMove(
        revision: 7,
        moveData: Uint8List.fromList([0x04]),
      );
      expect(encoded.length, 2 + 2 + 1 + 1);
      final frame = MeshGameCodec.decode(encoded);
      final body = MeshGameCodec.decodeMove(frame.body);
      expect(body.revision, 7);
      expect(body.moveData, [0x04]);
    });

    test('rejects moveData > 16 bytes', () {
      expect(
        () => MeshGameCodec.encodeMove(
          revision: 0,
          moveData: Uint8List(17),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('JOIN/QUIT/STATE_REQ', () {
    test('join round-trip', () {
      final encoded = MeshGameCodec.encodeJoin(revision: 3, status: 0x01);
      final body = MeshGameCodec.decodeJoin(MeshGameCodec.decode(encoded).body);
      expect(body.revision, 3);
      expect(body.status, 0x01);
    });

    test('quit round-trip', () {
      final encoded = MeshGameCodec.encodeQuit(revision: 42, reason: 0x01);
      final body = MeshGameCodec.decodeQuit(MeshGameCodec.decode(encoded).body);
      expect(body.revision, 42);
      expect(body.reason, 0x01);
    });

    test('state_req is just the header', () {
      final encoded = MeshGameCodec.encodeStateReq();
      expect(encoded.length, 2);
      final frame = MeshGameCodec.decode(encoded);
      expect(frame.opcode, MeshGameOpcode.stateReq);
      expect(frame.body, isEmpty);
    });
  });

  group('STATE_RESP round-trip', () {
    test('full payload encodes all fields', () {
      final blob = Uint8List.fromList(List.generate(16, (i) => i));
      final encoded = MeshGameCodec.encodeStateResp(
        revision: 5,
        turnIndex: 1,
        status: 0x02,
        winnerIndex: 0,
        stateBlob: blob,
      );
      final frame = MeshGameCodec.decode(encoded);
      final body = MeshGameCodec.decodeStateResp(frame.body);
      expect(body.revision, 5);
      expect(body.turnIndex, 1);
      expect(body.status, 0x02);
      expect(body.winnerIndex, 0);
      expect(body.stateBlob, blob);
    });

    test('rejects oversized state blob', () {
      expect(
        () => MeshGameCodec.encodeStateResp(
          revision: 0,
          turnIndex: 0,
          status: 1,
          winnerIndex: 0xFF,
          stateBlob: Uint8List(97),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('budget ceilings', () {
    test('RPS move encode fits in ~8 bytes', () {
      final encoded = MeshGameCodec.encodeMove(
        revision: 0xFFFF,
        moveData: Uint8List.fromList([0x02]),
      );
      expect(encoded.length, lessThanOrEqualTo(8));
    });

    test('TTT create encode fits under 179 B', () {
      final encoded = MeshGameCodec.encodeCreate(
        gameType: MeshGameType.ticTacToeV1,
        revision: 0,
        stateBlob: Uint8List(16),
      );
      expect(encoded.length, lessThan(MeshGameCodec.maxFrameBytes));
    });

    test('STATE_RESP with max blob stays under 179 B', () {
      final encoded = MeshGameCodec.encodeStateResp(
        revision: 0,
        turnIndex: 0,
        status: 1,
        winnerIndex: 0xFF,
        stateBlob: Uint8List(96),
      );
      expect(encoded.length, lessThan(MeshGameCodec.maxFrameBytes));
    });
  });
}
