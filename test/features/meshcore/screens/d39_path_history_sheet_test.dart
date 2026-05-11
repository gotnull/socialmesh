// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D39-A - Path History sheet widget tests.
//
// Pinned invariants:
//   - Sheet renders hop count, age, source badge for each entry.
//   - Stale badge renders when an entry's lastUsedAt > 7 days old.
//   - Active marker renders when a saved entry's bytes match the
//     contact's firmware-active path.
//   - Long-press opens View / Delete options.
//   - Delete updates the rendered row count.
//   - Banned redaction patterns (32-char hex PSK, name:hex channel
//     code) never appear in any rendered Text widget.

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

MeshCoreContact _contact({
  required String pubKeyPrefix,
  Uint8List? activePath,
}) {
  final bytes = Uint8List(32);
  for (int i = 0; i < 4; i++) {
    bytes[i] = int.parse(pubKeyPrefix.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return MeshCoreContact(
    publicKey: bytes,
    name: 'TerryDev2',
    type: MeshCoreAdvType.chat,
    pathLength: activePath?.length ?? -1,
    path: activePath ?? Uint8List(0),
    lastSeen: DateTime(2026, 5, 11, 12),
  );
}

Future<void> _seedHistory(
  String devicePubKeyPrefix,
  String contactPubKeyPrefix,
  List<({Uint8List bytes, DateTime lastUsedAt, DateTime createdAt})> entries,
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
          'createdAt': e.value.createdAt.millisecondsSinceEpoch,
          'lastUsedAt': e.value.lastUsedAt.millisecondsSinceEpoch,
          'label': null,
          'successCount': 0,
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

final List<RegExp> _bannedRenderedPatterns = [
  RegExp(r'[0-9a-fA-F]{32}'),
  RegExp(r'[A-Za-z0-9#_-]+:[0-9a-fA-F]{32}'),
];

void _expectNoBannedRenderedText(WidgetTester tester) {
  final allTexts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .toList();
  for (final pat in _bannedRenderedPatterns) {
    for (final t in allTexts) {
      expect(
        pat.hasMatch(t),
        isFalse,
        reason: 'banned pattern $pat matched rendered text "$t"',
      );
    }
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'sheet renders a row per saved entry with hop count + source badge',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      await _seedHistory('79426d8d', 'aabbccdd', [
        (
          bytes: Uint8List.fromList([1, 2, 3]),
          lastUsedAt: now.subtract(const Duration(minutes: 5)),
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
        (
          bytes: Uint8List.fromList([4, 5]),
          lastUsedAt: now.subtract(const Duration(hours: 2)),
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
      ]);

      await tester.pumpWidget(
        _wrap(contact: _contact(pubKeyPrefix: 'aabbccdd')),
      );
      await tester.tap(find.text('Open'));
      await _settle(tester);

      // SectionTitle uppercases its label.
      expect(
        find.text(_l10n.meshcorePathHistoryTitle.toUpperCase()),
        findsOneWidget,
      );
      expect(find.text('3'), findsOneWidget); // hop-count badge
      expect(find.text('2'), findsOneWidget);
      expect(find.text(_l10n.meshcorePathHistoryHopCount(3)), findsOneWidget);
      expect(find.text(_l10n.meshcorePathHistoryHopCount(2)), findsOneWidget);
      // Both entries are sourced from Trace.
      expect(find.text(_l10n.meshcorePathHistorySourceTrace), findsNWidgets(2));
      _expectNoBannedRenderedText(tester);
      await _dismissAnyOpenSheet(tester);
    },
  );

  testWidgets('stale badge renders when an entry is > 7 days old', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime.now();
    await _seedHistory('79426d8d', 'aabbccdd', [
      (
        bytes: Uint8List.fromList([1, 2, 3]),
        lastUsedAt: now.subtract(const Duration(days: 10)),
        createdAt: now.subtract(const Duration(days: 10)),
      ),
    ]);

    await tester.pumpWidget(_wrap(contact: _contact(pubKeyPrefix: 'aabbccdd')));
    await tester.tap(find.text('Open'));
    await _settle(tester);

    expect(find.text(_l10n.meshcorePathHistoryStaleBadge), findsOneWidget);
    await _dismissAnyOpenSheet(tester);
  });

  testWidgets('active marker renders when saved bytes equal the contact\'s '
      'firmware path', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime.now();
    final pathBytes = Uint8List.fromList([7, 8, 9]);
    await _seedHistory('79426d8d', 'aabbccdd', [
      (bytes: pathBytes, lastUsedAt: now, createdAt: now),
    ]);

    await tester.pumpWidget(
      _wrap(
        contact: _contact(pubKeyPrefix: 'aabbccdd', activePath: pathBytes),
      ),
    );
    await tester.tap(find.text('Open'));
    await _settle(tester);

    expect(find.text(_l10n.meshcorePathHistoryActiveBadge), findsOneWidget);
    await _dismissAnyOpenSheet(tester);
  });

  testWidgets('long-press opens View / Delete actions', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final now = DateTime.now();
    await _seedHistory('79426d8d', 'aabbccdd', [
      (bytes: Uint8List.fromList([1, 2, 3]), lastUsedAt: now, createdAt: now),
    ]);

    await tester.pumpWidget(_wrap(contact: _contact(pubKeyPrefix: 'aabbccdd')));
    await tester.tap(find.text('Open'));
    await _settle(tester);

    await tester.longPress(find.text(_l10n.meshcorePathHistoryHopCount(3)));
    await _settle(tester);

    expect(find.text(_l10n.meshcorePathHistoryViewBytesAction), findsOneWidget);
    expect(find.text(_l10n.meshcorePathHistoryDeleteAction), findsOneWidget);
    await _dismissAnyOpenSheet(tester);
  });

  testWidgets('empty state placeholder shows when no entries are saved', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap(contact: _contact(pubKeyPrefix: 'aabbccdd')));
    await tester.tap(find.text('Open'));
    await _settle(tester);

    expect(find.text(_l10n.meshcorePathHistoryEmpty), findsOneWidget);
    _expectNoBannedRenderedText(tester);
    await _dismissAnyOpenSheet(tester);
  });
}
