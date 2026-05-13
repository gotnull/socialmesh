// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../providers/app_providers.dart';
import '../widgets/drawer_menu_tile.dart';

/// User-controlled drawer customization state (hidden items + custom
/// order). Backed by SharedPreferences via [SettingsService] so the
/// state survives cold restarts.
///
/// The drawer renderer in `main_shell.dart` consumes this snapshot,
/// applies it as a filter + reorder over the default
/// `_buildDrawerMenuItems` output, and never touches the raw default
/// list. Items with `DrawerMenuItem.id == null` are NOT customizable
/// and are always rendered in their default position.
class DrawerCustomizationState {
  /// Set of item IDs the user has hidden.
  final Set<String> hiddenIds;

  /// User-chosen order of item IDs. `null` ⇒ use default order.
  /// Items with ids present here render in this order, before any
  /// items whose ids are absent (newly added items, etc.).
  final List<String>? customOrder;

  const DrawerCustomizationState({
    required this.hiddenIds,
    required this.customOrder,
  });

  static const DrawerCustomizationState empty = DrawerCustomizationState(
    hiddenIds: <String>{},
    customOrder: null,
  );

  bool get isModified => hiddenIds.isNotEmpty || customOrder != null;

  DrawerCustomizationState copyWith({
    Set<String>? hiddenIds,
    List<String>? customOrder,
    bool clearCustomOrder = false,
  }) {
    return DrawerCustomizationState(
      hiddenIds: hiddenIds ?? this.hiddenIds,
      customOrder: clearCustomOrder ? null : (customOrder ?? this.customOrder),
    );
  }
}

class DrawerCustomizationNotifier
    extends AsyncNotifier<DrawerCustomizationState> {
  @override
  Future<DrawerCustomizationState> build() async {
    final settings = await ref.watch(settingsServiceProvider.future);
    return DrawerCustomizationState(
      hiddenIds: settings.drawerHiddenItems.toSet(),
      customOrder: settings.drawerItemOrder,
    );
  }

  Future<void> hide(String id) async {
    final settings = await ref.read(settingsServiceProvider.future);
    final current = state.value ?? DrawerCustomizationState.empty;
    if (current.hiddenIds.contains(id)) return;
    final next = current.copyWith(hiddenIds: {...current.hiddenIds, id});
    state = AsyncData(next);
    await settings.setDrawerHiddenItems(next.hiddenIds.toList());
    AppLogging.settings('[Drawer] hide id=$id hidden=${next.hiddenIds.length}');
  }

  Future<void> show(String id) async {
    final settings = await ref.read(settingsServiceProvider.future);
    final current = state.value ?? DrawerCustomizationState.empty;
    if (!current.hiddenIds.contains(id)) return;
    final next = current.copyWith(
      hiddenIds: current.hiddenIds.where((e) => e != id).toSet(),
    );
    state = AsyncData(next);
    await settings.setDrawerHiddenItems(next.hiddenIds.toList());
    AppLogging.settings('[Drawer] show id=$id hidden=${next.hiddenIds.length}');
  }

  /// Persist an explicit ordering of item IDs. Pass `null` to clear and
  /// revert to default order.
  Future<void> setOrder(List<String>? ids) async {
    final settings = await ref.read(settingsServiceProvider.future);
    final current = state.value ?? DrawerCustomizationState.empty;
    final next = current.copyWith(
      customOrder: ids,
      clearCustomOrder: ids == null,
    );
    state = AsyncData(next);
    await settings.setDrawerItemOrder(ids);
    AppLogging.settings('[Drawer] setOrder length=${ids?.length ?? 'default'}');
  }

  /// Reset every customization back to defaults (drops hidden items
  /// AND custom order). The summary sheet's "Reset" CTA dispatches here.
  Future<void> resetToDefaults() async {
    final settings = await ref.read(settingsServiceProvider.future);
    state = const AsyncData(DrawerCustomizationState.empty);
    await settings.setDrawerHiddenItems(const <String>[]);
    await settings.setDrawerItemOrder(null);
    AppLogging.settings('[Drawer] resetToDefaults');
  }
}

