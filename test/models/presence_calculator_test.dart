import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/presence_confidence.dart';

void main() {
  test(
    'PresenceCalculator.fromLastHeard returns expected confidence levels',
    () {
      final now = DateTime.now();

      // Null lastHeard => unknown
      expect(
        PresenceCalculator.fromLastHeard(null, now: now),
        PresenceConfidence.unknown,
      );

      // Within active window
      expect(
        PresenceCalculator.fromLastHeard(
          now.subtract(const Duration(minutes: 1)),
          now: now,
        ),
        PresenceConfidence.active,
      );

      // Within fading window
      expect(
        PresenceCalculator.fromLastHeard(
          now.subtract(const Duration(minutes: 3)),
          now: now,
        ),
        PresenceConfidence.fading,
      );

      // Within stale window
      expect(
        PresenceCalculator.fromLastHeard(
          now.subtract(const Duration(minutes: 30)),
          now: now,
        ),
        PresenceConfidence.stale,
      );

      // Older than stale window => unknown
      expect(
        PresenceCalculator.fromLastHeard(
          now.subtract(const Duration(hours: 2)),
          now: now,
        ),
        PresenceConfidence.unknown,
      );
    },
  );
}
