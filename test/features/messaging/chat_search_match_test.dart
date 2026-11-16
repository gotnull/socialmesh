// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/messaging/chat_search_match.dart';
import 'package:socialmesh/models/mesh_models.dart';

Message _message({
  String text = 'see you at the ridge',
  String? senderLongName,
  String? senderShortName,
}) => Message(
  from: 0x4B5B951C,
  to: 0xFFFFFFFF,
  text: text,
  senderLongName: senderLongName,
  senderShortName: senderShortName,
);

void main() {
  group('messageMatchesChatSearch', () {
    test('matches the message text', () {
      expect(messageMatchesChatSearch(_message(), null, 'ridge'), isTrue);
    });

    test('matches the known sender long name', () {
      final sender = MeshNode(
        nodeNum: 0x4B5B951C,
        longName: 'ALR-CL-8',
        shortName: 'ALR',
      );
      expect(messageMatchesChatSearch(_message(), sender, 'alr-cl'), isTrue);
    });

    test('matches the known sender short name', () {
      final sender = MeshNode(
        nodeNum: 0x4B5B951C,
        longName: 'Lisbon Base',
        shortName: 'LSB1',
      );
      expect(messageMatchesChatSearch(_message(), sender, 'lsb1'), isTrue);
    });

    test('falls back to the names cached on the message', () {
      final message = _message(
        senderLongName: 'Porto Relay',
        senderShortName: 'PRT',
      );
      expect(messageMatchesChatSearch(message, null, 'porto'), isTrue);
      expect(messageMatchesChatSearch(message, null, 'prt'), isTrue);
    });

    test('does not match unrelated text or names', () {
      final sender = MeshNode(
        nodeNum: 0x4B5B951C,
        longName: 'Lisbon Base',
        shortName: 'LSB1',
      );
      expect(messageMatchesChatSearch(_message(), sender, 'porto'), isFalse);
    });
  });
}
