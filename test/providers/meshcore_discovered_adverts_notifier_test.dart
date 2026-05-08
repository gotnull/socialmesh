// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34b-A1 — `MeshCoreDiscoveredAdvertsNotifier` regression pins.
//
// Pinned invariants:
//   - recordAdvert adds new entries with full info from a 0x8A push.
//   - duplicate recordAdvert dedupes by pubkey, updates metadata, and
//     bumps lastHeard while preserving firstHeard.
//   - cap at MeshCoreDiscoveredAdvertsNotifier.maxEntries (100) — oldest
//     `lastHeard` evicted first.
//   - self-pubkey is filtered out (matched against
//     `meshCoreSelfInfoProvider.selfInfo.pubKey`).
//   - bumpLastHeard updates an existing entry's lastHeard without
//     mutating other fields.
//   - bumpLastHeard for an unknown pubkey creates a minimal stub
//     (`hasFullInfo = false`, empty name, null advType) so the
//     re-heard ping still surfaces in the recency feed.
//   - remove deletes only the requested entry; idempotent on miss.
//   - clearAll empties the list.
//   - state is always sorted by lastHeard descending and is an
//     unmodifiable view.

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_messages.dart';

MeshCoreContactInfo _info({
  required Uint8List pubKey,
  String name = 'Alpha',
  int advType = 1,
}) {
  return MeshCoreContactInfo(
    publicKey: pubKey,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MeshCoreDiscoveredAdvertsNotifier (D34b-A1)', () {
    test('initial state is empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(meshCoreDiscoveredAdvertsProvider);
      expect(state, isEmpty);
    });

    test('recordAdvert adds a new entry with full info from a 0x8A push', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        meshCoreDiscoveredAdvertsProvider.notifier,
      );
      final info = _info(pubKey: _pub(1), name: 'Alpha', advType: 2);
      notifier.recordAdvert(info, isNew: true);

      final state = container.read(meshCoreDiscoveredAdvertsProvider);
      expect(state, hasLength(1));
      expect(state.first.name, 'Alpha');
      expect(state.first.advType, 2);
      expect(state.first.hasFullInfo, isTrue);
    });

    test('duplicate recordAdvert dedupes by pubkey, updates metadata, '
        'bumps lastHeard, preserves firstHeard', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        meshCoreDiscoveredAdvertsProvider.notifier,
      );
      final pub = _pub(1);
      notifier.recordAdvert(
        _info(pubKey: pub, name: 'Alpha', advType: 1),
        isNew: true,
      );
      final firstHeardSnapshot = container
          .read(meshCoreDiscoveredAdvertsProvider)
          .first
          .firstHeard;
      // Yield to ensure DateTime.now() advances a tick before the
      // second recordAdvert call.
      await Future<void>.delayed(const Duration(milliseconds: 1));

      notifier.recordAdvert(
        _info(pubKey: pub, name: 'AlphaPrime', advType: 2),
        isNew: false,
      );
      final state = container.read(meshCoreDiscoveredAdvertsProvider);
      expect(state, hasLength(1), reason: 'must dedupe by pubkey');
      expect(state.first.name, 'AlphaPrime', reason: 'name updated');
      expect(state.first.advType, 2, reason: 'advType updated');
      expect(
        state.first.firstHeard,
        firstHeardSnapshot,
        reason: 'firstHeard preserved across updates',
      );
      expect(
        state.first.lastHeard.isAfter(firstHeardSnapshot) ||
            state.first.lastHeard.isAtSameMomentAs(firstHeardSnapshot),
        isTrue,
        reason: 'lastHeard >= firstHeard',
      );
    });

    test('cap at maxEntries (100) evicts oldest lastHeard first', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        meshCoreDiscoveredAdvertsProvider.notifier,
      );

      // Fill to the cap with distinct pubkeys; the test runs fast so we
      // sprinkle micro-delays to ensure lastHeard ordering is monotone.
      for (var i = 0; i < MeshCoreDiscoveredAdvertsNotifier.maxEntries; i++) {
        // Use seeds that wrap into [0..255] safely.
        final pub = Uint8List.fromList(
          List.generate(32, (k) => (i + k) & 0xFF),
        );
        notifier.recordAdvert(
          _info(pubKey: pub, name: 'N$i', advType: 1),
          isNew: true,
        );
      }
      expect(
        container.read(meshCoreDiscoveredAdvertsProvider),
        hasLength(MeshCoreDiscoveredAdvertsNotifier.maxEntries),
      );

      // Yield so the next recordAdvert's `now` is later than every
      // existing `lastHeard` — guarantees the oldest ([0]) is the
      // eviction target.
      await Future<void>.delayed(const Duration(milliseconds: 2));

      // First-seeded entry is the one with the oldest lastHeard.
      final firstEntryHex = Uint8List.fromList(
        List.generate(32, (k) => k & 0xFF),
      ).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      // Add a 101st distinct entry — should evict the oldest.
      final extra = Uint8List.fromList(List.generate(32, (k) => 0xC0 + k));
      notifier.recordAdvert(
        _info(pubKey: extra, name: 'overflow', advType: 1),
        isNew: true,
      );

      final state = container.read(meshCoreDiscoveredAdvertsProvider);
      expect(
        state,
        hasLength(MeshCoreDiscoveredAdvertsNotifier.maxEntries),
        reason: 'cap holds at $maxEntries',
      );
      expect(
        state.any((e) => e.publicKeyHex == firstEntryHex),
        isFalse,
        reason: 'oldest lastHeard entry must have been evicted',
      );
      expect(
        state.first.name,
        'overflow',
        reason: 'newest entry sorts to head of state list',
      );
    });

    test('self pubkey filter: when meshCoreSelfInfoProvider has a known '
        'self pubkey, recordAdvert and bumpLastHeard for that pubkey '
        'are silent no-ops', () {
      final selfPub = _pub(0xAA);
      final container = ProviderContainer(
        overrides: [
          meshCoreSelfInfoProvider.overrideWith(
            () => _StubSelfInfoNotifier.withSelf(selfPub),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(
        meshCoreDiscoveredAdvertsProvider.notifier,
      );

      notifier.recordAdvert(
        _info(pubKey: selfPub, name: 'me', advType: 1),
        isNew: true,
      );
      notifier.bumpLastHeard(selfPub);

      expect(
        container.read(meshCoreDiscoveredAdvertsProvider),
        isEmpty,
        reason: 'self pubkey must be filtered',
      );
    });

    test(
      'bumpLastHeard updates an existing entry without changing other fields',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final notifier = container.read(
          meshCoreDiscoveredAdvertsProvider.notifier,
        );
        final pub = _pub(1);
        notifier.recordAdvert(
          _info(pubKey: pub, name: 'Alpha', advType: 2),
          isNew: true,
        );
        final before = container.read(meshCoreDiscoveredAdvertsProvider).first;

        await Future<void>.delayed(const Duration(milliseconds: 1));
        notifier.bumpLastHeard(pub);
        final after = container.read(meshCoreDiscoveredAdvertsProvider).first;

        expect(after.name, 'Alpha');
        expect(after.advType, 2);
        expect(after.hasFullInfo, isTrue);
        expect(after.firstHeard, before.firstHeard);
        expect(after.lastHeard.isAfter(before.lastHeard), isTrue);
      },
    );

    test('bumpLastHeard for an unknown pubkey creates a minimal stub '
        '(hasFullInfo=false, empty name, null advType)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        meshCoreDiscoveredAdvertsProvider.notifier,
      );
      final pub = _pub(0x70);
      notifier.bumpLastHeard(pub);

      final state = container.read(meshCoreDiscoveredAdvertsProvider);
      expect(state, hasLength(1));
      expect(state.first.hasFullInfo, isFalse);
      expect(state.first.name, '');
      expect(state.first.advType, isNull);
    });

    test('bumpLastHeard ignores too-short pubkeys (defensive)', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        meshCoreDiscoveredAdvertsProvider.notifier,
      );
      notifier.bumpLastHeard(Uint8List.fromList([0x01, 0x02, 0x03]));
      expect(container.read(meshCoreDiscoveredAdvertsProvider), isEmpty);
    });

    test('remove deletes only the requested entry; idempotent on miss', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        meshCoreDiscoveredAdvertsProvider.notifier,
      );
      final a = _pub(1);
      final b = _pub(2);
      notifier.recordAdvert(_info(pubKey: a, name: 'A'), isNew: true);
      notifier.recordAdvert(_info(pubKey: b, name: 'B'), isNew: true);
      expect(container.read(meshCoreDiscoveredAdvertsProvider), hasLength(2));

      final aHex = a
          .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
          .join();
      notifier.remove(aHex);
      final remaining = container.read(meshCoreDiscoveredAdvertsProvider);
      expect(remaining, hasLength(1));
      expect(remaining.first.name, 'B');

      // Idempotent: removing again is a silent no-op.
      notifier.remove(aHex);
      expect(container.read(meshCoreDiscoveredAdvertsProvider), hasLength(1));
    });

    test('clearAll empties the list', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        meshCoreDiscoveredAdvertsProvider.notifier,
      );
      notifier.recordAdvert(_info(pubKey: _pub(1), name: 'A'), isNew: true);
      notifier.recordAdvert(_info(pubKey: _pub(2), name: 'B'), isNew: true);
      expect(container.read(meshCoreDiscoveredAdvertsProvider), hasLength(2));

      notifier.clearAll();
      expect(container.read(meshCoreDiscoveredAdvertsProvider), isEmpty);
    });

    test('state is sorted by lastHeard descending', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        meshCoreDiscoveredAdvertsProvider.notifier,
      );
      notifier.recordAdvert(_info(pubKey: _pub(1), name: 'older'), isNew: true);
      await Future<void>.delayed(const Duration(milliseconds: 2));
      notifier.recordAdvert(
        _info(pubKey: _pub(2), name: 'middle'),
        isNew: true,
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      notifier.recordAdvert(
        _info(pubKey: _pub(3), name: 'newest'),
        isNew: true,
      );

      final state = container.read(meshCoreDiscoveredAdvertsProvider);
      expect(state.map((e) => e.name).toList(), ['newest', 'middle', 'older']);
    });

    test('state is unmodifiable — callers cannot mutate the feed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(
        meshCoreDiscoveredAdvertsProvider.notifier,
      );
      notifier.recordAdvert(_info(pubKey: _pub(1)), isNew: true);
      final state = container.read(meshCoreDiscoveredAdvertsProvider);
      expect(() => state.add(state.first), throwsUnsupportedError);
    });
  });
}

const int maxEntries = MeshCoreDiscoveredAdvertsNotifier.maxEntries;

/// Test stub for `meshCoreSelfInfoProvider`. Builds an immediate
/// loaded state with a fixed pubkey so the `_isSelfPubkey` branch in
/// the notifier fires deterministically.
class _StubSelfInfoNotifier extends MeshCoreSelfInfoNotifier {
  _StubSelfInfoNotifier();

  factory _StubSelfInfoNotifier.withSelf(Uint8List selfPubKey) {
    return _StubSelfInfoNotifier().._self = selfPubKey;
  }

  Uint8List? _self;

  @override
  MeshCoreSelfInfoState build() {
    final self = _self;
    if (self == null) return const MeshCoreSelfInfoState();
    return MeshCoreSelfInfoState.loaded(
      MeshCoreSelfInfo(
        pubKey: self,
        nodeName: 'self',
        advType: 1,
        txPowerDbm: 0,
        maxLoraTxPower: 0,
        rawPayload: Uint8List(0),
      ),
    );
  }
}
