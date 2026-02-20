// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/nodedex/models/nodedex_entry.dart';
import 'package:socialmesh/features/nodedex/services/trust_score.dart';

void main() {
  // Reference time for deterministic testing.
  final now = DateTime(2025, 6, 15, 12, 0, 0);

  /// Helper to create a NodeDexEntry with specific fields relevant to trust.
  NodeDexEntry makeEntry({
    int encounterCount = 0,
    DateTime? firstSeen,
    DateTime? lastSeen,
    int messageCount = 0,
    String? lastKnownRole,
  }) {
    final fs = firstSeen ?? now;
    final ls = lastSeen ?? now;
    return NodeDexEntry(
      nodeNum: 42,
      firstSeen: fs,
      lastSeen: ls,
      encounterCount: encounterCount,
      messageCount: messageCount,
      lastKnownRole: lastKnownRole,
    );
  }

  group('TrustLevel enum', () {
    test('all levels have display labels', () {
      for (final level in TrustLevel.values) {
        expect(level.displayLabel.isNotEmpty, isTrue);
      }
    });

    test('all levels have descriptions', () {
      for (final level in TrustLevel.values) {
        expect(level.description.isNotEmpty, isTrue);
      }
    });

    test('all levels have distinct colors', () {
      final colors = TrustLevel.values.map((l) => l.color.value).toSet();
      expect(colors.length, equals(TrustLevel.values.length));
    });

    test('all levels have icons', () {
      for (final level in TrustLevel.values) {
        expect(level.icon, isNotNull);
      }
    });
  });

  group('TrustScore.computeAt', () {
    group('unknown level', () {
      test('brand new node with zero encounters is unknown', () {
        final entry = makeEntry();
        final result = TrustScore.computeAt(entry, now);
        expect(result.level, equals(TrustLevel.unknown));
        expect(result.score, equals(0.0));
      });

      test('zero encounters returns all-zero signals', () {
        final entry = makeEntry(encounterCount: 0);
        final result = TrustScore.computeAt(entry, now);
        expect(result.frequentlySeen, equals(0.0));
        expect(result.longLived, equals(0.0));
        expect(result.directContact, equals(0.0));
        expect(result.relayUsefulness, equals(0.0));
        expect(result.networkPresence, equals(0.0));
      });

      test('node with 1 encounter just discovered is observed', () {
        final entry = makeEntry(encounterCount: 1);
        final result = TrustScore.computeAt(entry, now);
        expect(result.level, equals(TrustLevel.observed));
      });
    });

    group('observed level', () {
      test('node with moderate encounters reaches observed', () {
        final entry = makeEntry(
          encounterCount: 5,
          firstSeen: now.subtract(const Duration(days: 2)),
          lastSeen: now.subtract(const Duration(hours: 1)),
        );
        final result = TrustScore.computeAt(entry, now);
        expect(result.level, equals(TrustLevel.observed));
        expect(result.score, greaterThanOrEqualTo(0.15));
        expect(result.score, lessThan(0.35));
      });
    });

    group('familiar level', () {
      test('node with good encounters and age reaches familiar', () {
        final entry = makeEntry(
          encounterCount: 15,
          firstSeen: now.subtract(const Duration(days: 14)),
          lastSeen: now.subtract(const Duration(hours: 2)),
          messageCount: 3,
        );
        final result = TrustScore.computeAt(entry, now);
        expect(result.level, equals(TrustLevel.familiar));
        expect(result.score, greaterThanOrEqualTo(0.35));
        expect(result.score, lessThan(0.55));
      });
    });

    group('trusted level', () {
      test('node with high encounters, messages, and age reaches trusted', () {
        final entry = makeEntry(
          encounterCount: 35,
          firstSeen: now.subtract(const Duration(days: 45)),
          lastSeen: now.subtract(const Duration(minutes: 30)),
          messageCount: 15,
        );
        final result = TrustScore.computeAt(entry, now);
        expect(result.level, equals(TrustLevel.trusted));
        expect(result.score, greaterThanOrEqualTo(0.55));
        expect(result.score, lessThan(0.75));
      });
    });

    group('established level', () {
      test('deeply documented relay node reaches established', () {
        final entry = makeEntry(
          encounterCount: 60,
          firstSeen: now.subtract(const Duration(days: 90)),
          lastSeen: now.subtract(const Duration(minutes: 5)),
          messageCount: 30,
          lastKnownRole: 'ROUTER',
        );
        final result = TrustScore.computeAt(entry, now);
        expect(result.level, equals(TrustLevel.established));
        expect(result.score, greaterThanOrEqualTo(0.75));
      });

      test('non-relay with very high metrics reaches established', () {
        final entry = makeEntry(
          encounterCount: 80,
          firstSeen: now.subtract(const Duration(days: 120)),
          lastSeen: now,
          messageCount: 40,
        );
        final result = TrustScore.computeAt(entry, now);
        expect(result.level, equals(TrustLevel.established));
        expect(result.score, greaterThanOrEqualTo(0.75));
      });
    });
  });

  group('individual signals', () {
    test('frequentlySeen increases with encounter count', () {
      final low = TrustScore.computeAt(makeEntry(encounterCount: 2), now);
      final mid = TrustScore.computeAt(makeEntry(encounterCount: 20), now);
      final high = TrustScore.computeAt(makeEntry(encounterCount: 60), now);
      expect(mid.frequentlySeen, greaterThan(low.frequentlySeen));
      expect(high.frequentlySeen, greaterThan(mid.frequentlySeen));
    });

    test('frequentlySeen is zero for zero encounters', () {
      final result = TrustScore.computeAt(makeEntry(encounterCount: 0), now);
      expect(result.frequentlySeen, equals(0.0));
    });

    test('longLived increases with age', () {
      final young = TrustScore.computeAt(
        makeEntry(
          encounterCount: 1,
          firstSeen: now.subtract(const Duration(hours: 1)),
        ),
        now,
      );
      final middle = TrustScore.computeAt(
        makeEntry(
          encounterCount: 1,
          firstSeen: now.subtract(const Duration(days: 14)),
        ),
        now,
      );
      final old = TrustScore.computeAt(
        makeEntry(
          encounterCount: 1,
          firstSeen: now.subtract(const Duration(days: 90)),
        ),
        now,
      );
      expect(middle.longLived, greaterThan(young.longLived));
      expect(old.longLived, greaterThan(middle.longLived));
    });

    test('longLived is zero for brand new node', () {
      final result = TrustScore.computeAt(
        makeEntry(encounterCount: 1, firstSeen: now),
        now,
      );
      expect(result.longLived, equals(0.0));
    });

    test('directContact increases with message count', () {
      final none = TrustScore.computeAt(
        makeEntry(encounterCount: 1, messageCount: 0),
        now,
      );
      final some = TrustScore.computeAt(
        makeEntry(encounterCount: 1, messageCount: 5),
        now,
      );
      final many = TrustScore.computeAt(
        makeEntry(encounterCount: 1, messageCount: 30),
        now,
      );
      expect(none.directContact, equals(0.0));
      expect(some.directContact, greaterThan(none.directContact));
      expect(many.directContact, greaterThan(some.directContact));
    });

    test('relayUsefulness is zero for non-relay nodes', () {
      final result = TrustScore.computeAt(makeEntry(encounterCount: 1), now);
      expect(result.relayUsefulness, equals(0.0));
    });

    test('relayUsefulness is positive for ROUTER role', () {
      final result = TrustScore.computeAt(
        makeEntry(lastKnownRole: 'ROUTER', encounterCount: 10),
        now,
      );
      expect(result.relayUsefulness, greaterThan(0.0));
    });

    test('relayUsefulness increases with encounters for relay nodes', () {
      final low = TrustScore.computeAt(
        makeEntry(lastKnownRole: 'ROUTER', encounterCount: 5),
        now,
      );
      final high = TrustScore.computeAt(
        makeEntry(lastKnownRole: 'ROUTER', encounterCount: 50),
        now,
      );
      expect(high.relayUsefulness, greaterThan(low.relayUsefulness));
    });

    test('relayUsefulness works for all relay roles', () {
      for (final role in [
        'ROUTER',
        'ROUTER_CLIENT',
        'REPEATER',
        'ROUTER_LATE',
      ]) {
        final result = TrustScore.computeAt(
          makeEntry(lastKnownRole: role, encounterCount: 10),
          now,
        );
        expect(
          result.relayUsefulness,
          greaterThan(0.0),
          reason: '$role should have positive relay score',
        );
      }
    });

    test('networkPresence is highest when just seen', () {
      final result = TrustScore.computeAt(
        makeEntry(encounterCount: 1, lastSeen: now),
        now,
      );
      expect(result.networkPresence, equals(1.0));
    });

    test('networkPresence decays over time', () {
      final recent = TrustScore.computeAt(
        makeEntry(
          encounterCount: 1,
          lastSeen: now.subtract(const Duration(hours: 1)),
        ),
        now,
      );
      final old = TrustScore.computeAt(
        makeEntry(
          encounterCount: 1,
          lastSeen: now.subtract(const Duration(days: 7)),
        ),
        now,
      );
      final veryOld = TrustScore.computeAt(
        makeEntry(
          encounterCount: 1,
          lastSeen: now.subtract(const Duration(days: 30)),
        ),
        now,
      );
      expect(recent.networkPresence, greaterThan(old.networkPresence));
      expect(old.networkPresence, greaterThan(veryOld.networkPresence));
    });
  });

  group('determinism', () {
    test('same inputs always produce same result', () {
      final entry = makeEntry(
        encounterCount: 25,
        firstSeen: now.subtract(const Duration(days: 30)),
        lastSeen: now.subtract(const Duration(hours: 2)),
        messageCount: 10,
        lastKnownRole: 'ROUTER_CLIENT',
      );
      final result1 = TrustScore.computeAt(entry, now);
      final result2 = TrustScore.computeAt(entry, now);
      expect(result1.score, equals(result2.score));
      expect(result1.level, equals(result2.level));
      expect(result1.frequentlySeen, equals(result2.frequentlySeen));
      expect(result1.longLived, equals(result2.longLived));
      expect(result1.directContact, equals(result2.directContact));
      expect(result1.relayUsefulness, equals(result2.relayUsefulness));
      expect(result1.networkPresence, equals(result2.networkPresence));
    });
  });

  group('edge cases', () {
    test('live role overrides lastKnownRole', () {
      final entry = makeEntry(encounterCount: 30, lastKnownRole: 'CLIENT');
      final withLive = TrustScore.computeAt(entry, now, role: 'ROUTER');
      final withoutLive = TrustScore.computeAt(entry, now);
      expect(withLive.relayUsefulness, greaterThan(0.0));
      expect(withoutLive.relayUsefulness, equals(0.0));
    });

    test('score is clamped between 0 and 1', () {
      // Max everything — should not exceed 1.0.
      final entry = makeEntry(
        encounterCount: 1000,
        firstSeen: now.subtract(const Duration(days: 365)),
        lastSeen: now,
        messageCount: 500,
        lastKnownRole: 'ROUTER',
      );
      final result = TrustScore.computeAt(entry, now);
      expect(result.score, lessThanOrEqualTo(1.0));
      expect(result.score, greaterThanOrEqualTo(0.0));
    });

    test('future firstSeen does not break', () {
      final entry = makeEntry(
        encounterCount: 1,
        firstSeen: now.add(const Duration(days: 1)),
      );
      final result = TrustScore.computeAt(entry, now);
      expect(result.longLived, equals(0.0));
    });

    test('future lastSeen gives max presence', () {
      final entry = makeEntry(
        encounterCount: 1,
        lastSeen: now.add(const Duration(hours: 1)),
      );
      final result = TrustScore.computeAt(entry, now);
      expect(result.networkPresence, equals(1.0));
    });
  });

  group('TrustResult', () {
    test('toString includes level and percentage', () {
      final result = TrustScore.computeAt(
        makeEntry(
          encounterCount: 20,
          firstSeen: now.subtract(const Duration(days: 30)),
          lastSeen: now,
          messageCount: 5,
        ),
        now,
      );
      expect(result.toString(), contains(result.level.displayLabel));
      expect(result.toString(), contains('%'));
    });
  });

  group('level boundaries', () {
    test('threshold progression is monotonic', () {
      // Create entries with progressively more data.
      final entries = <NodeDexEntry>[
        makeEntry(encounterCount: 0), // unknown
        makeEntry(
          encounterCount: 3,
          firstSeen: now.subtract(const Duration(days: 2)),
          lastSeen: now.subtract(const Duration(hours: 6)),
        ), // observed
        makeEntry(
          encounterCount: 12,
          firstSeen: now.subtract(const Duration(days: 10)),
          lastSeen: now.subtract(const Duration(hours: 6)),
          messageCount: 2,
        ), // familiar
        makeEntry(
          encounterCount: 30,
          firstSeen: now.subtract(const Duration(days: 40)),
          lastSeen: now.subtract(const Duration(hours: 1)),
          messageCount: 10,
        ), // trusted
        makeEntry(
          encounterCount: 60,
          firstSeen: now.subtract(const Duration(days: 90)),
          lastSeen: now,
          messageCount: 30,
          lastKnownRole: 'ROUTER',
        ), // established
      ];

      final scores = entries
          .map((e) => TrustScore.computeAt(e, now).score)
          .toList();

      for (int i = 1; i < scores.length; i++) {
        expect(
          scores[i],
          greaterThan(scores[i - 1]),
          reason: 'Score at index $i should be greater than $i-1',
        );
      }
    });

    test('levels progress in order with increasing data', () {
      final entries = <NodeDexEntry>[
        makeEntry(encounterCount: 0),
        makeEntry(
          encounterCount: 3,
          firstSeen: now.subtract(const Duration(days: 2)),
          lastSeen: now.subtract(const Duration(hours: 6)),
        ),
        makeEntry(
          encounterCount: 12,
          firstSeen: now.subtract(const Duration(days: 10)),
          lastSeen: now.subtract(const Duration(hours: 6)),
          messageCount: 2,
        ),
        makeEntry(
          encounterCount: 30,
          firstSeen: now.subtract(const Duration(days: 40)),
          lastSeen: now.subtract(const Duration(hours: 1)),
          messageCount: 10,
        ),
        makeEntry(
          encounterCount: 60,
          firstSeen: now.subtract(const Duration(days: 90)),
          lastSeen: now,
          messageCount: 30,
          lastKnownRole: 'ROUTER',
        ),
      ];

      final levels = entries
          .map((e) => TrustScore.computeAt(e, now).level)
          .toList();

      expect(levels[0], equals(TrustLevel.unknown));
      expect(levels[1], equals(TrustLevel.observed));
      expect(levels[2], equals(TrustLevel.familiar));
      expect(levels[3], equals(TrustLevel.trusted));
      expect(levels[4], equals(TrustLevel.established));
    });
  });
}
