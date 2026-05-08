// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34c-A — `MeshCoreContactDetailScreen` widget regression pins.
//
// Pinned invariants:
//   - Canonical sections render in order: Identity, Routing, Activity,
//     (Location only when GPS present), Actions.
//   - **No force-flood / force-direct / force-N-hop override controls
//     surface in this slice.** D34c-B will gate those behind a
//     dedicated safety-reviewed UI.
//   - GPS row hides when the contact has no real location (lat==null
//     && lon==null per the post-D34c-A parser semantics).
//   - The Trace Path and Reset Path action tiles are present and
//     keyed for stable lookup.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_contact_detail_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/meshcore_contact.dart';

MeshCoreContact _contact({
  String name = 'WisMeshCore',
  int type = MeshCoreAdvType.chat,
  int pathLength = 2,
  Uint8List? path,
  double? latitude,
  double? longitude,
  int? snrQuarter,
}) {
  return MeshCoreContact(
    publicKey: Uint8List.fromList(List.generate(32, (i) => i + 1)),
    name: name,
    type: type,
    pathLength: pathLength,
    path: path ?? Uint8List.fromList([0xAB, 0xCD]),
    latitude: latitude,
    longitude: longitude,
    lastSeen: DateTime(2026, 5, 7, 14, 30),
    snrQuarter: snrQuarter,
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

  testWidgets(
    'renders the canonical sections (Identity, Routing, Activity, Actions) '
    'and surfaces the contact name in the title',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(_contact()));
      await tester.pumpAndSettle();

      // Title shows the contact's name.
      expect(find.text('WisMeshCore'), findsWidgets);

      // Canonical sections (uppercased by SectionTitle).
      expect(find.text('IDENTITY'), findsOneWidget);
      expect(find.text('ROUTING'), findsOneWidget);
      expect(find.text('ACTIVITY'), findsOneWidget);
      expect(find.text('ACTIONS'), findsOneWidget);
    },
  );

  testWidgets(
    'GPS row hidden when contact has no location (lat==null && lon==null)',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(_contact()));
      await tester.pumpAndSettle();

      // No "LOCATION" section when the contact carries no GPS.
      expect(find.text('LOCATION'), findsNothing);
      expect(find.text('Latitude'), findsNothing);
      expect(find.text('Longitude'), findsNothing);
    },
  );

  testWidgets('GPS row shows when contact has a real location', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      _wrap(_contact(latitude: 51.408, longitude: -0.1234)),
    );
    await tester.pumpAndSettle();

    expect(find.text('LOCATION'), findsOneWidget);
    expect(find.text('Latitude'), findsOneWidget);
    expect(find.text('Longitude'), findsOneWidget);
    expect(find.text('51.40800'), findsOneWidget);
    expect(find.text('-0.12340'), findsOneWidget);
  });

  testWidgets('D34c-A scope guard: NO force-flood / force-direct / force-N-hop '
      'override controls surface', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(_contact()));
    await tester.pumpAndSettle();

    // Pin the absence of any string that names an override
    // semantic. These are the labels D34c-B might introduce; they
    // MUST NOT exist today.
    expect(find.textContaining('Force flood'), findsNothing);
    expect(find.textContaining('Force direct'), findsNothing);
    expect(find.textContaining('Force '), findsNothing);
    expect(find.textContaining('Override'), findsNothing);
    expect(find.textContaining('N hops'), findsNothing);
  });

  testWidgets(
    'action tiles for Trace Path and Reset Path are present and keyed',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(_contact()));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('meshcore-contact-detail-trace-path')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meshcore-contact-detail-reset-path')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'path bytes row hex-formats the saved hops uppercase, space-separated',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          _contact(pathLength: 3, path: Uint8List.fromList([0xAB, 0x0C, 0xDE])),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Path Bytes'), findsOneWidget);
      expect(find.text('AB 0C DE'), findsOneWidget);
    },
  );

  testWidgets(
    'pathLength == -1 (flood) hides hops as a number and shows a dash',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(_contact(pathLength: -1, path: Uint8List(0))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Hops'), findsOneWidget);
      // Hops value renders as an em-dash placeholder for flood.
      expect(find.text('—'), findsOneWidget);
      // Path bytes row hidden when there are no path bytes saved.
      expect(find.text('Path Bytes'), findsNothing);
    },
  );

  testWidgets('SNR row hidden when contact has no recorded SNR', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(_contact()));
    await tester.pumpAndSettle();

    // The localized SNR row label only appears when snrDb is non-null.
    expect(find.text('SNR'), findsNothing);
  });
}
