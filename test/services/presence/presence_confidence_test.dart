import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/models/presence_confidence.dart';

void main() {
  group('PresenceCalculator', () {
    test('returns unknown when lastHeard is null', () {
      final now = DateTime(2026, 1, 24, 12, 0, 0);
      final confidence = PresenceCalculator.fromLastHeard(null, now: now);
      expect(confidence, PresenceConfidence.unknown);
    });

    test('active within 2 minutes', () {
      final now = DateTime(2026, 1, 24, 12, 0, 0);
      expect(
        PresenceCalculator.fromLastHeard(
          now.subtract(const Duration(seconds: 30)),
          now: now,
        ),
        PresenceConfidence.active,
      );
      expect(
        PresenceCalculator.fromLastHeard(
          now.subtract(const Duration(minutes: 2)),
          now: now,
        ),
        PresenceConfidence.active,
      );
    });

    test('fading between 2 and 10 minutes', () {
      final now = DateTime(2026, 1, 24, 12, 0, 0);
      expect(
        PresenceCalculator.fromLastHeard(
          now.subtract(const Duration(minutes: 2, seconds: 1)),
          now: now,
        ),
        PresenceConfidence.fading,
      );
      expect(
        PresenceCalculator.fromLastHeard(
          now.subtract(const Duration(minutes: 10)),
          now: now,
        ),
        PresenceConfidence.fading,
      );
    });

    test('stale between 10 and 60 minutes', () {
      final now = DateTime(2026, 1, 24, 12, 0, 0);
      expect(
        PresenceCalculator.fromLastHeard(
          now.subtract(const Duration(minutes: 10, seconds: 1)),
          now: now,
        ),
        PresenceConfidence.stale,
      );
      expect(
        PresenceCalculator.fromLastHeard(
          now.subtract(const Duration(minutes: 60)),
          now: now,
        ),
        PresenceConfidence.stale,
      );
    });

    test('unknown after 60 minutes', () {
      final now = DateTime(2026, 1, 24, 12, 0, 0);
      expect(
        PresenceCalculator.fromLastHeard(
          now.subtract(const Duration(minutes: 60, seconds: 1)),
          now: now,
        ),
        PresenceConfidence.unknown,
      );
      expect(
        PresenceCalculator.fromLastHeard(
          now.subtract(const Duration(hours: 2)),
          now: now,
        ),
        PresenceConfidence.unknown,
      );
    });
  });
}
