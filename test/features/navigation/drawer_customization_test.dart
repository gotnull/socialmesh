// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/features/navigation/providers/drawer_customization_providers.dart';
import 'package:socialmesh/features/navigation/widgets/drawer_hidden_item_descriptor.dart';
import 'package:socialmesh/features/navigation/widgets/drawer_menu_tile.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/services/storage/storage_service.dart';

/// Sprint-7 drawer customization tests.
///
/// Covers:
/// - The pure `applyDrawerCustomization` filter+reorder algorithm.
/// - The SharedPreferences round-trip for `drawerHiddenItems` and
///   `drawerItemOrder` on [SettingsService].
/// - Stability pins on `DrawerMenuItem.id` strings — drift means
///   silent loss of user state.

DrawerMenuItem _item(String id, {String label = 'X'}) =>
    DrawerMenuItem(id: id, icon: Icons.circle, label: label);

DrawerMenuItem _idLessItem({String label = 'idless'}) =>
    DrawerMenuItem(icon: Icons.circle, label: label);

void main() {
  group('applyDrawerCustomization', () {
    test('returns the input unchanged for empty state', () {
      final list = [_item('a'), _item('b'), _item('c')];
      final result = applyDrawerCustomization(
        list,
        DrawerCustomizationState.empty,
      );
      expect(result, list);
    });

    test('hides items whose id is in hiddenIds', () {
      final list = [_item('a'), _item('b'), _item('c')];
      final result = applyDrawerCustomization(
        list,
        const DrawerCustomizationState(hiddenIds: {'b'}, customOrder: null),
      );
      expect(result.map((e) => e.id), ['a', 'c']);
    });

    test('preserves id-less items even when hiddenIds matches no item', () {
      final list = [_item('a'), _idLessItem(), _item('c')];
      final result = applyDrawerCustomization(
        list,
        const DrawerCustomizationState(hiddenIds: {'a'}, customOrder: null),
      );
      expect(result.map((e) => e.id), [null, 'c']);
    });

    test('customOrder is intentionally ignored — ordering is section-aware '
        '(see applySectionOrder + deriveSectionMembership)', () {
      // The old global-sort behaviour was the source of the
      // "items end up in the wrong section" bug. The pure helper
      // now does hide-only; intra-section ordering is composed by
      // the renderer using deriveSectionMembership + applySectionOrder.
      final list = [_item('a'), _item('b'), _item('c'), _item('d')];
      final result = applyDrawerCustomization(
        list,
        const DrawerCustomizationState(hiddenIds: {}, customOrder: ['c', 'a']),
      );
      // No global reorder — list comes back in default order.
      expect(result.map((e) => e.id), ['a', 'b', 'c', 'd']);
    });

    test('hide still applies even when customOrder is non-null', () {
      final list = [_item('a'), _item('b'), _item('c')];
      final result = applyDrawerCustomization(
        list,
        const DrawerCustomizationState(
          hiddenIds: {'b'},
          customOrder: ['b', 'c', 'a'],
        ),
      );
      // 'b' hidden, others in default order (no global reorder).
      expect(result.map((e) => e.id), ['a', 'c']);
    });

    test('hides a child without hiding its parent', () {
      final child = _item('child1', label: 'Sub one');
      final parent = DrawerMenuItem(
        id: 'parent',
        icon: Icons.circle,
        label: 'Parent',
        children: [
          child,
          _item('child2', label: 'Sub two'),
        ],
      );
      final result = applyDrawerCustomization(
        [parent],
        const DrawerCustomizationState(
          hiddenIds: {'child1'},
          customOrder: null,
        ),
      );
      expect(result.length, 1);
      expect(result.first.id, 'parent');
      expect(result.first.children!.map((c) => c.id), ['child2']);
    });

    test('returns the original parent instance when no child is filtered', () {
      final parent = DrawerMenuItem(
        id: 'parent',
        icon: Icons.circle,
        label: 'Parent',
        children: [_item('child1'), _item('child2')],
      );
      final result = applyDrawerCustomization(
        [parent],
        const DrawerCustomizationState(
          hiddenIds: {'unrelated'},
          customOrder: null,
        ),
      );
      // identical (not just equal) — the helper hands back the
      // original DrawerMenuItem when the subtree was unchanged so
      // const-Widget identity survives downstream.
      expect(identical(result.first, parent), true);
    });

    test('hidden parent shadows hidden child filter (children skipped)', () {
      final parent = DrawerMenuItem(
        id: 'parent',
        icon: Icons.circle,
        label: 'Parent',
        children: [_item('child1')],
      );
      final result = applyDrawerCustomization(
        [parent],
        const DrawerCustomizationState(
          hiddenIds: {'parent', 'child1'},
          customOrder: null,
        ),
      );
      // Parent hidden means the whole subtree is gone; no need to
      // visit children.
      expect(result, isEmpty);
    });
  });

  group('deriveSectionMembership', () {
    DrawerMenuItem itemWithSection(String id, {String? section}) =>
        DrawerMenuItem(
          id: id,
          icon: Icons.circle,
          label: id,
          sectionHeader: section,
        );

    test('assigns each item to the most-recent sectionHeader', () {
      final list = [
        itemWithSection('a', section: 'Discover'),
        itemWithSection('b'),
        itemWithSection('c', section: 'Identity'),
        itemWithSection('d'),
      ];
      final m = deriveSectionMembership(list);
      expect(m.sectionByItemId, {
        'a': 'Discover',
        'b': 'Discover',
        'c': 'Identity',
        'd': 'Identity',
      });
      expect(m.sectionTitlesInOrder, ['Discover', 'Identity']);
    });

    test('items before any sectionHeader land in the unnamed section', () {
      final list = [
        itemWithSection('a'),
        itemWithSection('b', section: 'Tools'),
        itemWithSection('c'),
      ];
      final m = deriveSectionMembership(list);
      expect(m.sectionByItemId, {'a': '', 'b': 'Tools', 'c': 'Tools'});
      expect(m.sectionTitlesInOrder, ['', 'Tools']);
    });

    test(
      'skips id-less items in the membership map but keeps section order',
      () {
        final list = [
          itemWithSection('a', section: 'Discover'),
          DrawerMenuItem(icon: Icons.circle, label: 'no-id'),
          itemWithSection('c'),
        ];
        final m = deriveSectionMembership(list);
        // Only ids are in the map.
        expect(m.sectionByItemId, {'a': 'Discover', 'c': 'Discover'});
        // Section title order is unaffected by id-less items.
        expect(m.sectionTitlesInOrder, ['Discover']);
      },
    );
  });

  group('applySectionOrder', () {
    test('returns input unchanged when customOrder is null', () {
      final list = [_item('a'), _item('b'), _item('c')];
      expect(applySectionOrder(list, null), list);
    });

    test('sorts items by customOrder index', () {
      final list = [_item('a'), _item('b'), _item('c')];
      final result = applySectionOrder(list, ['c', 'a', 'b']);
      expect(result.map((e) => e.id), ['c', 'a', 'b']);
    });

    test('items not in customOrder go to the end in default order', () {
      final list = [_item('a'), _item('newcomer'), _item('b'), _item('extra')];
      final result = applySectionOrder(list, ['b', 'a']);
      // 'b' + 'a' from customOrder first, then 'newcomer' + 'extra'
      // in their relative default order.
      expect(result.map((e) => e.id), ['b', 'a', 'newcomer', 'extra']);
    });

    test('id-less items are kept and pushed to the end', () {
      final list = [_item('a'), _idLessItem(label: 'IDless'), _item('b')];
      final result = applySectionOrder(list, ['b', 'a']);
      expect(result.map((e) => e.id), ['b', 'a', null]);
      expect(result.last.label, 'IDless');
    });

    test('stale customOrder entries are silently skipped', () {
      final list = [_item('a'), _item('b')];
      final result = applySectionOrder(list, ['ghost', 'b', 'a']);
      // 'ghost' is not in the input — just dropped.
      expect(result.map((e) => e.id), ['b', 'a']);
    });
  });

  group('DrawerCustomizationState', () {
    test('isModified is false for empty state', () {
      expect(DrawerCustomizationState.empty.isModified, false);
    });

    test('isModified is true when hiddenIds is non-empty', () {
      const s = DrawerCustomizationState(hiddenIds: {'a'}, customOrder: null);
      expect(s.isModified, true);
    });

    test('isModified is true when customOrder is non-null', () {
      const s = DrawerCustomizationState(hiddenIds: {}, customOrder: ['x']);
      expect(s.isModified, true);
    });
  });

  group('SettingsService — drawer customization keys', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('drawerHiddenItems defaults to empty list', () async {
      final s = SettingsService();
      await s.init();
      expect(s.drawerHiddenItems, isEmpty);
    });

    test('drawerHiddenItems round-trips across instances', () async {
      final a = SettingsService();
      await a.init();
      await a.setDrawerHiddenItems(const ['world_map', 'routes']);

      final b = SettingsService();
      await b.init();
      expect(b.drawerHiddenItems, ['world_map', 'routes']);
    });

    test('drawerItemOrder defaults to null', () async {
      final s = SettingsService();
      await s.init();
      expect(s.drawerItemOrder, isNull);
    });

    test('drawerItemOrder round-trips, then clears to null on reset', () async {
      final s = SettingsService();
      await s.init();
      await s.setDrawerItemOrder(const ['nodedex', 'telemetry']);
      expect(s.drawerItemOrder, ['nodedex', 'telemetry']);

      await s.setDrawerItemOrder(null);
      expect(s.drawerItemOrder, isNull);
    });

    test('corrupt drawer_hidden_items JSON falls back to empty', () async {
      SharedPreferences.setMockInitialValues({
        'drawer_hidden_items': 'not-valid-json',
      });
      final s = SettingsService();
      await s.init();
      expect(s.drawerHiddenItems, isEmpty);
    });

    test('corrupt drawer_item_order JSON falls back to null', () async {
      SharedPreferences.setMockInitialValues({
        'drawer_item_order': '{not a list}',
      });
      final s = SettingsService();
      await s.init();
      expect(s.drawerItemOrder, isNull);
    });
  });

  group('DrawerCustomizationNotifier — behaviour', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('hide / show toggle persists state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(drawerCustomizationProvider.future);
      await container
          .read(drawerCustomizationProvider.notifier)
          .hide('world_map');

      final state = container.read(drawerCustomizationProvider).value;
      expect(state?.hiddenIds, contains('world_map'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('drawer_hidden_items'), '["world_map"]');

      await container
          .read(drawerCustomizationProvider.notifier)
          .show('world_map');
      final stateAfter = container.read(drawerCustomizationProvider).value;
      expect(stateAfter?.hiddenIds, isEmpty);
    });

    test('setOrder persists and resetToDefaults clears everything', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(drawerCustomizationProvider.future);
      final notifier = container.read(drawerCustomizationProvider.notifier);
      await notifier.setOrder(const ['nodedex', 'telemetry']);
      await notifier.hide('routes');

      final pre = container.read(drawerCustomizationProvider).value!;
      expect(pre.customOrder, ['nodedex', 'telemetry']);
      expect(pre.hiddenIds, contains('routes'));
      expect(pre.isModified, true);

      await notifier.resetToDefaults();
      final post = container.read(drawerCustomizationProvider).value!;
      expect(post.customOrder, isNull);
      expect(post.hiddenIds, isEmpty);
      expect(post.isModified, false);
    });
  });

  group('Drawer item ID stability (release contract)', () {
    final shellFile = File('lib/features/navigation/main_shell.dart');
    late String source;

    setUpAll(() {
      expect(shellFile.existsSync(), true);
      source = shellFile.readAsStringSync();
    });

    // Every customizable item must keep its ID across releases —
    // renaming an ID silently drops any user customization that
    // referenced it. Pin the full set here. When adding a new item:
    // add it to this list and the SharedPreferences side stays in
    // lockstep.
    //
    // Retiring an id is allowed, but only with a migration: add it to
    // `kRetiredDrawerItemIds` so the persisted state is pruned on read,
    // then drop it from these lists. Without the prune, the customize
    // sheet keeps listing a hidden item that no longer exists and renders
    // it as a raw id. `nodedex_map` went that way when the NodeDex map
    // became a tab in the NodeDex shell.
    test('a retired id is pruned from persisted customization', () {
      // The user hid NodeDex Map back when it was a drawer child. Their
      // stored state still names it; the prune is what stops the
      // customize sheet listing an item that no longer exists.
      expect(pruneRetiredDrawerIds(['nodedex', 'nodedex_map', 'presence']), [
        'nodedex',
        'presence',
      ]);
    });

    test('pruning leaves a list with no retired ids untouched', () {
      const order = ['nodedex', 'presence', 'world_map'];
      expect(pruneRetiredDrawerIds(order), order);
    });

    test('a retired id has no hidden-item descriptor', () {
      // The descriptor and the prune have to agree: an id that still
      // resolved here would render in the sheet after being pruned out of
      // the user's state, which is the same mystery row in reverse.
      final l10n = lookupAppLocalizations(const Locale('en'));
      for (final id in kRetiredDrawerItemIds) {
        expect(
          drawerHiddenItemDescriptor(id, l10n),
          isNull,
          reason: 'Retired drawer id "$id" must not resolve a descriptor',
        );
      }
    });

    test('all customizable top-level items have stable IDs', () {
      const expectedIds = [
        'nodedex',
        'nodeboard',
        'operations',
        'presence',
        'world_map',
        'mesh_explorer',
        'mesh_capacity',
        'mesh_feed',
        'telemetry',
        'file_transfers',
        'aether',
        'tak_gateway',
        'tak_map',
        'sip',
        'mrrp_harness',
        'mesh_incidents',
        'timeline',
        'routes',
        'reachability',
        'mesh_health',
        'device_logs',
        'translation_pack',
        'theme_pack',
        'ringtone_pack',
        'widgets',
        'automations',
        'ifttt_integration',
      ];
      for (final id in expectedIds) {
        expect(
          source.contains("id: '$id',"),
          true,
          reason:
              'Drawer item id "$id" is part of the release contract — '
              'renaming or removing it without a migration silently '
              'drops any user customization that referenced it.',
        );
      }
    });

    // The customize sheet renders each hidden item by id via the
    // descriptor lookup. If a customizable id ships in the drawer
    // without a matching descriptor, the user sees the fallback
    // (raw id + help icon) instead of the real label — degraded
    // UX. Pin parity so the sheet always renders the canonical
    // icon + accent + localized label for every customizable id.
    test('every customizable id resolves to a hidden-item descriptor', () {
      const expectedIds = [
        'nodedex',
        'nodeboard',
        'operations',
        'presence',
        'world_map',
        'mesh_explorer',
        'mesh_capacity',
        'mesh_feed',
        'telemetry',
        'file_transfers',
        'aether',
        'tak_gateway',
        'tak_map',
        'sip',
        'mrrp_harness',
        'mesh_incidents',
        'timeline',
        'routes',
        'reachability',
        'mesh_health',
        'device_logs',
        'translation_pack',
        'theme_pack',
        'ringtone_pack',
        'widgets',
        'automations',
        'ifttt_integration',
      ];
      final l10n = lookupAppLocalizations(const Locale('en'));
      for (final id in expectedIds) {
        final descriptor = drawerHiddenItemDescriptor(id, l10n);
        expect(
          descriptor,
          isNotNull,
          reason:
              'Drawer item id "$id" has no entry in '
              'drawerHiddenItemDescriptor — the customize sheet will '
              'fall back to a neutral tile instead of the real label '
              'and accent. Add the case to the descriptor switch.',
        );
        expect(
          descriptor!.label,
          isNotEmpty,
          reason:
              'Descriptor for "$id" returned an empty label — likely '
              'a missing ARB key.',
        );
      }
    });

    test('Scaffold.onDrawerChanged forces exit from edit mode on close', () {
      // The drawer's edit mode is in-memory (drawerEditModeProvider).
      // It must be torn down when the drawer closes so the next open
      // does not present a stale mid-edit state. Pin the wiring here:
      // any future refactor that removes this exit() call would
      // silently regress the UX.
      final flat = source.replaceAll(RegExp(r'\s+'), ' ');
      expect(
        flat.contains('onDrawerChanged: (isOpen) {'),
        true,
        reason:
            'Scaffold must register onDrawerChanged to detect drawer close.',
      );
      expect(
        flat.contains('ref.read(drawerEditModeProvider.notifier).exit();'),
        true,
        reason:
            'Drawer close must call exit() on the edit-mode provider so '
            'the next open starts in normal mode.',
      );
    });
  });
}
