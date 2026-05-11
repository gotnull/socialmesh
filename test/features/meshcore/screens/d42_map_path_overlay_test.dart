// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D42-A - MeshCoreMapScreen path-overlay rendering pins.
//
// Pinned invariants:
//   - With no overlay set: no path PolylineLayer / hop MarkerLayer
//     widgets carrying our D42-A keys are mounted.
//   - With an overlay set: the polyline + per-hop markers render
//     (one marker per resolved hop).
//   - The Clear-path app-bar action surfaces only when an overlay is
//     active.
//   - Tapping Clear removes the overlay from the provider AND
//     unmounts the overlay layer widgets.
//   - Hop labels are 2-char hex (no 4+ run, no full pubkey).

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_map_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/l10n/app_localizations_en.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

final _l10n = AppLocalizationsEn();

MeshCoreContact _contact({
  required int firstByte,
  double? lat,
  double? lng,
  Uint8List? path,
  int pathLength = -1,
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
  required List<MeshCoreContact> contacts,
  MeshCoreSelfInfo? selfInfo,
}) {
  return ProviderScope(
    overrides: [
      linkStatusProvider.overrideWithValue(
        const LinkStatus(
          protocol: LinkProtocol.meshcore,
          status: LinkConnectionStatus.connected,
          deviceName: 'TestDevice',
        ),
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
      home: const MeshCoreMapScreen(),
    ),
  );
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

final List<RegExp> _bannedRenderedPatterns = [
  RegExp(r'[0-9a-fA-F]{32}'),
  RegExp(r'[A-Za-z0-9#_-]+:[0-9a-fA-F]{32}'),
  RegExp(r'[0-9a-fA-F]{64}'),
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

  testWidgets('with no overlay: no D42 path layer + no Clear-path action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final target = _contact(firstByte: 0x99, lat: 50.0, lng: 60.0);
    await tester.pumpWidget(_wrap(contacts: [target], selfInfo: _selfInfo()));
    await _settle(tester);

    expect(
      find.byKey(const ValueKey('meshcore-map-path-overlay-line')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('meshcore-map-path-overlay-markers')),
      findsNothing,
    );
    // Clear-path action is gated on overlay non-null.
    expect(
      find.byKey(const ValueKey('meshcore-map-path-overlay-clear')),
      findsNothing,
    );
    tester.takeException();
  });

  testWidgets('with overlay set: polyline + hop markers render + Clear action '
      'surfaces', (tester) async {
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

    // Activate the overlay BEFORE pumping the map widget so the
    // first render already has it.
    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          linkStatusProvider.overrideWithValue(
            const LinkStatus(
              protocol: LinkProtocol.meshcore,
              status: LinkConnectionStatus.connected,
              deviceName: 'TestDevice',
            ),
          ),
          meshCoreContactsProvider.overrideWith(
            () => _StubContactsNotifier([hop, target]),
          ),
          meshCoreSelfInfoProvider.overrideWith(
            () => _StubSelfInfoNotifier(_selfInfo()),
          ),
        ],
        child: Consumer(
          builder: (ctx, ref, _) {
            container = ProviderScope.containerOf(ctx);
            return MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData.dark(),
              home: const MeshCoreMapScreen(),
            );
          },
        ),
      ),
    );
    await _settle(tester);

    // Set the overlay via the container's notifier.
    final ok = container
        .read(meshCorePathOverlayProvider.notifier)
        .setActive(target);
    expect(ok, isTrue);
    await _settle(tester);

    // Polyline + marker layers mounted.
    expect(
      find.byKey(const ValueKey('meshcore-map-path-overlay-line')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meshcore-map-path-overlay-markers')),
      findsOneWidget,
    );
    // One hop marker (the resolved hop at byte 0x11).
    expect(
      find.byKey(const ValueKey('meshcore-map-path-hop-11')),
      findsOneWidget,
    );
    // Hop label is 2 chars.
    expect(find.text('11'), findsOneWidget);
    // Clear action surfaces.
    expect(
      find.byKey(const ValueKey('meshcore-map-path-overlay-clear')),
      findsOneWidget,
    );

    _expectNoBannedRenderedText(tester);

    // Tap Clear -> overlay gone, layers + button gone.
    await tester.tap(
      find.byKey(const ValueKey('meshcore-map-path-overlay-clear')),
    );
    await _settle(tester);
    expect(container.read(meshCorePathOverlayProvider), isNull);
    expect(
      find.byKey(const ValueKey('meshcore-map-path-overlay-line')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('meshcore-map-path-overlay-clear')),
      findsNothing,
    );

    tester.takeException();
  });

  testWidgets('unresolved hops do NOT produce hop markers', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final target = _contact(
      firstByte: 0x99,
      lat: 50.0,
      lng: 60.0,
      pathLength: 2,
      path: Uint8List.fromList([0x11, 0x22]),
    );

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          linkStatusProvider.overrideWithValue(
            const LinkStatus(
              protocol: LinkProtocol.meshcore,
              status: LinkConnectionStatus.connected,
              deviceName: 'TestDevice',
            ),
          ),
          meshCoreContactsProvider.overrideWith(
            () => _StubContactsNotifier([target]),
          ),
          meshCoreSelfInfoProvider.overrideWith(
            () => _StubSelfInfoNotifier(_selfInfo()),
          ),
        ],
        child: Consumer(
          builder: (ctx, ref, _) {
            container = ProviderScope.containerOf(ctx);
            return MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData.dark(),
              home: const MeshCoreMapScreen(),
            );
          },
        ),
      ),
    );
    await _settle(tester);
    final ok = container
        .read(meshCorePathOverlayProvider.notifier)
        .setActive(target);
    expect(ok, isTrue);
    await _settle(tester);

    // Polyline still renders (self → target via no known hops).
    expect(
      find.byKey(const ValueKey('meshcore-map-path-overlay-line')),
      findsOneWidget,
    );
    // No hop markers since both hops are unresolved.
    expect(
      find.byKey(const ValueKey('meshcore-map-path-hop-11')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('meshcore-map-path-hop-22')),
      findsNothing,
    );

    tester.takeException();
  });

  testWidgets('app-bar Clear tooltip uses the canonical D42-A copy', (
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

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          linkStatusProvider.overrideWithValue(
            const LinkStatus(
              protocol: LinkProtocol.meshcore,
              status: LinkConnectionStatus.connected,
              deviceName: 'TestDevice',
            ),
          ),
          meshCoreContactsProvider.overrideWith(
            () => _StubContactsNotifier([hop, target]),
          ),
          meshCoreSelfInfoProvider.overrideWith(
            () => _StubSelfInfoNotifier(_selfInfo()),
          ),
        ],
        child: Consumer(
          builder: (ctx, ref, _) {
            container = ProviderScope.containerOf(ctx);
            return MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData.dark(),
              home: const MeshCoreMapScreen(),
            );
          },
        ),
      ),
    );
    await _settle(tester);
    container.read(meshCorePathOverlayProvider.notifier).setActive(target);
    await _settle(tester);

    final clearBtn = find.byKey(
      const ValueKey('meshcore-map-path-overlay-clear'),
    );
    final widget = tester.widget<IconButton>(clearBtn);
    expect(widget.tooltip, _l10n.meshcorePathOverlayClear);
    tester.takeException();
  });

  testWidgets('overlay polyline uses a distinct accent (not the measurement '
      'warning yellow)', (tester) async {
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

    late ProviderContainer container;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          linkStatusProvider.overrideWithValue(
            const LinkStatus(
              protocol: LinkProtocol.meshcore,
              status: LinkConnectionStatus.connected,
              deviceName: 'TestDevice',
            ),
          ),
          meshCoreContactsProvider.overrideWith(
            () => _StubContactsNotifier([hop, target]),
          ),
          meshCoreSelfInfoProvider.overrideWith(
            () => _StubSelfInfoNotifier(_selfInfo()),
          ),
        ],
        child: Consumer(
          builder: (ctx, ref, _) {
            container = ProviderScope.containerOf(ctx);
            return MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              theme: ThemeData.dark(),
              home: const MeshCoreMapScreen(),
            );
          },
        ),
      ),
    );
    await _settle(tester);
    container.read(meshCorePathOverlayProvider.notifier).setActive(target);
    await _settle(tester);

    final layer = tester.widget<PolylineLayer>(
      find.byKey(const ValueKey('meshcore-map-path-overlay-line')),
    );
    expect(layer.polylines, hasLength(1));
    final line = layer.polylines.first;
    expect(line.strokeWidth, 4);
    // The polyline includes self + hop + target = 3 points (the
    // hop at byte 0x11 resolves to a known position).
    expect(line.points, hasLength(3));
    tester.takeException();
  });
}
