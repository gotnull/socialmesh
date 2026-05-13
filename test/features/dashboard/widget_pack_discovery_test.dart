// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Widgets Pack discovery surfaces', () {
    final dashboardFile = File(
      'lib/features/dashboard/widget_dashboard_screen.dart',
    );
    final subscriptionFile = File(
      'lib/features/settings/subscription_screen.dart',
    );

    late String dashboardSource;
    late String subscriptionSource;

    setUpAll(() {
      expect(dashboardFile.existsSync(), true);
      expect(subscriptionFile.existsSync(), true);
      dashboardSource = dashboardFile.readAsStringSync();
      subscriptionSource = subscriptionFile.readAsStringSync();
    });

    group('autoOpenPicker constructor', () {
      test('accepts the flag with a default of false', () {
        expect(
          dashboardSource.contains('final bool autoOpenPicker;'),
          true,
          reason:
              'WidgetDashboardScreen must hold an autoOpenPicker field so the '
              'post-purchase route can request the picker open on entry.',
        );
        expect(
          dashboardSource.contains('this.autoOpenPicker = false'),
          true,
          reason:
              'autoOpenPicker must default to false — drawer/dashboard '
              'navigation MUST NOT auto-open the picker.',
        );
      });

      test('one-shot guard prevents repeated openings on rebuild', () {
        expect(
          dashboardSource.contains('bool _didAutoOpenPicker = false;'),
          true,
          reason:
              'State class must hold _didAutoOpenPicker so the post-frame '
              'callback fires exactly once.',
        );
        expect(
          dashboardSource.contains('addPostFrameCallback'),
          true,
          reason:
              'Auto-open must defer until after the first frame so the bottom '
              'sheet has a valid Navigator/MediaQuery context.',
        );
      });
    });

    group('post-purchase routing', () {
      test('homeWidgets snackbar action lands on the dashboard, not the '
          'builder', () {
        // The route table is a switch in _showUnlockedSnackBar.
        // Pin the homeWidgets case AND assert WidgetBuilderScreen is not
        // referenced anywhere in this file (the import was removed).
        expect(
          subscriptionSource.contains(
            'PremiumFeature.homeWidgets => const WidgetDashboardScreen(',
          ),
          true,
          reason:
              'Post-purchase snackbar action for Widgets Pack must push '
              'WidgetDashboardScreen so the user lands where they can '
              'actually add the unlocked widgets.',
        );
        expect(
          subscriptionSource.contains('autoOpenPicker: true'),
          true,
          reason:
              'The dashboard push must request the picker auto-opens — '
              'otherwise the user is back at square one (looking for the '
              'small "+" icon).',
        );
        expect(
          subscriptionSource.contains('WidgetBuilderScreen'),
          false,
          reason:
              'subscription_screen.dart must not reference WidgetBuilderScreen '
              'anymore — the post-purchase route was the only call site. '
              'WidgetBuilderScreen is still reachable from main_shell drawer.',
        );
      });
    });

    group('owner-aware dashboard surfaces', () {
      test('discovery card and upsell card branch on hasWidgetPack', () {
        expect(
          dashboardSource.contains('_buildWidgetUpsellCard'),
          true,
          reason: 'Non-owner upsell card must remain.',
        );
        expect(
          dashboardSource.contains('_buildPackOwnerDiscoveryCard'),
          true,
          reason: 'Owner discovery card must exist.',
        );
        expect(
          dashboardSource.contains('showOwnerDiscovery'),
          true,
          reason:
              'Owner discovery must be gated by an explicit boolean (so the '
              'card hides when count == 0 or in edit mode).',
        );
        // Whitespace-agnostic match so the formatter can rewrap the
        // multi-line conjunction without invalidating the pin.
        final flattened = dashboardSource.replaceAll(RegExp(r'\s+'), ' ');
        expect(
          flattened.contains(
            'hasWidgetPack && !_editMode && unusedPremiumCount > 0',
          ),
          true,
          reason:
              'Owner discovery card visibility predicate must require '
              'ownership AND not-edit-mode AND at least one unused premium '
              'widget — all three together. Tranche 1 added a fourth '
              'conjunct (!discoveryDismissed) but the original three must '
              'still appear in this order.',
        );
        expect(
          flattened.contains('!discoveryDismissed'),
          true,
          reason:
              'Tranche 1 added a persistent ack flag — visibility must '
              'also gate on !discoveryDismissed so a customized dashboard '
              'does not keep showing the discovery card.',
        );
      });

      test('discovery card and edit-mode add tile log on user intent only', () {
        // Check the message strings + that they appear inside an
        // AppLogging.widgets(...) call. Whitespace-agnostic so the
        // formatter can't break the pin.
        const expectedLogs = <String>[
          '[Dashboard] Owner discovery card tapped → opening picker',
          '[Dashboard] Edit-mode add tile tapped → opening picker',
          '[Dashboard] autoOpenPicker fired (post-purchase)',
        ];
        for (final message in expectedLogs) {
          expect(
            dashboardSource.contains(message),
            true,
            reason:
                'Expected log message "$message" must be present so we can '
                'correlate the user-intent event with downstream activity.',
          );
        }
        expect(
          'AppLogging.widgets('.allMatches(dashboardSource).length,
          greaterThanOrEqualTo(3),
          reason:
              'Expect at least 3 AppLogging.widgets(...) calls — one per '
              'user-intent event (discovery tap, edit-tile tap, autoOpen '
              'fire). No build-side logs.',
        );
      });
    });

    group('sticky edit-mode "Add another widget" tile', () {
      test('exists and is gated on visible widget count', () {
        expect(
          dashboardSource.contains('_buildEditModeAddTile'),
          true,
          reason: 'Sticky edit-mode add tile builder must exist.',
        );
        // Visible-count gating: must reference enabledWidgets.length —
        // the visible list — when comparing to maxWidgets, NOT
        // widgetConfigs.length (which would include hidden persisted
        // configs and incorrectly suppress the tile).
        expect(
          dashboardSource.contains(
            'enabledWidgets.length < DashboardWidgetsNotifier.maxWidgets',
          ),
          true,
          reason:
              'Sticky tile gating must compare visible-widget count against '
              'maxWidgets. Using the raw widgetConfigs.length would let '
              'hidden persisted configs incorrectly suppress the tile.',
        );
      });
    });

    group('shared addable / unused-premium helpers', () {
      test('helpers exist as top-level functions', () {
        expect(
          dashboardSource.contains(
            'Iterable<DashboardWidgetType> _addableWidgetTypes()',
          ),
          true,
          reason:
              '_addableWidgetTypes() must exist as the single source of '
              'truth for the picker\'s addable list.',
        );
        expect(
          dashboardSource.contains(
            'int _unusedPremiumCount(Set<DashboardWidgetType> addedTypes)',
          ),
          true,
          reason:
              '_unusedPremiumCount() must exist so the dashboard\'s discovery '
              'card and the picker\'s header hint share the same count.',
        );
      });

      test('picker sheet consumes the shared addable helper', () {
        // Old code did:
        //   DashboardWidgetType.values.where((t) => t != ...custom).toList()
        // Replaced with:
        //   _addableWidgetTypes().toList()
        expect(
          dashboardSource.contains('_addableWidgetTypes().toList()'),
          true,
          reason:
              '_AddWidgetSheet must source its sortedTypes list from '
              '_addableWidgetTypes() so the picker and dashboard never drift.',
        );
      });

      test('both the dashboard and picker sheet call _unusedPremiumCount', () {
        // Two call sites: one in _buildDashboard (dashboard discovery card),
        // one in _AddWidgetSheet.build (picker header hint).
        final occurrences = '_unusedPremiumCount('
            .allMatches(dashboardSource)
            .length;
        expect(
          occurrences >= 3,
          true,
          reason:
              '_unusedPremiumCount must be called at least 3× in this file: '
              'the definition, _buildDashboard, and _AddWidgetSheet.build. '
              'Found $occurrences call/definition site(s).',
        );
      });
    });

    group('ARB key references', () {
      test('all 4 new keys are referenced in the dashboard file', () {
        const expectedKeys = <String>[
          'dashboardOwnerDiscoveryTitle',
          'dashboardOwnerDiscoverySubtitle',
          'dashboardManageWidgetsPackHint',
          'dashboardAddAnotherWidget',
        ];
        for (final key in expectedKeys) {
          expect(
            dashboardSource.contains('l10n.$key'),
            true,
            reason:
                'Dashboard must reference l10n.$key — the discovery surfaces '
                'depend on it.',
          );
        }
      });
    });
  });
}
