// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D37-C-A - pure render-order + filter-aware-reorder helpers for the
// MeshCore channels screen. Kept separate from the screen widget so
// the algorithm has direct unit-test coverage (no widget pumping).
//
// Order list semantics:
//   - The user-defined order is a list of MeshCore channel slot
//     indices. Channels whose slot index is present in the list render
//     first, in the list's exact order. Channels not in the list
//     render after, in firmware slot-index ascending order.
//   - Slot index is the only stable, non-secret identifier (mirrors
//     mute / hide). Channel name and PSK are never part of the order
//     identity.
//   - The order list survives schema bumps because it sits in a
//     forward-compatible JSON blob alongside `muted` and `hidden`.
//
// Filter-aware reorder semantics:
//   - When the user reorders a *filtered* view (Public / Private /
//     Hidden), channels outside the active filter must keep their
//     positions in the full order. Only the visible subset shuffles.
//   - The algorithm: capture the positions of the visible tiles
//     within the current full order; rewrite those positions with the
//     visible tiles in their post-drag sequence. Unaffected positions
//     stay untouched.

import '../../../models/meshcore_channel.dart';

/// Returns [firmwareSorted] reordered to put channels listed in
/// [userOrder] first (in [userOrder]'s sequence), followed by channels
/// not in [userOrder] in their original slot-index order.
///
/// Invariants:
///   - never adds or removes channels; output length == input length.
///   - empty [userOrder] returns [firmwareSorted] unchanged.
///   - missing slot indices in [userOrder] are silently dropped at
///     render time (no error logged — the prefs store may carry stale
///     entries from before a channel was removed).
///   - duplicate slot indices in [userOrder] are deduped (first wins).
List<MeshCoreChannel> applyChannelOrder(
  List<MeshCoreChannel> firmwareSorted,
  List<int> userOrder,
) {
  if (userOrder.isEmpty) return firmwareSorted;

  // Build an index lookup from the firmware list for O(1) resolution
  // by slot index.
  final bySlot = <int, MeshCoreChannel>{
    for (final c in firmwareSorted) c.index: c,
  };

  final listed = <MeshCoreChannel>[];
  final seen = <int>{};
  for (final idx in userOrder) {
    if (!seen.add(idx)) continue; // dedup first-wins
    final ch = bySlot[idx];
    if (ch == null) continue; // stale entry, drop silently
    listed.add(ch);
  }

  final unlisted = <MeshCoreChannel>[];
  for (final ch in firmwareSorted) {
    if (seen.contains(ch.index)) continue;
    unlisted.add(ch);
  }

  return [...listed, ...unlisted];
}

/// Compute the new full-order list after the user drags a tile from
/// [oldVisibleIndex] to [newVisibleIndex] within the currently
/// rendered [visible] subset of [full].
///
/// Channels in [full] but not in [visible] keep their absolute slots
/// in the returned order; only the slots occupied by [visible] get
/// rewritten with the visible-after-drag sequence.
///
/// Returns a new list of slot indices in the user's preferred order
/// suitable to pass to `MeshCoreChannelPrefsNotifier.setOrder`.
///
/// Behaviour notes:
///   - [full] must already reflect the user's current render order
///     (i.e. the output of [applyChannelOrder]).
///   - [visible] must be a subset of [full] preserving relative order.
///   - Slot index is the identity; equality is by `index`.
///   - The Flutter `onReorder` callback hands us indexes that need the
///     standard `newIndex--` fixup when moving forward; the caller is
///     responsible for that fixup before calling this helper.
List<int> computeReorderedFullList({
  required List<MeshCoreChannel> full,
  required List<MeshCoreChannel> visible,
  required int oldVisibleIndex,
  required int newVisibleIndex,
}) {
  if (oldVisibleIndex == newVisibleIndex) {
    return full.map((c) => c.index).toList();
  }

  // 1. Compute the visible-after-drag sequence by moving the dragged
  //    tile inside [visible].
  final visibleSlots = visible.map((c) => c.index).toList();
  if (oldVisibleIndex < 0 ||
      oldVisibleIndex >= visibleSlots.length ||
      newVisibleIndex < 0 ||
      newVisibleIndex >= visibleSlots.length) {
    // Defensive: bad indices return the unchanged full order.
    return full.map((c) => c.index).toList();
  }
  final dragged = visibleSlots.removeAt(oldVisibleIndex);
  visibleSlots.insert(newVisibleIndex, dragged);

  // 2. Map visible-set membership for O(1) lookup.
  final visibleSet = <int>{for (final c in visible) c.index};

  // 3. Walk the full list. Whenever we hit a slot that was in the
  //    visible set, consume the next entry from [visibleSlots] in
  //    its new order; otherwise keep the full-list entry in place.
  final result = <int>[];
  var visiblePtr = 0;
  for (final ch in full) {
    if (visibleSet.contains(ch.index)) {
      result.add(visibleSlots[visiblePtr++]);
    } else {
      result.add(ch.index);
    }
  }
  return result;
}
