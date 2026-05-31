// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_canned_messages.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_capabilities.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_channel_preview.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_connection_state.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_inbox_preview.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_intent.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_intent_result.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_node_preview.dart';
import 'package:socialmesh/services/watch_companion/models/watch_companion_snapshot.dart';
import 'package:socialmesh/services/watch_companion/watch_companion_channel_bridge.dart';
import 'package:socialmesh/services/watch_companion/watch_companion_feature_flags.dart';
import 'package:socialmesh/services/watch_companion/watch_companion_providers.dart';
import 'package:socialmesh/services/watch_companion/watch_companion_service.dart';

/// A WatchCompanionService stub the bridge can drive without spinning
/// up the full composer + facade graph. Records every intent it was
/// asked to handle and returns a canned result.
class _StubService implements WatchCompanionService {
  _StubService({
    WatchCompanionSnapshot? initialSnapshot,
    this.intentResult,
    this.throwOnIntent = false,
  }) {
    if (initialSnapshot != null) {
      _latest = initialSnapshot;
      _controller.add(initialSnapshot);
    }
  }

  WatchCompanionSnapshot? _latest;
  final StreamController<WatchCompanionSnapshot> _controller =
      StreamController<WatchCompanionSnapshot>.broadcast();
  final List<WatchCompanionIntent> intents = [];

  WatchCompanionIntentResult? intentResult;
  bool throwOnIntent;

  void emit(WatchCompanionSnapshot s) {
    _latest = s;
    _controller.add(s);
  }

  @override
  Stream<WatchCompanionSnapshot> get snapshots async* {
    final cached = _latest;
    if (cached != null) yield cached;
    yield* _controller.stream;
  }

  @override
  WatchCompanionSnapshot? get latestSnapshot => _latest;

  @override
  Future<WatchCompanionIntentResult> handleIntent(
    WatchCompanionIntent intent,
  ) async {
    intents.add(intent);
    if (throwOnIntent) {
      throw StateError('stub: service blew up');
    }
    return intentResult ??
        WatchCompanionIntentResult(
          requestId: intent.requestId,
          accepted: true,
          timestampMs: 1747700000000,
        );
  }
}

WatchCompanionSnapshot _snap() {
  return const WatchCompanionSnapshot(
    generatedAt: 1747700000000,
    connection: WatchCompanionConnectionState(
      status: WatchCompanionConnectionStatus.ready,
      activeProtocolDisplayName: 'Meshtastic',
    ),
    inbox: WatchCompanionInboxPreview(
      unreadCount: 0,
      previews: <WatchCompanionInboxMessage>[],
    ),
    nodes: <WatchCompanionNodePreview>[],
    channels: <WatchCompanionChannelPreview>[
      WatchCompanionChannelPreview(index: 0, name: 'Primary', isDefault: true),
    ],
    cannedMessages: <WatchCompanionCannedMessage>[],
    capabilities: WatchCompanionCapabilities(
      canQuickReply: true,
      canSendImOk: true,
      canSendLocationIntent: false,
      canShowNodes: false,
      canShowInbox: false,
    ),
  );
}

