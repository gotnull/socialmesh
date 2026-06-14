// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/utils/byte_format.dart';

void main() {
  group('formatByteSize', () {
    test('bytes below 1 KiB show whole bytes', () {
      expect(formatByteSize(0), '0 B');
      expect(formatByteSize(512), '512 B');
      expect(formatByteSize(1023), '1023 B');
    });

    test('steps up through KB / MB / GB', () {
      expect(formatByteSize(1024), '1.0 KB');
      expect(formatByteSize(1536), '1.5 KB');
      expect(formatByteSize(1024 * 1024), '1.0 MB');
      expect(formatByteSize(1024 * 1024 * 1024), '1.0 GB');
    });

    test('honours fractionDigits', () {
      expect(
        formatByteSize(1024 * 1024 + 512 * 1024, fractionDigits: 2),
        '1.50 MB',
      );
      expect(formatByteSize(1536, fractionDigits: 0), '2 KB');
    });
  });
}
