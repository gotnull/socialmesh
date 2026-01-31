import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/signals/utils/signal_utils.dart';

void main() {
  test(
    'formatSignalTtlCountdown uses seconds under a minute and fades at zero',
    () {
      expect(
        formatSignalTtlCountdown(const Duration(seconds: 59)),
        'Fades in 59s',
      );
      expect(
        formatSignalTtlCountdown(const Duration(seconds: 1)),
        'Fades in 1s',
      );
      expect(formatSignalTtlCountdown(const Duration(seconds: 0)), 'Faded');
      expect(formatSignalTtlCountdown(const Duration(seconds: -1)), 'Faded');
    },
  );
}
