// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D36-A: Neighbours tile gating on the contact detail screen.
//
// Pinned invariants:
//   - The Neighbours tile renders for advType=repeater.
//   - The Neighbours tile is HIDDEN entirely for advType=chat.
//   - The other action tiles (Trace, Path override, Reset) keep
//     rendering across both repeater and chat contact types.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_contact_detail_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/meshcore_contact.dart';

MeshCoreContact _contact({required int advType, String name = 'Test'}) {
  return MeshCoreContact(
    publicKey: Uint8List.fromList(List.generate(32, (i) => i + 1)),
    name: name,
    type: advType,
    pathLength: 2,
    path: Uint8List.fromList([0xAB, 0xCD]),
    lastSeen: DateTime(2026, 5, 11, 12),
  );
}

Widget _wrap(MeshCoreContact contact) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: MeshCoreContactDetailScreen(initialContact: contact),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Neighbours tile renders for advType=repeater', (tester) async {
    tester.view.physicalSize = const Size(440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(_contact(advType: MeshCoreAdvType.repeater)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('meshcore-contact-detail-neighbors')),
      findsOneWidget,
    );
    expect(find.text('Neighbours'), findsOneWidget);
    expect(find.text("Repeater's adjacent peers"), findsOneWidget);
  });

  testWidgets('Neighbours tile is HIDDEN for advType=chat', (tester) async {
    tester.view.physicalSize = const Size(440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(_contact(advType: MeshCoreAdvType.chat)));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('meshcore-contact-detail-neighbors')),
      findsNothing,
    );
    expect(find.text('Neighbours'), findsNothing);
    expect(find.text("Repeater's adjacent peers"), findsNothing);
  });

  testWidgets(
    'other action tiles (Trace, Path override, Reset) still render for both '
    'repeater and chat contacts',
    (tester) async {
      tester.view.physicalSize = const Size(440, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Repeater first.
      await tester.pumpWidget(
        _wrap(_contact(advType: MeshCoreAdvType.repeater)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('meshcore-contact-detail-trace-path')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meshcore-contact-detail-path-override')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meshcore-contact-detail-reset-path')),
        findsOneWidget,
      );

      // Chat next.
      await tester.pumpWidget(_wrap(_contact(advType: MeshCoreAdvType.chat)));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('meshcore-contact-detail-trace-path')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meshcore-contact-detail-path-override')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meshcore-contact-detail-reset-path')),
        findsOneWidget,
      );
    },
  );
}
