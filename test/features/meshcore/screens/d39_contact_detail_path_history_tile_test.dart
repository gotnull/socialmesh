// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D39-A - contact-detail Path History tile visibility pins.
//
// Pinned invariants:
//   - Tile is hidden when the contact has 0 saved paths.
//   - Tile renders the canonical title + count when N > 0.
//   - The pre-existing Trace / Path Override / Reset Path tiles
//     remain reachable post-D39-A (regression against D28 / D34c-A /
//     D34c-B-A wiring).

import 'dart:convert';
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
  // First 4 bytes -> contact prefix "aabbccdd".
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

Future<void> _seedOnePath() async {
  final now = DateTime.now();
  SharedPreferences.setMockInitialValues({
    'meshcore_path_history_79426d8d_aabbccdd': jsonEncode({
      'entries': [
        {
          'id': 'id-1',
          'bytes': base64Encode([1, 2, 3]),
          'len': 3,
          'source': 'trace',
          'createdAt': now.millisecondsSinceEpoch,
          'lastUsedAt': now.millisecondsSinceEpoch,
          'label': null,
          'successCount': 0,
        },
      ],
    }),
  });
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

  testWidgets('Path History tile is hidden when the contact has 0 saved '
      'paths', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(contact: _contact()));
    await _settle(tester);

    expect(find.text(_l10n.meshcorePathHistoryTileTitle), findsNothing);
    // Pre-existing D34c tiles still reachable.
    expect(find.text(_l10n.meshcoreTracePathTitle), findsOneWidget);
    expect(find.text(_l10n.meshcorePathOverrideTitle), findsOneWidget);
    expect(find.text(_l10n.meshcoreResetPath), findsOneWidget);
  });

  testWidgets('Path History tile is visible when the contact has saved '
      'paths', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await _seedOnePath();

    await tester.pumpWidget(_wrap(contact: _contact()));
    await _settle(tester);
    // Provider deferred load needs an extra cycle.
    await _settle(tester);

    expect(find.text(_l10n.meshcorePathHistoryTileTitle), findsOneWidget);
    expect(find.text(_l10n.meshcorePathHistoryTileSubtitle(1)), findsOneWidget);
    // Pre-existing D34c tiles still reachable.
    expect(find.text(_l10n.meshcoreTracePathTitle), findsOneWidget);
    expect(find.text(_l10n.meshcorePathOverrideTitle), findsOneWidget);
    expect(find.text(_l10n.meshcoreResetPath), findsOneWidget);
  });
}
