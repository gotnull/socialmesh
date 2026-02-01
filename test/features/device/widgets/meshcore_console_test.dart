// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/device/widgets/meshcore_console.dart';
import 'package:socialmesh/models/mesh_device.dart';
import 'package:socialmesh/providers/meshcore_providers.dart';
import 'package:socialmesh/services/meshcore/protocol/meshcore_capture.dart';

void main() {
  group('MeshCoreConsole.shouldShow', () {
    test('returns true for MeshCore protocol in debug mode', () {
      // Note: kDebugMode is true in test environment
      expect(MeshCoreConsole.shouldShow(MeshProtocolType.meshcore), isTrue);
    });

    test('returns false for Meshtastic protocol', () {
      expect(MeshCoreConsole.shouldShow(MeshProtocolType.meshtastic), isFalse);
    });

    test('returns false for unknown protocol', () {
      expect(MeshCoreConsole.shouldShow(MeshProtocolType.unknown), isFalse);
    });

    test('returns false for null protocol', () {
      expect(MeshCoreConsole.shouldShow(null), isFalse);
    });
  });

  group('MeshCoreConsole widget', () {
    testWidgets('renders header with frame count', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshCoreCaptureSnapshotProvider.overrideWith(() {
              return _TestCaptureNotifier(
                const MeshCoreCaptureSnapshot.empty(),
              );
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: MeshCoreConsole())),
        ),
      );

      // Header should be visible
      expect(find.text('MeshCore Console'), findsOneWidget);
      expect(find.text('DEV'), findsOneWidget);
      expect(find.text('0 frames captured'), findsOneWidget);
    });

    testWidgets('expands to show action buttons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshCoreCaptureSnapshotProvider.overrideWith(() {
              return _TestCaptureNotifier(
                const MeshCoreCaptureSnapshot.empty(),
              );
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: MeshCoreConsole()),
            ),
          ),
        ),
      );

      // Initially collapsed - buttons not visible
      expect(find.text('Refresh'), findsNothing);

      // Tap to expand
      await tester.tap(find.text('MeshCore Console'));
      await tester.pumpAndSettle();

      // Buttons should now be visible
      expect(find.text('Refresh'), findsOneWidget);
      expect(find.text('Copy Hex'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);
    });

    testWidgets('shows frame list when frames are captured', (tester) async {
      final frames = [
        CapturedFrame(
          direction: CaptureDirection.tx,
          timestampMs: 0,
          code: 0x07,
          payload: Uint8List(0),
        ),
        CapturedFrame(
          direction: CaptureDirection.rx,
          timestampMs: 50,
          code: 0x01,
          payload: Uint8List(32),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshCoreCaptureSnapshotProvider.overrideWith(() {
              return _TestCaptureNotifier(
                MeshCoreCaptureSnapshot(
                  frames: frames,
                  totalCount: 2,
                  isActive: true,
                ),
              );
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: MeshCoreConsole()),
            ),
          ),
        ),
      );

      // Shows frame count
      expect(find.text('2 frames captured'), findsOneWidget);

      // Expand
      await tester.tap(find.text('MeshCore Console'));
      await tester.pumpAndSettle();

      // Should show TX and RX badges
      expect(find.text('TX'), findsOneWidget);
      expect(find.text('RX'), findsOneWidget);

      // Should show hex codes
      expect(find.text('0x07'), findsOneWidget);
      expect(find.text('0x01'), findsOneWidget);

      // Should show payload sizes
      expect(find.text('0B'), findsOneWidget);
      expect(find.text('32B'), findsOneWidget);
    });

    testWidgets('shows empty state when no frames', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshCoreCaptureSnapshotProvider.overrideWith(() {
              return _TestCaptureNotifier(
                const MeshCoreCaptureSnapshot.empty(),
              );
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: MeshCoreConsole()),
            ),
          ),
        ),
      );

      // Expand
      await tester.tap(find.text('MeshCore Console'));
      await tester.pumpAndSettle();

      expect(find.text('No frames captured yet'), findsOneWidget);
    });

    testWidgets('Clear button clears frames', (tester) async {
      final notifier = _TestCaptureNotifier(
        MeshCoreCaptureSnapshot(
          frames: [
            CapturedFrame(
              direction: CaptureDirection.tx,
              timestampMs: 0,
              code: 0x07,
              payload: Uint8List(0),
            ),
          ],
          totalCount: 1,
          isActive: true,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshCoreCaptureSnapshotProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: MeshCoreConsole()),
            ),
          ),
        ),
      );

      // Expand
      await tester.tap(find.text('MeshCore Console'));
      await tester.pumpAndSettle();

      // Tap clear
      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      // Verify clear was called
      expect(notifier.clearCalled, isTrue);
    });
  });

  group('MeshCoreConsole clipboard', () {
    testWidgets('Copy hex log copies to clipboard', (tester) async {
      // Set up clipboard mock
      final clipboardData = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall methodCall) async {
          if (methodCall.method == 'Clipboard.setData') {
            final data = methodCall.arguments as Map<String, dynamic>;
            clipboardData.add(data['text'] as String);
          }
          return null;
        },
      );

      final notifier = _TestCaptureNotifier(
        MeshCoreCaptureSnapshot(
          frames: [
            CapturedFrame(
              direction: CaptureDirection.tx,
              timestampMs: 0,
              code: 0x07,
              payload: Uint8List(0),
            ),
          ],
          totalCount: 1,
          isActive: true,
        ),
        hexLog: '[TX] @0ms 0x07: (test log)',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            meshCoreCaptureSnapshotProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: MeshCoreConsole()),
            ),
          ),
        ),
      );

      // Expand
      await tester.tap(find.text('MeshCore Console'));
      await tester.pumpAndSettle();

      // Tap Copy Hex
      await tester.tap(find.text('Copy Hex'));
      await tester.pumpAndSettle();

      // Verify clipboard was set
      expect(clipboardData.isNotEmpty, isTrue);
      expect(clipboardData.first, contains('test log'));
    });
  });
}

/// Test notifier that allows controlling the snapshot state.
class _TestCaptureNotifier extends MeshCoreCaptureNotifier {
  MeshCoreCaptureSnapshot _state;
  final String hexLog;
  bool clearCalled = false;
  bool refreshCalled = false;

  _TestCaptureNotifier(this._state, {this.hexLog = '(no capture active)'});

  @override
  MeshCoreCaptureSnapshot build() => _state;

  @override
  void refresh() {
    refreshCalled = true;
  }

  @override
  void clear() {
    clearCalled = true;
    _state = const MeshCoreCaptureSnapshot.empty();
    state = _state;
  }

  @override
  String getHexLog() => hexLog;
}
