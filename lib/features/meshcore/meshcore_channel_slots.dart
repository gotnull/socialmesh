// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// The lowest channel slot below [capacity] that is not in [used], or null
/// when every slot is taken. [capacity] is the radio's slot count
/// (`meshCoreChannelSlotCapacityProvider`), which varies by board and build.
int? firstFreeMeshCoreChannelSlot(Iterable<int> used, int capacity) {
  final taken = used.toSet();
  for (var i = 0; i < capacity; i++) {
    if (!taken.contains(i)) return i;
  }
  return null;
}
