// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_instance.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_template.dart';
import 'package:socialmesh/features/mesh_services/widgets/mesh_service_instance_card.dart';
import 'package:socialmesh/features/sip/widgets/sip_hub_your_services_section.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/providers/sip_hub_services_providers.dart';

MeshServiceInstance _inst({
  required String id,
  required String title,
  MeshServiceType type = MeshServiceType.feed,
}) {
  return MeshServiceInstance(
    instanceId: id,
    canonicalType: type,
    title: title,
    description: 'desc',
    createdAt: DateTime.now(),
    status: MeshServiceStatus.active,
  );
}

Widget _harness() {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Consumer(
        builder: (context, ref, _) =>
            CustomScrollView(slivers: buildYourServicesSlivers(context, ref)),
      ),
    ),
  );
}

void main() {
  group('buildYourServicesSlivers', () {
    testWidgets('renders header + Create CTA when empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localServicesSummaryProvider.overrideWith(
              (_) async => const <MeshServiceInstance>[],
            ),
          ],
          child: _harness(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('YOUR SERVICES'), findsOneWidget);
      expect(find.text('Create Service'), findsOneWidget);
      expect(find.byType(MeshServiceInstanceCard), findsNothing);
    });

    testWidgets('renders an instance card per active service', (tester) async {
      final instances = [
        _inst(id: 'a', title: 'Alpha service'),
        _inst(id: 'b', title: 'Beta service'),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localServicesSummaryProvider.overrideWith((_) async => instances),
          ],
          child: _harness(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Service'), findsOneWidget);
      expect(find.byType(MeshServiceInstanceCard), findsNWidgets(2));
      expect(find.text('Alpha service'), findsOneWidget);
      expect(find.text('Beta service'), findsOneWidget);
    });

    testWidgets('section header count reflects instance list length', (
      tester,
    ) async {
      final instances = [
        _inst(id: 'a', title: 'Alpha'),
        _inst(id: 'b', title: 'Beta'),
        _inst(id: 'c', title: 'Gamma'),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localServicesSummaryProvider.overrideWith((_) async => instances),
          ],
          child: _harness(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('YOUR SERVICES'), findsOneWidget);
      expect(find.byType(MeshServiceInstanceCard), findsNWidgets(3));
    });
  });
}
