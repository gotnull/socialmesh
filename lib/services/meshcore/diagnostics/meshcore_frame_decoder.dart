// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q9 Row 51: pretty-printer registry for the MeshCore Frame Log
// viewer. Maps `(direction, opcode)` to a list of `(label, value)`
// pairs the UI renders inline below the raw hex.
//
// Direction matters: commands and responses share the byte space.
// Example: `0x03` means `CMD_SEND_CHANNEL_TXT_MSG` on TX but
// `RESP_CODE_CONTACT` on RX. The decoder branches on direction so
// the wrong parser never sees the wrong wire layout.
//
// Privacy invariants (mirror D-Q6 diagnostics bundle):
//   - NO chat / DM message bodies. Send-text and channel-text
//     opcodes show field structure only (timestamp, flags, byte
//     count); the plaintext is intentionally absent.
//   - NO full public keys. Anywhere a 32-byte pubkey appears we
//     show the 8-byte fingerprint via the existing
//     `AppLogging.publicKeyFingerprint` helper.
//   - NO PSK / channel-key bytes. The CHANNEL_INFO decoder shows
//     `psk: <first 4 hex>…` only.
//
// The registry is intentionally narrow — only opcodes whose
// structure is genuinely useful for field debugging get a decoder
// entry. Anything else falls through to "no decoded view; raw hex
// only", which is what the viewer already shows.

import 'dart:typed_data';

import '../../../core/logging.dart';
import '../../../core/meshcore_constants.dart';

/// A single decoded row to render under the raw hex. `label` is
/// localised externally (decoder bodies emit English-source labels
/// the screen maps to ARB keys; this keeps the decoder pure).
class MeshCoreFrameDecodedField {
  final String label;
  final String value;
  const MeshCoreFrameDecodedField(this.label, this.value);
}

/// Decode a captured frame's payload into a labelled key/value list.
/// TX vs RX disambiguator — the byte-space is shared so the same
/// opcode means different things on opposite directions.
enum MeshCoreFrameDirection { tx, rx }

/// Returns an empty list when the opcode has no registered decoder
/// or the payload is too short to parse — the caller renders the
/// raw hex as-is in that case.
///
/// Pure: no Riverpod, no I/O. Safe to call from any isolate.
List<MeshCoreFrameDecodedField> decodeMeshCoreFrame({
  required MeshCoreFrameDirection direction,
  required int opcode,
  required Uint8List payload,
}) {
  if (direction == MeshCoreFrameDirection.tx) {
    switch (opcode) {
      case MeshCoreCommands.sendTxtMsg:
        return _decodeSendTxtMsg(payload);
      case MeshCoreCommands.sendChannelTxtMsg:
        return _decodeSendChannelTxtMsg(payload);
      case MeshCoreCommands.getChannel:
        return _decodeGetChannel(payload);
      case MeshCoreCommands.getStats:
        return _decodeGetStats(payload);
      default:
        return const [];
    }
  }
  switch (opcode) {
    case MeshCoreResponses.ok:
      return const [MeshCoreFrameDecodedField('result', 'OK')];
    case MeshCoreResponses.err:
      return _decodeErr(payload);
    case MeshCoreResponses.sent:
      return _decodeSent(payload);
    case MeshCoreResponses.channelInfo:
      return _decodeChannelInfo(payload);
    case MeshCoreResponses.contact:
      return _decodeContact(payload);
    case MeshCoreResponses.stats:
      return _decodeStatsResponse(payload);
    case MeshCorePushCodes.binaryResponse:
      return _decodeBinaryResponse(payload);
    case MeshCorePushCodes.statusResponse:
      return [MeshCoreFrameDecodedField('size', '${payload.length} B')];
    default:
      return const [];
  }
}

/// Returns `true` when the `(direction, opcode)` pair has a
/// registered decoder. UI uses this to decide whether to show a
/// "Decoded" header above the fields list.
bool meshCoreFrameHasDecoder({
  required MeshCoreFrameDirection direction,
  required int opcode,
}) {
  if (direction == MeshCoreFrameDirection.tx) {
    return _txAllowList.contains(opcode);
  }
  return _rxAllowList.contains(opcode);
}

const Set<int> _txAllowList = {
  MeshCoreCommands.sendTxtMsg,
  MeshCoreCommands.sendChannelTxtMsg,
  MeshCoreCommands.getChannel,
  MeshCoreCommands.getStats,
};

const Set<int> _rxAllowList = {
  MeshCoreResponses.ok,
  MeshCoreResponses.err,
  MeshCoreResponses.sent,
  MeshCoreResponses.channelInfo,
  MeshCoreResponses.contact,
  MeshCoreResponses.stats,
  MeshCorePushCodes.binaryResponse,
  MeshCorePushCodes.statusResponse,
};

// ---------------------------------------------------------------------------
// Per-opcode decoders.
// ---------------------------------------------------------------------------

List<MeshCoreFrameDecodedField> _decodeSendTxtMsg(Uint8List p) {
  // Wire: [pubkey:32][txt_type:u8][timestamp:u32 LE][text...]
  // We deliberately do NOT surface the plaintext.
  if (p.length < 37) return const [];
  final pubkey = p.sublist(0, 32);
  final txtType = p[32];
  final ts = ByteData.sublistView(p, 33, 37).getUint32(0, Endian.little);
  final textLen = p.length - 37;
  return [
    MeshCoreFrameDecodedField('to', AppLogging.publicKeyFingerprint(pubkey)),
    MeshCoreFrameDecodedField('txt_type', _hex2(txtType)),
    MeshCoreFrameDecodedField('timestamp', '$ts'),
    MeshCoreFrameDecodedField('text_len', '$textLen B'),
  ];
}

