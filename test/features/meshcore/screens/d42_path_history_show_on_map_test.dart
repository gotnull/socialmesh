// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D42-A - Path History sheet "Show on map" long-press action.
//
// Pinned invariants:
//   - Long-press on a saved-path row reveals the "Show on map" action
//     alongside View and Delete.
//   - Tapping "Show on map" sets the overlay via
//     meshCorePathOverlayProvider with source=history.
//   - Long-press menu still surfaces View and Delete (D39-A actions
//     stay reachable).

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
import 'package:socialmesh/models/meshcore_path_overlay.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

final _l10n = AppLocalizationsEn();

MeshCoreContact _contact({
  required int firstByte,
  double? lat,
  double? lng,
  String name = 'Repeater',
}) {
  final pubKey = Uint8List(32);
  pubKey[0] = firstByte;
  return MeshCoreContact(
    publicKey: pubKey,
    name: name,
    type: MeshCoreAdvType.repeater,
    pathLength: -1,
    path: Uint8List(0),
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

Future<void> _seedHistory(
  String devicePubKeyPrefix,
  String contactPubKeyPrefix,
  Uint8List hopBytes,
) async {
  final now = DateTime.now();
  SharedPreferences.setMockInitialValues({
    'meshcore_path_history_${devicePubKeyPrefix}_$contactPubKeyPrefix':
        jsonEncode({
          'entries': [
            {
              'id': 'id-1',
              'bytes': base64Encode(hopBytes),
              'len': hopBytes.length,
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

Widget _wrap({
  required MeshCoreContact target,
  required List<MeshCoreContact> contacts,
  MeshCoreSelfInfo? selfInfo,
  String devicePubKeyPrefix = '79426d8d',
}) {
  return ProviderScope(
    overrides: [
      meshCoreSelfPubKeyPrefixProvider.overrideWith(
        (ref) => devicePubKeyPrefix,
      ),
      meshCoreContactsProvider.overrideWith(
        () => _StubContactsNotifier(contacts),
      ),
      meshCoreSelfInfoProvider.overrideWith(
        () => _StubSelfInfoNotifier(selfInfo),
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
                  showMeshCorePathHistorySheet(ctx, contact: target),
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

Future<void> _popAndDrain(WidgetTester tester) async {
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

  testWidgets('long-press on a saved row exposes View / Show on map / Delete', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final hop = _contact(firstByte: 0x11, lat: 10.0, lng: 20.0);
    final target = _contact(firstByte: 0x99, lat: 50.0, lng: 60.0);
    await _seedHistory('79426d8d', 'aabbccdd', Uint8List.fromList([0x11]));
    // The target's first byte must match `aabbccdd` -> 0xaa.
    final pubKey = Uint8List(32);
    pubKey[0] = 0xAA;
    pubKey[1] = 0xBB;
    pubKey[2] = 0xCC;
    pubKey[3] = 0xDD;
    final t = MeshCoreContact(
      publicKey: pubKey,
      name: 'TerryDev2',
      type: MeshCoreAdvType.chat,
      pathLength: -1,
      path: Uint8List(0),
      latitude: 50.0,
      longitude: 60.0,
      lastSeen: DateTime(2026, 5, 11, 12),
    );

    await tester.pumpWidget(
      _wrap(target: t, contacts: [hop, t], selfInfo: _selfInfo()),
    );
    await tester.tap(find.text('Open'));
    await _settle(tester);

    // Long-press the row (1 hop).
    await tester.longPress(find.text(_l10n.meshcorePathHistoryHopCount(1)));
    await _settle(tester);

    // View + Show on map + Delete all surface.
    expect(find.text(_l10n.meshcorePathHistoryViewBytesAction), findsOneWidget);
    expect(find.text(_l10n.meshcorePathOverlayShowOnMap), findsOneWidget);
    expect(find.text(_l10n.meshcorePathHistoryDeleteAction), findsOneWidget);

    // Suppress the unused `target` reference.
    expect(target.publicKeyHex, isNotEmpty);

    await _popAndDrain(tester);
  });

  testWidgets('tapping Show on map sets the overlay from saved bytes with '
      'source=history', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final hop = _contact(firstByte: 0x11, lat: 10.0, lng: 20.0);
    final pubKey = Uint8List(32);
    pubKey[0] = 0xAA;
    pubKey[1] = 0xBB;
    pubKey[2] = 0xCC;
    pubKey[3] = 0xDD;
    final target = MeshCoreContact(
      publicKey: pubKey,
      name: 'TerryDev2',
      type: MeshCoreAdvType.chat,
      pathLength: -1,
      path: Uint8List(0),
      latitude: 50.0,
      longitude: 60.0,
      lastSeen: DateTime(2026, 5, 11, 12),
    );
    await _seedHistory('79426d8d', 'aabbccdd', Uint8List.fromList([0x11]));

    // Capture the overlay via a watcher widget so we can assert
    // after the long-press flow.
    MeshCorePathOverlay? captured;
    final scope = ProviderScope(
      overrides: [
        meshCoreSelfPubKeyPrefixProvider.overrideWith((ref) => '79426d8d'),
        meshCoreContactsProvider.overrideWith(
          () => _StubContactsNotifier([hop, target]),
        ),
        meshCoreSelfInfoProvider.overrideWith(
          () => _StubSelfInfoNotifier(_selfInfo()),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData.dark(),
        home: Scaffold(
          body: Consumer(
            builder: (ctx, ref, _) {
              captured = ref.watch(meshCorePathOverlayProvider);
              return Center(
                child: ElevatedButton(
                  onPressed: () =>
                      showMeshCorePathHistorySheet(ctx, contact: target),
                  child: const Text('Open'),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.pumpWidget(scope);
    await tester.tap(find.text('Open'));
    await _settle(tester);

    await tester.longPress(find.text(_l10n.meshcorePathHistoryHopCount(1)));
    await _settle(tester);
    await tester.tap(find.text(_l10n.meshcorePathOverlayShowOnMap));
    await _settle(tester);
    await _settle(tester);

    expect(captured, isNotNull);
    expect(captured!.source, MeshCorePathOverlaySource.history);
    expect(captured!.hops, hasLength(1));
    expect(captured!.hops.single.byte, 0x11);

    // Drain any framework exception from the pushed map screen +
    // any auto-dismissing snackbar timer.
    tester.takeException();
    await _popAndDrain(tester);
  });
}
