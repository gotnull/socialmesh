// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Wire codec for mesh-games v1.
///
/// Frames are carried inside MRRP `interact` payloads (actionId
/// `0x0003`) targeting service `0x00000010`. The enclosing dispatcher
/// strips a leading 16-byte `instance_id` prefix; this codec operates
/// on the remaining inner payload.
///
/// See `docs/mesh_games/MESH_GAMES_V0_1.md` § 5 for the normative spec.
library;

import 'dart:typed_data';

import '../models/mesh_game_type.dart';

/// Discriminator byte for game-router frames.
///
/// Picked outside the 0..7 range that poll / checklist interact
/// payloads naturally occupy in their first byte, so the router can
/// unambiguously detect a game frame inside the shared
/// `MeshServicesAction.interact` action.
const int kMeshGameMagicByte = 0xA6;

/// Current wire protocol version (top nibble of byte 1).
const int kMeshGameProtocolVersion = 1;

enum MeshGameOpcode {
  create(0x1),
  join(0x2),
  move(0x3),
  stateReq(0x4),
  stateResp(0x5),
  quit(0x6);

  const MeshGameOpcode(this.code);

  final int code;

  static MeshGameOpcode? fromCode(int code) {
    for (final op in values) {
      if (op.code == code) return op;
    }
    return null;
  }
}

/// Decoded frame header. Payload interpretation depends on [opcode].
class MeshGameFrame {
  final int version;
  final MeshGameOpcode opcode;
  final Uint8List body;

  const MeshGameFrame({
    required this.version,
    required this.opcode,
    required this.body,
  });
}

/// Decoded `CREATE` body.
class MeshGameCreateBody {
  final MeshGameType gameType;
  final int revision;
  final Uint8List config;
  final Uint8List stateBlob;

  const MeshGameCreateBody({
    required this.gameType,
    required this.revision,
    required this.config,
    required this.stateBlob,
  });
}

/// Decoded `JOIN` body.
class MeshGameJoinBody {
  final int revision;
  final int status;

  const MeshGameJoinBody({required this.revision, required this.status});
}

/// Decoded `MOVE` body.
class MeshGameMoveBody {
  final int revision;
  final Uint8List moveData;

  const MeshGameMoveBody({required this.revision, required this.moveData});
}

/// Decoded `STATE_RESP` body.
class MeshGameStateRespBody {
  final int revision;
  final int turnIndex;
  final int status;
  final int winnerIndex;
  final Uint8List stateBlob;

  const MeshGameStateRespBody({
    required this.revision,
    required this.turnIndex,
    required this.status,
    required this.winnerIndex,
    required this.stateBlob,
  });
}

/// Decoded `QUIT` body.
class MeshGameQuitBody {
  final int revision;
  final int reason;

  const MeshGameQuitBody({required this.revision, required this.reason});
}

/// Encoder/decoder for the mesh-games wire format.
abstract final class MeshGameCodec {
  /// Absolute maximum size of a single encoded frame, so the caller
  /// can fail fast if it would blow the enclosing MRRP budget.
  /// 20 B MRRP header + 16 B instance ID prefix + body ≤ 179 B.
  static const int maxFrameBytes = 179;

  /// Decode the magic/version/opcode header. Throws [FormatException]
  /// on a malformed header or unsupported version.
  static MeshGameFrame decode(Uint8List payload) {
    if (payload.length < 2) {
      throw const FormatException('mesh-game frame under 2 bytes');
    }
    if (payload[0] != kMeshGameMagicByte) {
      throw FormatException(
        'mesh-game magic mismatch: 0x${payload[0].toRadixString(16)}',
      );
    }
    final version = (payload[1] >> 4) & 0x0F;
    final opcodeCode = payload[1] & 0x0F;
    if (version != kMeshGameProtocolVersion) {
      throw FormatException('unsupported mesh-game protocol version $version');
    }
    final opcode = MeshGameOpcode.fromCode(opcodeCode);
    if (opcode == null) {
      throw FormatException('unknown mesh-game opcode 0x$opcodeCode');
    }
    return MeshGameFrame(
      version: version,
      opcode: opcode,
      body: Uint8List.sublistView(payload, 2),
    );
  }

  // --- Header helpers -------------------------------------------------

  static void _writeHeader(BytesBuilder out, MeshGameOpcode opcode) {
    out.addByte(kMeshGameMagicByte);
    out.addByte((kMeshGameProtocolVersion << 4) | (opcode.code & 0x0F));
  }

  // --- CREATE ---------------------------------------------------------

  /// Encode a `CREATE` frame. `config` is an opaque game-type-specific
  /// blob ≤ 32 bytes (may be empty). `stateBlob` is the initial state
  /// as produced by the engine, ≤ 96 bytes.
  static Uint8List encodeCreate({
    required MeshGameType gameType,
    required int revision,
    Uint8List? config,
    required Uint8List stateBlob,
  }) {
    final cfg = config ?? Uint8List(0);
    if (cfg.length > 32) {
      throw ArgumentError('CREATE config exceeds 32 bytes: ${cfg.length}');
    }
    if (stateBlob.length > gameType.maxStateBytes) {
      throw ArgumentError(
        'CREATE stateBlob exceeds ${gameType.maxStateBytes} bytes',
      );
    }
    final out = BytesBuilder(copy: false);
    _writeHeader(out, MeshGameOpcode.create);
    out.addByte(gameType.code & 0xFF);
    _writeUint16(out, revision);
    out.addByte(cfg.length);
    out.add(cfg);
    out.add(stateBlob);
    return Uint8List.fromList(out.toBytes());
  }

