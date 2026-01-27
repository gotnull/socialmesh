import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/providers/connectivity_providers.dart';
import 'package:socialmesh/providers/auth_providers.dart';
import 'package:socialmesh/providers/signal_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';
import 'package:socialmesh/services/signal_service.dart';
import 'package:socialmesh/models/social.dart';

class FakeSignalService extends SignalService {
  bool? lastUseCloud;
  String? lastContent;

  @override
  Future<Post> createSignal({
    required String content,
    int ttlMinutes = SignalTTL.defaultTTL,
    PostLocation? location,
    int? meshNodeId,
    String? imageLocalPath,
    PostAuthorSnapshot? authorSnapshot,
    bool useCloud = true,
  }) async {
    lastUseCloud = useCloud;
    lastContent = content;

    // Return a minimal Post - reuse original createSignal behaviour not required
    final now = DateTime.now();
    return Post(
      id: 'fake-${DateTime.now().millisecondsSinceEpoch.toString()}',
      authorId: 'fake',
      content: content,
      mediaUrls: const [],
      location: location,
      nodeId: meshNodeId?.toRadixString(16),
      createdAt: now,
      commentCount: 0,
      likeCount: 0,
      authorSnapshot: null,
      postMode: PostMode.signal,
      origin: SignalOrigin.mesh,
      expiresAt: now.add(Duration(minutes: ttlMinutes)),
      meshNodeId: meshNodeId,
    );
  }
}

void main() {
  // Ensure bindings initialized for any WidgetsBinding usage in service code
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('canUseCloudFeatures logic - online & signed in -> true', () async {
    final container = ProviderContainer(
      overrides: [
        // online stream emits true
        isOnlineProvider.overrideWithValue(true),
        isSignedInProvider.overrideWithValue(true),
      ],
    );

    final can = container.read(canUseCloudFeaturesProvider);
    expect(can, isTrue);
  });

  test(
    'Signal create uses useCloud=false when offline or unauthenticated',
    () async {
      final fake = FakeSignalService();

      final container = ProviderContainer(
        overrides: [
          // offline stream -> false
          isOnlineProvider.overrideWithValue(false),
          isSignedInProvider.overrideWithValue(false),
          // device connected
          isDeviceConnectedProvider.overrideWithValue(true),
          // inject fake signal service
          signalServiceProvider.overrideWithValue(fake),
        ],
      );

      final notifier = container.read(signalFeedProvider.notifier);

      final result = await notifier.createSignal(content: 'offline test');

      expect(result, isNotNull);
      expect(fake.lastUseCloud, isFalse);
      expect(fake.lastContent, equals('offline test'));

      container.dispose();
    },
  );
}
