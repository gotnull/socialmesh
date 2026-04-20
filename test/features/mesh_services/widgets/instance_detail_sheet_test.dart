// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_instance.dart';
import 'package:socialmesh/features/mesh_services/models/mesh_service_template.dart';
import 'package:socialmesh/features/mesh_services/widgets/instance_detail_sheet.dart';
import 'package:socialmesh/features/mesh_services/widgets/mesh_service_status_badge.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

MeshServiceInstance _inst({
  required String title,
  MeshServiceStatus status = MeshServiceStatus.active,
  DateTime? expiresAt,
  String description = '',
}) {
  return MeshServiceInstance(
    instanceId: 'test-$title',
    canonicalType: MeshServiceType.feed,
    title: title,
    description: description,
    createdAt: DateTime.now(),
    expiresAt: expiresAt,
    status: status,
  );
}

Widget _harness(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(padding: const EdgeInsets.all(16), child: child),
        ),
      ),
    ),
  );
}

void main() {
  group('InstanceDetailSheet', () {
    testWidgets('renders title, description, and status badge', (tester) async {
      final instance = _inst(
        title: 'Campfire Circle',
        description: 'Local meetup at the park',
      );
      await tester.pumpWidget(
        _harness(InstanceDetailSheet(instance: instance)),
      );
      await tester.pump();

      expect(find.text('Campfire Circle'), findsOneWidget);
      expect(find.text('Local meetup at the park'), findsOneWidget);
      expect(find.byType(MeshServiceStatusBadge), findsOneWidget);
    });

    testWidgets('active instance shows both Stop and Delete actions', (
      tester,
    ) async {
      final instance = _inst(title: 'Active svc');
      await tester.pumpWidget(
        _harness(InstanceDetailSheet(instance: instance)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.stop_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('stopped instance hides Stop action but keeps Delete', (
      tester,
    ) async {
      final instance = _inst(
        title: 'Stopped svc',
        status: MeshServiceStatus.stopped,
      );
      await tester.pumpWidget(
        _harness(InstanceDetailSheet(instance: instance)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.stop_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('expired instance hides Stop action but keeps Delete', (
      tester,
    ) async {
      final instance = _inst(
        title: 'Expired svc',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      await tester.pumpWidget(
        _harness(InstanceDetailSheet(instance: instance)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.stop_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('description is omitted when empty', (tester) async {
      final instance = _inst(title: 'No desc', description: '');
      await tester.pumpWidget(
        _harness(InstanceDetailSheet(instance: instance)),
      );
      await tester.pump();

      expect(find.text('No desc'), findsOneWidget);
    });
  });
}
