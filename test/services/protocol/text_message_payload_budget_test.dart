// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/protocol/text_message_payload_budget.dart';

void main() {
  group('TextMessagePayloadSizer', () {
    test('standard text message allows 228 UTF-8 bytes', () {
      final sizer = TextMessagePayloadSizer.standard();

      expect(sizer.maxUtf8Bytes, 228);

      final exact = sizer.measure('a' * 228);
      final over = sizer.measure('a' * 229);

      expect(exact.fitsInPacket, isTrue);
      expect(exact.encodedDataBytes, 233);
      expect(over.fitsInPacket, isFalse);
      expect(over.encodedDataBytes, 234);
    });

    test('reply messages reserve space for reply_id metadata', () {
      final sizer = TextMessagePayloadSizer.standard(replyId: 12345);

      expect(sizer.maxUtf8Bytes, 223);

      final exact = sizer.measure('a' * 223);
      final over = sizer.measure('a' * 224);

      expect(exact.fitsInPacket, isTrue);
      expect(exact.encodedDataBytes, 233);
      expect(over.fitsInPacket, isFalse);
      expect(over.encodedDataBytes, 234);
    });

    test('emoji tapbacks reserve space for emoji metadata', () {
      final sizer = TextMessagePayloadSizer.standard(isEmoji: true);

      expect(sizer.maxUtf8Bytes, 223);
    });

    test('counts UTF-8 bytes for multibyte characters', () {
      final sizer = TextMessagePayloadSizer.standard();
      final budget = sizer.measure('hello🙂');

      expect(TextMessagePayloadSizer.utf8ByteLength('hello🙂'), 9);
      expect(budget.utf8Bytes, 9);
      expect(budget.fitsInPacket, isTrue);
    });

    test('counts spaces in the raw draft byte length', () {
      final sizer = TextMessagePayloadSizer.standard();
      final budget = sizer.measure('Hello ');

      expect(TextMessagePayloadSizer.utf8ByteLength('Hello '), 6);
      expect(budget.utf8Bytes, 6);
      expect(budget.fitsInPacket, isTrue);
    });
  });
}
