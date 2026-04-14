// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/core/widgets/loading_indicator.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_instance.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_signal_kind.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_template.dart';
import 'package:socialmesh/features/mesh_services/presentation/mesh_service_presentation.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Widget buildHarness(Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  test(
    'registry maps each type to presenter with humanized discovery copy',
    () {
      final expectations = <MeshServiceType, ({String eyebrow, String cta})>{
        MeshServiceType.feed: (eyebrow: 'Nearby update', cta: 'Read update'),
        MeshServiceType.list: (
          eyebrow: 'Shared checklist',
          cta: 'Open checklist',
        ),
        MeshServiceType.poll: (
          eyebrow: 'Nearby question',
          cta: 'Answer question',
        ),
        MeshServiceType.signal: (eyebrow: 'Active alert', cta: 'View alert'),
        MeshServiceType.sensor: (eyebrow: 'Live reading', cta: 'Check reading'),
      };

      for (final entry in expectations.entries) {
        final spec = MeshServicePresentationRegistry.forType(entry.key);

        expect(spec.type, entry.key);
        expect(spec.discoveryEyebrow(l10n), entry.value.eyebrow);
        expect(spec.discoveryCta(l10n), entry.value.cta);
      }
    },
  );

  testWidgets('poll preview renders option chips', (tester) async {
    final spec = MeshServicePresentationRegistry.forType(MeshServiceType.poll);

    await tester.pumpWidget(
      buildHarness(
        Builder(
          builder: (context) => spec.buildComposePreviewContent(
            context,
            l10n,
            const MeshServiceComposeDraft(
              title: 'Which route?',
              description: 'Pick one',
              ttlMinutes: 30,
              options: ['North', 'South', 'Stay put'],
            ),
          ),
        ),
      ),
    );

    expect(find.text('North'), findsOneWidget);
    expect(find.text('South'), findsOneWidget);
    expect(find.text('Stay put'), findsOneWidget);
  });

  testWidgets('signal preview renders signal kind and active status', (
    tester,
  ) async {
    final spec = MeshServicePresentationRegistry.forType(
      MeshServiceType.signal,
    );

    await tester.pumpWidget(
      buildHarness(
        Builder(
          builder: (context) => spec.buildComposePreviewContent(
            context,
            l10n,
            const MeshServiceComposeDraft(
              title: 'Trail alert',
              description: 'Loose rock ahead',
              ttlMinutes: 20,
              signalKind: MeshServiceSignalKind.hazard,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Hazard'), findsOneWidget);
    expect(find.text('Active now'), findsOneWidget);
  });

  testWidgets('list remote detail shows collaborative progress', (
    tester,
  ) async {
    final spec = MeshServicePresentationRegistry.forType(MeshServiceType.list);

    await tester.pumpWidget(
      buildHarness(
        Builder(
          builder: (context) => spec.buildRemoteDetailContent(
            context,
            l10n,
            const MeshServiceRemoteDetailViewData(
              title: 'Camp chores',
              description: 'Wrap up before dark',
              expiresAt: null,
              createdAt: null,
              listItems: ['Filter water', 'Pitch tent', 'Check radio'],
              listItemStates: [true, false, true],
              listTotalItems: 3,
            ),
          ),
        ),
      ),
    );

    expect(find.text('2 of 3 done'), findsOneWidget);
    expect(find.text('Filter water'), findsOneWidget);
    expect(find.text('Pitch tent'), findsOneWidget);
    expect(find.text('Check radio'), findsOneWidget);
  });

  testWidgets('list remote detail shows inline pending feedback', (
    tester,
  ) async {
    final spec = MeshServicePresentationRegistry.forType(MeshServiceType.list);

    await tester.pumpWidget(
      buildHarness(
        Builder(
          builder: (context) => spec.buildRemoteDetailContent(
            context,
            l10n,
            const MeshServiceRemoteDetailViewData(
              title: 'Camp chores',
              description: 'Wrap up before dark',
              expiresAt: null,
              createdAt: null,
              listItems: ['Filter water', 'Pitch tent', 'Check radio'],
              listItemStates: [true, false, true],
              listTotalItems: 3,
              isInteractionBusy: true,
              pendingListItemIndex: 1,
            ),
          ),
        ),
      ),
    );

    expect(find.byType(LoadingIndicator), findsOneWidget);
    expect(find.byIcon(Icons.check_box), findsNWidgets(2));
    expect(find.text('Pitch tent'), findsOneWidget);
  });

  testWidgets('sensor local summary shows value, unit, and source', (
    tester,
  ) async {
    final spec = MeshServicePresentationRegistry.forType(
      MeshServiceType.sensor,
    );
    final instance = MeshServiceInstance(
      instanceId: 'sensor-1',
      canonicalType: MeshServiceType.sensor,
      presetId: MeshServicePresetId.weatherStation,
      title: 'Ridge weather',
      createdAt: DateTime(2026),
      config: const {
        'sensorValue': '23.4',
        'sensorUnit': '°C',
        'sensorSource': 'Trail station',
      },
    );

    await tester.pumpWidget(
      buildHarness(
        Builder(
          builder: (context) => spec.buildLocalSummary(context, l10n, instance),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText && widget.text.toPlainText().contains('23.4 °C'),
      ),
      findsOneWidget,
    );
    expect(find.text('Trail station'), findsOneWidget);
  });
}
