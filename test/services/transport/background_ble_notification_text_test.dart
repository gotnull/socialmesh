// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/transport/background_ble_service.dart';

void main() {
  // Fixed reference clock so the relative "time ago" labels are deterministic.
  final now = DateTime(2026, 6, 28, 12, 0, 0);

  String body({
    required int styleValue,
    int? nodeCount,
    DateTime? lastMessageAt,
  }) {
    return BackgroundBleService.buildNotificationBody(
      styleValue: styleValue,
      nodeCount: nodeCount,
      lastMessageAt: lastMessageAt,
      now: now,
    );
  }

  group('BackgroundBleService.buildNotificationBody', () {
    test('minimal style ignores stats and shows the static text', () {
      expect(
        body(
          styleValue: 0,
          nodeCount: 12,
          lastMessageAt: now.subtract(const Duration(minutes: 3)),
        ),
        'Mesh radio connection active',
      );
    });

    test('detailed style with no stats falls back to the minimal text', () {
      expect(body(styleValue: 1), 'Mesh radio connection active');
    });

    test('detailed style shows node count and last message age', () {
      expect(
        body(
          styleValue: 1,
          nodeCount: 12,
          lastMessageAt: now.subtract(const Duration(minutes: 3)),
        ),
        '12 nodes heard, last message 3m ago',
      );
    });

    test('detailed style singularises a single node', () {
      expect(body(styleValue: 1, nodeCount: 1), '1 node heard');
    });

    test('detailed style shows node count alone when no messages yet', () {
      expect(body(styleValue: 1, nodeCount: 5), '5 nodes heard');
    });

    test('detailed style shows last message alone when node count is null', () {
      expect(
        body(
          styleValue: 1,
          lastMessageAt: now.subtract(const Duration(hours: 2)),
        ),
        'last message 2h ago',
      );
    });

    test('zero nodes still renders (not treated as missing)', () {
      expect(body(styleValue: 1, nodeCount: 0), '0 nodes heard');
    });

    group('relative age boundaries', () {
      test('under five seconds reads "just now"', () {
        expect(
          body(
            styleValue: 1,
            lastMessageAt: now.subtract(const Duration(seconds: 3)),
          ),
          'last message just now',
        );
      });

      test('seconds granularity', () {
        expect(
          body(
            styleValue: 1,
            lastMessageAt: now.subtract(const Duration(seconds: 42)),
          ),
          'last message 42s ago',
        );
      });

      test('hours granularity', () {
        expect(
          body(
            styleValue: 1,
            lastMessageAt: now.subtract(const Duration(hours: 5)),
          ),
          'last message 5h ago',
        );
      });

      test('days granularity', () {
        expect(
          body(
            styleValue: 1,
            lastMessageAt: now.subtract(const Duration(days: 2)),
          ),
          'last message 2d ago',
        );
      });

      test('a future timestamp (clock skew) reads "just now"', () {
        expect(
          body(
            styleValue: 1,
            lastMessageAt: now.add(const Duration(seconds: 30)),
          ),
          'last message just now',
        );
      });
    });
  });
}
