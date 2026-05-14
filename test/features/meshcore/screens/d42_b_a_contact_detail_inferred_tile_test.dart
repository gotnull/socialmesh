// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D42-B-A: Contact Detail "Show inferred path" tile pins.
//
// The tile is always visible (no eager evidence load on contact-detail
// open). Tap behaviour depends on whether app-local evidence resolves
// to a drawable overlay. This file pins:
//   - tile renders with the canonical title + subtitle.
//   - tile is reachable via its stable ValueKey.
//   - pre-existing D42-A "Show on map" tile remains alongside it.
//   - pre-existing Trace / Path Override / Reset Path tiles remain.
//   - rendered text never embeds a 64-char pubkey hex or long base64.
//   - tap with NO evidence shows the unavailable info snackbar and
//     does NOT push the map route.
//   - tap with seeded D39 evidence pushes the map route.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_contact_detail_screen.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_map_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';
import 'package:socialmesh/services/meshcore/storage/meshcore_path_history_store.dart';

final _l10n = AppLocalizationsEn();

MeshCoreContact _contact({
  required int firstByte,
  double? lat,
  double? lng,
  int pathLength = -1,
  Uint8List? path,
}) {
  final pubKey = Uint8List(32);
  pubKey[0] = firstByte;
  return MeshCoreContact(
    publicKey: pubKey,
    name: 'TerryDev2',
    type: MeshCoreAdvType.chat,
    pathLength: pathLength,
    path: path ?? Uint8List(0),
    latitude: lat,
    longitude: lng,
    lastSeen: DateTime(2026, 5, 11, 12),
  );
}

class _StubContactsNotifier extends MeshCoreContactsNotifier {
  _StubContactsNotifier(this._seed);
  final List<MeshCoreContact> _seed;
  @override
  MeshCoreContactsState build() =>
      MeshCoreContactsState(contacts: List.unmodifiable(_seed));
}

class _StubSelfInfoNotifier extends MeshCoreSelfInfoNotifier {
  _StubSelfInfoNotifier(this._info);
  final MeshCoreSelfInfo? _info;
  @override
  MeshCoreSelfInfoState build() => _info == null
      ? const MeshCoreSelfInfoState.initial()
      : MeshCoreSelfInfoState.loaded(_info);
}

const _selfPrefix = '79426d8d';

MeshCoreSelfInfo _selfInfo({double lat = 0.5, double lng = 0.7}) {
  return MeshCoreSelfInfo(
    advType: 1,
    txPowerDbm: 22,
    maxLoraTxPower: 22,
    pubKey: Uint8List.fromList(List.generate(32, (i) => 0xAA - i)),
    latitude: (lat * 1e7).round(),
    longitude: (lng * 1e7).round(),
    nodeName: 'self',
    rawPayload: Uint8List(0),
  );
}

