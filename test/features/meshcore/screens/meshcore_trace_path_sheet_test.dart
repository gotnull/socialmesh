// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/widgets/primary_gradient_button.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_tools_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

MeshCoreContact _contact(String name, int first, int type) => MeshCoreContact(
  publicKey: Uint8List.fromList(List.generate(32, (i) => (first + i) & 0xFF)),
  name: name,
  type: type,
  pathLength: 0,
  path: Uint8List(0),
  lastSeen: DateTime(2026, 11, 24, 12),
);

class _Roster extends MeshCoreContactsNotifier {
  @override
  MeshCoreContactsState build() => MeshCoreContactsState(
    contacts: [
      _contact('TerryDev2', 0x79, MeshCoreAdvType.chat),
      _contact('Coburg Hill', 0x30, MeshCoreAdvType.repeater),
      _contact('Bendigo Relay', 0x40, MeshCoreAdvType.repeater),
    ],
    lastRefresh: DateTime(2026, 11, 24),
  );
}

Widget _wrap() => ProviderScope(
  overrides: [
    meshCoreSessionProvider.overrideWithValue(null),
    meshCoreContactsProvider.overrideWith(_Roster.new),
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: ThemeData.dark(),
    home: Material(
      child: MeshCoreTracePathSheet(scrollController: ScrollController()),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  testWidgets('search narrows the trace targets; Run waits for a pick', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(find.text('TerryDev2'), findsOneWidget);
    expect(find.text('Coburg Hill'), findsOneWidget);
    PrimaryGradientButton run() => tester.widget<PrimaryGradientButton>(
      find.byType(PrimaryGradientButton),
    );
    expect(run().enabled, isFalse);

    await tester.enterText(find.byType(TextField), 'terry');
    await tester.pump();
    expect(find.text('TerryDev2'), findsOneWidget);
    expect(find.text('Coburg Hill'), findsNothing);

    // A key prefix finds a contact too.
    await tester.enterText(find.byType(TextField), '3031');
    await tester.pump();
    expect(find.text('Coburg Hill'), findsOneWidget);
    expect(find.text('TerryDev2'), findsNothing);

    await tester.tap(find.text('Coburg Hill'));
    await tester.pump();
    expect(run().enabled, isTrue);
  });

  testWidgets('a failed trace offers Retry and Back to the picker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap());
    await tester.pump();
    final l10n = AppLocalizations.of(
      tester.element(find.byType(MeshCoreTracePathSheet)),
    );

    // No session: the trace fails at once.
    await tester.tap(find.text('TerryDev2'));
    await tester.pump();
    await tester.tap(find.text(l10n.meshcoreTracePathRunButton));
    await tester.pump();

    expect(find.text(l10n.meshcoreTracePathFailed), findsOneWidget);
    expect(find.text(l10n.commonRetry), findsOneWidget);
    await tester.tap(find.text(l10n.commonBack));
    await tester.pump();
    expect(find.text(l10n.meshcoreTracePathPickContact), findsOneWidget);
    expect(find.text('TerryDev2'), findsOneWidget);
  });

  testWidgets('each contact row is its own accessible button', (tester) async {
    final semantics = tester.ensureSemantics();
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(find.bySemanticsLabel(RegExp(r'^TerryDev2')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Coburg Hill')), findsOneWidget);
    semantics.dispose();
  });
}
