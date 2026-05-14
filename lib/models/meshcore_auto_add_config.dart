// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D47-A: per-device auto-add policy carried in the single-byte
// payload of `CMD_SET_AUTO_ADD_CONFIG (0x3A)` and the
// `RESP_CODE_AUTO_ADD_CONFIG (0x19)` response. Each bit corresponds
// to one auto-promotion category (chat / repeater / room / sensor)
// or the eviction policy (overwrite-oldest).
//
// Round-trip note: the wire-format reserves bits 0x20..0x80. We
// preserve those bits verbatim on encode so an app that loaded an
// older config from a forward-compat firmware doesn't strip newly-
// introduced toggles by writing the config back.

import '../core/meshcore_constants.dart';

class MeshCoreAutoAddConfig {
  /// Evict the oldest non-favorite contact when the firmware roster
  /// is full and a new candidate qualifies.
  final bool overwriteOldest;

  /// Auto-add chat / companion-type contacts.
  final bool autoAddChat;

  /// Auto-add repeater-type contacts.
  final bool autoAddRepeater;

  /// Auto-add room-server-type contacts.
  final bool autoAddRoomServer;

  /// Auto-add sensor-type contacts.
  final bool autoAddSensor;

  /// Bits 0x20..0x80 preserved verbatim from the wire so a write
  /// back doesn't drop forward-compat firmware toggles we don't
  /// model yet. Always 0 for app-constructed instances.
  final int reservedBits;

  const MeshCoreAutoAddConfig({
    this.overwriteOldest = false,
    this.autoAddChat = false,
    this.autoAddRepeater = false,
    this.autoAddRoomServer = false,
    this.autoAddSensor = false,
    this.reservedBits = 0,
  });

  /// All-off default; matches firmware factory state.
  const MeshCoreAutoAddConfig.off()
    : overwriteOldest = false,
      autoAddChat = false,
      autoAddRepeater = false,
      autoAddRoomServer = false,
      autoAddSensor = false,
      reservedBits = 0;

  /// Pack the config into the single wire byte. Reserved bits flow
  /// through unchanged.
  int toFlagsByte() {
    var byte = reservedBits & 0xE0; // 0x20..0x80
    if (overwriteOldest) byte |= MeshCoreAutoAddFlag.overwriteOldest;
    if (autoAddChat) byte |= MeshCoreAutoAddFlag.chat;
    if (autoAddRepeater) byte |= MeshCoreAutoAddFlag.repeater;
    if (autoAddRoomServer) byte |= MeshCoreAutoAddFlag.roomServer;
    if (autoAddSensor) byte |= MeshCoreAutoAddFlag.sensor;
    return byte & 0xFF;
  }

  /// Parse a single wire byte into a typed config. Bits 0x20..0x80
  /// land in [reservedBits] for round-trip fidelity.
  static MeshCoreAutoAddConfig fromFlagsByte(int byte) {
    final masked = byte & 0xFF;
    return MeshCoreAutoAddConfig(
      overwriteOldest: (masked & MeshCoreAutoAddFlag.overwriteOldest) != 0,
      autoAddChat: (masked & MeshCoreAutoAddFlag.chat) != 0,
      autoAddRepeater: (masked & MeshCoreAutoAddFlag.repeater) != 0,
      autoAddRoomServer: (masked & MeshCoreAutoAddFlag.roomServer) != 0,
      autoAddSensor: (masked & MeshCoreAutoAddFlag.sensor) != 0,
      reservedBits: masked & 0xE0,
    );
  }

  MeshCoreAutoAddConfig copyWith({
    bool? overwriteOldest,
    bool? autoAddChat,
    bool? autoAddRepeater,
    bool? autoAddRoomServer,
    bool? autoAddSensor,
    int? reservedBits,
  }) {
    return MeshCoreAutoAddConfig(
      overwriteOldest: overwriteOldest ?? this.overwriteOldest,
      autoAddChat: autoAddChat ?? this.autoAddChat,
      autoAddRepeater: autoAddRepeater ?? this.autoAddRepeater,
      autoAddRoomServer: autoAddRoomServer ?? this.autoAddRoomServer,
      autoAddSensor: autoAddSensor ?? this.autoAddSensor,
      reservedBits: reservedBits ?? this.reservedBits,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshCoreAutoAddConfig &&
          other.overwriteOldest == overwriteOldest &&
          other.autoAddChat == autoAddChat &&
          other.autoAddRepeater == autoAddRepeater &&
          other.autoAddRoomServer == autoAddRoomServer &&
          other.autoAddSensor == autoAddSensor &&
          other.reservedBits == reservedBits;

  @override
  int get hashCode => Object.hash(
    overwriteOldest,
    autoAddChat,
    autoAddRepeater,
    autoAddRoomServer,
    autoAddSensor,
    reservedBits,
  );

  @override
  String toString() =>
      // lint-allow: hardcoded-string — diagnostic, never user-visible.
      'MeshCoreAutoAddConfig(flags=0x'
      '${toFlagsByte().toRadixString(16).padLeft(2, '0')})';
}
