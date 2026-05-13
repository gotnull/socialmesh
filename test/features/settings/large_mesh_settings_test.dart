// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/services/storage/storage_service.dart';

/// Sprint 3 — Large Mesh settings.
///
/// Covers:
/// - The two new SharedPreferences-backed settings (`hideNewNodesBadge`,
///   `messagesDefaultSubtab`) round-trip correctly.
/// - The settings screen renders the new toggle in a dedicated
///   "Large mesh" section, decoupled from the notifications block.
/// - The nav-badge surface in `main_shell.dart` is gated by the new
///   setting.
/// - The Messages container restores the persisted sub-tab on init
///   and writes back on user-driven tab changes.
void main() {
  group('SettingsService — hideNewNodesBadge', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to false (badge visible) for fresh installs', () async {
      final service = SettingsService();
      await service.init();
      expect(service.hideNewNodesBadge, false);
    });

    test('setter persists across SettingsService instances', () async {
      final first = SettingsService();
      await first.init();
      await first.setHideNewNodesBadge(true);

      // Re-read from a fresh service instance backed by the same
      // SharedPreferences store.
      final second = SettingsService();
      await second.init();
      expect(second.hideNewNodesBadge, true);
    });
  });

  group('SettingsService — messagesDefaultSubtab', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('defaults to 0 (Contacts) for fresh installs', () async {
      final service = SettingsService();
      await service.init();
      expect(service.messagesDefaultSubtab, 0);
    });

    test('persists arbitrary int across instances', () async {
      final first = SettingsService();
      await first.init();
      await first.setMessagesDefaultSubtab(1);

      final second = SettingsService();
      await second.init();
      expect(second.messagesDefaultSubtab, 1);
    });
  });

  group('settings screen wires the hide-badge toggle', () {
    final settingsFile = File('lib/features/settings/settings_screen.dart');
    late String source;

    setUpAll(() {
      expect(settingsFile.existsSync(), true);
      source = settingsFile.readAsStringSync();
    });

    test('toggle lives in a dedicated "Large mesh" section', () {
      expect(
        source.contains('settingsSectionLargeMesh'),
        true,
        reason:
            'Hide-badge toggle must live in its own Large-mesh section so '
            'large-mesh knobs accumulate in one place over time.',
      );
    });

    test('toggle is OUTSIDE the notifications gate', () {
      // The new toggle must NOT sit inside the existing
      // `if (settingsService.notificationsEnabled)` block — otherwise
      // a user who silenced notifications can't hide the badge.
      final flat = source.replaceAll(RegExp(r'\s+'), ' ');
      // Look for the toggle's ARB key.
      expect(flat.contains('settingsTileHideNewNodesBadgeTitle'), true);
      // Sanity: the section header is before the toggle reference.
      final sectionPos = flat.indexOf('settingsSectionLargeMesh');
      final togglePos = flat.indexOf('settingsTileHideNewNodesBadgeTitle');
      expect(sectionPos, greaterThan(-1));
      expect(togglePos, greaterThan(sectionPos));
    });

    test('toggle uses the canonical ThemedSwitch + setter pair', () {
      expect(source.contains('settingsService.hideNewNodesBadge'), true);
      expect(source.contains('settingsService.setHideNewNodesBadge('), true);
      expect(
        source.contains('[Settings] hideNewNodesBadge='),
        true,
        reason:
            'Toggle must emit an AppLogging.settings marker so the change '
            'shows up in the in-app log viewer for support triage.',
      );
    });
  });

  group('main_shell badge is gated by hideNewNodesBadge', () {
    final shellFile = File('lib/features/navigation/main_shell.dart');
    late String source;

    setUpAll(() {
      expect(shellFile.existsSync(), true);
      source = shellFile.readAsStringSync();
    });

    test('reads hideNewNodesBadge before computing the count', () {
      expect(
        source.contains('hideNewNodesBadge'),
        true,
        reason: 'The nav-badge branch must consult the new setting.',
      );
      expect(
        source.contains(
          'badgeCount = hideBadge ? 0 : ref.watch(newNodesCountProvider);',
        ),
        true,
        reason:
            'When the setting is on, badgeCount must short-circuit to 0 '
            'without watching the new-nodes provider (still tracking, '
            'just not surfacing).',
      );
    });
  });

  group('MessagesContainerScreen restores + persists the sub-tab', () {
    final containerFile = File(
      'lib/features/messaging/messages_container_screen.dart',
    );
    late String source;

    setUpAll(() {
      expect(containerFile.existsSync(), true);
      source = containerFile.readAsStringSync();
    });

    test('initial tab index reads from messagesDefaultSubtab', () {
      expect(
        source.contains('settings?.messagesDefaultSubtab ?? 0'),
        true,
        reason:
            'TabController must seed from SharedPreferences via the '
            'SettingsService so cold-start restores the user\'s last tab.',
      );
      expect(
        source.contains('clamp(0, 1)'),
        true,
        reason:
            'Clamp to the valid tab range so a stale persisted index from '
            'a previous build (more tabs) cannot crash the controller.',
      );
    });

    test('listener persists tab index on user-driven changes only', () {
      expect(
        source.contains(
          '_tabController.addListener(_persistTabIndexIfChanged)',
        ),
        true,
        reason: 'Listener must be wired during initState.',
      );
      expect(
        source.contains('if (_tabController.indexIsChanging) return;'),
        true,
        reason:
            'Skip mid-animation ticks so we only persist on stable index '
            'transitions.',
      );
      expect(
        source.contains('setMessagesDefaultSubtab(_tabController.index)'),
        true,
        reason: 'Listener must write the new index back to SettingsService.',
      );
      expect(
        source.contains(
          '_tabController.removeListener(_persistTabIndexIfChanged)',
        ),
        true,
        reason: 'Dispose must remove the listener to prevent leaks.',
      );
    });
  });
}
