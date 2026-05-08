// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// RadioCompatibilityCard widget tests — direct rendering coverage.
//
// Pins the card's status -> localized-label mapping so a future ARB key
// rename or a status-table edit is caught at the widget layer instead of
// only at the helper layer. The pure helper is covered separately by
// radio_compatibility_test.dart; the provider join is covered by
// nodedex_radio_compatibility_provider_test.dart. This test exercises the
// rendered output for each NodeDexReachabilityStatus by overriding the
// summary provider directly.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/models/observation_source.dart';
import 'package:socialmesh/features/nodedex/providers/nodedex_radio_compatibility_provider.dart';
import 'package:socialmesh/features/nodedex/services/radio_compatibility.dart';
import 'package:socialmesh/features/nodedex/widgets/radio_compatibility_card.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';

const int _testNodeNum = 0xACB22B4;
final AppLocalizations _l10n = AppLocalizationsEn();

NodeDexRadioCompatibilitySummary _summary(
  NodeDexReachabilityStatus status, {
  int? localPresetNow,
  int? lastObservedOnPreset,
  ObservationSource? observationSource,
  int? hopsAway,
  bool isSelf = false,
}) {
  return NodeDexRadioCompatibilitySummary(
    status: status,
    localPresetNow: localPresetNow,
    lastObservedOnPreset: lastObservedOnPreset,
    observationSource: observationSource,
    hopsAway: hopsAway,
    isSelf: isSelf,
  );
}

Widget _wrap({required NodeDexRadioCompatibilitySummary? summary}) {
  return ProviderScope(
    overrides: [
      nodeDexRadioCompatibilityProvider(
        _testNodeNum,
      ).overrideWith((ref) => summary),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Center(child: RadioCompatibilityCard(nodeNum: _testNodeNum)),
      ),
    ),
  );
}

void main() {
  // Ensure the per-nodeNum log dedupe map does not leak state between
  // tests. The provider only fires its log line on a status transition,
  // so we clear the cache before each pump.
  setUp(() {
    debugLastLoggedStatus.clear();
  });

  group('RadioCompatibilityCard — visible statuses', () {
    final visibleCases = <(NodeDexReachabilityStatus, String)>[
      (
        NodeDexReachabilityStatus.likelyReachableOnRf,
        _l10n.nodedexReachabilityLikelyOnRf,
      ),
      (
        NodeDexReachabilityStatus.differentPreset,
        _l10n.nodedexReachabilityDifferentPreset,
      ),
      (
        NodeDexReachabilityStatus.differentFrequencyOffset,
        _l10n.nodedexReachabilityDifferentFrequencyOffset,
      ),
      (
        NodeDexReachabilityStatus.indirectOrMqttObservation,
        _l10n.nodedexReachabilityIndirectOrMqtt,
      ),
      (
        NodeDexReachabilityStatus.localRadioUnknown,
        _l10n.nodedexReachabilityLocalRadioUnknown,
      ),
      (NodeDexReachabilityStatus.unknown, _l10n.nodedexReachabilityUnknown),
    ];

    for (final (status, expectedLabel) in visibleCases) {
      testWidgets('renders localized reachability label for ${status.name}', (
        tester,
      ) async {
        await tester.pumpWidget(_wrap(summary: _summary(status)));
        await tester.pump();

        expect(
          find.text(expectedLabel),
          findsOneWidget,
          reason:
              'Reachability row for ${status.name} must show the localized '
              'label "$expectedLabel"',
        );
        // The card title is rendered by SectionTitle, which uppercases
        // its input. Asserting the uppercased form proves the card body
        // is mounted (not collapsed to SizedBox.shrink).
        expect(
          find.text(_l10n.nodedexRadioCompatibilityTitle.toUpperCase()),
          findsOneWidget,
          reason: 'Card title must render for visible status ${status.name}',
        );
      });
    }
  });

  group('RadioCompatibilityCard — hidden cases', () {
    testWidgets('selfNode hides the entire card', (tester) async {
      await tester.pumpWidget(
        _wrap(
          summary: _summary(NodeDexReachabilityStatus.selfNode, isSelf: true),
        ),
      );
      await tester.pump();

      // No reachability text and no card title should be in the tree.
      expect(
        find.text(_l10n.nodedexReachabilitySelf),
        findsNothing,
        reason: 'Self-node card body must not render',
      );
      expect(
        find.text(_l10n.nodedexRadioCompatibilityTitle.toUpperCase()),
        findsNothing,
        reason: 'Self-node card title must not render',
      );
    });

    testWidgets('null summary (entry not yet discovered) collapses the card', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(summary: null));
      await tester.pump();

      expect(
        find.text(_l10n.nodedexRadioCompatibilityTitle.toUpperCase()),
        findsNothing,
        reason: 'Card must not render when no summary is available',
      );
    });
  });

  group('RadioCompatibilityCard — auxiliary rows', () {
    testWidgets(
      'renders observation source and hops rows when summary carries them',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            summary: _summary(
              NodeDexReachabilityStatus.indirectOrMqttObservation,
              observationSource: ObservationSource.mqtt,
              hopsAway: 2,
            ),
          ),
        );
        await tester.pump();

        expect(
          find.text(_l10n.nodedexObservationSourceMqtt),
          findsOneWidget,
          reason: 'MQTT observation source value must render',
        );
        expect(
          find.text(_l10n.nodedexHopsAwayValue(2)),
          findsOneWidget,
          reason: 'Hops-away value must render via the plural ARB key',
        );
      },
    );
  });
}