final drawerCustomizationProvider =
    AsyncNotifierProvider<
      DrawerCustomizationNotifier,
      DrawerCustomizationState
    >(DrawerCustomizationNotifier.new);

/// Transient in-memory flag: are we currently in long-press edit mode?
///
/// Not persisted — edit mode exits when the drawer closes or the user
/// taps Done. We keep it on its own provider so the rest of the drawer
/// can read it cheaply without rebuilding when the persisted
/// customization state changes.
class DrawerEditModeNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void enter() {
    if (state) return;
    state = true;
    AppLogging.settings('[Drawer] edit mode entered');
  }

  void exit() {
    if (!state) return;
    state = false;
    AppLogging.settings('[Drawer] edit mode exited');
  }

  void toggle() => state ? exit() : enter();
}

final drawerEditModeProvider = NotifierProvider<DrawerEditModeNotifier, bool>(
  DrawerEditModeNotifier.new,
);

/// Applies the hidden-items filter from [state] to [defaultList].
/// Reordering is intentionally NOT applied here — section-aware
/// ordering lives in the drawer renderer (see `main_shell.dart`), which
/// groups by intrinsic section membership before sorting within each
/// section by `state.customOrder`. Doing the sort in this pure helper
/// would have a global effect and break section boundaries (an item
/// hoisted globally by customOrder would orphan itself from its
/// declared section).
///
/// Items with `id == null` cannot be hidden.
List<DrawerMenuItem> applyDrawerCustomization(
  List<DrawerMenuItem> defaultList,
  DrawerCustomizationState state,
) {
  return defaultList
      .where((item) => !(item.id != null && state.hiddenIds.contains(item.id)))
      .toList(growable: false);
}

/// Resolves the section membership of every item in [defaultList] by
/// walking forward and propagating the most-recently-seen
/// `sectionHeader` to subsequent items. Items appearing before any
/// section header land in the unnamed section (`''`).
///
/// Section identity is intentionally decoupled from physical position
/// in the rendered list — once a user starts reordering, the item
/// that originally bore a `sectionHeader` may end up elsewhere in its
/// section. Using this map for grouping keeps the section a stable
/// concept (every item knows the section it was born into) so a
/// reorder cannot orphan an item.
///
/// Keyed by `item.id`. Items with `id == null` are skipped (they
/// remain in their default position and are not customizable).
({Map<String, String> sectionByItemId, List<String> sectionTitlesInOrder})
deriveSectionMembership(List<DrawerMenuItem> defaultList) {
  final map = <String, String>{};
  final titles = <String>[];
  var current = '';
  for (final item in defaultList) {
    if (item.sectionHeader != null) {
      current = item.sectionHeader!;
    }
    if (!titles.contains(current)) {
      titles.add(current);
    }
    if (item.id != null) {
      map[item.id!] = current;
    }
  }
  return (sectionByItemId: map, sectionTitlesInOrder: titles);
}

/// Applies the user's intra-section custom order to [sectionItems]
/// (items belonging to a single section, in default order). Items
/// whose `id` is in [customOrder] sort by that index; items not in
/// `customOrder` keep their default position relative to each other
/// and come AFTER the custom-ordered items.
///
/// This isolated helper lets section-aware ordering live alongside
/// the section-membership derivation while keeping the logic
/// independently unit-testable.
List<DrawerMenuItem> applySectionOrder(
  List<DrawerMenuItem> sectionItems,
  List<String>? customOrder,
) {
  if (customOrder == null) return sectionItems;
  final orderIndex = <String, int>{
    for (var i = 0; i < customOrder.length; i++) customOrder[i]: i,
  };
  final inOrder =
      sectionItems
          .where((item) => item.id != null && orderIndex.containsKey(item.id))
          .toList()
        ..sort((a, b) => orderIndex[a.id]!.compareTo(orderIndex[b.id]!));
  final notInOrder = sectionItems.where(
    (item) => item.id == null || !orderIndex.containsKey(item.id),
  );
  return [...inOrder, ...notInOrder];
}
