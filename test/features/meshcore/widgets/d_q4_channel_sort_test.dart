// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D-Q4: `sortChannels` pure-helper pins.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/meshcore/widgets/meshcore_channel_sort.dart';
import 'package:socialmesh/models/meshcore_channel.dart';

MeshCoreChannel _ch(int index, String name) =>
    MeshCoreChannel(index: index, name: name, psk: Uint8List(16));

void main() {
  group('sortChannels - D-Q4', () {
    final input = [
      _ch(0, 'public'),
      _ch(1, 'Alerts'),
      _ch(2, 'zeta'),
      _ch(3, 'beta'),
    ];

    test('manual mode returns the input order verbatim', () {
      final out = sortChannels(input, mode: MeshCoreChannelSortMode.manual);
      expect(out.map((c) => c.index).toList(), [0, 1, 2, 3]);
    });

    test('aToZ sorts case-insensitively by displayName ascending', () {
      final out = sortChannels(input, mode: MeshCoreChannelSortMode.aToZ);
      expect(out.map((c) => c.displayName).toList(), [
        'Alerts',
        'beta',
        'public',
        'zeta',
      ]);
    });

    test('aToZ ties broken by slot index', () {
      final dupes = [_ch(5, 'alpha'), _ch(1, 'alpha'), _ch(3, 'alpha')];
      final out = sortChannels(dupes, mode: MeshCoreChannelSortMode.aToZ);
      expect(out.map((c) => c.index).toList(), [1, 3, 5]);
    });

    test('latest mode orders by lastMessageTime desc, nulls last', () {
      final times = <int, DateTime?>{
        0: DateTime(2026, 5, 15, 10),
        1: DateTime(2026, 5, 15, 12),
        2: null,
        3: DateTime(2026, 5, 15, 11),
      };
      final out = sortChannels(
        input,
        mode: MeshCoreChannelSortMode.latest,
        byIndexLastMessageTime: times,
      );
      expect(out.map((c) => c.index).toList(), [1, 3, 0, 2]);
    });

    test('latest mode with no activity at all falls back to slot index', () {
      final out = sortChannels(
        input,
        mode: MeshCoreChannelSortMode.latest,
        byIndexLastMessageTime: const {},
      );
      expect(out.map((c) => c.index).toList(), [0, 1, 2, 3]);
    });

    test(
      'unread mode orders by unread count desc, then time desc, then slot',
      () {
        final unread = <int, int>{0: 0, 1: 5, 2: 2, 3: 5};
        final times = <int, DateTime?>{
          1: DateTime(2026, 5, 15, 10),
          3: DateTime(2026, 5, 15, 11),
        };
        final out = sortChannels(
          input,
          mode: MeshCoreChannelSortMode.unread,
          byIndexUnreadCount: unread,
          byIndexLastMessageTime: times,
        );
        // 3 + 1 both have 5 unread; 3 has the more recent timestamp.
        // Then 2 (2 unread), then 0 (0 unread).
        expect(out.map((c) => c.index).toList(), [3, 1, 2, 0]);
      },
    );

    test('unread mode treats missing entries as 0', () {
      final out = sortChannels(input, mode: MeshCoreChannelSortMode.unread);
      // Everyone has 0 unread; tie-break is slot index.
      expect(out.map((c) => c.index).toList(), [0, 1, 2, 3]);
    });

    test('returned list is a copy (no input mutation)', () {
      final mutableInput = [_ch(2, 'z'), _ch(0, 'a'), _ch(1, 'm')];
      final out = sortChannels(
        mutableInput,
        mode: MeshCoreChannelSortMode.aToZ,
      );
      expect(out.map((c) => c.index).toList(), [0, 1, 2]);
      // Original list unchanged.
      expect(mutableInput.map((c) => c.index).toList(), [2, 0, 1]);
    });
  });
}
