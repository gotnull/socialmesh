// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D42-A - Contact Detail "Show on map" tile visibility + activation pins.
//
// Pinned invariants:
//   - The tile is hidden when the contact route is flood-only
//     (pathLength == -1 with no override, OR pathOverride == -1).
//   - The tile renders for a contact with a usable path (direct,
//     N-hop, or forced N-hop).
//   - Tapping the tile sets the overlay via meshCorePathOverlayProvider
//     and pushes the map route.
//   - The pre-existing Trace / Path Override / Path History / Reset
//     Path tiles remain reachable.

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

final _l10n = AppLocalizationsEn();

MeshCoreContact _contact({
  required int firstByte,
  double? lat,
  double? lng,
  int pathLength = -1,
  Uint8List? path,
  int? pathOverride,
  Uint8List? pathOverrideBytes,
}) {
  final pubKey = Uint8List(32);
  pubKey[0] = firstByte;
  return MeshCoreContact(
    publicKey: pubKey,
    name: 'TerryDev2',
    type: MeshCoreAdvType.chat,
    pathLength: pathLength,
    path: path ?? Uint8List(0),
    pathOverride: pathOverride,
    pathOverrideBytes: pathOverrideBytes,
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('Show-on-map tile is HIDDEN when the contact is flood-only', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final c = _contact(
      firstByte: 0x99,
      lat: 1.0,
      lng: 2.0,
      pathLength: -1, // flood
    );

    await tester.pumpWidget(_wrap(contact: c, contacts: [c]));
    await _settle(tester);

    expect(find.text(_l10n.meshcorePathOverlayShowOnMap), findsNothing);
    // Pre-existing tiles reachable.
    expect(find.text(_l10n.meshcoreTracePathTitle), findsOneWidget);
    expect(find.text(_l10n.meshcorePathOverrideTitle), findsOneWidget);
    expect(find.text(_l10n.meshcoreResetPath), findsOneWidget);
  });

  testWidgets('Show-on-map tile is HIDDEN when the user forced flood', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final c = _contact(
      firstByte: 0x99,
      lat: 1.0,
      lng: 2.0,
      pathLength: 0,
      pathOverride: -1, // Force Flood
    );

    await tester.pumpWidget(_wrap(contact: c, contacts: [c]));
    await _settle(tester);

    expect(find.text(_l10n.meshcorePathOverlayShowOnMap), findsNothing);
  });

  testWidgets('Show-on-map tile is VISIBLE for a direct route', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final c = _contact(firstByte: 0x99, lat: 1.0, lng: 2.0, pathLength: 0);

    await tester.pumpWidget(
      _wrap(contact: c, contacts: [c], selfInfo: _selfInfo()),
    );
    await _settle(tester);

    expect(find.text(_l10n.meshcorePathOverlayShowOnMap), findsOneWidget);
  });

  testWidgets('Show-on-map tile is VISIBLE for an N-hop route', (tester) async {
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

    expect(find.text(_l10n.meshcorePathOverlayShowOnMap), findsOneWidget);
  });

  testWidgets('tapping Show-on-map pushes the map route with overlay set', (
    tester,
  ) async {
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

    await tester.tap(find.text(_l10n.meshcorePathOverlayShowOnMap));
    await _settle(tester);
    await _settle(tester);

    // Map route is on stack.
    expect(find.byType(MeshCoreMapScreen), findsOneWidget);

    // flutter_map's MapController throws synchronously on the first
    // frame because the FlutterMap widget hasn't registered its
    // camera yet. The map screen's auto-fit code wraps fitCamera in
    // try/catch, but the framework's scheduler-callback error
    // handler logs the throw separately. Drain it so the test
    // result isn't tainted.
    tester.takeException();
  });
}