Widget _wrap({
  required MeshCoreContact contact,
  required List<MeshCoreContact> contacts,
  MeshCoreSelfInfo? selfInfo,
}) {
  return ProviderScope(
    overrides: [
      meshCoreContactsProvider.overrideWith(
        () => _StubContactsNotifier(contacts),
      ),
      meshCoreSelfInfoProvider.overrideWith(
        () => _StubSelfInfoNotifier(selfInfo),
      ),
      meshCoreSelfPubKeyPrefixProvider.overrideWith((ref) => _selfPrefix),
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

Future<void> _seedSavedPathFor(
  MeshCoreContact contact, {
  required List<int> bytes,
  required DateTime lastUsedAt,
}) async {
  final store = MeshCorePathHistoryStore();
  final contactPrefix = meshCoreContactPubKeyPrefix(contact.publicKeyHex);
  await store.save(_selfPrefix, contactPrefix, [
    MeshCorePathHistoryEntry(
      id: 'seed-${lastUsedAt.millisecondsSinceEpoch}',
      bytes: Uint8List.fromList(bytes),
      len: bytes.length,
      source: MeshCorePathSource.trace,
      createdAt: lastUsedAt,
      lastUsedAt: lastUsedAt,
    ),
  ]);
}

final List<RegExp> _bannedRenderTextPatterns = [
  RegExp(r'[0-9a-fA-F]{32}'),
  RegExp(r'[0-9a-fA-F]{64}'),
  RegExp(r'[A-Za-z0-9+/_-]{32,}={0,2}'),
];

void _expectNoBannedText(WidgetTester tester) {
  final allTexts = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .toList();
  for (final pat in _bannedRenderTextPatterns) {
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
    'Show inferred path tile renders with canonical title + subtitle',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final c = _contact(firstByte: 0x99, lat: 1.0, lng: 2.0);

      await tester.pumpWidget(
        _wrap(contact: c, contacts: [c], selfInfo: _selfInfo()),
      );
      await _settle(tester);

      expect(
        find.byKey(
          const ValueKey('meshcore-contact-detail-show-inferred-path'),
        ),
        findsOneWidget,
      );
      expect(find.text(_l10n.meshcorePathOverlayShowInferred), findsOneWidget);
      expect(
        find.text(_l10n.meshcorePathOverlayShowInferredSubtitle),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'pre-existing D42-A and D34c action tiles remain reachable alongside '
    'the new Show-inferred-path tile',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final hop = _contact(firstByte: 0x11, lat: 10.0, lng: 20.0);
      final target = _contact(
        firstByte: 0x99,
        lat: 50.0,
        lng: 60.0,
        pathLength: 1,
        path: Uint8List.fromList([0x11]),
      );

      await tester.pumpWidget(
        _wrap(contact: target, contacts: [hop, target], selfInfo: _selfInfo()),
      );
      await _settle(tester);

      // D34c-A trace + override + reset.
      expect(find.text(_l10n.meshcoreTracePathTitle), findsOneWidget);
      expect(find.text(_l10n.meshcorePathOverrideTitle), findsOneWidget);
      expect(find.text(_l10n.meshcoreResetPath), findsOneWidget);
      // D42-A Show on map tile.
      expect(find.text(_l10n.meshcorePathOverlayShowOnMap), findsOneWidget);
      // D42-B-A new tile.
      expect(find.text(_l10n.meshcorePathOverlayShowInferred), findsOneWidget);
    },
  );

  testWidgets('rendered text never embeds a pubkey hex or base64 envelope', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final c = _contact(firstByte: 0x99, lat: 1.0, lng: 2.0);
    await tester.pumpWidget(
      _wrap(contact: c, contacts: [c], selfInfo: _selfInfo()),
    );
    await _settle(tester);

    _expectNoBannedText(tester);
  });

  testWidgets(
    'tap with no evidence shows unavailable snackbar; map route is NOT pushed',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final c = _contact(firstByte: 0x99, lat: 1.0, lng: 2.0);
      await tester.pumpWidget(
        _wrap(contact: c, contacts: [c], selfInfo: _selfInfo()),
      );
      await _settle(tester);

      await tester.tap(find.text(_l10n.meshcorePathOverlayShowInferred));
      await _settle(tester);

      expect(
        find.text(_l10n.meshcorePathOverlayInferredUnavailable),
        findsOneWidget,
      );
      expect(find.byType(MeshCoreMapScreen), findsNothing);
    },
  );

  testWidgets('tap with seeded D39 evidence pushes the map route', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final hop = _contact(firstByte: 0x11, lat: 10.0, lng: 20.0);
    final target = _contact(firstByte: 0x99, lat: 50.0, lng: 60.0);

    // Seed BEFORE pumpWidget so the path-history store already has
    // an entry when the tile invokes setInferred.
    await _seedSavedPathFor(
      target,
      bytes: [0x11],
      lastUsedAt: DateTime.utc(2026, 5, 12, 9),
    );

    await tester.pumpWidget(
      _wrap(contact: target, contacts: [hop, target], selfInfo: _selfInfo()),
    );
    await _settle(tester);

    await tester.tap(find.text(_l10n.meshcorePathOverlayShowInferred));
    await _settle(tester);
    await _settle(tester);

    expect(find.byType(MeshCoreMapScreen), findsOneWidget);

    // flutter_map throws synchronously on first frame before the
    // FlutterMap registers its camera; drain so the test result
    // isn't tainted (same pattern as the D42-A tile test).
    tester.takeException();
  });
}
