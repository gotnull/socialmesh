// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/utils/uptime_formatter.dart';

void main() {
  group('formatUptime', () {
    test('formats seconds', () {
      expect(formatUptime(0), '0s');
      expect(formatUptime(45), '45s');
      expect(formatUptime(59), '59s');
    });

    test('formats minutes', () {
      expect(formatUptime(60), '1m');
      expect(formatUptime(120), '2m');
      expect(formatUptime(3599), '59m');
    });

    test('formats hours and minutes', () {
      expect(formatUptime(3600), '1h 0m');
      expect(formatUptime(3660), '1h 1m');
      expect(formatUptime(7200), '2h 0m');
      expect(formatUptime(86399), '23h 59m');
    });

    test('formats days and hours', () {
      expect(formatUptime(86400), '1d 0h');
      expect(formatUptime(90000), '1d 1h');
      expect(formatUptime(172800), '2d 0h');
      expect(formatUptime(259200), '3d 0h');
    });
  });
}
