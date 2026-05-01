// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:socialmesh/features/nodedex/map/nodedex_map_pin.dart';
import 'package:socialmesh/features/nodedex/map/nodedex_map_pins_provider.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/providers/nodedex_providers.dart';

NodeDexEntry _entry({
  required int nodeNum,
  required List<EncounterRecord> encounters,
  int encounterCount = 1,
  String? lastKnownName,
  NodeSocialTag? socialTag,
}) {
  // For test purposes, fix firstSeen / lastSeen to bracket the
  // encounter timestamps so the entry is internally consistent.
  final firstSeen = encounters.isNotEmpty
      ? encounters.first.timestamp
      : DateTime(2026, 1, 1);
  final lastSeen = encounters.isNotEmpty
      ? encounters.last.timestamp
      : DateTime(2026, 1, 1);
  return NodeDexEntry(
    nodeNum: nodeNum,
    firstSeen: firstSeen,
    lastSeen: lastSeen,
    encounterCount: encounterCount,
    encounters: encounters,
    lastKnownName: lastKnownName,
    socialTag: socialTag,
  );
}

ProviderContainer _container(Map<int, NodeDexEntry> entries, {DateTime? now}) {
  return ProviderContainer(
    overrides: [
      nodeDexProvider.overrideWith(_StubNodeDexNotifier.new),
      _stubEntriesProvider.overrideWithValue(entries),
      if (now != null) nodedexMapNowProvider.overrideWithValue(now),
    ],
  );
}

/// Pluggable seam — the real `nodeDexProvider` reads SQLite during
/// `build()`. Tests replace the notifier with one that emits a
/// preset map of entries (read from `_stubEntriesProvider`).
class _StubNodeDexNotifier extends NodeDexNotifier {
  @override
  Map<int, NodeDexEntry> build() {
    return ref.watch(_stubEntriesProvider);
  }
}

final _stubEntriesProvider = Provider<Map<int, NodeDexEntry>>(
  (_) => const <int, NodeDexEntry>{},
);

