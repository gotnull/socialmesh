// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q9 Row 51 pure-decoder pins. The decoder is the contract the
// Frame Log screen renders inline; these tests pin:
//   - The (direction, opcode) registry separates TX vs RX so
//     opcodes that share a byte value (e.g. 0x03 =
//     CMD_SEND_CHANNEL_TXT_MSG on TX vs RESP_CODE_CONTACT on RX)
//     route to the correct parser.
//   - Privacy: send-text decoders never emit the plaintext; only
//     the byte count + timestamp + flags. Pubkeys are redacted
//     to the 8-byte fingerprint.
//   - PSK preview is the first 4 hex chars + ellipsis.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/services/meshcore/diagnostics/meshcore_frame_decoder.dart';

void main() {
  group('decodeMeshCoreFrame: direction disambiguates shared byte 0x03', () {
    test('TX 0x03 routes to sendChannelTxtMsg decoder', () {
      // [channel_idx][txt_type][timestamp:u32 LE][text 5 bytes]
      final payload = Uint8List.fromList([
        0x02, // channel 2
        0x01, // text type
        0x10, 0x20, 0x30, 0x40, // timestamp = 0x40302010
        ...List.filled(5, 0x41), // 'AAAAA'
      ]);
      final fields = decodeMeshCoreFrame(
        direction: MeshCoreFrameDirection.tx,
        opcode: MeshCoreCommands.sendChannelTxtMsg,
        payload: payload,
      );
      expect(fields, isNotEmpty);
      final labels = fields.map((f) => f.label).toList();
      expect(labels, contains('channel'));
      expect(labels, contains('text_len'));
      // Privacy guard: no plaintext.
      for (final f in fields) {
        expect(f.value, isNot(contains('AAAAA')));
      }
    });

    test('RX 0x03 routes to contact decoder (NOT sendChannelTxtMsg)', () {
      // 32 bytes pubkey + extra body.
      final payload = Uint8List.fromList(List.generate(64, (i) => i & 0xFF));
      final fields = decodeMeshCoreFrame(
        direction: MeshCoreFrameDirection.rx,
        opcode: MeshCoreResponses.contact,
        payload: payload,
      );
      expect(fields, isNotEmpty);
      final labels = fields.map((f) => f.label).toList();
      expect(labels, contains('pubkey'));
      expect(labels, isNot(contains('channel')));
    });
  });

  group('decodeMeshCoreFrame: privacy invariants', () {
    test('sendTxtMsg never emits the plaintext', () {
      const plaintext = 'Secret hello to peer';
      final payload = Uint8List.fromList([
        ...List.filled(32, 0xAA), // pubkey
        0x01, // txt type
        0x10, 0x20, 0x30, 0x40, // timestamp
        ...plaintext.codeUnits,
      ]);
      final fields = decodeMeshCoreFrame(
        direction: MeshCoreFrameDirection.tx,
        opcode: MeshCoreCommands.sendTxtMsg,
        payload: payload,
      );
      for (final f in fields) {
        expect(f.value, isNot(contains('Secret')));
        expect(f.value, isNot(contains('hello')));
      }
    });

    test('sendTxtMsg pubkey is redacted to the 8-byte fingerprint', () {
      final pubkey = Uint8List.fromList(List.generate(32, (i) => 0xCC));
      final payload = Uint8List.fromList([
        ...pubkey,
        0x01, 0x10, 0x20, 0x30, 0x40,
        0x68, 0x69, // 'hi'
      ]);
      final fields = decodeMeshCoreFrame(
        direction: MeshCoreFrameDirection.tx,
        opcode: MeshCoreCommands.sendTxtMsg,
        payload: payload,
      );
      final toField = fields.firstWhere((f) => f.label == 'to');
      // Full 64-char pubkey hex must NEVER appear.
      expect(toField.value, isNot(contains('cccccccc' * 4)));
      // Fingerprint format is `32B:<8 hex>…<8 hex>` — 21 chars,
      // well under the full 64-char pubkey.
      expect(toField.value.length, lessThanOrEqualTo(24));
    });

    test('channelInfo psk preview is 4 hex chars + ellipsis', () {
      final psk = Uint8List.fromList(List.generate(16, (i) => 0xF0 + (i % 16)));
      final payload = Uint8List.fromList([
        0x02, // slot
        ...'Public'.codeUnits,
        ...List.filled(26, 0), // pad name to 32
        ...psk,
      ]);
      final fields = decodeMeshCoreFrame(
        direction: MeshCoreFrameDirection.rx,
        opcode: MeshCoreResponses.channelInfo,
        payload: payload,
      );
      final pskField = fields.firstWhere((f) => f.label == 'psk');
      expect(pskField.value, equals('f0f1f2f3…'));
    });
  });

  group('decodeMeshCoreFrame: too-short payloads return empty', () {
    test('sendTxtMsg with < 37 bytes returns empty', () {
      final fields = decodeMeshCoreFrame(
        direction: MeshCoreFrameDirection.tx,
        opcode: MeshCoreCommands.sendTxtMsg,
        payload: Uint8List(36),
      );
      expect(fields, isEmpty);
    });

    test('sent with < 9 bytes returns empty', () {
      final fields = decodeMeshCoreFrame(
        direction: MeshCoreFrameDirection.rx,
        opcode: MeshCoreResponses.sent,
        payload: Uint8List(8),
      );
      expect(fields, isEmpty);
    });

    test('channelInfo with < 49 bytes returns empty', () {
      final fields = decodeMeshCoreFrame(
        direction: MeshCoreFrameDirection.rx,
        opcode: MeshCoreResponses.channelInfo,
        payload: Uint8List(48),
      );
      expect(fields, isEmpty);
    });

    test('unknown opcode returns empty (raw-hex fallback path)', () {
      final fields = decodeMeshCoreFrame(
        direction: MeshCoreFrameDirection.rx,
        opcode: 0xFE, // unknown
        payload: Uint8List.fromList([1, 2, 3, 4]),
      );
      expect(fields, isEmpty);
    });
  });

  group('decodeMeshCoreFrame: sent / err / stats', () {
    test(
      'sent decodes route_type + tag (u32 LE) + est_timeout_ms (u32 LE)',
      () {
        // route_type=0x01, tag=0xDEADBEEF, est=0x000003E8 (1000ms)
        final payload = Uint8List.fromList([
          0x01,
          0xEF,
          0xBE,
          0xAD,
          0xDE,
          0xE8,
          0x03,
          0x00,
          0x00,
        ]);
        final fields = decodeMeshCoreFrame(
          direction: MeshCoreFrameDirection.rx,
          opcode: MeshCoreResponses.sent,
          payload: payload,
        );
        expect(
          fields.firstWhere((f) => f.label == 'tag').value.toLowerCase(),
          contains('deadbeef'),
        );
        expect(
          fields.firstWhere((f) => f.label == 'est_timeout_ms').value,
          '1000',
        );
      },
    );

    test('err with reason byte surfaces the reason', () {
      final fields = decodeMeshCoreFrame(
        direction: MeshCoreFrameDirection.rx,
        opcode: MeshCoreResponses.err,
        payload: Uint8List.fromList([0x07]),
      );
      expect(fields, hasLength(2));
      expect(fields[0].value, 'ERR');
      expect(fields[1].label, 'reason');
      expect(fields[1].value, '0x07');
    });

    test('getStats TX subtype byte renders RADIO / CORE / PACKETS labels', () {
      for (final entry in {
        MeshCoreStatsType.radio: 'RADIO',
        MeshCoreStatsType.core: 'CORE',
        MeshCoreStatsType.packets: 'PACKETS',
      }.entries) {
        final fields = decodeMeshCoreFrame(
          direction: MeshCoreFrameDirection.tx,
          opcode: MeshCoreCommands.getStats,
          payload: Uint8List.fromList([entry.key]),
        );
        expect(fields.single.value, contains(entry.value));
      }
    });
  });

  group('meshCoreFrameHasDecoder: registry allow-list', () {
    test('TX-side known commands are registered', () {
      expect(
        meshCoreFrameHasDecoder(
          direction: MeshCoreFrameDirection.tx,
          opcode: MeshCoreCommands.sendTxtMsg,
        ),
        isTrue,
      );
      expect(
        meshCoreFrameHasDecoder(
          direction: MeshCoreFrameDirection.tx,
          opcode: MeshCoreCommands.getChannel,
        ),
        isTrue,
      );
    });

    test('RX-side known responses are registered', () {
      expect(
        meshCoreFrameHasDecoder(
          direction: MeshCoreFrameDirection.rx,
          opcode: MeshCoreResponses.contact,
        ),
        isTrue,
      );
      expect(
        meshCoreFrameHasDecoder(
          direction: MeshCoreFrameDirection.rx,
          opcode: MeshCoreResponses.channelInfo,
        ),
        isTrue,
      );
    });

    test('byte 0x03 has DIFFERENT registry presence per direction', () {
      // TX 0x03 = sendChannelTxtMsg (registered)
      expect(
        meshCoreFrameHasDecoder(
          direction: MeshCoreFrameDirection.tx,
          opcode: MeshCoreCommands.sendChannelTxtMsg,
        ),
        isTrue,
      );
      // RX 0x03 = contact (registered)
      expect(
        meshCoreFrameHasDecoder(
          direction: MeshCoreFrameDirection.rx,
          opcode: MeshCoreResponses.contact,
        ),
        isTrue,
      );
    });

    test('unknown opcode is NOT registered in either direction', () {
      expect(
        meshCoreFrameHasDecoder(
          direction: MeshCoreFrameDirection.tx,
          opcode: 0xFE,
        ),
        isFalse,
      );
      expect(
        meshCoreFrameHasDecoder(
          direction: MeshCoreFrameDirection.rx,
          opcode: 0xFE,
        ),
        isFalse,
      );
    });
  });
}
