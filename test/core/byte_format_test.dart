// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/units/byte_format.dart';

void main() {
  group('formatByteSize', () {
    test('renders bytes whole', () {
      expect(formatByteSize(0), '0 B');
      expect(formatByteSize(1), '1 B');
      expect(formatByteSize(1023), '1023 B');
    });

    test('steps up a unit at each 1024 boundary', () {
      expect(formatByteSize(1024), '1.0 KB');
      expect(formatByteSize(1024 * 1024), '1.0 MB');
      expect(formatByteSize(1024 * 1024 * 1024), '1.0 GB');
      expect(formatByteSize(1024 * 1024 * 1024 * 1024), '1.0 TB');
    });

    test('keeps one decimal place above bytes', () {
      expect(formatByteSize(1536), '1.5 KB');
      expect(formatByteSize(24576), '24.0 KB');
      expect(formatByteSize(1441792), '1.4 MB');
    });

    test('rolls up rather than printing a full unit of the smaller one', () {
      // 1048570 B is 1023.99 KB — rounding to one decimal would otherwise
      // print "1024.0 KB".
      expect(formatByteSize(1048570), '1.0 MB');
    });

    test('caps at the largest known unit', () {
      final huge = 1024 * 1024 * 1024 * 1024 * 1024 * 5;
      expect(formatByteSize(huge), endsWith(' TB'));
    });

    test('treats a negative size as empty', () {
      expect(formatByteSize(-1), '0 B');
    });
  });

  group('formatNodeId', () {
    test('renders the canonical eight-hex-digit form', () {
      expect(formatNodeId(0xa6960864), '!a6960864');
      expect(formatNodeId(0x0abc), '!00000abc');
    });

    test('masks values wider than 32 bits', () {
      expect(formatNodeId(0x1ffffffff), '!ffffffff');
    });
  });
}
