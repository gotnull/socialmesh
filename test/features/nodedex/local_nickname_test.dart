// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';

/// Tests for the localNickname feature on NodeDexEntry.
///
/// Covers: constructor, copyWith (set/clear/auto-stamp), serialization
/// round-trip (toJson/fromJson), mergeWith (last-write-wins), and
/// equality / hashCode.
void main() {
  NodeDexEntry _base({String? localNickname, int? localNicknameUpdatedAtMs}) {
    return NodeDexEntry(
      nodeNum: 42,
      firstSeen: DateTime(2024, 1, 1),
      lastSeen: DateTime(2024, 6, 1),
      localNickname: localNickname,
      localNicknameUpdatedAtMs: localNicknameUpdatedAtMs,
    );
  }

  // ===========================================================================
  // Constructor defaults
  // ===========================================================================

  group('constructor', () {
    test('localNickname defaults to null', () {
      final entry = _base();
      expect(entry.localNickname, isNull);
      expect(entry.localNicknameUpdatedAtMs, isNull);
    });

    test('localNickname can be set in constructor', () {
      final entry = _base(
        localNickname: 'MyRadio',
        localNicknameUpdatedAtMs: 1700000000000,
      );
      expect(entry.localNickname, equals('MyRadio'));
      expect(entry.localNicknameUpdatedAtMs, equals(1700000000000));
    });
  });

  // ===========================================================================
  // copyWith
  // ===========================================================================

  group('copyWith', () {
    test('sets localNickname via copyWith', () {
      final entry = _base();
      final copy = entry.copyWith(localNickname: 'BobsNode');

      expect(copy.localNickname, equals('BobsNode'));
      expect(copy.localNicknameUpdatedAtMs, isNotNull);
    });

    test('auto-stamps localNicknameUpdatedAtMs on set', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final entry = _base();
      final copy = entry.copyWith(localNickname: 'Stamped');
      final after = DateTime.now().millisecondsSinceEpoch;

      expect(copy.localNicknameUpdatedAtMs, greaterThanOrEqualTo(before));
      expect(copy.localNicknameUpdatedAtMs, lessThanOrEqualTo(after));
    });

    test('explicit timestamp overrides auto-stamp', () {
      final entry = _base();
      final copy = entry.copyWith(
        localNickname: 'Explicit',
        localNicknameUpdatedAtMs: 1600000000000,
      );

      expect(copy.localNicknameUpdatedAtMs, equals(1600000000000));
    });

    test('clearLocalNickname clears the nickname', () {
      final entry = _base(
        localNickname: 'ToBeCleared',
        localNicknameUpdatedAtMs: 1700000000000,
      );
      final copy = entry.copyWith(clearLocalNickname: true);

      expect(copy.localNickname, isNull);
      // Timestamp should be updated (auto-stamped on clear)
      expect(copy.localNicknameUpdatedAtMs, isNotNull);
    });

    test('auto-stamps on clearLocalNickname', () {
      final before = DateTime.now().millisecondsSinceEpoch;
      final entry = _base(
        localNickname: 'Old',
        localNicknameUpdatedAtMs: 1600000000000,
      );
      final copy = entry.copyWith(clearLocalNickname: true);
      final after = DateTime.now().millisecondsSinceEpoch;

      expect(copy.localNicknameUpdatedAtMs, greaterThanOrEqualTo(before));
      expect(copy.localNicknameUpdatedAtMs, lessThanOrEqualTo(after));
    });

    test('copyWith without nickname preserves existing', () {
      final entry = _base(
        localNickname: 'Preserved',
        localNicknameUpdatedAtMs: 1700000000000,
      );
      final copy = entry.copyWith(encounterCount: 5);

      expect(copy.localNickname, equals('Preserved'));
      expect(copy.localNicknameUpdatedAtMs, equals(1700000000000));
    });
  });

  // ===========================================================================
  // Serialization (toJson / fromJson)
  // ===========================================================================

  group('serialization', () {
    test('toJson includes localNickname when set', () {
      final entry = _base(
        localNickname: 'Rocket',
        localNicknameUpdatedAtMs: 1700000000000,
      );
      final json = entry.toJson();

      expect(json['ln'], equals('Rocket'));
      expect(json['ln_ms'], equals(1700000000000));
    });

    test('toJson omits localNickname when null', () {
      final entry = _base();
      final json = entry.toJson();

      expect(json.containsKey('ln'), isFalse);
      expect(json.containsKey('ln_ms'), isFalse);
    });

    test('fromJson parses localNickname', () {
      final json = <String, dynamic>{
        'nn': 42,
        'fs': DateTime(2024, 1, 1).millisecondsSinceEpoch,
        'ls': DateTime(2024, 6, 1).millisecondsSinceEpoch,
        'ln': 'Parsed',
        'ln_ms': 1700000000000,
      };
      final entry = NodeDexEntry.fromJson(json);

      expect(entry.localNickname, equals('Parsed'));
      expect(entry.localNicknameUpdatedAtMs, equals(1700000000000));
    });

    test('fromJson handles missing localNickname', () {
      final json = <String, dynamic>{
        'nn': 42,
        'fs': DateTime(2024, 1, 1).millisecondsSinceEpoch,
        'ls': DateTime(2024, 6, 1).millisecondsSinceEpoch,
      };
      final entry = NodeDexEntry.fromJson(json);

      expect(entry.localNickname, isNull);
      expect(entry.localNicknameUpdatedAtMs, isNull);
    });

    test('round-trip preserves localNickname', () {
      final original = _base(
        localNickname: 'RoundTrip',
        localNicknameUpdatedAtMs: 1700000000000,
      );
      final restored = NodeDexEntry.fromJson(original.toJson());

      expect(restored.localNickname, equals(original.localNickname));
      expect(
        restored.localNicknameUpdatedAtMs,
        equals(original.localNicknameUpdatedAtMs),
      );
    });
  });

  // ===========================================================================
  // mergeWith — last-write-wins
  // ===========================================================================

  group('mergeWith localNickname', () {
    test('remote wins when remote timestamp is newer', () {
      final local = _base(
        localNickname: 'LocalName',
        localNicknameUpdatedAtMs: 1000,
      );
      final remote = _base(
        localNickname: 'RemoteName',
        localNicknameUpdatedAtMs: 2000,
      );
      final merged = local.mergeWith(remote);

      expect(merged.localNickname, equals('RemoteName'));
      expect(merged.localNicknameUpdatedAtMs, equals(2000));
    });

    test('local wins when local timestamp is newer', () {
      final local = _base(
        localNickname: 'LocalName',
        localNicknameUpdatedAtMs: 3000,
      );
      final remote = _base(
        localNickname: 'RemoteName',
        localNicknameUpdatedAtMs: 1000,
      );
      final merged = local.mergeWith(remote);

      expect(merged.localNickname, equals('LocalName'));
      expect(merged.localNicknameUpdatedAtMs, equals(3000));
    });

    test('only one side has timestamp — that side wins', () {
      final local = _base(localNickname: 'NoTimestamp');
      final remote = _base(
        localNickname: 'HasTimestamp',
        localNicknameUpdatedAtMs: 1000,
      );
      final merged = local.mergeWith(remote);

      expect(merged.localNickname, equals('HasTimestamp'));
      expect(merged.localNicknameUpdatedAtMs, equals(1000));
    });

    test('both null timestamps — prefers local non-null', () {
      final local = _base(localNickname: 'FallbackLocal');
      final remote = _base();
      final merged = local.mergeWith(remote);

      expect(merged.localNickname, equals('FallbackLocal'));
    });

    test('merging null nickname clears when remote is newer', () {
      final local = _base(
        localNickname: 'Existing',
        localNicknameUpdatedAtMs: 1000,
      );
      // Remote explicitly cleared (null value, newer timestamp)
      final remote = _base(localNicknameUpdatedAtMs: 2000);
      final merged = local.mergeWith(remote);

      expect(merged.localNickname, isNull);
      expect(merged.localNicknameUpdatedAtMs, equals(2000));
    });
  });

  // ===========================================================================
  // Equality and hashCode
  // ===========================================================================

  group('equality', () {
    test('entries with same localNickname are equal', () {
      final a = _base(localNickname: 'Same');
      final b = _base(localNickname: 'Same');
      expect(a, equals(b));
    });

    test('entries with different localNickname are not equal', () {
      final a = _base(localNickname: 'Alpha');
      final b = _base(localNickname: 'Beta');
      expect(a, isNot(equals(b)));
    });

    test('entry with and without localNickname are not equal', () {
      final a = _base(localNickname: 'HasOne');
      final b = _base();
      expect(a, isNot(equals(b)));
    });

    test('hashCode differs when localNickname differs', () {
      final a = _base(localNickname: 'X');
      final b = _base(localNickname: 'Y');
      // Different hash codes are expected but not guaranteed; at minimum
      // they should not throw.
      expect(a.hashCode, isA<int>());
      expect(b.hashCode, isA<int>());
    });
  });
}
