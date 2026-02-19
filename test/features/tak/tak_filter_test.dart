// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/tak/models/tak_event.dart';
import 'package:socialmesh/features/tak/providers/tak_filter_provider.dart';
import 'package:socialmesh/features/tak/utils/cot_affiliation.dart';

/// Helper to create a [TakEvent] with minimal fields for filter testing.
TakEvent _event({
  String uid = 'TEST-001',
  String type = 'a-f-G-U-C',
  String? callsign,
  int? staleUtcMs,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return TakEvent(
    uid: uid,
    type: type,
    callsign: callsign,
    lat: 37.0,
    lon: -122.0,
    timeUtcMs: now - 5000,
    staleUtcMs: staleUtcMs ?? (now + 300000),
    receivedUtcMs: now,
  );
}

/// Applies filter logic matching [filteredTakEventsProvider] without Riverpod.
List<TakEvent> _applyFilter(List<TakEvent> events, TakFilterState filter) {
  var filtered = events;

  if (filter.affiliations.isNotEmpty) {
    filtered = filtered.where((e) {
      final aff = parseAffiliation(e.type);
      return filter.affiliations.contains(aff);
    }).toList();
  }

  switch (filter.staleMode) {
    case TakStaleMode.all:
      break;
    case TakStaleMode.activeOnly:
      filtered = filtered.where((e) => !e.isStale).toList();
    case TakStaleMode.staleOnly:
      filtered = filtered.where((e) => e.isStale).toList();
  }

  if (filter.searchQuery.isNotEmpty) {
    final query = filter.searchQuery.toLowerCase();
    filtered = filtered.where((e) {
      final callsign = (e.callsign ?? '').toLowerCase();
      final uid = e.uid.toLowerCase();
      return callsign.contains(query) || uid.contains(query);
    }).toList();
  }

  return filtered;
}

void main() {
  group('TakFilterState', () {
    test('default state has no active filters', () {
      const state = TakFilterState();
      expect(state.isActive, isFalse);
      expect(state.affiliations, isEmpty);
      expect(state.staleMode, TakStaleMode.all);
      expect(state.searchQuery, isEmpty);
    });

    test('isActive is true when affiliations are set', () {
      const state = TakFilterState(affiliations: {CotAffiliation.friendly});
      expect(state.isActive, isTrue);
    });

    test('isActive is true when staleMode is not all', () {
      const state = TakFilterState(staleMode: TakStaleMode.activeOnly);
      expect(state.isActive, isTrue);
    });

    test('isActive is true when searchQuery is nonempty', () {
      const state = TakFilterState(searchQuery: 'alpha');
      expect(state.isActive, isTrue);
    });

    test('copyWith preserves unmodified fields', () {
      const state = TakFilterState(
        affiliations: {CotAffiliation.hostile},
        staleMode: TakStaleMode.staleOnly,
        searchQuery: 'test',
      );
      final copy = state.copyWith(searchQuery: 'new');
      expect(copy.affiliations, {CotAffiliation.hostile});
      expect(copy.staleMode, TakStaleMode.staleOnly);
      expect(copy.searchQuery, 'new');
    });
  });

  group('Filter logic - affiliation', () {
    final events = [
      _event(uid: 'F1', type: 'a-f-G-U-C', callsign: 'Alpha'),
      _event(uid: 'H1', type: 'a-h-G-U-C', callsign: 'Bravo'),
      _event(uid: 'N1', type: 'a-n-G-U', callsign: 'Charlie'),
      _event(uid: 'U1', type: 'a-u-G', callsign: 'Delta'),
    ];

    test('empty affiliations returns all events', () {
      const filter = TakFilterState();
      expect(_applyFilter(events, filter).length, 4);
    });

    test('single affiliation filters correctly', () {
      const filter = TakFilterState(affiliations: {CotAffiliation.friendly});
      final result = _applyFilter(events, filter);
      expect(result.length, 1);
      expect(result.first.uid, 'F1');
    });

    test('multiple affiliations combine as OR', () {
      const filter = TakFilterState(
        affiliations: {CotAffiliation.friendly, CotAffiliation.hostile},
      );
      final result = _applyFilter(events, filter);
      expect(result.length, 2);
      expect(result.map((e) => e.uid).toSet(), {'F1', 'H1'});
    });

    test('non-matching affiliation returns empty', () {
      const filter = TakFilterState(
        affiliations: {CotAffiliation.assumedFriend},
      );
      expect(_applyFilter(events, filter), isEmpty);
    });
  });

  group('Filter logic - stale mode', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final events = [
      _event(uid: 'ACTIVE', staleUtcMs: now + 300000),
      _event(uid: 'STALE', staleUtcMs: now - 10000),
    ];

    test('TakStaleMode.all returns all events', () {
      const filter = TakFilterState(staleMode: TakStaleMode.all);
      expect(_applyFilter(events, filter).length, 2);
    });

    test('TakStaleMode.activeOnly returns only active events', () {
      const filter = TakFilterState(staleMode: TakStaleMode.activeOnly);
      final result = _applyFilter(events, filter);
      expect(result.length, 1);
      expect(result.first.uid, 'ACTIVE');
    });

    test('TakStaleMode.staleOnly returns only stale events', () {
      const filter = TakFilterState(staleMode: TakStaleMode.staleOnly);
      final result = _applyFilter(events, filter);
      expect(result.length, 1);
      expect(result.first.uid, 'STALE');
    });
  });

  group('Filter logic - search', () {
    final events = [
      _event(uid: 'ANDROID-001', callsign: 'Alpha'),
      _event(uid: 'ANDROID-002', callsign: 'Bravo'),
      _event(uid: 'IPHONE-003', callsign: null),
    ];

    test('empty search returns all events', () {
      const filter = TakFilterState(searchQuery: '');
      expect(_applyFilter(events, filter).length, 3);
    });

    test('search matches callsign (case-insensitive)', () {
      const filter = TakFilterState(searchQuery: 'alpha');
      final result = _applyFilter(events, filter);
      expect(result.length, 1);
      expect(result.first.uid, 'ANDROID-001');
    });

    test('search matches UID (case-insensitive)', () {
      const filter = TakFilterState(searchQuery: 'iphone');
      final result = _applyFilter(events, filter);
      expect(result.length, 1);
      expect(result.first.uid, 'IPHONE-003');
    });

    test('search substring match works', () {
      const filter = TakFilterState(searchQuery: 'ANDROID');
      final result = _applyFilter(events, filter);
      expect(result.length, 2);
    });

    test('search with no match returns empty', () {
      const filter = TakFilterState(searchQuery: 'DOES_NOT_EXIST');
      expect(_applyFilter(events, filter), isEmpty);
    });

    test('search ignores null callsign gracefully', () {
      const filter = TakFilterState(searchQuery: 'zzzz');
      expect(_applyFilter(events, filter), isEmpty);
    });
  });

  group('Filter logic - combined filters', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    final events = [
      _event(
        uid: 'F-ACTIVE',
        type: 'a-f-G-U-C',
        callsign: 'Alpha',
        staleUtcMs: now + 300000,
      ),
      _event(
        uid: 'F-STALE',
        type: 'a-f-G-U-C',
        callsign: 'Bravo',
        staleUtcMs: now - 10000,
      ),
      _event(
        uid: 'H-ACTIVE',
        type: 'a-h-G-U-C',
        callsign: 'Charlie',
        staleUtcMs: now + 300000,
      ),
    ];

    test('affiliation + stale mode combined', () {
      const filter = TakFilterState(
        affiliations: {CotAffiliation.friendly},
        staleMode: TakStaleMode.activeOnly,
      );
      final result = _applyFilter(events, filter);
      expect(result.length, 1);
      expect(result.first.uid, 'F-ACTIVE');
    });

    test('affiliation + search combined', () {
      const filter = TakFilterState(
        affiliations: {CotAffiliation.friendly},
        searchQuery: 'bravo',
      );
      final result = _applyFilter(events, filter);
      expect(result.length, 1);
      expect(result.first.uid, 'F-STALE');
    });

    test('all three filters combined', () {
      const filter = TakFilterState(
        affiliations: {CotAffiliation.friendly},
        staleMode: TakStaleMode.activeOnly,
        searchQuery: 'alpha',
      );
      final result = _applyFilter(events, filter);
      expect(result.length, 1);
      expect(result.first.uid, 'F-ACTIVE');
    });

    test('all three filters with no match', () {
      const filter = TakFilterState(
        affiliations: {CotAffiliation.hostile},
        staleMode: TakStaleMode.staleOnly,
        searchQuery: 'alpha',
      );
      expect(_applyFilter(events, filter), isEmpty);
    });
  });
}
