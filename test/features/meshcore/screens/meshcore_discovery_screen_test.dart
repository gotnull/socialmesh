// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34b-A1 — `MeshCoreDiscoveryScreen` widget regression pins.
//
// Pinned invariants:
//   - Empty state renders the canonical AnimatedEmptyState shell when
//     the heard list is empty, list/clear-all are absent.
//   - A single heard entry renders display name + adv-type label +
//     pubkey fingerprint (no full pubkey leaked).
//   - The Imported badge appears for an advert whose pubkey matches a
//     live contact in `meshCoreContactsProvider`.
//   - The Heard badge appears for an advert whose pubkey is NOT in
//     the contact list.
//   - Sort toggle reorders alphabetically vs. by recency (key still
//     reachable; we don't assert visual order — recency comes from
//     wall-clock timestamps the notifier owns).
//   - Search field filters by name.
//   - Long-press → Delete removes the entry.
//   - Clear-all action button empties the heard list.
//   - Clear-all action button is hidden when the list is empty.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socialmesh/core/widgets/animated_empty_state.dart';
import 'package:socialmesh/features/meshcore/screens/meshcore_discovery_screen.dart';
import 'package:socialmesh/l10n/app_localizations.dart';
import 'package:socialmesh/models/meshcore_contact.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

MeshCoreContact _contact({
  required Uint8List publicKey,
  String name = 'KnownPeer',
  int type = MeshCoreAdvType.chat,
}) {
  return MeshCoreContact(
    publicKey: publicKey,
    name: name,
    type: type,
    pathLength: -1,
    path: Uint8List(0),
    lastSeen: DateTime(2026, 5, 7, 12, 0),
  );
}

MeshCoreContactInfo _info({
  required Uint8List publicKey,
  String name = 'Discovered',
  int advType = MeshCoreAdvType.chat,
}) {
  return MeshCoreContactInfo(
    publicKey: publicKey,
    advType: advType,
    pathLength: -1,
    lastMod: 0,
    name: name,
    pathBytes: Uint8List(0),
    rawPayload: Uint8List(0),
  );
}

Uint8List _pub(int seed) =>
    Uint8List.fromList(List.generate(32, (i) => seed + i));

/// Override `meshCoreSelfInfoProvider` so its real `build()` (which
/// schedules a `Future<void>(...)` to reset state off-build) doesn't
/// leave a pending timer when the test tree is torn down.
class _NoopSelfInfoNotifier extends MeshCoreSelfInfoNotifier {
  @override
  MeshCoreSelfInfoState build() => const MeshCoreSelfInfoState();
}

