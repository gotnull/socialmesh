import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/connection/reconnect_direction_estimator.dart';

void main() {
  group('ReconnectDirectionEstimator', () {
    test('derives a heading and grows confidence with more samples', () {
      final now = DateTime.now();
      final estimator = ReconnectDirectionEstimator(
        windowDuration: const Duration(seconds: 60),
      );

      estimator.addSample(rssi: -65, headingDeg: 5, timestamp: now);
      final first = estimator.estimate;

      estimator.addSample(
        rssi: -55,
        headingDeg: 15,
        timestamp: now.add(const Duration(seconds: 1)),
      );
      final second = estimator.estimate;

      expect(second.bestHeadingDeg, isNotNull);
      expect(second.confidence, greaterThan(first.confidence));
      expect(second.lastRssi, equals(-55));
      expect(second.sampleCount, greaterThan(0));
    });

    test('reset clears stored samples and metadata', () {
      final estimator = ReconnectDirectionEstimator();
      estimator.addSample(rssi: -70, headingDeg: 180);

      estimator.reset();

      final result = estimator.estimate;
      expect(result.bestHeadingDeg, isNull);
      expect(result.confidence, equals(0));
      expect(result.lastRssi, isNull);
      expect(result.sampleCount, equals(0));
    });
  });
}
