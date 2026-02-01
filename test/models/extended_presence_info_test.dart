// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/models/presence_confidence.dart';

void main() {
  group('ExtendedPresenceInfo', () {
    group('JSON serialization', () {
      test('serializes intent only', () {
        const info = ExtendedPresenceInfo(intent: PresenceIntent.camping);
        final json = info.toJson();
        expect(json, {'i': 2});
      });

      test('serializes status only', () {
        const info = ExtendedPresenceInfo(shortStatus: 'hiking');
        final json = info.toJson();
        expect(json, {'s': 'hiking'});
      });

      test('serializes both intent and status', () {
        const info = ExtendedPresenceInfo(
          intent: PresenceIntent.traveling,
          shortStatus: 'on the road',
        );
        final json = info.toJson();
        expect(json, {'i': 3, 's': 'on the road'});
      });

      test('serializes empty for defaults', () {
        const info = ExtendedPresenceInfo();
        final json = info.toJson();
        expect(json, isEmpty);
      });

      test('toPayload returns null for defaults', () {
        const info = ExtendedPresenceInfo();
        expect(info.toPayload(), isNull);
      });

      test('toPayload returns compact JSON', () {
        const info = ExtendedPresenceInfo(
          intent: PresenceIntent.available,
          shortStatus: 'here',
        );
        expect(info.toPayload(), '{"i":1,"s":"here"}');
      });
    });

    group('JSON deserialization', () {
      test('parses intent only', () {
        final info = ExtendedPresenceInfo.fromJson({'i': 2});
        expect(info.intent, PresenceIntent.camping);
        expect(info.shortStatus, isNull);
      });

      test('parses status only', () {
        final info = ExtendedPresenceInfo.fromJson({'s': 'testing'});
        expect(info.intent, PresenceIntent.unknown);
        expect(info.shortStatus, 'testing');
      });

      test('parses both', () {
        final info = ExtendedPresenceInfo.fromJson({'i': 4, 's': 'ready'});
        expect(info.intent, PresenceIntent.emergencyStandby);
        expect(info.shortStatus, 'ready');
      });

      test('handles null gracefully', () {
        final info = ExtendedPresenceInfo.fromJson(null);
        expect(info.intent, PresenceIntent.unknown);
        expect(info.shortStatus, isNull);
      });

      test('handles empty map', () {
        final info = ExtendedPresenceInfo.fromJson({});
        expect(info.intent, PresenceIntent.unknown);
        expect(info.shortStatus, isNull);
      });

      test('handles unknown intent value', () {
        final info = ExtendedPresenceInfo.fromJson({'i': 999});
        expect(info.intent, PresenceIntent.unknown);
      });

      test('trims whitespace from status', () {
        final info = ExtendedPresenceInfo.fromJson({'s': '  hello  '});
        expect(info.shortStatus, 'hello');
      });

      test('treats empty status as null', () {
        final info = ExtendedPresenceInfo.fromJson({'s': '   '});
        expect(info.shortStatus, isNull);
      });
    });

    group('max status length enforcement', () {
      test('truncates long status on parse', () {
        final longStatus = 'a' * 100;
        final info = ExtendedPresenceInfo.fromJson({'s': longStatus});
        expect(info.shortStatus!.length, ExtendedPresenceInfo.maxStatusLength);
      });

      test('truncates long status on serialize', () {
        final longStatus = 'b' * 100;
        final info = ExtendedPresenceInfo(shortStatus: longStatus);
        final json = info.toJson();
        expect(
          (json['s'] as String).length,
          ExtendedPresenceInfo.maxStatusLength,
        );
      });
    });

    group('fromPayload', () {
      test('parses valid JSON string', () {
        final info = ExtendedPresenceInfo.fromPayload('{"i":1,"s":"hi"}');
        expect(info.intent, PresenceIntent.available);
        expect(info.shortStatus, 'hi');
      });

      test('handles null payload', () {
        final info = ExtendedPresenceInfo.fromPayload(null);
        expect(info.intent, PresenceIntent.unknown);
        expect(info.shortStatus, isNull);
      });

      test('handles empty payload', () {
        final info = ExtendedPresenceInfo.fromPayload('');
        expect(info.intent, PresenceIntent.unknown);
      });

      test('handles malformed JSON gracefully', () {
        final info = ExtendedPresenceInfo.fromPayload('not json');
        expect(info.intent, PresenceIntent.unknown);
        expect(info.shortStatus, isNull);
      });

      test('handles corrupted JSON gracefully', () {
        final info = ExtendedPresenceInfo.fromPayload('{broken');
        expect(info.intent, PresenceIntent.unknown);
      });
    });

    group('hasData', () {
      test('false for defaults', () {
        const info = ExtendedPresenceInfo();
        expect(info.hasData, isFalse);
      });

      test('true for non-unknown intent', () {
        const info = ExtendedPresenceInfo(intent: PresenceIntent.passive);
        expect(info.hasData, isTrue);
      });

      test('true for non-empty status', () {
        const info = ExtendedPresenceInfo(shortStatus: 'hello');
        expect(info.hasData, isTrue);
      });

      test('false for whitespace-only status', () {
        const info = ExtendedPresenceInfo(shortStatus: '   ');
        expect(info.hasData, isFalse);
      });
    });

    group('equality', () {
      test('equal for same values', () {
        const a = ExtendedPresenceInfo(
          intent: PresenceIntent.camping,
          shortStatus: 'test',
        );
        const b = ExtendedPresenceInfo(
          intent: PresenceIntent.camping,
          shortStatus: 'test',
        );
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('not equal for different intent', () {
        const a = ExtendedPresenceInfo(intent: PresenceIntent.camping);
        const b = ExtendedPresenceInfo(intent: PresenceIntent.traveling);
        expect(a, isNot(equals(b)));
      });

      test('not equal for different status', () {
        const a = ExtendedPresenceInfo(shortStatus: 'a');
        const b = ExtendedPresenceInfo(shortStatus: 'b');
        expect(a, isNot(equals(b)));
      });
    });
  });

  group('PresenceIntent', () {
    test('all values have unique int values', () {
      final values = PresenceIntent.values.map((e) => e.value).toSet();
      expect(values.length, PresenceIntent.values.length);
    });

    test('fromValue returns correct intent', () {
      expect(PresenceIntent.fromValue(0), PresenceIntent.unknown);
      expect(PresenceIntent.fromValue(1), PresenceIntent.available);
      expect(PresenceIntent.fromValue(2), PresenceIntent.camping);
      expect(PresenceIntent.fromValue(3), PresenceIntent.traveling);
      expect(PresenceIntent.fromValue(4), PresenceIntent.emergencyStandby);
      expect(PresenceIntent.fromValue(5), PresenceIntent.relayNode);
      expect(PresenceIntent.fromValue(6), PresenceIntent.passive);
    });

    test('fromValue handles null', () {
      expect(PresenceIntent.fromValue(null), PresenceIntent.unknown);
    });

    test('fromValue handles invalid value', () {
      expect(PresenceIntent.fromValue(999), PresenceIntent.unknown);
      expect(PresenceIntent.fromValue(-1), PresenceIntent.unknown);
    });

    test('all intents have labels', () {
      for (final intent in PresenceIntent.values) {
        expect(intent.label, isNotEmpty);
      }
    });
  });

  group('LastSeenBucket', () {
    test('activeRecently for <15 minutes', () {
      expect(
        LastSeenBucket.fromDuration(const Duration(minutes: 0)),
        LastSeenBucket.activeRecently,
      );
      expect(
        LastSeenBucket.fromDuration(const Duration(minutes: 14)),
        LastSeenBucket.activeRecently,
      );
    });

    test('seenToday for 15min to 24h', () {
      expect(
        LastSeenBucket.fromDuration(const Duration(minutes: 15)),
        LastSeenBucket.seenToday,
      );
      expect(
        LastSeenBucket.fromDuration(const Duration(hours: 23)),
        LastSeenBucket.seenToday,
      );
    });

    test('seenThisWeek for 24h to 7d', () {
      expect(
        LastSeenBucket.fromDuration(const Duration(hours: 24)),
        LastSeenBucket.seenThisWeek,
      );
      expect(
        LastSeenBucket.fromDuration(const Duration(days: 6)),
        LastSeenBucket.seenThisWeek,
      );
    });

    test('inactive for >=7d', () {
      expect(
        LastSeenBucket.fromDuration(const Duration(days: 7)),
        LastSeenBucket.inactive,
      );
      expect(
        LastSeenBucket.fromDuration(const Duration(days: 30)),
        LastSeenBucket.inactive,
      );
    });

    test('inactive for null', () {
      expect(LastSeenBucket.fromDuration(null), LastSeenBucket.inactive);
    });

    test('all buckets have labels', () {
      for (final bucket in LastSeenBucket.values) {
        expect(bucket.label, isNotEmpty);
      }
    });
  });

  group('ConfidenceTier', () {
    test('maps from confidence correctly', () {
      expect(
        ConfidenceTier.fromConfidence(PresenceConfidence.active),
        ConfidenceTier.strong,
      );
      expect(
        ConfidenceTier.fromConfidence(PresenceConfidence.fading),
        ConfidenceTier.moderate,
      );
      expect(
        ConfidenceTier.fromConfidence(PresenceConfidence.stale),
        ConfidenceTier.weak,
      );
      expect(
        ConfidenceTier.fromConfidence(PresenceConfidence.unknown),
        ConfidenceTier.weak,
      );
    });

    test('all tiers have labels', () {
      for (final tier in ConfidenceTier.values) {
        expect(tier.label, isNotEmpty);
      }
    });
  });
}
