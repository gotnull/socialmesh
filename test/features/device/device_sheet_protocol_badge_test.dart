// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/mesh_device.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';

void main() {
  group('Protocol Badge Widget Tests', () {
    testWidgets(
      'displays Meshtastic protocol badge when connected to Meshtastic device',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            meshDeviceInfoProvider.overrideWithValue(
              const MeshDeviceInfo(
                protocolType: MeshProtocolType.meshtastic,
                displayName: 'Test Meshtastic Node',
                nodeId: 'ABCD1234',
                firmwareVersion: '2.3.4',
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(home: _TestProtocolBadgeWidget()),
          ),
        );

        expect(find.text('Meshtastic'), findsOneWidget);
        expect(find.text('MeshCore'), findsNothing);
      },
    );

    testWidgets(
      'displays MeshCore protocol badge when connected to MeshCore device',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            meshDeviceInfoProvider.overrideWithValue(
              const MeshDeviceInfo(
                protocolType: MeshProtocolType.meshcore,
                displayName: 'Test MeshCore Node',
                nodeId: 'MC-001',
                firmwareVersion: '1.0.0',
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(home: _TestProtocolBadgeWidget()),
          ),
        );

        expect(find.text('MeshCore'), findsOneWidget);
        expect(find.text('Meshtastic'), findsNothing);
      },
    );

    testWidgets('displays Unknown when protocol type is unknown', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          meshDeviceInfoProvider.overrideWithValue(
            const MeshDeviceInfo(
              protocolType: MeshProtocolType.unknown,
              displayName: 'Unknown Device',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: _TestProtocolBadgeWidget()),
        ),
      );

      expect(find.text('Unknown'), findsOneWidget);
    });

    testWidgets('shows no protocol badge when not connected', (tester) async {
      final container = ProviderContainer(
        overrides: [meshDeviceInfoProvider.overrideWithValue(null)],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: _TestProtocolBadgeWidget()),
        ),
      );

      expect(find.text('Meshtastic'), findsNothing);
      expect(find.text('MeshCore'), findsNothing);
      expect(find.text('Unknown'), findsNothing);
      expect(find.text('Not Connected'), findsOneWidget);
    });

    testWidgets('displays device info from MeshDeviceInfo', (tester) async {
      final container = ProviderContainer(
        overrides: [
          meshDeviceInfoProvider.overrideWithValue(
            const MeshDeviceInfo(
              protocolType: MeshProtocolType.meshtastic,
              displayName: 'My Meshtastic Node',
              nodeId: '12345678',
              firmwareVersion: '2.5.0',
              hardwareModel: 'T-Beam',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: _TestDeviceInfoWidget()),
        ),
      );

      expect(find.text('My Meshtastic Node'), findsOneWidget);
      expect(find.text('12345678'), findsOneWidget);
      expect(find.text('2.5.0'), findsOneWidget);
    });
  });

  group('Ping Test State Widget Tests', () {
    testWidgets('shows idle state initially', (tester) async {
      final container = ProviderContainer();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: _TestPingWidget()),
        ),
      );

      expect(find.text('Idle'), findsOneWidget);
    });

    testWidgets('updates to in-progress state', (tester) async {
      final container = ProviderContainer(
        overrides: [
          pingTestProvider.overrideWith(() => _MockPingTestNotifier()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: _TestPingWidget()),
        ),
      );

      // Trigger ping
      await tester.tap(find.text('Ping'));
      await tester.pump();

      expect(find.text('In Progress'), findsOneWidget);
    });

    testWidgets('shows success state with latency', (tester) async {
      final container = ProviderContainer(
        overrides: [
          pingTestProvider.overrideWith(
            () => _SuccessPingTestNotifier(const Duration(milliseconds: 42)),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: _TestPingWidget()),
        ),
      );

      expect(find.text('Success: 42ms'), findsOneWidget);
    });

    testWidgets('shows failure state with error', (tester) async {
      final container = ProviderContainer(
        overrides: [
          pingTestProvider.overrideWith(
            () => _FailurePingTestNotifier('Connection lost'),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: _TestPingWidget()),
        ),
      );

      expect(find.text('Error: Connection lost'), findsOneWidget);
    });
  });

  group('MeshProtocolType', () {
    test('displayName returns correct values', () {
      expect(MeshProtocolType.meshtastic.displayName, equals('Meshtastic'));
      expect(MeshProtocolType.meshcore.displayName, equals('MeshCore'));
      expect(MeshProtocolType.unknown.displayName, equals('Unknown'));
    });
  });

  group('MeshDeviceInfo', () {
    test('equality works correctly', () {
      const info1 = MeshDeviceInfo(
        protocolType: MeshProtocolType.meshtastic,
        displayName: 'Test',
        nodeId: '123',
      );
      const info2 = MeshDeviceInfo(
        protocolType: MeshProtocolType.meshtastic,
        displayName: 'Test',
        nodeId: '123',
      );
      const info3 = MeshDeviceInfo(
        protocolType: MeshProtocolType.meshcore,
        displayName: 'Test',
        nodeId: '123',
      );

      expect(info1, equals(info2));
      expect(info1, isNot(equals(info3)));
    });

    test('copyWith works correctly', () {
      const original = MeshDeviceInfo(
        protocolType: MeshProtocolType.meshtastic,
        displayName: 'Original',
        nodeId: '123',
      );

      final copied = original.copyWith(displayName: 'Modified');

      expect(copied.displayName, equals('Modified'));
      expect(copied.protocolType, equals(MeshProtocolType.meshtastic));
      expect(copied.nodeId, equals('123'));
    });
  });

  group('PingTestState', () {
    test('isIdle returns correct value', () {
      expect(const PingTestState.idle().isIdle, isTrue);
      expect(const PingTestState.inProgress().isIdle, isFalse);
    });

    test('isInProgress returns correct value', () {
      expect(const PingTestState.inProgress().isInProgress, isTrue);
      expect(const PingTestState.idle().isInProgress, isFalse);
    });

    test('isSuccess returns correct value', () {
      expect(
        const PingTestState.success(Duration(milliseconds: 10)).isSuccess,
        isTrue,
      );
      expect(const PingTestState.idle().isSuccess, isFalse);
    });

    test('isFailure returns correct value', () {
      expect(const PingTestState.failure('error').isFailure, isTrue);
      expect(const PingTestState.idle().isFailure, isFalse);
    });
  });
}

