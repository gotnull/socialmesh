import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/providers/signal_bookmark_provider.dart';

void main() {
  group('SignalViewMode', () {
    test('has all expected values', () {
      expect(SignalViewMode.values.length, 4);
      expect(SignalViewMode.values, contains(SignalViewMode.list));
      expect(SignalViewMode.values, contains(SignalViewMode.grid));
      expect(SignalViewMode.values, contains(SignalViewMode.gallery));
      expect(SignalViewMode.values, contains(SignalViewMode.map));
    });
  });

  group('SignalViewModeNotifier', () {
    test('signalViewModeProvider is a NotifierProvider', () {
      expect(
        signalViewModeProvider,
        isA<NotifierProvider<SignalViewModeNotifier, SignalViewMode>>(),
      );
    });

    test('initial state is list view', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final viewMode = container.read(signalViewModeProvider);

      expect(viewMode, SignalViewMode.list);
    });

    test('setMode updates state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(signalViewModeProvider.notifier)
          .setMode(SignalViewMode.grid);

      expect(container.read(signalViewModeProvider), SignalViewMode.grid);
    });

    test('setMode supports all view modes', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      for (final mode in SignalViewMode.values) {
        await container.read(signalViewModeProvider.notifier).setMode(mode);
        expect(container.read(signalViewModeProvider), mode);
      }
    });
  });

  group('SignalBookmarksNotifier', () {
    test('signalBookmarksProvider is an AsyncNotifierProvider', () {
      expect(
        signalBookmarksProvider,
        isA<AsyncNotifierProvider<SignalBookmarksNotifier, Set<String>>>(),
      );
    });
  });

  group('HiddenSignalsNotifier', () {
    test('hiddenSignalsProvider is a NotifierProvider', () {
      expect(
        hiddenSignalsProvider,
        isA<NotifierProvider<HiddenSignalsNotifier, Set<String>>>(),
      );
    });

    test('initial state is empty set', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final hidden = container.read(hiddenSignalsProvider);

      expect(hidden, isEmpty);
    });

    test('hideSignal adds signal to hidden set', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(hiddenSignalsProvider.notifier)
          .hideSignal('signal_1');

      expect(container.read(hiddenSignalsProvider), contains('signal_1'));
    });

    test('hideSignal handles multiple signals', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(hiddenSignalsProvider.notifier)
          .hideSignal('signal_1');
      await container
          .read(hiddenSignalsProvider.notifier)
          .hideSignal('signal_2');
      await container
          .read(hiddenSignalsProvider.notifier)
          .hideSignal('signal_3');

      final hidden = container.read(hiddenSignalsProvider);
      expect(hidden.length, 3);
      expect(hidden, contains('signal_1'));
      expect(hidden, contains('signal_2'));
      expect(hidden, contains('signal_3'));
    });

    test('hideSignal does not duplicate signals', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(hiddenSignalsProvider.notifier)
          .hideSignal('signal_1');
      await container
          .read(hiddenSignalsProvider.notifier)
          .hideSignal('signal_1');

      expect(container.read(hiddenSignalsProvider).length, 1);
    });

    test('unhideSignal removes signal from hidden set', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(hiddenSignalsProvider.notifier)
          .hideSignal('signal_1');
      await container
          .read(hiddenSignalsProvider.notifier)
          .hideSignal('signal_2');

      await container
          .read(hiddenSignalsProvider.notifier)
          .unhideSignal('signal_1');

      final hidden = container.read(hiddenSignalsProvider);
      expect(hidden.length, 1);
      expect(hidden, isNot(contains('signal_1')));
      expect(hidden, contains('signal_2'));
    });

    test('unhideSignal is no-op for non-hidden signal', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(hiddenSignalsProvider.notifier)
          .hideSignal('signal_1');

      await container
          .read(hiddenSignalsProvider.notifier)
          .unhideSignal('signal_2');

      expect(container.read(hiddenSignalsProvider).length, 1);
      expect(container.read(hiddenSignalsProvider), contains('signal_1'));
    });

    test('isHidden returns correct value', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(hiddenSignalsProvider.notifier)
          .hideSignal('signal_1');

      expect(
        container.read(hiddenSignalsProvider.notifier).isHidden('signal_1'),
        true,
      );
      expect(
        container.read(hiddenSignalsProvider.notifier).isHidden('signal_2'),
        false,
      );
    });

    test('clearAll removes all hidden signals', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container
          .read(hiddenSignalsProvider.notifier)
          .hideSignal('signal_1');
      await container
          .read(hiddenSignalsProvider.notifier)
          .hideSignal('signal_2');
      await container
          .read(hiddenSignalsProvider.notifier)
          .hideSignal('signal_3');

      await container.read(hiddenSignalsProvider.notifier).clearAll();

      expect(container.read(hiddenSignalsProvider), isEmpty);
    });
  });

  group('isSignalBookmarkedProvider', () {
    test('returns false for non-bookmarked signal', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Without Firebase, bookmarks will be empty, so any signal is not bookmarked
      final isBookmarked = container.read(
        isSignalBookmarkedProvider('test_signal'),
      );
      expect(isBookmarked, false);
    });
  });

  group('signalViewCountProvider', () {
    test('provider can be created for any signal id', () {
      // Just verify the provider can be created without throwing
      expect(() => signalViewCountProvider('test_signal'), returnsNormally);
    });
  });
}
