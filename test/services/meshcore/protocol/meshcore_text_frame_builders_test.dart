// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_text_frame_builders.dart';

void main() {
  group('MeshCore text byte limits', () {
    test('a DM fills a 172-byte frame: 158 bytes of text', () {
      expect(meshCoreContactTextMaxBytes, 158);
      final frame = meshCoreBuildSendContactTextFrame(
        recipientPubKey: Uint8List(32),
        text: 'a' * meshCoreContactTextMaxBytes,
        timestampS: 1795493244,
      );
      expect(frame.isValidSize, isTrue);
      final over = meshCoreBuildSendContactTextFrame(
        recipientPubKey: Uint8List(32),
        text: 'a' * (meshCoreContactTextMaxBytes + 1),
        timestampS: 1795493244,
      );
      expect(over.isValidSize, isFalse);
    });

    test('a channel post leaves room for "<name>: "', () {
      // "WisMeshCore: " is 13 bytes.
      expect(meshCoreChannelTextByteLimit('WisMeshCore'), 147);
    });

    test('the sender name is measured in UTF-8 bytes', () {
      // "Port Phillip " is 13 bytes and the emoji 4, so 17 in all.
      expect(meshCoreChannelTextByteLimit('Port Phillip 📡'), 160 - 17 - 2);
    });

    test('an unknown name is taken at the longest the firmware stores', () {
      expect(meshCoreChannelTextByteLimit(null), 160 - 31 - 2);
    });
  });
}
