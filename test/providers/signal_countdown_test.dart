import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:socialmesh/models/social.dart';
import 'package:socialmesh/providers/auth_providers.dart';
import 'package:socialmesh/providers/connectivity_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';
import 'package:socialmesh/providers/signal_providers.dart';
import 'package:socialmesh/services/signal_service.dart';

class FakeSignalService extends SignalService {
  FakeSignalService(this.nowProvider);

  final DateTime Function() nowProvider;

  @override
  Future<Post> createSignal({
    required String content,
    int ttlMinutes = SignalTTL.defaultTTL,
    PostLocation? location,
    int? meshNodeId,
    List<String>? imageLocalPaths,
    PostAuthorSnapshot? authorSnapshot,
    bool useCloud = true,
    Map<String, dynamic>? presenceInfo,
  }) async {
    final now = nowProvider();
    return Post(
      id: 'signal_${now.microsecondsSinceEpoch}',
      authorId: 'tester',
      content: content,
      createdAt: now,
      postMode: PostMode.signal,
      origin: SignalOrigin.mesh,
      expiresAt: now.add(const Duration(seconds: 1)),
      meshNodeId: meshNodeId,
      presenceInfo: presenceInfo,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('countdown tick fades and removes expired signals', () {
    fakeAsync((async) {
      var now = DateTime(2024, 1, 1, 12, 0, 0);
      final fake = FakeSignalService(() => now);

      final container = ProviderContainer(
        overrides: [
          signalServiceProvider.overrideWithValue(fake),
          isDeviceConnectedProvider.overrideWithValue(true),
          isSignedInProvider.overrideWithValue(true),
          isOnlineProvider.overrideWithValue(true),
          authStateProvider.overrideWithValue(AsyncValue.data(null)),
        ],
      );

      final notifier = container.read(signalFeedProvider.notifier);

      async.run((_) async {
        final signal = await notifier.createSignal(content: 'expires soon');
        expect(signal, isNotNull);
        expect(container.read(signalFeedProvider).signals.length, 1);

        notifier.tickCountdownForTest(now);
        expect(container.read(signalFeedProvider).fadingSignalIds, isEmpty);

        now = now.add(const Duration(seconds: 2));
        notifier.tickCountdownForTest(now);
        expect(
          container.read(signalFeedProvider).fadingSignalIds,
          contains(signal!.id),
        );

        async.elapse(const Duration(seconds: 3));
        async.flushMicrotasks();

        expect(
          container
              .read(signalFeedProvider)
              .signals
              .where((s) => s.id == signal.id)
              .isEmpty,
          isTrue,
        );
      });

      async.flushMicrotasks();
      container.dispose();
    });
  });
}