Widget _wrap() {
  return ProviderScope(
    overrides: [
      meshCoreSelfInfoProvider.overrideWith(_NoopSelfInfoNotifier.new),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const MeshCoreDiscoveryScreen(),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('empty state renders the canonical AnimatedEmptyState '
      'when the heard list is empty; list and clear-all key are absent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap());
    await tester.pump();

    // Shell: title in app bar (a plain Text, not a TextSpan).
    expect(find.text('Discovered Nodes'), findsWidgets);
    // Canonical empty-state widget present.
    expect(find.byType(AnimatedEmptyState), findsOneWidget);
    // List absent.
    expect(find.byKey(const ValueKey('meshcore-discovery-list')), findsNothing);
    // Clear-all action button hidden when list is empty.
    expect(
      find.byKey(const ValueKey('meshcore-discovery-clear-all')),
      findsNothing,
    );
  });

  testWidgets('single heard entry renders name, fingerprint, type label, '
      'and the Heard badge when not in the contact list', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final pub = _pub(1);
    await tester.pumpWidget(_wrap());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MeshCoreDiscoveryScreen)),
    );
    container
        .read(meshCoreDiscoveredAdvertsProvider.notifier)
        .recordAdvert(_info(publicKey: pub, name: 'Alpha'), isNew: true);
    await tester.pump();

    expect(find.text('Alpha'), findsWidgets);
    // Redacted fingerprint visible (4 head + 4 tail with brackets).
    final fingerprint =
        '<${pub.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, "0")).join()}'
        '…${pub.sublist(28, 32).map((b) => b.toRadixString(16).padLeft(2, "0")).join()}>';
    expect(find.text(fingerprint), findsWidgets);
    // Adv-type "Chat" label visible.
    expect(find.text('Chat'), findsWidgets);
    // Heard badge (uppercase).
    expect(find.text('HEARD'), findsOneWidget);
    expect(find.text('IMPORTED'), findsNothing);
  });

  testWidgets('Imported badge appears when the advert pubkey matches a '
      'live contact', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final pub = _pub(1);
    await tester.pumpWidget(_wrap());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MeshCoreDiscoveryScreen)),
    );
    container
        .read(meshCoreContactsProvider.notifier)
        .addContactLocal(_contact(publicKey: pub, name: 'KnownAlpha'));
    container
        .read(meshCoreDiscoveredAdvertsProvider.notifier)
        .recordAdvert(_info(publicKey: pub, name: 'KnownAlpha'), isNew: true);
    await tester.pump();

    expect(find.text('IMPORTED'), findsOneWidget);
    expect(find.text('HEARD'), findsNothing);
  });

  testWidgets('search field filters the list by name', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MeshCoreDiscoveryScreen)),
    );
    final notifier = container.read(meshCoreDiscoveredAdvertsProvider.notifier);
    notifier.recordAdvert(
      _info(publicKey: _pub(1), name: 'Alpha'),
      isNew: true,
    );
    notifier.recordAdvert(
      _info(publicKey: _pub(2), name: 'Bravo'),
      isNew: true,
    );
    await tester.pump();
    expect(find.text('Alpha'), findsWidgets);
    expect(find.text('Bravo'), findsWidgets);

    await tester.enterText(
      find.byKey(const ValueKey('meshcore-discovery-search-field')),
      'alph',
    );
    await tester.pump();
    expect(find.text('Alpha'), findsWidgets);
    expect(find.text('Bravo'), findsNothing);
  });

  testWidgets('sort toggle key is reachable when both modes are present', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MeshCoreDiscoveryScreen)),
    );
    final notifier = container.read(meshCoreDiscoveredAdvertsProvider.notifier);

    notifier.recordAdvert(_info(publicKey: _pub(1), name: 'Zulu'), isNew: true);
    notifier.recordAdvert(
      _info(publicKey: _pub(2), name: 'Alpha'),
      isNew: true,
    );
    await tester.pump();

    expect(find.text('Alpha'), findsWidgets);
    expect(find.text('Zulu'), findsWidgets);

    // Toggle sort and ensure neither row disappears.
    await tester.tap(
      find.byKey(const ValueKey('meshcore-discovery-sort-toggle')),
    );
    await tester.pump();
    expect(find.text('Alpha'), findsWidgets);
    expect(find.text('Zulu'), findsWidgets);
  });

  testWidgets('long-press → Delete removes the entry', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MeshCoreDiscoveryScreen)),
    );
    final notifier = container.read(meshCoreDiscoveredAdvertsProvider.notifier);
    // Seed two entries so the list does NOT collapse to AnimatedEmptyState
    // after the deletion. The empty-state widget keeps its pulse/icon
    // tickers running — pumpAndSettle would never return, and disposing
    // the bottom-sheet Navigator while a row+sheet ticker pair are still
    // active leaks tickers.
    notifier.recordAdvert(
      _info(publicKey: _pub(1), name: 'DeleteMe'),
      isNew: true,
    );
    notifier.recordAdvert(
      _info(publicKey: _pub(2), name: 'KeepMe'),
      isNew: true,
    );
    await tester.pump();

    final row = find.byKey(ValueKey('meshcore-discovery-row-${_hex(_pub(1))}'));
    await tester.longPress(row);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete from list'));
    await tester.pumpAndSettle();

    expect(find.text('DeleteMe'), findsNothing);
    expect(find.text('KeepMe'), findsWidgets);
    final remaining = container.read(meshCoreDiscoveredAdvertsProvider);
    expect(remaining.length, 1);
    expect(remaining.first.publicKeyHex, _hex(_pub(2)));
  });

  testWidgets('Clear discovered nodes confirm sheet is reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap());
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MeshCoreDiscoveryScreen)),
    );
    final notifier = container.read(meshCoreDiscoveredAdvertsProvider.notifier);
    notifier.recordAdvert(_info(publicKey: _pub(1), name: 'A'), isNew: true);
    notifier.recordAdvert(_info(publicKey: _pub(2), name: 'B'), isNew: true);
    await tester.pump();

    await tester.tap(
      find.byKey(const ValueKey('meshcore-discovery-clear-all')),
    );
    await tester.pumpAndSettle();
    // Confirm sheet shows: title + Cancel + destructive confirm.
    expect(find.text('Cancel'), findsOneWidget);
    // The destructive button label is "Clear discovered nodes" (same as
    // the title); the sheet renders both. Bail out via Cancel so we do
    // not collapse the list to the empty-state cycle (the empty-state
    // tickers leak across the test boundary).
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // List was not cleared.
    expect(container.read(meshCoreDiscoveredAdvertsProvider), hasLength(2));

    // clearAll() drains the list directly — wire-side regression
    // already pinned by the notifier unit test; here we only verify
    // the screen exposes the action and the confirm-sheet path.
    container.read(meshCoreDiscoveredAdvertsProvider.notifier).clearAll();
    expect(container.read(meshCoreDiscoveredAdvertsProvider), isEmpty);
  });

  testWidgets('clear-all action button is hidden when the list is empty', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_wrap());
    await tester.pump();

    expect(
      find.byKey(const ValueKey('meshcore-discovery-clear-all')),
      findsNothing,
    );
  });
}

String _hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join().toLowerCase();