// Test widgets for verifying protocol badge behavior
class _TestProtocolBadgeWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceInfo = ref.watch(meshDeviceInfoProvider);

    if (deviceInfo == null) {
      return const Scaffold(body: Center(child: Text('Not Connected')));
    }

    return Scaffold(
      body: Center(child: Text(deviceInfo.protocolType.displayName)),
    );
  }
}

class _TestDeviceInfoWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deviceInfo = ref.watch(meshDeviceInfoProvider);

    if (deviceInfo == null) {
      return const Scaffold(body: Center(child: Text('No device')));
    }

    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(deviceInfo.displayName),
          if (deviceInfo.nodeId != null) Text(deviceInfo.nodeId!),
          if (deviceInfo.firmwareVersion != null)
            Text(deviceInfo.firmwareVersion!),
        ],
      ),
    );
  }
}

class _TestPingWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pingState = ref.watch(pingTestProvider);

    String text;
    if (pingState.isIdle) {
      text = 'Idle';
    } else if (pingState.isInProgress) {
      text = 'In Progress';
    } else if (pingState.isSuccess) {
      text = 'Success: ${pingState.latency!.inMilliseconds}ms';
    } else {
      text = 'Error: ${pingState.errorMessage}';
    }

    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(text),
          ElevatedButton(
            onPressed: () => ref.read(pingTestProvider.notifier).ping(),
            child: const Text('Ping'),
          ),
        ],
      ),
    );
  }
}

// Mock notifiers for testing
class _MockPingTestNotifier extends PingTestNotifier {
  @override
  Future<void> ping() async {
    state = const PingTestState.inProgress();
  }
}

class _SuccessPingTestNotifier extends PingTestNotifier {
  final Duration _latency;

  _SuccessPingTestNotifier(this._latency);

  @override
  PingTestState build() => PingTestState.success(_latency);
}

class _FailurePingTestNotifier extends PingTestNotifier {
  final String _error;

  _FailurePingTestNotifier(this._error);

  @override
  PingTestState build() => PingTestState.failure(_error);
}
