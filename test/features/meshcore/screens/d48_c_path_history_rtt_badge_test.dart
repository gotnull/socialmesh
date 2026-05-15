// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D48-C: RTT badge in the path-history sheet.
//
// Pinned invariants:
//   - When `avgTripTimeMs > 0` the sheet renders an RTT badge for
//     that entry.
//   - When `avgTripTimeMs == 0` (no sample yet) the badge is hidden.
//   - Sub-second values render as integer milliseconds ("RTT 850 ms").
//   - >= 1 s values render with one decimal of seconds ("RTT 1.2 s").
//   - The two rows in a mixed list (one with sample, one without)
//     are rendered independently: only the entry with a sample
//     shows the badge.

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_path_history_sheet.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

final _l10n = AppLocalizationsEn();

MeshCoreContact _contact({required String pubKeyPrefix}) {
  final bytes = Uint8List(32);
  for (int i = 0; i < 4; i++) {
    bytes[i] = int.parse(pubKeyPrefix.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return MeshCoreContact(
    publicKey: bytes,
    name: 'Bob',
    type: MeshCoreAdvType.chat,
    pathLength: -1,
    path: Uint8List(0),
    lastSeen: DateTime(2026, 5, 11, 12),
  );
}

Future<void> _seedHistoryWithRtt(
  String devicePubKeyPrefix,
  String contactPubKeyPrefix,
  List<({Uint8List bytes, DateTime lastUsedAt, double avgTripTimeMs})> entries,
) async {
  final list = entries
      .asMap()
      .entries
      .map(
        (e) => {
          'id': 'id-${e.key}',
          'bytes': base64Encode(e.value.bytes),
          'len': e.value.bytes.length,
          'source': 'trace',
          'createdAt': e.value.lastUsedAt.millisecondsSinceEpoch,
          'lastUsedAt': e.value.lastUsedAt.millisecondsSinceEpoch,
          'label': null,
          'successCount': 1,
          'failureCount': 0,
          'routeWeight': 3.0,
          'avgTripTimeMs': e.value.avgTripTimeMs,
        },
      )
      .toList();
  SharedPreferences.setMockInitialValues({
    'meshcore_path_history_${devicePubKeyPrefix}_'
        '$contactPubKeyPrefix': jsonEncode({
      'entries': list,
    }),
  });
}

Widget _wrap({
  required MeshCoreContact contact,
  String devicePubKeyPrefix = '79426d8d',
}) {
  return ProviderScope(
    overrides: [
      meshCoreSelfPubKeyPrefixProvider.overrideWith(
        (ref) => devicePubKeyPrefix,
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark(),
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () =>
                  showMeshCorePathHistorySheet(ctx, contact: contact),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> _dismissAnyOpenSheet(WidgetTester tester) async {
  final navFinder = find.byType(Navigator);
  if (navFinder.evaluate().isNotEmpty) {
    final navState = tester.state<NavigatorState>(navFinder.last);
    while (navState.canPop()) {
      navState.pop();
    }
  }
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(seconds: 5));
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('sub-second RTT renders as integer ms', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime.now();
    await _seedHistoryWithRtt('79426d8d', 'aabbccdd', [
      (
        bytes: Uint8List.fromList([1, 2, 3]),
        lastUsedAt: now.subtract(const Duration(minutes: 1)),
        avgTripTimeMs: 850.0,
      ),
    ]);

    await tester.pumpWidget(_wrap(contact: _contact(pubKeyPrefix: 'aabbccdd')));
    await _settle(tester);
    await tester.tap(find.text('Open'));
    await _settle(tester);

    expect(
      find.text(_l10n.meshcorePathHistoryRttBadgeMs('850')),
      findsOneWidget,
    );
    await _dismissAnyOpenSheet(tester);
  });

  testWidgets('>= 1 s RTT renders as one-decimal seconds', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime.now();
    await _seedHistoryWithRtt('79426d8d', 'aabbccdd', [
      (
        bytes: Uint8List.fromList([1, 2, 3]),
        lastUsedAt: now.subtract(const Duration(minutes: 1)),
        avgTripTimeMs: 1234.0,
      ),
    ]);

    await tester.pumpWidget(_wrap(contact: _contact(pubKeyPrefix: 'aabbccdd')));
    await _settle(tester);
    await tester.tap(find.text('Open'));
    await _settle(tester);

    expect(
      find.text(_l10n.meshcorePathHistoryRttBadgeSeconds('1.2')),
      findsOneWidget,
    );
    await _dismissAnyOpenSheet(tester);
  });

  testWidgets('no badge when avgTripTimeMs == 0 (no sample yet)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime.now();
    await _seedHistoryWithRtt('79426d8d', 'aabbccdd', [
      (
        bytes: Uint8List.fromList([1, 2, 3]),
        lastUsedAt: now.subtract(const Duration(minutes: 1)),
        avgTripTimeMs: 0.0,
      ),
    ]);

    await tester.pumpWidget(_wrap(contact: _contact(pubKeyPrefix: 'aabbccdd')));
    await _settle(tester);
    await tester.tap(find.text('Open'));
    await _settle(tester);

    // The "RTT " prefix is unique to the new badge keys; assert no
    // Text widget on screen contains it.
    final rttBadges = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => (t.data ?? '').contains('RTT'));
    expect(rttBadges, isEmpty);
    await _dismissAnyOpenSheet(tester);
  });

  testWidgets('mixed list: only the entry with a sample shows the RTT badge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime.now();
    await _seedHistoryWithRtt('79426d8d', 'aabbccdd', [
      (
        bytes: Uint8List.fromList([1, 2]),
        lastUsedAt: now.subtract(const Duration(minutes: 1)),
        avgTripTimeMs: 420.0,
      ),
      (
        bytes: Uint8List.fromList([3, 4]),
        lastUsedAt: now.subtract(const Duration(minutes: 2)),
        avgTripTimeMs: 0.0,
      ),
    ]);

    await tester.pumpWidget(_wrap(contact: _contact(pubKeyPrefix: 'aabbccdd')));
    await _settle(tester);
    await tester.tap(find.text('Open'));
    await _settle(tester);

    // Exactly one badge with "RTT 420 ms".
    expect(
      find.text(_l10n.meshcorePathHistoryRttBadgeMs('420')),
      findsOneWidget,
    );
    // Verify no second RTT badge slipped in.
    final allRttTexts = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data ?? '')
        .where((s) => s.contains('RTT'))
        .toList();
    expect(allRttTexts, hasLength(1));
    await _dismissAnyOpenSheet(tester);
  });
}
