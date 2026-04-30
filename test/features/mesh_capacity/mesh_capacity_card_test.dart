// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_capacity/mesh_capacity_card.dart';
import 'package:socialmesh/generated/meshtastic/config.pbenum.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/mesh_capacity_provider.dart';
import 'package:socialmesh/services/mesh_capacity/mesh_capacity_models.dart';

class _FakeSnapshotNotifier extends MeshCapacitySnapshotNotifier {
  _FakeSnapshotNotifier(this._snapshot);
  final MeshCapacitySnapshot _snapshot;
  @override
  MeshCapacitySnapshot build() => _snapshot;
}

Widget _wrap(MeshCapacitySnapshot snapshot) {
  return ProviderScope(
    overrides: [
      meshCapacitySnapshotProvider.overrideWith(
        () => _FakeSnapshotNotifier(snapshot),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: const Scaffold(body: MeshCapacityCard()),
    ),
  );
}

MeshCapacitySnapshot _snapshot({
  required MeshCapacityPressureLevel pressure,
  required MeshCapacityRecommendation recommendation,
  int rf15m = 0,
  Config_LoRaConfig_ModemPreset? preset,
}) {
  return MeshCapacitySnapshot(
    activeRfNodes5m: rf15m,
    activeRfNodes15m: rf15m,
    activeRfNodes60m: rf15m,
    totalKnownNodes: rf15m,
    currentModemPreset: preset,
    currentChannelName: null,
    hasPresetInfo: preset != null,
    hasSufficientSignalData: rf15m > 0,
    pressureLevel: pressure,
    recommendation: recommendation,
    generatedAt: DateTime.utc(2026, 4, 30),
  );
}

void main() {
  testWidgets('Card is hidden for healthy snapshot', (tester) async {
    final snap = _snapshot(
      pressure: MeshCapacityPressureLevel.healthy,
      recommendation: const MeshCapacityRecommendation.none(),
      preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
    );
    await tester.pumpWidget(_wrap(snap));
    await tester.pump();

    expect(find.text('Mesh is getting busy'), findsNothing);
    expect(find.text('Dense mesh detected'), findsNothing);
  });

  testWidgets('Card is visible for congested snapshot', (tester) async {
    final snap = _snapshot(
      pressure: MeshCapacityPressureLevel.congested,
      rf15m: 45,
      preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
      recommendation: const MeshCapacityRecommendation(
        severity: MeshCapacityRecommendationSeverity.advisory,
        reasonCode: MeshCapacityReasonCode.longPresetDenseMesh,
        shouldShowCard: true,
        suggestedPreset: Config_LoRaConfig_ModemPreset.MEDIUM_FAST,
      ),
    );
    await tester.pumpWidget(_wrap(snap));
    await tester.pump();

    expect(find.text('Dense mesh detected'), findsOneWidget);
    expect(
      find.textContaining('45 nearby nodes are active over RF'),
      findsOneWidget,
    );
  });

  testWidgets('Card is visible with strong title for capacity-limited', (
    tester,
  ) async {
    final snap = _snapshot(
      pressure: MeshCapacityPressureLevel.capacityLimited,
      rf15m: 80,
      preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
      recommendation: const MeshCapacityRecommendation(
        severity: MeshCapacityRecommendationSeverity.warning,
        reasonCode: MeshCapacityReasonCode.longPresetDenseMesh,
        shouldShowCard: true,
        suggestedPreset: Config_LoRaConfig_ModemPreset.SHORT_FAST,
      ),
    );
    await tester.pumpWidget(_wrap(snap));
    await tester.pump();

    expect(find.text('This area may need a faster preset'), findsOneWidget);
  });

  testWidgets('Dismiss action hides the card', (tester) async {
    final snap = _snapshot(
      pressure: MeshCapacityPressureLevel.congested,
      rf15m: 45,
      preset: Config_LoRaConfig_ModemPreset.LONG_FAST,
      recommendation: const MeshCapacityRecommendation(
        severity: MeshCapacityRecommendationSeverity.advisory,
        reasonCode: MeshCapacityReasonCode.longPresetDenseMesh,
        shouldShowCard: true,
        suggestedPreset: Config_LoRaConfig_ModemPreset.MEDIUM_FAST,
      ),
    );
    await tester.pumpWidget(_wrap(snap));
    await tester.pump();

    expect(find.text('Dense mesh detected'), findsOneWidget);

    final dismissButton = find.byIcon(Icons.close);
    expect(dismissButton, findsOneWidget);
    await tester.tap(dismissButton);
    await tester.pumpAndSettle();

    expect(find.text('Dense mesh detected'), findsNothing);
  });

  testWidgets('Preset-unknown card shows preset-unknown copy', (tester) async {
    final snap = _snapshot(
      pressure: MeshCapacityPressureLevel.unknown,
      rf15m: 12,
      preset: null,
      recommendation: const MeshCapacityRecommendation(
        severity: MeshCapacityRecommendationSeverity.info,
        reasonCode: MeshCapacityReasonCode.presetUnknown,
        shouldShowCard: true,
      ),
    );
    await tester.pumpWidget(_wrap(snap));
    await tester.pump();

    expect(find.text('Preset not yet readable'), findsOneWidget);
    expect(
      find.textContaining('Socialmesh can\'t assess preset suitability'),
      findsOneWidget,
    );
  });
}
