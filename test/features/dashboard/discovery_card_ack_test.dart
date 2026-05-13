// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/features/dashboard/providers/dashboard_providers.dart';

/// Source + behaviour tests for the Tranche 1 dashboard discovery card
/// acknowledgement.
///
/// The pack-owner "you have N unused widgets" card kept resurfacing for
/// users who had already customized their dashboard. The fix persists a
/// SharedPreferences key on first interaction and hides the card forever
/// thereafter. The non-owner upsell card is unrelated paywall surface
/// and is NOT gated by this flag.
void main() {
  group('Dashboard discovery card ack — source pins', () {
    final screenFile = File(
      'lib/features/dashboard/widget_dashboard_screen.dart',
    );
    final providersFile = File(
      'lib/features/dashboard/providers/dashboard_providers.dart',
    );

    late String screenSource;
    late String providersSource;

    setUpAll(() {
      expect(screenFile.existsSync(), true);
      expect(providersFile.existsSync(), true);
      screenSource = screenFile.readAsStringSync();
      providersSource = providersFile.readAsStringSync();
    });

    test(
      'SharedPreferences key is dashboard_widget_discovery_dismissed_at',
      () {
        expect(
          providersSource.contains(
            "static const String _storageKey = "
            "'dashboard_widget_discovery_dismissed_at';",
          ),
          true,
          reason:
              'Key name is part of the contract; renaming it would lose the '
              'dismissed state for existing users.',
        );
      },
    );

    test('owner-discovery visibility honors the ack flag', () {
      expect(
        screenSource.contains(
          'ref.watch(dashboardDiscoveryAckProvider).value ?? false',
        ),
        true,
        reason:
            'Dashboard must read the ack provider as a defaulting boolean — '
            'unset (first launch) treats as not-yet-dismissed.',
      );
      expect(
        screenSource.contains('!discoveryDismissed'),
        true,
        reason:
            'The card visibility gate must include the discoveryDismissed '
            'check; otherwise the dismiss is cosmetic-only.',
      );
    });

    test('card tap and edit-mode entry both dismiss', () {
      expect(
        screenSource.contains(".dismiss(reason: 'card_tap')"),
        true,
        reason:
            'Tapping the discovery card must persist the ack so a power '
            'user does not see it again after opening the picker once.',
      );
      expect(
        screenSource.contains(".dismiss(reason: 'edit_mode_entered')"),
        true,
        reason:
            'Entering edit mode must also persist the ack — that is the '
            'clearest signal the user understands the customization model.',
      );
    });

    test('non-owner upsell card is NOT gated by the ack flag', () {
      expect(
        screenSource.contains(
          'final showUpsell = !hasWidgetPack && !_editMode',
        ),
        true,
        reason:
            'The paywall upsell card must remain independent of the '
            'discovery ack — it is monetization surface, not noise.',
      );
    });
  });

  group('DashboardDiscoveryAckNotifier — behaviour', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('starts as not-dismissed when key is absent', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final dismissed = await container.read(
        dashboardDiscoveryAckProvider.future,
      );
      expect(dismissed, false);
    });

    test('dismiss() persists and flips state to true', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(dashboardDiscoveryAckProvider.future);
      await container
          .read(dashboardDiscoveryAckProvider.notifier)
          .dismiss(reason: 'unit_test');

      expect(container.read(dashboardDiscoveryAckProvider).value, true);

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('dashboard_widget_discovery_dismissed_at'),
        isNotNull,
        reason: 'dismiss must write the ISO timestamp to SharedPreferences.',
      );
    });

    test(
      'subsequent dismiss() is a no-op (does not overwrite the timestamp)',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        await container.read(dashboardDiscoveryAckProvider.future);
        final notifier = container.read(dashboardDiscoveryAckProvider.notifier);

        await notifier.dismiss(reason: 'first');
        final prefs = await SharedPreferences.getInstance();
        final firstTimestamp = prefs.getString(
          'dashboard_widget_discovery_dismissed_at',
        );

        await Future<void>.delayed(const Duration(milliseconds: 10));
        await notifier.dismiss(reason: 'second');
        final secondTimestamp = prefs.getString(
          'dashboard_widget_discovery_dismissed_at',
        );

        expect(firstTimestamp, secondTimestamp);
      },
    );

    test('reset() clears the key and re-arms the card', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(dashboardDiscoveryAckProvider.future);
      final notifier = container.read(dashboardDiscoveryAckProvider.notifier);

      await notifier.dismiss(reason: 'unit_test');
      await notifier.reset();

      expect(container.read(dashboardDiscoveryAckProvider).value, false);
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('dashboard_widget_discovery_dismissed_at'),
        isNull,
      );
    });
  });
}
