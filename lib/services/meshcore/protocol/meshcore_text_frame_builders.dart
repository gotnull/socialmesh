// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pure helpers for assembling MeshCore text-message wire frames.
// Mirrors the inline builders in `meshcore_chat_screen.dart`
// (`_buildSendTextMsgFrame` / `_buildSendChannelTextMsgFrame`) so the
// automation engine + chat screen can both speak the same wire shape
// without each duplicating the byte layout.
//
// Wire formats are frozen by the upstream MeshCore protocol — see
// `examples/companion_radio/MyMesh.cpp` in `meshcore-dev/MeshCore` for
// the firmware side. The watched commit is pinned in
// `meshcore_protocol/pin.yml`. Do not change field offsets / sizes
// without bumping the pin.

import 'dart:convert';
import 'dart:typed_data';

import '../../../core/meshcore_constants.dart';
import 'meshcore_frame.dart';

// CMD_SEND_TXT_MSG (0x02) — contact-direct DM.
// Layout: [txt_type=0][attempt=0][ts:4 LE][recipient_pubkey_prefix:6][text][\0]
MeshCoreFrame meshCoreBuildSendContactTextFrame({
  required Uint8List recipientPubKey,
  required String text,
  required int timestampS,
}) {
  final builder = BytesBuilder();
  builder.addByte(0); // txt_type = plain
  builder.addByte(0); // attempt = 0
  builder.addByte(timestampS & 0xFF);
  builder.addByte((timestampS >> 8) & 0xFF);
  builder.addByte((timestampS >> 16) & 0xFF);
  builder.addByte((timestampS >> 24) & 0xFF);
  builder.add(recipientPubKey.sublist(0, 6));
  builder.add(utf8.encode(text));
  builder.addByte(0);

  return MeshCoreFrame(
    command: MeshCoreCommands.sendTxtMsg,
    payload: builder.toBytes(),
  );
}

// CMD_SEND_CHANNEL_TXT_MSG (0x03) — channel broadcast.
// Layout: [txt_type=0][channel_idx][ts:4 LE][text][\0]
MeshCoreFrame meshCoreBuildSendChannelTextFrame({
  required int channelIndex,
  required String text,
  required int timestampS,
}) {
  final builder = BytesBuilder();
  builder.addByte(0); // txt_type = plain
  builder.addByte(channelIndex);
  builder.addByte(timestampS & 0xFF);
  builder.addByte((timestampS >> 8) & 0xFF);
  builder.addByte((timestampS >> 16) & 0xFF);
  builder.addByte((timestampS >> 24) & 0xFF);
  builder.add(utf8.encode(text));
  builder.addByte(0);

  return MeshCoreFrame(
    command: MeshCoreCommands.sendChannelTxtMsg,
    payload: builder.toBytes(),
  );
}