  static MeshGameCreateBody decodeCreate(Uint8List body) {
    if (body.length < 4) {
      throw const FormatException('CREATE body < 4 bytes');
    }
    final type = MeshGameType.fromCode(body[0]);
    if (type == null) {
      throw FormatException('unknown game type code 0x${body[0]}');
    }
    final revision = _readUint16(body, 1);
    final cfgLen = body[3];
    final cfgEnd = 4 + cfgLen;
    if (cfgEnd > body.length) {
      throw const FormatException('CREATE config length overruns body');
    }
    final cfg = Uint8List.fromList(body.sublist(4, cfgEnd));
    final stateBlob = Uint8List.fromList(body.sublist(cfgEnd));
    if (stateBlob.length > type.maxStateBytes) {
      throw FormatException(
        'CREATE stateBlob exceeds ${type.maxStateBytes} bytes for $type',
      );
    }
    return MeshGameCreateBody(
      gameType: type,
      revision: revision,
      config: cfg,
      stateBlob: stateBlob,
    );
  }

  // --- JOIN -----------------------------------------------------------

  static Uint8List encodeJoin({required int revision, required int status}) {
    final out = BytesBuilder(copy: false);
    _writeHeader(out, MeshGameOpcode.join);
    _writeUint16(out, revision);
    out.addByte(status & 0xFF);
    return Uint8List.fromList(out.toBytes());
  }

  static MeshGameJoinBody decodeJoin(Uint8List body) {
    if (body.length < 3) throw const FormatException('JOIN body < 3 bytes');
    return MeshGameJoinBody(revision: _readUint16(body, 0), status: body[2]);
  }

  // --- MOVE -----------------------------------------------------------

  static Uint8List encodeMove({
    required int revision,
    required Uint8List moveData,
  }) {
    if (moveData.length > 16) {
      throw ArgumentError('MOVE data exceeds 16 bytes');
    }
    final out = BytesBuilder(copy: false);
    _writeHeader(out, MeshGameOpcode.move);
    _writeUint16(out, revision);
    out.addByte(moveData.length);
    out.add(moveData);
    return Uint8List.fromList(out.toBytes());
  }

  static MeshGameMoveBody decodeMove(Uint8List body) {
    if (body.length < 3) throw const FormatException('MOVE body < 3 bytes');
    final rev = _readUint16(body, 0);
    final len = body[2];
    if (3 + len > body.length) {
      throw const FormatException('MOVE data length overruns body');
    }
    return MeshGameMoveBody(
      revision: rev,
      moveData: Uint8List.fromList(body.sublist(3, 3 + len)),
    );
  }

  // --- STATE_REQ / STATE_RESP -----------------------------------------

  static Uint8List encodeStateReq() {
    final out = BytesBuilder(copy: false);
    _writeHeader(out, MeshGameOpcode.stateReq);
    return Uint8List.fromList(out.toBytes());
  }

  static Uint8List encodeStateResp({
    required int revision,
    required int turnIndex,
    required int status,
    required int winnerIndex,
    required Uint8List stateBlob,
  }) {
    if (stateBlob.length > 96) {
      throw ArgumentError('STATE_RESP stateBlob exceeds 96 bytes');
    }
    final out = BytesBuilder(copy: false);
    _writeHeader(out, MeshGameOpcode.stateResp);
    _writeUint16(out, revision);
    out.addByte(turnIndex & 0xFF);
    out.addByte(status & 0xFF);
    out.addByte(winnerIndex & 0xFF);
    out.addByte(stateBlob.length);
    out.add(stateBlob);
    return Uint8List.fromList(out.toBytes());
  }

  static MeshGameStateRespBody decodeStateResp(Uint8List body) {
    if (body.length < 6) {
      throw const FormatException('STATE_RESP body < 6 bytes');
    }
    final rev = _readUint16(body, 0);
    final turnIndex = body[2];
    final status = body[3];
    final winnerIndex = body[4];
    final len = body[5];
    if (6 + len > body.length) {
      throw const FormatException('STATE_RESP stateBlob overruns body');
    }
    return MeshGameStateRespBody(
      revision: rev,
      turnIndex: turnIndex,
      status: status,
      winnerIndex: winnerIndex,
      stateBlob: Uint8List.fromList(body.sublist(6, 6 + len)),
    );
  }

  // --- QUIT -----------------------------------------------------------

  static Uint8List encodeQuit({required int revision, required int reason}) {
    final out = BytesBuilder(copy: false);
    _writeHeader(out, MeshGameOpcode.quit);
    _writeUint16(out, revision);
    out.addByte(reason & 0xFF);
    return Uint8List.fromList(out.toBytes());
  }

  static MeshGameQuitBody decodeQuit(Uint8List body) {
    if (body.length < 3) throw const FormatException('QUIT body < 3 bytes');
    return MeshGameQuitBody(revision: _readUint16(body, 0), reason: body[2]);
  }

  // --- Shared helpers -------------------------------------------------

  static void _writeUint16(BytesBuilder out, int value) {
    final bytes = Uint8List(2);
    ByteData.sublistView(bytes).setUint16(0, value & 0xFFFF, Endian.little);
    out.add(bytes);
  }

  static int _readUint16(Uint8List body, int offset) {
    return ByteData.sublistView(
      body,
      offset,
      offset + 2,
    ).getUint16(0, Endian.little);
  }
}
