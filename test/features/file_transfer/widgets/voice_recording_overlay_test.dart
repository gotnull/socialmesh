// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Widget tests for VoiceRecordingOverlay — verifies structural elements,
// stop-button callback, and crash-free behaviour with no amplitude stream.

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
  VoidCallback? onStop,
  Stream<double>? amplitudeStream,
}) {
  return VoiceRecordingOverlay(
    onStop: onStop ?? () {},
    amplitudeStream: amplitudeStream,
  );
}

// =============================================================================
// Tests
// =============================================================================

void main() {
  group('VoiceRecordingOverlay — structure', () {
    testWidgets('renders "REC" text when visible', (tester) async {
      await tester.pumpWidget(_wrap(_overlay()));
      await tester.pump();

      expect(find.text('REC'), findsOneWidget);
    });

    testWidgets('renders stop button', (tester) async {
      await tester.pumpWidget(_wrap(_overlay()));
      await tester.pump();

      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
    });

    testWidgets('stop button invokes onStop callback', (tester) async {
      var called = false;
      await tester.pumpWidget(_wrap(_overlay(onStop: () => called = true)));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pump();

      expect(called, isTrue);
    });

    testWidgets('timer text is present on initial frame', (tester) async {
      await tester.pumpWidget(_wrap(_overlay()));
      await tester.pump();

      // The initial elapsed time is "0:00".
      expect(find.text('0:00'), findsOneWidget);
    });

    testWidgets('renders with null amplitude stream without crash', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(_overlay()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // If we reach here without exception, the test passes.
      expect(find.byType(VoiceRecordingOverlay), findsOneWidget);
    });
  });

  group('VoiceRecordingOverlay — amplitude stream', () {
    testWidgets('subscribes to amplitude stream and repaints without crash', (
      tester,
    ) async {
      final controller = StreamController<double>.broadcast();
      addTearDown(controller.close);

      await tester.pumpWidget(
        _wrap(_overlay(amplitudeStream: controller.stream)),
      );
      await tester.pump();

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
        _wrap(_overlay(amplitudeStream: controller.stream)),
      );
      await tester.pump();

      // Add a sample, then remove the overlay.
      controller.add(0.5);
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      // Adding to the stream after disposal must not crash.
      expect(() => controller.add(0.9), returnsNormally);
    });
  });

  group('VoiceRecordingOverlay — timer advancement', () {
    testWidgets('timer increments elapsed time', (tester) async {
      await tester.pumpWidget(_wrap(_overlay()));
      await tester.pump();

      // Advance fake async clock by just over 1 second.
      await tester.pump(const Duration(milliseconds: 1100));

      // After 1 second, timer should read "0:01".
      expect(find.text('0:01'), findsOneWidget);
    });
  });
}
