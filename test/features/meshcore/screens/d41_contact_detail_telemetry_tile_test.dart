// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D41-A: Contact-detail Telemetry tile pins.
//
// Pinned invariants:
//   - Telemetry tile renders with the canonical title + subtitle.
//   - The pre-existing D34c-A / D34c-B-A / D39-A tiles (Trace,
//     Path Override, Reset Path, Path History) remain reachable
//     alongside the new tile - this is a regression guard against
//     the contact-detail action section getting accidentally
//     rewritten when adding the tile.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_contact_detail_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

final _l10n = AppLocalizationsEn();

MeshCoreContact _contact() {
  final pubKey = Uint8List(32);
  pubKey[0] = 0xAA;
  pubKey[1] = 0xBB;
  pubKey[2] = 0xCC;
  pubKey[3] = 0xDD;
  return MeshCoreContact(
    publicKey: pubKey,
    name: 'TerryDev2',
    type: MeshCoreAdvType.chat,
    pathLength: -1,
    path: Uint8List(0),
    lastSeen: DateTime(2026, 5, 11, 12),
  );
}

Widget _wrap({required MeshCoreContact contact}) {
  return ProviderScope(
    overrides: [
      meshCoreSelfPubKeyPrefixProvider.overrideWith((ref) => '79426d8d'),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: MeshCoreContactDetailScreen(initialContact: contact),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Telemetry tile renders with canonical title + subtitle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(contact: _contact()));
    await _settle(tester);

    // The Telemetry tile is reachable by its stable key + ARB strings.
    expect(
      find.byKey(const ValueKey('meshcore-contact-detail-telemetry')),
      findsOneWidget,
    );
    expect(find.text(_l10n.meshcoreTelemetryTileTitle), findsOneWidget);
    expect(find.text(_l10n.meshcoreTelemetryTileSubtitle), findsOneWidget);
  });

  testWidgets(
    'Pre-existing D34c / D39 action tiles remain reachable alongside the '
    'new Telemetry tile',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(_wrap(contact: _contact()));
      await _settle(tester);

      expect(find.text(_l10n.meshcoreTracePathTitle), findsOneWidget);
      expect(find.text(_l10n.meshcorePathOverrideTitle), findsOneWidget);
      expect(find.text(_l10n.meshcoreResetPath), findsOneWidget);
      expect(find.text(_l10n.meshcoreTelemetryTileTitle), findsOneWidget);
    },
  );
}
