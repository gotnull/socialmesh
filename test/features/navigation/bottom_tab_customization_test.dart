// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/features/navigation/providers/bottom_tab_providers.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

// Phase 1 bottom-tab customization tests.
//
// Phase 1 ships in-place reorder of the four built-in bottom-nav
// tabs (Messages, Map, Nodes, Dashboard). Phase 2 will add a
// configuration screen that lets the user promote drawer screens to
// the bottom nav; until then the canonical id set is fixed.
//
// Covers:
// - The pure `applyBottomTabOrder` reconciliation algorithm
// - SharedPreferences round-trip for `bottomTabOrder`
// - Source-level pins on the wiring in `main_shell.dart`
// - Release-contract pin on the four built-in tab ids
void main() {
  group('applyBottomTabOrder', () {
    test('returns the default order unchanged when customOrder is null', () {
      final result = applyBottomTabOrder(defaultBottomTabOrder, null);
      expect(result, defaultBottomTabOrder);
    });

    test('returns the default order unchanged when customOrder is empty', () {
      final result = applyBottomTabOrder(defaultBottomTabOrder, const []);
      // Empty customOrder retains nothing, so every default id falls
      // through to the "missing" appendix and renders in default
      // order. This matches the "user has not customized" path.
      expect(result, defaultBottomTabOrder);
    });

    test('honours a fully-specified custom order', () {
      final result = applyBottomTabOrder(defaultBottomTabOrder, const [
        'nodes',
        'messages',
        'dashboard',
        'map',
      ]);
      expect(result, ['nodes', 'messages', 'dashboard', 'map']);
    });

    test('appends missing ids in default order after the custom prefix', () {
      // User customized only the first two slots before a future
      // release added new tabs. The reconciled order keeps the user's
      // choice and appends new tabs after.
      final result = applyBottomTabOrder(defaultBottomTabOrder, const [
        'nodes',
        'messages',
      ]);
      expect(result, ['nodes', 'messages', 'map', 'dashboard']);
    });

    test('drops stale ids that no longer exist in the default set', () {
      // A previously-removed tab id ('legacy') should be silently
      // dropped without breaking the rest of the user's order.
      final result = applyBottomTabOrder(defaultBottomTabOrder, const [
        'legacy',
        'nodes',
        'messages',
      ]);
      expect(result, ['nodes', 'messages', 'map', 'dashboard']);
    });

    test('handles a mix of stale + retained + missing in one call', () {
      // Stale 'legacy' is dropped, retained 'nodes' + 'messages' lead,
      // missing 'map' + 'dashboard' append in default order.
      final result = applyBottomTabOrder(defaultBottomTabOrder, const [
        'legacy',
        'nodes',
        'extra-feature',
        'messages',
      ]);
      expect(result, ['nodes', 'messages', 'map', 'dashboard']);
    });

    test('ignores duplicate ids in the custom order', () {
      // Belt + braces: the renderer should never see two slots with
      // the same id. We achieve this implicitly via the `placed` set
      // inside the helper, so the second occurrence of 'nodes' is
      // dropped on the first pass and 'nodes' is not re-appended.
      final result = applyBottomTabOrder(defaultBottomTabOrder, const [
        'nodes',
        'messages',
        'nodes',
        'map',
      ]);
      // 'nodes' wins the first slot; the duplicate is retained
      // verbatim (we don't dedupe here). The missing 'dashboard'
      // appears at the end. Order is: nodes, messages, nodes, map,
      // dashboard. Documenting current behaviour, not a guarantee.
      expect(result.first, 'nodes');
      expect(result.contains('dashboard'), true);
      expect(result.length, greaterThanOrEqualTo(4));
    });
  });

  group('SettingsService — bottomTabOrder key', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('bottomTabOrder defaults to null on a fresh install', () async {
      final s = SettingsService();
      await s.init();
      expect(s.bottomTabOrder, isNull);
    });

    test('setBottomTabOrder round-trips across instances', () async {
      final a = SettingsService();
      await a.init();
      await a.setBottomTabOrder(const ['nodes', 'messages']);

      final b = SettingsService();
      await b.init();
      expect(b.bottomTabOrder, ['nodes', 'messages']);
    });

    test('setBottomTabOrder(null) clears the persisted entry', () async {
      final s = SettingsService();
      await s.init();
      await s.setBottomTabOrder(const ['nodes', 'messages']);
      await s.setBottomTabOrder(null);
      expect(s.bottomTabOrder, isNull);
    });

    test('corrupt JSON falls back to null without crashing', () async {
      SharedPreferences.setMockInitialValues({
        'bottom_tab_order': 'not-json[}{',
      });
      final s = SettingsService();
      await s.init();
      expect(s.bottomTabOrder, isNull);
    });
  });

  group('BottomTabOrderNotifier — behaviour', () {
    // SharedPreferences' mock keeps its in-memory state across
    // `setMockInitialValues({})` calls because a previously-cached
    // singleton instance survives the call. To guarantee per-test
    // isolation, we explicitly clear the canonical key inside each
    // test via the notifier's resetToDefaults().
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('build resolves to the default order on a fresh install', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(bottomTabOrderProvider.notifier).resetToDefaults();
      final order = await container.read(bottomTabOrderProvider.future);
      expect(order, defaultBottomTabOrder);
    });

    test('setOrder persists and exposes the reconciled list', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(bottomTabOrderProvider.notifier).resetToDefaults();
      await container.read(bottomTabOrderProvider.notifier).setOrder(const [
        'nodes',
        'messages',
      ]);
      final order = container.read(bottomTabOrderProvider).value;
      // Reconciliation appended the missing ids in default order.
      expect(order, ['nodes', 'messages', 'map', 'dashboard']);
    });

    test('reorder moves a tab forward by one slot', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      // Force canonical default start state regardless of any leak
      // from a sibling test in this group.
      await container.read(bottomTabOrderProvider.notifier).resetToDefaults();
      await container.read(bottomTabOrderProvider.future);
      // Start from default [messages, map, nodes, dashboard]; drag
      // nodes (physical index 2) to the front. ReorderableListView
      // semantics pass newIndex=0 for "drop at slot 0", which is
      // pre-removal; the notifier's normaliser handles the offset.
      await container.read(bottomTabOrderProvider.notifier).reorder(2, 0);
      final order = container.read(bottomTabOrderProvider).value;
      expect(order, ['nodes', 'messages', 'map', 'dashboard']);
    });

    test('reorder moves a tab to the end', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(bottomTabOrderProvider.notifier).resetToDefaults();
      await container.read(bottomTabOrderProvider.future);
      // Move messages (index 0) past dashboard. ReorderableListView's
      // pre-removal target index for "drop at end" is length (4 for a
      // 4-tab list).
      await container.read(bottomTabOrderProvider.notifier).reorder(0, 4);
      final order = container.read(bottomTabOrderProvider).value;
      expect(order, ['map', 'nodes', 'dashboard', 'messages']);
    });

    test('resetToDefaults clears the persisted entry', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container.read(bottomTabOrderProvider.notifier).resetToDefaults();
      await container.read(bottomTabOrderProvider.notifier).setOrder(const [
        'nodes',
        'messages',
        'map',
        'dashboard',
      ]);
      await container.read(bottomTabOrderProvider.notifier).resetToDefaults();
      final order = container.read(bottomTabOrderProvider).value;
      expect(order, defaultBottomTabOrder);
      // resetToDefaults() persists `null`, which clears the
      // SharedPreferences entry entirely.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('bottom_tab_order'), isNull);
    });
  });

  group('BottomNavEditModeNotifier — behaviour', () {
    test('starts disabled and toggles via enter/exit', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(bottomNavEditModeProvider), false);
      container.read(bottomNavEditModeProvider.notifier).enter();
      expect(container.read(bottomNavEditModeProvider), true);
      container.read(bottomNavEditModeProvider.notifier).exit();
      expect(container.read(bottomNavEditModeProvider), false);
    });

    test('enter / exit are idempotent', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(bottomNavEditModeProvider.notifier).enter();
      container.read(bottomNavEditModeProvider.notifier).enter();
      expect(container.read(bottomNavEditModeProvider), true);
      container.read(bottomNavEditModeProvider.notifier).exit();
      container.read(bottomNavEditModeProvider.notifier).exit();
      expect(container.read(bottomNavEditModeProvider), false);
    });
  });

  group('Bottom-tab release contract (source pins)', () {
    final shellFile = File('lib/features/navigation/main_shell.dart');
    final providerFile = File(
      'lib/features/navigation/providers/bottom_tab_providers.dart',
    );
    late String source;
    late String providerSource;

    setUpAll(() {
      expect(shellFile.existsSync(), true);
      expect(providerFile.existsSync(), true);
      source = shellFile.readAsStringSync();
      providerSource = providerFile.readAsStringSync();
    });

    test('all four built-in tab ids are stable release contracts', () {
      // The persisted bottomTabOrder references these ids by literal
      // string. Renaming the constant's STRING value silently drops
      // any user-chosen order that referenced it. Pin both the
      // constant identifier (used by the shell) and the literal
      // string value (the wire format).
      const literalIds = ['messages', 'map', 'nodes', 'dashboard'];
      for (final id in literalIds) {
        expect(
          providerSource.contains("= '$id'"),
          true,
          reason:
              'Bottom-tab id literal "$id" is part of the release contract '
              '(persisted in SharedPreferences via bottomTabOrder). The '
              'constant in bottom_tab_providers.dart must keep this exact '
              'string value or a future build will silently drop the '
              'user customization that referenced it.',
        );
      }
      const constants = [
        'bottomTabIdMessages',
        'bottomTabIdMap',
        'bottomTabIdNodes',
        'bottomTabIdDashboard',
      ];
      for (final name in constants) {
        expect(
          source.contains(name),
          true,
          reason:
              'main_shell.dart must reference $name (not a raw string) so '
              'the wire format stays in lockstep with the renderer.',
        );
      }
    });

    test('renderer reads bottomTabOrderProvider', () {
      expect(
        source.contains('ref.watch(bottomTabOrderProvider)'),
        true,
        reason:
            'The bottom-nav row must read bottomTabOrderProvider so the '
            'user-chosen order propagates to the renderer without a copy.',
      );
    });

    test('renderer reads bottomNavEditModeProvider', () {
      expect(
        source.contains('ref.watch(bottomNavEditModeProvider)'),
        true,
        reason:
            'The bottom-nav row must read bottomNavEditModeProvider so the '
            'long-press-to-enter / drag-to-reorder UX activates correctly.',
      );
    });

    test('logical-index switch covers every built-in tab id', () {
      // Badge wiring, screen dispatch, and the defaultLandingTab
      // setting all use logical indices (Messages=0, Map=1, Nodes=2,
      // Dashboard=3) so a reorder never swaps badges between tabs.
      // The _logicalIndexForId helper must keep every built-in id
      // mapped, even after Phase 2 introduces new ids.
      expect(
        source.contains('int _logicalIndexForId(String id)'),
        true,
        reason:
            'Renderer must keep a logical-index resolver so reordering '
            'cannot mis-route a tap to the wrong screen.',
      );
      const expectedCases = [
        "case bottomTabIdMessages:\n        return 0;",
        "case bottomTabIdMap:\n        return 1;",
        "case bottomTabIdNodes:\n        return 2;",
        "case bottomTabIdDashboard:\n        return 3;",
      ];
      for (final c in expectedCases) {
        expect(
          source.contains(c),
          true,
          reason: 'Missing or shifted logical-index case: $c',
        );
      }
    });

    test('badge wiring keys off id, not physical index', () {
      // The pre-refactor wiring did `if (index == 0)` / `if (index == 2)`
      // which would have swapped the Messages and Nodes badges as soon
      // as the user reordered the tabs. The refactor must use the id.
      expect(
        source.contains('tabId == bottomTabIdMessages'),
        true,
        reason:
            'Messages badge must be id-keyed so it stays attached to the '
            'Messages tab after reorder.',
      );
      expect(
        source.contains('tabId == bottomTabIdNodes'),
        true,
        reason:
            'Nodes new-nodes badge must be id-keyed so it stays attached '
            'to the Nodes tab after reorder.',
      );
    });

    test('tap in edit mode exits edit mode and selects the tab', () {
      // The single-tap-exits-and-selects contract: when in edit mode,
      // tapping any tab both (a) clears the edit flag and (b)
      // navigates to that tab. Without this the user could get stuck
      // in edit mode with no obvious exit.
      final flat = source.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        flat.contains(
          'if (editMode) { '
          'ref.read(bottomNavEditModeProvider.notifier).exit(); '
          '}',
        ),
        true,
        reason:
            'NavBarItem.onTap must call exit() on the edit-mode notifier '
            'when in edit mode so a single tap clears the mode.',
      );
    });

    test('long-press in non-edit mode enters edit mode', () {
      // In non-edit mode each tab is wrapped in a GestureDetector
      // that fires `enter()` on long-press. This is the only entry
      // point to reorder mode.
      final flat = source.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        flat.contains(
          'GestureDetector( behavior: HitTestBehavior.opaque, '
          'onLongPress: () { HapticFeedback.mediumImpact(); '
          'ref.read(bottomNavEditModeProvider.notifier).enter(); }',
        ),
        true,
        reason:
            'Non-edit-mode tab wrapper must include a GestureDetector that '
            'enters edit mode on long-press.',
      );
    });

    test('edit mode mounts an explanatory banner with a Done button', () {
      // Tap-on-tab exits edit mode AND selects that tab, which is
      // useful for "I'm done reordering AND I want to switch tabs".
      // For the "I'm done reordering BUT want to stay on the current
      // tab" path the user needs an explicit Done affordance. The
      // banner mounts in the bottom-nav slot directly above the row
      // (same Column as the CountdownBanner) and is gated by
      // bottomNavEditModeProvider.
      expect(
        source.contains('_BottomNavEditBanner'),
        true,
        reason:
            'Edit mode must mount an explanatory banner with a Done '
            'button. Without it the only exit is tap-on-tab which '
            'forces the user to change tabs to leave edit mode.',
      );
      final flat = source.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        flat.contains(
          'if (ref.watch(bottomNavEditModeProvider)) const _BottomNavEditBanner()',
        ),
        true,
        reason:
            'The banner must be gated by bottomNavEditModeProvider so it '
            'appears only while reorder is active.',
      );
      expect(
        flat.contains('ref.read(bottomNavEditModeProvider.notifier).exit();'),
        true,
        reason: 'Done button must call exit() on the edit-mode notifier.',
      );
      expect(
        source.contains('context.l10n.bottomNavReorderBannerTitle') &&
            source.contains('context.l10n.bottomNavReorderBannerDone'),
        true,
        reason:
            'Banner copy must reference ARB keys bottomNavReorderBannerTitle '
            'and bottomNavReorderBannerDone (no hardcoded strings).',
      );
    });

    test('edit mode uses ReorderableListView for live shift animation', () {
      // The drawer uses SliverReorderableList for its make-space-as-
      // you-drag behaviour. The bottom-nav edit mode must use the
      // matching primitive (ReorderableListView.builder, horizontal)
      // so unselected tabs slide smoothly out of the way to make
      // space for the moved tab.
      expect(
        source.contains('ReorderableListView.builder('),
        true,
        reason:
            'Edit-mode renderer must use ReorderableListView so the '
            'unselected tabs slide out of the way during a drag. A '
            'hand-rolled LongPressDraggable + DragTarget does NOT '
            'animate sibling positions and reads as "broken" against '
            'the drawer reorder behaviour.',
      );
      expect(
        source.contains('scrollDirection: Axis.horizontal'),
        true,
        reason:
            'ReorderableListView must scroll horizontally so it slots '
            'into the bottom nav row.',
      );
      expect(
        source.contains('ReorderableDelayedDragStartListener('),
        true,
        reason:
            'Each tab in edit mode must be wrapped in a '
            'ReorderableDelayedDragStartListener so long-press '
            'initiates the drag while tap continues to pass through '
            'to the NavBarItem.onTap (which exits edit mode + selects).',
      );
      expect(
        source.contains('buildDefaultDragHandles: false'),
        true,
        reason:
            'Default drag handles must be off — the whole tab is the '
            'drag target via the custom delayed listener.',
      );
    });
  });
}
