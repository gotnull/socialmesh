// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/messaging/message_utils.dart';

void main() {
  test('parsePushMessagePayload preserves packet metadata when present', () {
    final message = parsePushMessagePayload({
      'fromNode': '10',
      'toNode': '20',
      'text': '👍',
      'timestamp': '1712736000000',
      'packetId': '42',
      'replyId': '41',
      'isEmoji': 'true',
    });

    expect(message, isNotNull);
    expect(message?.packetId, 42);
    expect(message?.replyId, 41);
    expect(message?.isEmoji, isTrue);
  });
}