List<MeshCoreFrameDecodedField> _decodeSendChannelTxtMsg(Uint8List p) {
  // Wire: [channel_idx:u8][txt_type:u8][timestamp:u32 LE][text...]
  if (p.length < 6) return const [];
  final slot = p[0];
  final txtType = p[1];
  final ts = ByteData.sublistView(p, 2, 6).getUint32(0, Endian.little);
  final textLen = p.length - 6;
  return [
    MeshCoreFrameDecodedField('channel', '$slot'),
    MeshCoreFrameDecodedField('txt_type', _hex2(txtType)),
    MeshCoreFrameDecodedField('timestamp', '$ts'),
    MeshCoreFrameDecodedField('text_len', '$textLen B'),
  ];
}

List<MeshCoreFrameDecodedField> _decodeGetChannel(Uint8List p) {
  if (p.isEmpty) return const [];
  return [MeshCoreFrameDecodedField('slot', '${p[0]}')];
}

List<MeshCoreFrameDecodedField> _decodeGetStats(Uint8List p) {
  if (p.isEmpty) return const [];
  final subtype = p[0];
  final label = switch (subtype) {
    MeshCoreStatsType.radio => 'RADIO',
    MeshCoreStatsType.core => 'CORE',
    MeshCoreStatsType.packets => 'PACKETS',
    _ => '?',
  };
  return [MeshCoreFrameDecodedField('subtype', '${_hex2(subtype)} ($label)')];
}

List<MeshCoreFrameDecodedField> _decodeErr(Uint8List p) {
  if (p.isEmpty) {
    return const [MeshCoreFrameDecodedField('result', 'ERR')];
  }
  return [
    const MeshCoreFrameDecodedField('result', 'ERR'),
    MeshCoreFrameDecodedField('reason', _hex2(p[0])),
  ];
}

List<MeshCoreFrameDecodedField> _decodeSent(Uint8List p) {
  // Wire: [route_type:u8][tag:u32 LE][est_timeout_ms:u32 LE]
  if (p.length < 9) return const [];
  final routeType = p[0];
  final tag = ByteData.sublistView(p, 1, 5).getUint32(0, Endian.little);
  final estTimeout = ByteData.sublistView(p, 5, 9).getUint32(0, Endian.little);
  return [
    MeshCoreFrameDecodedField('route_type', _hex2(routeType)),
    MeshCoreFrameDecodedField('tag', '0x${tag.toRadixString(16)}'),
    MeshCoreFrameDecodedField('est_timeout_ms', '$estTimeout'),
  ];
}

List<MeshCoreFrameDecodedField> _decodeChannelInfo(Uint8List p) {
  // Wire: [slot:u8][name:32 null-padded][psk:16]
  if (p.length < 1 + 32 + 16) return const [];
  final slot = p[0];
  final nameBytes = p.sublist(1, 33);
  final firstNull = nameBytes.indexOf(0);
  final nameLen = firstNull < 0 ? 32 : firstNull;
  final name = nameLen == 0
      ? '<empty>'
      : String.fromCharCodes(nameBytes.sublist(0, nameLen));
  final pskHead = p
      .sublist(33, 37)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return [
    MeshCoreFrameDecodedField('slot', '$slot'),
    MeshCoreFrameDecodedField('name', name),
    MeshCoreFrameDecodedField('psk', '$pskHead…'),
  ];
}

List<MeshCoreFrameDecodedField> _decodeContact(Uint8List p) {
  // The full contact wire layout is large (~100 bytes). The viewer
  // only needs a quick identity badge, so we surface the leading
  // pubkey fingerprint + payload length and let the user open the
  // full Contact Detail screen for the rest.
  if (p.length < 32) return const [];
  return [
    MeshCoreFrameDecodedField(
      'pubkey',
      AppLogging.publicKeyFingerprint(p.sublist(0, 32)),
    ),
    MeshCoreFrameDecodedField('size', '${p.length} B'),
  ];
}

List<MeshCoreFrameDecodedField> _decodeStatsResponse(Uint8List p) {
  if (p.isEmpty) return const [];
  final subtype = p[0];
  final label = switch (subtype) {
    MeshCoreStatsType.radio => 'RADIO',
    MeshCoreStatsType.core => 'CORE',
    MeshCoreStatsType.packets => 'PACKETS',
    _ => '?',
  };
  return [
    MeshCoreFrameDecodedField('subtype', '${_hex2(subtype)} ($label)'),
    MeshCoreFrameDecodedField('body_len', '${p.length - 1} B'),
  ];
}

List<MeshCoreFrameDecodedField> _decodeBinaryResponse(Uint8List p) {
  // Wire: [reserved:u8][tag:u32 LE][response_data...]
  if (p.length < 5) return const [];
  final tag = ByteData.sublistView(p, 1, 5).getUint32(0, Endian.little);
  return [
    MeshCoreFrameDecodedField('tag', '0x${tag.toRadixString(16)}'),
    MeshCoreFrameDecodedField('body_len', '${p.length - 5} B'),
  ];
}

String _hex2(int b) => '0x${b.toRadixString(16).padLeft(2, '0').toUpperCase()}';