void main() {
  group('nodedexMapPinsProvider', () {
    test('middle encounter has GPS, newest does not — pin uses middle, '
        'positionedAt < lastEncounterAt', () {
      final container = _container({
        1: _entry(
          nodeNum: 1,
          encounterCount: 3,
          lastKnownName: 'alpha',
          encounters: [
            EncounterRecord(timestamp: DateTime(2026, 4, 20, 10)),
            EncounterRecord(
              timestamp: DateTime(2026, 4, 22, 14),
              latitude: 37.0,
              longitude: -122.0,
            ),
            EncounterRecord(timestamp: DateTime(2026, 4, 24, 9)),
          ],
        ),
      });
      addTearDown(container.dispose);

      final pins = container.read(nodedexMapPinsProvider);
      expect(pins, hasLength(1));
      final pin = pins.single;
      expect(pin.nodeNum, 1);
      expect(pin.position.latitude, 37.0);
      expect(pin.position.longitude, -122.0);
      expect(pin.positionedAt, DateTime(2026, 4, 22, 14));
      expect(pin.lastEncounterAt, DateTime(2026, 4, 24, 9));
      expect(pin.hasNewerEncounterThanPosition, isTrue);
    });

    test('all encounters have GPS — positionedAt == lastEncounterAt', () {
      final container = _container({
        1: _entry(
          nodeNum: 1,
          encounterCount: 2,
          encounters: [
            EncounterRecord(
              timestamp: DateTime(2026, 4, 20, 10),
              latitude: 1,
              longitude: 1,
            ),
            EncounterRecord(
              timestamp: DateTime(2026, 4, 22, 14),
              latitude: 2,
              longitude: 2,
            ),
          ],
        ),
      });
      addTearDown(container.dispose);

      final pin = container.read(nodedexMapPinsProvider).single;
      expect(pin.positionedAt, DateTime(2026, 4, 22, 14));
      expect(pin.lastEncounterAt, DateTime(2026, 4, 22, 14));
      expect(pin.hasNewerEncounterThanPosition, isFalse);
    });

    test('entry with all GPS-less encounters is filtered out', () {
      final container = _container({
        1: _entry(
          nodeNum: 1,
          encounters: [
            EncounterRecord(timestamp: DateTime(2026, 4, 20, 10)),
            EncounterRecord(timestamp: DateTime(2026, 4, 21, 10)),
          ],
        ),
      });
      addTearDown(container.dispose);

      expect(container.read(nodedexMapPinsProvider), isEmpty);
    });

    test('entry with empty encounters list is filtered out', () {
      final container = _container({
        1: _entry(nodeNum: 1, encounters: const []),
      });
      addTearDown(container.dispose);

      expect(container.read(nodedexMapPinsProvider), isEmpty);
    });

    test('empty NodeDex map returns empty list', () {
      final container = _container(const {});
      addTearDown(container.dispose);

      expect(container.read(nodedexMapPinsProvider), isEmpty);
    });

    test('multiple entries are sorted ascending by positionedAt '
        '(freshest paints last → on top)', () {
      final container = _container({
        1: _entry(
          nodeNum: 1,
          encounters: [
            EncounterRecord(
              timestamp: DateTime(2026, 4, 22),
              latitude: 1,
              longitude: 1,
            ),
          ],
        ),
        2: _entry(
          nodeNum: 2,
          encounters: [
            EncounterRecord(
              timestamp: DateTime(2026, 4, 20),
              latitude: 2,
              longitude: 2,
            ),
          ],
        ),
        3: _entry(
          nodeNum: 3,
          encounters: [
            EncounterRecord(
              timestamp: DateTime(2026, 4, 24),
              latitude: 3,
              longitude: 3,
            ),
          ],
        ),
      });
      addTearDown(container.dispose);

      final order = container
          .read(nodedexMapPinsProvider)
          .map((p) => p.nodeNum)
          .toList();
      expect(order, [2, 1, 3]); // oldest first, newest last
    });

    test('staleness uses injected nodedexMapNowProvider clock', () {
      final base = DateTime(2026, 4, 24, 12);
      final container = _container({
        1: _entry(
          nodeNum: 1,
          encounters: [
            EncounterRecord(
              timestamp: base.subtract(const Duration(days: 8)),
              latitude: 1,
              longitude: 1,
            ),
          ],
        ),
        2: _entry(
          nodeNum: 2,
          encounters: [
            EncounterRecord(
              timestamp: base.subtract(const Duration(days: 6)),
              latitude: 2,
              longitude: 2,
            ),
          ],
        ),
      }, now: base);
      addTearDown(container.dispose);

      final pins = {
        for (final p in container.read(nodedexMapPinsProvider)) p.nodeNum: p,
      };
      final now = container.read(nodedexMapNowProvider);
      expect(pins[1]!.isStaleAt(now), isTrue, reason: '8 days > 7-day cutoff');
      expect(
        pins[2]!.isStaleAt(now),
        isFalse,
        reason: '6 days <= 7-day cutoff',
      );
    });

    test('staleness 7-day boundary is strict greater-than (exactly 7 days '
        'is NOT stale)', () {
      final base = DateTime(2026, 4, 24, 12);
      final pin = NodeDexMapPin(
        nodeNum: 1,
        position: LatLng(0, 0),
        positionedAt: base.subtract(const Duration(days: 7)),
        lastEncounterAt: base.subtract(const Duration(days: 7)),
        encounterCount: 1,
      );
      expect(pin.isStaleAt(base), isFalse);

      final stalerPin = NodeDexMapPin(
        nodeNum: 1,
        position: LatLng(0, 0),
        positionedAt: base.subtract(const Duration(days: 7, seconds: 1)),
        lastEncounterAt: base.subtract(const Duration(days: 7, seconds: 1)),
        encounterCount: 1,
      );
      // inDays truncates seconds — still 7 days, not 8
      expect(stalerPin.isStaleAt(base), isFalse);

      final staleEnoughPin = NodeDexMapPin(
        nodeNum: 1,
        position: LatLng(0, 0),
        positionedAt: base.subtract(const Duration(days: 8)),
        lastEncounterAt: base.subtract(const Duration(days: 8)),
        encounterCount: 1,
      );
      expect(staleEnoughPin.isStaleAt(base), isTrue);
    });
  });
}
