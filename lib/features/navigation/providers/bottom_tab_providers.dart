// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../providers/app_providers.dart';

// Stable string ids for the four built-in bottom-nav tabs. Once
// shipped, these must NEVER be renamed: persisted user-chosen orders
// reference them by id, and a rename would silently drop the user's
// preferences.
//
// Phase 2 will introduce additional tab ids when drawer-screens
// become promotable to bottom-nav. Adding new ids is safe; renaming
// existing ones is a release-contract violation.
const String bottomTabIdMessages = 'messages';
const String bottomTabIdMap = 'map';
const String bottomTabIdNodes = 'nodes';
const String bottomTabIdDashboard = 'dashboard';

// Canonical default order of bottom-nav tabs. Mirrors the original
// hardcoded `_buildNavItems` order in `main_shell.dart` so users who
// have never reordered see no visual change.
const List<String> defaultBottomTabOrder = [
  bottomTabIdMessages,
  bottomTabIdMap,
  bottomTabIdNodes,
  bottomTabIdDashboard,
];

/// Reconciles a persisted custom tab order against the canonical
/// default set, returning the order the renderer should use.
///
/// Rules:
/// 1. Ids in [customOrder] that still exist in [defaultIds] render
///    first, in their stored order. This honours user intent.
/// 2. Ids in [defaultIds] that are NOT in [customOrder] (e.g. a new
///    tab added in a future release that the user never reordered)
///    append in default order. This means new tabs never disappear
///    on update.
/// 3. Stale ids in [customOrder] (refer to a tab no longer in
///    [defaultIds]) are silently dropped. This protects against
///    feature flags removing a tab without losing the rest of the
///    user's order.
///
/// Pure function so widget tests can pin the reconciliation contract
/// without spinning up the full shell.
List<String> applyBottomTabOrder(
  List<String> defaultIds,
  List<String>? customOrder,
) {
  if (customOrder == null) return defaultIds;
  final defaultSet = defaultIds.toSet();
  final retained = <String>[
    for (final id in customOrder)
      if (defaultSet.contains(id)) id,
  ];
  final placed = retained.toSet();
  final missing = [
    for (final id in defaultIds)
      if (!placed.contains(id)) id,
  ];
  return [...retained, ...missing];
}

/// Notifier exposing the user's resolved bottom-tab order. Watches
/// SettingsService.bottomTabOrder and applies
/// [applyBottomTabOrder] so the rest of the app reads a clean,
/// already-reconciled list of ids.
class BottomTabOrderNotifier extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final settings = await ref.watch(settingsServiceProvider.future);
    return applyBottomTabOrder(defaultBottomTabOrder, settings.bottomTabOrder);
  }

  /// Persist a new order. Pass `null` to clear customization and
  /// fall back to the default order. Updates happen optimistically
  /// (state first, persistence next) so the bottom nav redraws
  /// without waiting on disk I/O.
  Future<void> setOrder(List<String>? ids) async {
    final settings = await ref.read(settingsServiceProvider.future);
    final next = applyBottomTabOrder(defaultBottomTabOrder, ids);
    state = AsyncData(next);
    await settings.setBottomTabOrder(ids);
    AppLogging.settings(
      '[BottomTab] order updated -> ${ids?.join(',') ?? 'default'}',
    );
  }

  /// Convenience: reorder by physical positions (oldIndex -> newIndex
  /// in the current resolved order). Used directly by the
  /// long-press drag handler so the call site stays a one-liner.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final current = state.value ?? defaultBottomTabOrder;
    if (oldIndex < 0 ||
        oldIndex >= current.length ||
        newIndex < 0 ||
        newIndex > current.length) {
      return;
    }
    // ReorderableListView passes newIndex as the target slot in the
    // PRE-removal list. Normalise to the post-removal index so the
    // splice is symmetric.
    final from = oldIndex;
    final to = newIndex > oldIndex ? newIndex - 1 : newIndex;
    if (from == to) return;
    final next = [...current];
    final moved = next.removeAt(from);
    next.insert(to, moved);
    await setOrder(next);
  }

  /// Drop any user customization. Phase 1 has no UI surface that
  /// calls this directly (the user can drag back to the default
  /// order manually), but it ships now so Phase 2's settings screen
  /// has a hook to wire up the "Reset to defaults" CTA.
  Future<void> resetToDefaults() async {
    await setOrder(null);
  }
}

final bottomTabOrderProvider =
    AsyncNotifierProvider<BottomTabOrderNotifier, List<String>>(
      BottomTabOrderNotifier.new,
    );

/// Transient in-memory flag: are we currently in bottom-nav reorder
/// edit mode? Mirrors `drawerEditModeProvider` for the drawer
/// surface. Long-press on any bottom tab enters edit mode; tapping
/// any tab exits edit mode (and selects that tab) so the user
/// always has a single-tap exit path.
class BottomNavEditModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void enter() {
    if (state) return;
    state = true;
    AppLogging.settings('[BottomTab] edit mode entered');
  }

  void exit() {
    if (!state) return;
    state = false;
    AppLogging.settings('[BottomTab] edit mode exited');
  }
}

final bottomNavEditModeProvider =
    NotifierProvider<BottomNavEditModeNotifier, bool>(
      BottomNavEditModeNotifier.new,
    );
