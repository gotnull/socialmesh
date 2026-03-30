// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Widget tests for VoiceRecordingOverlay — verifies the four-phase flow
// (idle → recording → paused → reviewing) and crash-free behaviour.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/file_transfer/widgets/voice_recording_overlay.dart';
import 'package:socialmesh/l10n/app_localizations.dart';

// =============================================================================
// Helpers
// =============================================================================

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

VoiceRecordingOverlay _overlay({
  Future<Stream<double>?> Function()? onStartRecording,
  VoidCallback? onRecordingStopped,
  VoidCallback? onSend,
  VoidCallback? onCancel,
  Future<Stream<double>?> Function()? onRestart,
  VoidCallback? onPauseRecording,
  VoidCallback? onResumeRecording,
  ValueNotifier<bool>? autoStopNotifier,
}) {
  return VoiceRecordingOverlay(
    onStartRecording: onStartRecording ?? () async => null,
    onRecordingStopped: onRecordingStopped ?? () {},
    onSend: onSend ?? () {},
    onCancel: onCancel ?? () {},
    onRestart: onRestart ?? () async => null,
    onPauseRecording: onPauseRecording,
    onResumeRecording: onResumeRecording,
    autoStopNotifier: autoStopNotifier,
  );
}

/// Taps the big red record button to transition from idle to recording.
Future<void> _tapRecord(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.mic_rounded));
  await tester.pump();
  await tester.pump();
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  group('VoiceRecordingOverlay — idle phase', () {
    testWidgets('starts in idle phase with record button', (tester) async {
      await tester.pumpWidget(_wrap(_overlay()));
      await tester.pump();

      // Idle phase shows the mic icon (record button).
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      // Should show 'Tap to record' hint text.
      expect(find.text('Tap to record'), findsOneWidget);
      // REC pill should NOT be visible in idle.
      expect(find.text('REC'), findsNothing);
    });

    testWidgets('cancel from idle invokes onCancel', (tester) async {
      var called = false;
      await tester.pumpWidget(_wrap(_overlay(onCancel: () => called = true)));
      await tester.pump();

      await tester.tap(find.text('Cancel'));
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('tapping record invokes onStartRecording', (tester) async {
      var called = false;
      await tester.pumpWidget(
        _wrap(
          _overlay(
            onStartRecording: () async {
              called = true;
              return null;
            },
          ),
        ),
      );
      await tester.pump();

      await _tapRecord(tester);

      expect(called, isTrue);
    });
  });

  group('VoiceRecordingOverlay — recording phase', () {
    testWidgets('transitions to recording after tapping record', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_overlay()));
      await tester.pump();

      await _tapRecord(tester);

      // REC pill should now be visible.
      expect(find.text('REC'), findsOneWidget);
      // Timer text should show 0:00.
      expect(find.text('0:00'), findsOneWidget);
    });

    testWidgets('pause button invokes onPauseRecording', (tester) async {
      var called = false;
      await tester.pumpWidget(
        _wrap(_overlay(onPauseRecording: () => called = true)),
      );
      await tester.pump();
      await _tapRecord(tester);

      await tester.tap(find.text('Pause'));
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('cancel during recording shows confirmation', (tester) async {
      var called = false;
      await tester.pumpWidget(_wrap(_overlay(onCancel: () => called = true)));
      await tester.pump();
      await _tapRecord(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      // Complete the sheet push animation (350ms) so it doesn't leak.
      await tester.pump(const Duration(milliseconds: 400));

      // Confirmation sheet should appear.
      expect(find.text('Discard recording?'), findsOneWidget);

      // Tap Discard to confirm.
      await tester.tap(find.text('Discard'));
      await tester.pump();
      // Complete the sheet pop animation (250ms).
      await tester.pump(const Duration(milliseconds: 300));

      expect(called, isTrue);
    });

    testWidgets('cancel during recording can be dismissed', (tester) async {
      var called = false;
      await tester.pumpWidget(_wrap(_overlay(onCancel: () => called = true)));
      await tester.pump();
      await _tapRecord(tester);

      await tester.tap(find.text('Cancel'));
      await tester.pump();
      // Complete the sheet push animation (350ms).
      await tester.pump(const Duration(milliseconds: 400));

      // Tap the cancel button in the confirmation sheet to keep recording.
      // AppBottomSheet.showConfirm uses 'Cancel' as default cancelLabel.
      // There are two 'Cancel' texts — the overlay button and the sheet button.
      // The sheet's Cancel is rendered later in the tree, so tap the last one.
      await tester.tap(find.text('Cancel').last);
      await tester.pump();
      // Complete the sheet pop animation (250ms).
      await tester.pump(const Duration(milliseconds: 300));

      // onCancel should NOT have been called.
      expect(called, isFalse);
    });

    testWidgets('stop transitions to review phase', (tester) async {
      await tester.pumpWidget(_wrap(_overlay()));
      await tester.pump();
      await _tapRecord(tester);

      // Find the stop button — it's a Container with a white rounded square
      // inside the red circle. The GestureDetector wrapping the 80×80 circle
      // should contain a white container (the stop square).
      // Tap into the center of the recording actions area.
      final stopFinder = find.ancestor(
        of: find.byWidgetPredicate((w) {
          if (w is Container && w.decoration is BoxDecoration) {
            final dec = w.decoration! as BoxDecoration;
            return dec.shape == BoxShape.circle &&
                dec.color == const Color(0xFFFF3B30);
          }
          return false;
        }),
        matching: find.byType(GestureDetector),
      );
      await tester.tap(stopFinder.first);
      await tester.pump();

      // Review phase shows send arrow.
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });
  });

  group('VoiceRecordingOverlay — paused phase', () {
    testWidgets('pause transitions to paused state', (tester) async {
      await tester.pumpWidget(_wrap(_overlay()));
      await tester.pump();
      await _tapRecord(tester);

      await tester.tap(find.text('Pause'));
      await tester.pump();

      // PAUSED pill should be visible (pill + subtitle both show it).
      expect(find.text('PAUSED'), findsWidgets);
      // Resume button should appear.
      expect(find.text('Resume'), findsOneWidget);
    });

    testWidgets('resume from paused invokes onResumeRecording', (tester) async {
      var called = false;
      await tester.pumpWidget(
        _wrap(_overlay(onResumeRecording: () => called = true)),
      );
      await tester.pump();
      await _tapRecord(tester);

      await tester.tap(find.text('Pause'));
      await tester.pump();

      await tester.tap(find.text('Resume'));
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('resume from paused returns to recording phase', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_overlay()));
      await tester.pump();
      await _tapRecord(tester);

      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(find.text('PAUSED'), findsWidgets);

      await tester.tap(find.text('Resume'));
      await tester.pump();

      // Should be back to recording: REC pill visible, PAUSED gone.
      expect(find.text('REC'), findsOneWidget);
      expect(find.text('PAUSED'), findsNothing);
      expect(find.text('REC'), findsOneWidget);
      expect(find.text('PAUSED'), findsNothing);
    });
  });

  group('VoiceRecordingOverlay — review phase', () {
    testWidgets('autoStopNotifier transitions to review phase', (tester) async {
      final notifier = ValueNotifier<bool>(false);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(_wrap(_overlay(autoStopNotifier: notifier)));
      await tester.pump();
      await _tapRecord(tester);

      notifier.value = true;
      await tester.pump();

      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);
    });

    testWidgets('send button in review phase invokes onSend', (tester) async {
      var called = false;
      final notifier = ValueNotifier<bool>(false);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(
        _wrap(
          _overlay(onSend: () => called = true, autoStopNotifier: notifier),
        ),
      );
      await tester.pump();
      await _tapRecord(tester);

      notifier.value = true;
      await tester.pump();

      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('retake resets to idle phase', (tester) async {
      final notifier = ValueNotifier<bool>(false);
      addTearDown(notifier.dispose);

      await tester.pumpWidget(_wrap(_overlay(autoStopNotifier: notifier)));
      await tester.pump();
      await _tapRecord(tester);

      // Enter review phase via auto-stop.
      notifier.value = true;
      await tester.pump();
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

      // Tap Retake — confirmation sheet should appear.
      await tester.tap(find.text('Retake'));
      // Pump through the bottom sheet open animation (repeating overlay
      // animations prevent pumpAndSettle, so pump a fixed duration instead).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Confirm discard in the modal.
      expect(find.text('Discard'), findsOneWidget);
      await tester.tap(find.text('Discard'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Should be back to idle: record button visible.
      expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
      expect(find.text('Tap to record'), findsOneWidget);
    });
  });

  group('VoiceRecordingOverlay — amplitude stream', () {
    testWidgets('subscribes to amplitude stream from onStartRecording', (
      tester,
    ) async {
      final controller = StreamController<double>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _wrap(_overlay(onStartRecording: () async => controller.stream)),
      );
      await tester.pump();
      await _tapRecord(tester);

      // Push a few amplitude samples.
      for (final level in [0.1, 0.5, 0.8, 0.3]) {
        controller.add(level);
        await tester.pump(const Duration(milliseconds: 50));
      }

      // Waveform widget (CustomPaint) should still be present after samples.
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('disposes subscription on widget removal', (tester) async {
      final controller = StreamController<double>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _wrap(_overlay(onStartRecording: () async => controller.stream)),
      );
      await tester.pump();
      await _tapRecord(tester);

      controller.add(0.5);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      // Adding to the stream after disposal must not crash.
      expect(() => controller.add(0.9), returnsNormally);
    });
  });

  group('VoiceRecordingOverlay — timer advancement', () {
    testWidgets('timer increments elapsed time while recording', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_overlay()));
      await tester.pump();
      await _tapRecord(tester);

      // Advance fake async clock by just over 1 second.
      await tester.pump(const Duration(milliseconds: 1100));

      // After 1 second, timer should read '0:01'.
      expect(find.text('0:01'), findsOneWidget);
    });

    testWidgets('timer does not advance when paused', (tester) async {
      await tester.pumpWidget(_wrap(_overlay()));
      await tester.pump();
      await _tapRecord(tester);

      // Advance 1 second while recording.
      await tester.pump(const Duration(milliseconds: 1100));
      expect(find.text('0:01'), findsOneWidget);

      // Pause.
      await tester.tap(find.text('Pause'));
      await tester.pump();

      // Advance another 2 seconds while paused.
      await tester.pump(const Duration(milliseconds: 2000));

      // Timer should still read '0:01' (frozen).
      expect(find.text('0:01'), findsOneWidget);
    });
  });

  group('VoiceRecordingOverlay — crash-free rendering', () {
    testWidgets('renders without crash when no optional params given', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_overlay()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(VoiceRecordingOverlay), findsOneWidget);
    });
  });
}
