// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/meshcore/meshcore_channel_slots.dart';

void main() {
  test('returns the lowest slot not in use', () {
    expect(firstFreeMeshCoreChannelSlot(const [], 8), 0);
    expect(firstFreeMeshCoreChannelSlot(const [0, 1, 3], 8), 2);
  });

  test('looks past slot 7 on a radio with more slots', () {
    final firstEight = List<int>.generate(8, (i) => i);
    expect(firstFreeMeshCoreChannelSlot(firstEight, 40), 8);
    expect(firstFreeMeshCoreChannelSlot(firstEight, 8), isNull);
  });

  test('returns null when every slot is taken', () {
    expect(
      firstFreeMeshCoreChannelSlot(List<int>.generate(21, (i) => i), 21),
      isNull,
    );
  });
}