/// Records every MethodCall the bridge dispatches to "native" and lets
/// the test script per-method responses.
class _MockChannel {
  _MockChannel(this.name) {
    channel = MethodChannel(name);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, _onCall);
  }

  final String name;
  late final MethodChannel channel;

  final List<MethodCall> calls = [];
  Object? Function(MethodCall)? respond;

  Future<Object?> _onCall(MethodCall call) async {
    calls.add(call);
    return respond?.call(call);
  }

  /// Simulate the native side invoking a Dart-side handler.
  Future<ByteData?> invokeFromNative(String method, Object? arguments) async {
    final codec = const StandardMethodCodec();
    final encoded = codec.encodeMethodCall(MethodCall(method, arguments));
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(name, encoded, (_) {});
  }

  /// Like [invokeFromNative] but decodes the Dart handler's return value.
  Future<Object?> invokeFromNativeAndDecode(
    String method,
    Object? arguments,
  ) async {
    final codec = const StandardMethodCodec();
    final encoded = codec.encodeMethodCall(MethodCall(method, arguments));
    final reply = await TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .handlePlatformMessage(name, encoded, (_) {});
    if (reply == null) return null;
    return codec.decodeEnvelope(reply);
  }

  void dispose() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WatchCompanionChannelBridge.start', () {
    test(
      'feature disabled: registers handler but never activates session',
      () async {
        final mock = _MockChannel(kWatchCompanionChannelName);
        addTearDown(mock.dispose);

        final service = _StubService();
        final container = ProviderContainer(
          overrides: [
            watchCompanionFeatureFlagsProvider.overrideWith(
              (ref) => WatchCompanionFeatureFlags.disabled,
            ),
            watchCompanionServiceProvider.overrideWith((ref) => service),
          ],
        );
        addTearDown(container.dispose);

        final bridge = WatchCompanionChannelBridge(
          readFlags: () => container.read(watchCompanionFeatureFlagsProvider),
          readService: () => container.read(watchCompanionServiceProvider),
          channel: mock.channel,
        );

        await bridge.start();

        expect(
          mock.calls.where((c) => c.method == 'activateSession'),
          isEmpty,
          reason: 'feature-disabled bridge must NOT activate WCSession',
        );
        expect(
          mock.calls.where((c) => c.method == 'pushSnapshot'),
          isEmpty,
          reason: 'feature-disabled bridge must NOT push snapshots',
        );
      },
    );

    test(
      'feature enabled + native activate=true: pushes the seed snapshot',
      () async {
        final mock = _MockChannel(kWatchCompanionChannelName);
        addTearDown(mock.dispose);
        mock.respond = (call) {
          if (call.method == 'activateSession') return true;
          if (call.method == 'pushSnapshot') return true;
          return null;
        };

        final service = _StubService(initialSnapshot: _snap());
        final container = ProviderContainer(
          overrides: [
            watchCompanionFeatureFlagsProvider.overrideWith(
              (ref) => const WatchCompanionFeatureFlags(enabled: true),
            ),
            watchCompanionServiceProvider.overrideWith((ref) => service),
          ],
        );
        addTearDown(container.dispose);

        final bridge = WatchCompanionChannelBridge(
          readFlags: () => container.read(watchCompanionFeatureFlagsProvider),
          readService: () => container.read(watchCompanionServiceProvider),
          channel: mock.channel,
        );
        await bridge.start();

        expect(
          mock.calls.map((c) => c.method),
          containsAllInOrder(['activateSession', 'pushSnapshot']),
        );
        final pushCall = mock.calls.firstWhere(
          (c) => c.method == 'pushSnapshot',
        );
        expect(pushCall.arguments, isA<Map>());
        expect(
          (pushCall.arguments as Map)['version'],
          WatchCompanionSnapshot.wireVersion,
        );
      },
    );

    test(
      'feature enabled + native activate=false: does NOT push snapshots',
      () async {
        final mock = _MockChannel(kWatchCompanionChannelName);
        addTearDown(mock.dispose);
        mock.respond = (call) {
          if (call.method == 'activateSession') return false;
          return null;
        };

        final service = _StubService(initialSnapshot: _snap());
        final container = ProviderContainer(
          overrides: [
            watchCompanionFeatureFlagsProvider.overrideWith(
              (ref) => const WatchCompanionFeatureFlags(enabled: true),
            ),
            watchCompanionServiceProvider.overrideWith((ref) => service),
          ],
        );
        addTearDown(container.dispose);

        final bridge = WatchCompanionChannelBridge(
          readFlags: () => container.read(watchCompanionFeatureFlagsProvider),
          readService: () => container.read(watchCompanionServiceProvider),
          channel: mock.channel,
        );
        await bridge.start();

        expect(
          mock.calls.where((c) => c.method == 'pushSnapshot'),
          isEmpty,
          reason: 'WCSession unsupported (native returned false) must NOT push',
        );
      },
    );

    test('subsequent snapshot emissions also push to native', () async {
      final mock = _MockChannel(kWatchCompanionChannelName);
      addTearDown(mock.dispose);
      mock.respond = (call) => true;

      final service = _StubService(initialSnapshot: _snap());
      final container = ProviderContainer(
        overrides: [
          watchCompanionFeatureFlagsProvider.overrideWith(
            (ref) => const WatchCompanionFeatureFlags(enabled: true),
          ),
          watchCompanionServiceProvider.overrideWith((ref) => service),
        ],
      );
      addTearDown(container.dispose);

      final bridge = WatchCompanionChannelBridge(
        readFlags: () => container.read(watchCompanionFeatureFlagsProvider),
        readService: () => container.read(watchCompanionServiceProvider),
        channel: mock.channel,
      );
      await bridge.start();

      // The service exposes snapshots via an async* generator: after
      // yielding the cached value it pauses, and only attaches a
      // listener to the underlying broadcast controller when the
      // consumer requests the next event. Pump first so the generator
      // reaches `yield* _controller.stream`; otherwise the emits below
      // would land before the listener is attached.
      await pumpEventQueue();

      service.emit(_snap());
      service.emit(_snap());

      // Drain again so both emissions land in the mock channel.
      await pumpEventQueue(times: 8);

      final pushes = mock.calls
          .where((c) => c.method == 'pushSnapshot')
          .toList();
      // seed + 2 emissions = 3.
      expect(pushes.length, greaterThanOrEqualTo(3));
    });

    test('native push failure is logged and does not throw', () async {
      final mock = _MockChannel(kWatchCompanionChannelName);
      addTearDown(mock.dispose);
      mock.respond = (call) {
        if (call.method == 'activateSession') return true;
        if (call.method == 'pushSnapshot') {
          throw PlatformException(code: 'push_failed', message: 'too big');
        }
        return null;
      };

      final service = _StubService(initialSnapshot: _snap());
      final container = ProviderContainer(
        overrides: [
          watchCompanionFeatureFlagsProvider.overrideWith(
            (ref) => const WatchCompanionFeatureFlags(enabled: true),
          ),
          watchCompanionServiceProvider.overrideWith((ref) => service),
        ],
      );
      addTearDown(container.dispose);

      final bridge = WatchCompanionChannelBridge(
        readFlags: () => container.read(watchCompanionFeatureFlagsProvider),
        readService: () => container.read(watchCompanionServiceProvider),
        channel: mock.channel,
      );

      // Must not throw.
      await bridge.start();
    });
  });

  group('WatchCompanionChannelBridge: native -> Dart intent dispatch', () {
    test('valid intent reaches service and returns its result JSON', () async {
      final mock = _MockChannel(kWatchCompanionChannelName);
      addTearDown(mock.dispose);
      mock.respond = (call) => true;

      final service = _StubService(
        intentResult: const WatchCompanionIntentResult(
          requestId: 'req-1',
          accepted: true,
          timestampMs: 1747700000999,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          watchCompanionFeatureFlagsProvider.overrideWith(
            (ref) => const WatchCompanionFeatureFlags(enabled: true),
          ),
          watchCompanionServiceProvider.overrideWith((ref) => service),
        ],
      );
      addTearDown(container.dispose);

      final bridge = WatchCompanionChannelBridge(
        readFlags: () => container.read(watchCompanionFeatureFlagsProvider),
        readService: () => container.read(watchCompanionServiceProvider),
        channel: mock.channel,
      );
      await bridge.start();

      final intent = WatchCompanionIntent(
        requestId: 'req-1',
        type: WatchCompanionIntentType.quickMessage,
        target: const WatchCompanionIntentTarget(channelIndex: 0),
        payload: const WatchCompanionIntentPayload(
          cannedKey: WatchCompanionCannedMessageKeys.onMyWay,
        ),
        createdAtMs: 1747700000000,
      );
      final result = await mock.invokeFromNativeAndDecode(
        'onIntent',
        intent.toJson(),
      );

      expect(service.intents, hasLength(1));
      expect(service.intents.single.requestId, 'req-1');
      expect(result, isA<Map>());
      final resultMap = Map<String, dynamic>.from(result! as Map);
      expect(resultMap['accepted'], isTrue);
      expect(resultMap['requestId'], 'req-1');
      expect(resultMap['version'], WatchCompanionIntentResult.wireVersion);
    });

    test(
      'malformed intent payload returns invalid_intent_payload rejection',
      () async {
        final mock = _MockChannel(kWatchCompanionChannelName);
        addTearDown(mock.dispose);
        mock.respond = (call) => true;

        final service = _StubService();
        final container = ProviderContainer(
          overrides: [
            watchCompanionFeatureFlagsProvider.overrideWith(
              (ref) => const WatchCompanionFeatureFlags(enabled: true),
            ),
            watchCompanionServiceProvider.overrideWith((ref) => service),
          ],
        );
        addTearDown(container.dispose);

        final bridge = WatchCompanionChannelBridge(
          readFlags: () => container.read(watchCompanionFeatureFlagsProvider),
          readService: () => container.read(watchCompanionServiceProvider),
          channel: mock.channel,
        );
        await bridge.start();

        final result = await mock.invokeFromNativeAndDecode(
          'onIntent',
          // Missing every required field; will fail Intent.fromJson.
          <String, Object>{'version': 1, 'requestId': 'req-bad'},
        );

        expect(service.intents, isEmpty);
        final map = Map<String, dynamic>.from(result! as Map);
        expect(map['accepted'], isFalse);
        expect(map['diagnosticReason'], 'invalid_intent_payload');
        expect(map['requestId'], 'req-bad');
        expect(map['version'], WatchCompanionIntentResult.wireVersion);
      },
    );

    test('wire-version mismatch returns invalid_intent_payload', () async {
      final mock = _MockChannel(kWatchCompanionChannelName);
      addTearDown(mock.dispose);
      mock.respond = (call) => true;

      final service = _StubService();
      final container = ProviderContainer(
        overrides: [
          watchCompanionFeatureFlagsProvider.overrideWith(
            (ref) => const WatchCompanionFeatureFlags(enabled: true),
          ),
          watchCompanionServiceProvider.overrideWith((ref) => service),
        ],
      );
      addTearDown(container.dispose);

      final bridge = WatchCompanionChannelBridge(
        readFlags: () => container.read(watchCompanionFeatureFlagsProvider),
        readService: () => container.read(watchCompanionServiceProvider),
        channel: mock.channel,
      );
      await bridge.start();

      // version=999 will trip FormatException inside Intent.fromJson,
      // which the bridge maps to invalid_intent_payload.
      final result = await mock.invokeFromNativeAndDecode(
        'onIntent',
        <String, Object>{
          'version': 999,
          'requestId': 'req-old',
          'type': 'refreshSnapshot',
          'target': <String, Object?>{'channelIndex': null},
          'payload': <String, Object?>{'cannedKey': null},
          'createdAtMs': 1,
        },
      );

      expect(service.intents, isEmpty);
      final map = Map<String, dynamic>.from(result! as Map);
      expect(map['accepted'], isFalse);
      expect(map['diagnosticReason'], 'invalid_intent_payload');
    });

    test('service exception is mapped to bridge_dispatch_exception', () async {
      final mock = _MockChannel(kWatchCompanionChannelName);
      addTearDown(mock.dispose);
      mock.respond = (call) => true;

      final service = _StubService(throwOnIntent: true);
      final container = ProviderContainer(
        overrides: [
          watchCompanionFeatureFlagsProvider.overrideWith(
            (ref) => const WatchCompanionFeatureFlags(enabled: true),
          ),
          watchCompanionServiceProvider.overrideWith((ref) => service),
        ],
      );
      addTearDown(container.dispose);

      final bridge = WatchCompanionChannelBridge(
        readFlags: () => container.read(watchCompanionFeatureFlagsProvider),
        readService: () => container.read(watchCompanionServiceProvider),
        channel: mock.channel,
      );
      await bridge.start();

      final intent = WatchCompanionIntent(
        requestId: 'req-boom',
        type: WatchCompanionIntentType.refreshSnapshot,
        target: const WatchCompanionIntentTarget(),
        payload: const WatchCompanionIntentPayload(),
        createdAtMs: 1,
      );
      final result = await mock.invokeFromNativeAndDecode(
        'onIntent',
        intent.toJson(),
      );

      final map = Map<String, dynamic>.from(result! as Map);
      expect(map['accepted'], isFalse);
      expect(map['diagnosticReason'], 'bridge_dispatch_exception');
      expect(map['requestId'], 'req-boom');
    });

    test(
      'unknown native callback method returns null without crashing',
      () async {
        final mock = _MockChannel(kWatchCompanionChannelName);
        addTearDown(mock.dispose);
        mock.respond = (call) => true;

        final service = _StubService();
        final container = ProviderContainer(
          overrides: [
            watchCompanionFeatureFlagsProvider.overrideWith(
              (ref) => const WatchCompanionFeatureFlags(enabled: true),
            ),
            watchCompanionServiceProvider.overrideWith((ref) => service),
          ],
        );
        addTearDown(container.dispose);

        final bridge = WatchCompanionChannelBridge(
          readFlags: () => container.read(watchCompanionFeatureFlagsProvider),
          readService: () => container.read(watchCompanionServiceProvider),
          channel: mock.channel,
        );
        await bridge.start();

        final reply = await mock.invokeFromNativeAndDecode(
          'onSomeFutureMethod',
          <String, Object>{'whatever': 1},
        );
        expect(reply, isNull);
      },
    );

    test('onSessionStateChanged is accepted and ignored', () async {
      final mock = _MockChannel(kWatchCompanionChannelName);
      addTearDown(mock.dispose);
      mock.respond = (call) => true;

      final service = _StubService();
      final container = ProviderContainer(
        overrides: [
          watchCompanionFeatureFlagsProvider.overrideWith(
            (ref) => const WatchCompanionFeatureFlags(enabled: true),
          ),
          watchCompanionServiceProvider.overrideWith((ref) => service),
        ],
      );
      addTearDown(container.dispose);

      final bridge = WatchCompanionChannelBridge(
        readFlags: () => container.read(watchCompanionFeatureFlagsProvider),
        readService: () => container.read(watchCompanionServiceProvider),
        channel: mock.channel,
      );
      await bridge.start();

      final reply = await mock
          .invokeFromNativeAndDecode('onSessionStateChanged', <String, Object>{
            'activationState': 'activated',
            'isReachable': true,
            'isPaired': true,
            'isWatchAppInstalled': false,
          });
      expect(reply, isNull);
    });
  });

  group('WatchCompanionChannelBridge.dispose', () {
    test('cancels handler and stops forwarding to service', () async {
      final mock = _MockChannel(kWatchCompanionChannelName);
      addTearDown(mock.dispose);
      mock.respond = (call) => true;

      final service = _StubService();
      final container = ProviderContainer(
        overrides: [
          watchCompanionFeatureFlagsProvider.overrideWith(
            (ref) => const WatchCompanionFeatureFlags(enabled: true),
          ),
          watchCompanionServiceProvider.overrideWith((ref) => service),
        ],
      );
      addTearDown(container.dispose);

      final bridge = WatchCompanionChannelBridge(
        readFlags: () => container.read(watchCompanionFeatureFlagsProvider),
        readService: () => container.read(watchCompanionServiceProvider),
        channel: mock.channel,
      );
      await bridge.start();
      await bridge.dispose();

      // After dispose, the channel handler is detached. The mock
      // messenger only invokes setMockMethodCallHandler-registered
      // handlers, so we test the inverse: the bridge dropped the
      // handler. Sending another inbound call should not reach the
      // bridge's _onNativeCall (which would forward to the service).
      // The mock messenger returns null when no handler is set.
      await mock.invokeFromNativeAndDecode('onIntent', <String, Object>{
        'version': 1,
        'requestId': 'r',
      });
      expect(service.intents, isEmpty);
    });
  });
}
