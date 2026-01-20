import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/signals/utils/signal_utils.dart';

void main() {
  group('formatSignalTtlCountdown', () {
    test('returns empty string for null', () {
      expect(formatSignalTtlCountdown(null), '');
    });

    test('returns Faded for zero or negative', () {
      expect(formatSignalTtlCountdown(const Duration(seconds: 0)), 'Faded');
      expect(
        formatSignalTtlCountdown(const Duration(seconds: -1)),
        'Faded',
      );
    });

    test('uses seconds under 60s', () {
      expect(
        formatSignalTtlCountdown(const Duration(seconds: 59)),
        'Fades in 59s',
      );
    });

    test('uses minutes under 60m', () {
      expect(
        formatSignalTtlCountdown(const Duration(seconds: 60)),
        'Fades in 1m',
      );
      expect(
        formatSignalTtlCountdown(const Duration(minutes: 59)),
        'Fades in 59m',
      );
    });

    test('uses hours under 24h', () {
      expect(
        formatSignalTtlCountdown(const Duration(hours: 1)),
        'Fades in 1h',
      );
    });

    test('uses days at 24h+', () {
      expect(
        formatSignalTtlCountdown(const Duration(days: 2)),
        'Fades in 2d',
      );
    });
  });
}
