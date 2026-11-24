// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/meshcore_constants.dart';
import 'package:socialmesh/features/meshcore/parsers/meshcore_message_frame_parser.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_frame.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_smaz.dart';

String _compressed(String text) =>
    's:${base64Encode(meshCoreSmazCompress(Uint8List.fromList(utf8.encode(text))))}';

Uint8List _v3Contact(int txtType, String text) => Uint8List.fromList([
  8, 0, 0, // snr, reserved
  0x79, 0x42, 0x6d, 0x8d, 0x01, 0x02, // sender prefix
  0, txtType, // path_len, txt_type
  0x7c, 0x1d, 0x05, 0x6b, // timestamp
  ...utf8.encode(text),
]);

void main() {
  const sentence = 'the meeting is at the station in the morning';

  test('codebook words compress to single codes', () {
    // "the" is code 1 and " " code 0 in the standard codebook.
    expect(meshCoreSmazCompress(Uint8List.fromList(utf8.encode('the'))), [1]);
    expect(meshCoreSmazCompress(Uint8List.fromList(utf8.encode(' '))), [0]);
  });

  test('a compressed text round-trips', () {
    final packed = _compressed(sentence);
    expect(packed.length, lessThan(sentence.length));
    expect(meshCoreSmazDecodeText(packed), sentence);
  });

  test('UTF-8 outside the codebook survives as verbatim bytes', () {
    const text = 'the relay at the station is back 📡 the end';
    expect(meshCoreSmazDecodeText(_compressed(text)), text);
  });

  test('decodes what other MeshCore clients send', () {
    // Produced by another MeshCore client's SMAZ encoder.
    expect(meshCoreSmazDecodeText('s:AXvrSmN0hwE+yI0paQF7KglG'), sentence);
    expect(
      meshCoreSmazDecodeText('s:mdf+a0ZOaHMtAP5DBlqWOyQh6EYAU1vNWx4H7ngM'),
      'checking in from Coburg, reading you loud and clear',
    );
    expect(
      meshCoreSmazDecodeText('s:AdGJR4cBPsiNKXRa7/5rAP8D8J+ToQ0LMxg='),
      'the relay at the station is back 📡 the end',
    );
  });

  test('plain text that starts with s: is left alone', () {
    expect(meshCoreSmazDecodeText('s:test'), isNull);
    expect(meshCoreSmazDecodeText('s: see you there'), isNull);
    expect(meshCoreSmazDecodeText('hello'), isNull);
    expect(meshCoreSmazDecodeText('s:'), isNull);
  });

  group('inbound frames', () {
    test('a compressed DM is shown expanded', () {
      final frame = MeshCoreFrame(
        command: MeshCoreResponses.contactMsgRecvV3,
        payload: _v3Contact(MeshCoreTextTypes.plain, _compressed(sentence)),
      );
      final v = MeshCoreMessageFrameParser.parseContactMessage(frame).value!;
      expect(v.text, sentence);
    });

    test('a CLI reply is never expanded', () {
      final packed = _compressed(sentence);
      final frame = MeshCoreFrame(
        command: MeshCoreResponses.contactMsgRecvV3,
        payload: _v3Contact(MeshCoreTextTypes.cliData, packed),
      );
      final v = MeshCoreMessageFrameParser.parseContactMessage(frame).value!;
      expect(v.text, packed);
    });

    test('a channel post keeps its sender and expands the text', () {
      final frame = MeshCoreFrame(
        command: MeshCoreResponses.channelMsgRecvV3,
        payload: Uint8List.fromList([
          8, 0, 0, // snr, reserved
          1, 0, 0, // channel, path_len, txt_type
          0x7c, 0x1d, 0x05, 0x6b, // timestamp
          ...utf8.encode('Coburg Hill: ${_compressed(sentence)}'),
        ]),
      );
      final v = MeshCoreMessageFrameParser.parseChannelMessage(frame).value!;
      expect(v.text, 'Coburg Hill: $sentence');
    });
  });
}
