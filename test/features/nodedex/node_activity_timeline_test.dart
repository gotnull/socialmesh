// SPDX-License-Identifier: GPL-3.0-or-later

// Widget tests for NodeActivityTimeline — verifies rendering of mixed
// event types, empty state, pagination trigger, and event ordering.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/features/nodedex/models/node_activity_event.dart';
import 'package:socialmesh/features/nodedex/providers/nodedex_providers.dart';
import 'package:socialmesh/features/nodedex/widgets/node_activity_timeline.dart';
import 'package:socialmesh/models/presence_confidence.dart';

// =============================================================================
// Test helpers
// =============================================================================

const _testNodeNum = 12345;
final _now = DateTime(2026, 2, 20, 14, 0);

List<NodeActivityEvent> _mixedEvents() {
  return [
    EncounterActivityEvent(
      timestamp: _now.subtract(const Duration(minutes: 5)),
      distanceMeters: 1200,
      snr: 8,
    ),
    MessageActivityEvent(
      timestamp: _now.subtract(const Duration(minutes: 10)),
      text: 'Hello from the mesh!',
      outgoing: false,
      channel: 0,
    ),
    PresenceChangeActivityEvent(
      timestamp: _now.subtract(const Duration(minutes: 30)),
      fromState: PresenceConfidence.fading,
      toState: PresenceConfidence.active,
    ),
    SignalActivityEvent(
      timestamp: _now.subtract(const Duration(hours: 1)),
      content: 'Testing signal broadcast',
      signalId: 'sig-001',
    ),
    MilestoneActivityEvent(
      timestamp: _now.subtract(const Duration(days: 7)),
      kind: MilestoneKind.firstSeen,
      label: 'First discovered',
    ),
    MessageActivityEvent(
      timestamp: _now.subtract(const Duration(hours: 2)),
      text: 'Outbound message test',
      outgoing: true,
    ),
  ];
}

Widget _buildTestWidget({required List overrides}) {
  return ProviderScope(
    overrides: overrides.cast(),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: NodeActivityTimeline(
            nodeNum: _testNodeNum,
            accentColor: const Color(0xFF0EA5E9),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('NodeActivityTimeline', () {
    testWidgets('renders mixed event types', (tester) async {
      final events = _mixedEvents()..sort();

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: [
            nodeActivityTimelineProvider(
              _testNodeNum,
            ).overrideWith((ref) => Future.value(events)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Should show encounter event
      expect(find.textContaining('Encountered at'), findsOneWidget);

      // Should show received message
      expect(find.textContaining('Received: Hello'), findsOneWidget);

      // Should show sent message
      expect(find.textContaining('Sent: Outbound'), findsOneWidget);

      // Should show presence change
      expect(find.textContaining('Fading'), findsOneWidget);
      expect(find.textContaining('Active'), findsOneWidget);

      // Should show signal
      expect(find.textContaining('Signal: Testing'), findsOneWidget);

      // Should show milestone
      expect(find.text('First discovered'), findsOneWidget);
    });

    testWidgets('renders empty state when no events', (tester) async {
      await tester.pumpWidget(
        _buildTestWidget(
          overrides: [
            nodeActivityTimelineProvider(
              _testNodeNum,
            ).overrideWith((ref) => Future.value(<NodeActivityEvent>[])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No activity yet'), findsOneWidget);
      expect(find.textContaining('Events will appear here'), findsOneWidget);
    });

    testWidgets('shows page controls when events exceed page size', (
      tester,
    ) async {
      // Default page size is 10. Generate 15 events => 2 pages.
      final events = List.generate(
        15,
        (i) => EncounterActivityEvent(
          timestamp: _now.subtract(Duration(minutes: i * 10)),
          snr: 5,
        ),
      );

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: [
            nodeActivityTimelineProvider(
              _testNodeNum,
            ).overrideWith((ref) => Future.value(events)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets('does not show page controls when within single page', (
      tester,
    ) async {
      final events = [EncounterActivityEvent(timestamp: _now, snr: 10)];

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: [
            nodeActivityTimelineProvider(
              _testNodeNum,
            ).overrideWith((ref) => Future.value(events)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 / 1'), findsNothing);
    });

    testWidgets('does not show page controls when exactly at page size', (
      tester,
    ) async {
      // Exactly 10 events (default page size) => 1 page, no controls.
      final events = List.generate(
        10,
        (i) => EncounterActivityEvent(
          timestamp: _now.subtract(Duration(minutes: i * 10)),
          snr: 5,
        ),
      );

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: [
            nodeActivityTimelineProvider(
              _testNodeNum,
            ).overrideWith((ref) => Future.value(events)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 / 1'), findsNothing);
    });

    testWidgets('tapping next page advances and shows new page indicator', (
      tester,
    ) async {
      // 25 events => 3 pages (10, 10, 5).
      final events = List.generate(
        25,
        (i) => EncounterActivityEvent(
          timestamp: _now.subtract(Duration(minutes: i * 10)),
          snr: 5,
        ),
      );

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: [
            nodeActivityTimelineProvider(
              _testNodeNum,
            ).overrideWith((ref) => Future.value(events)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 / 3'), findsOneWidget);

      // Tap the right chevron to go to page 2.
      await tester.ensureVisible(find.text('1 / 3'));
      await tester.pumpAndSettle();
      // Find the right chevron button (second GestureDetector in the row).
      final rightChevron = find.byIcon(Icons.chevron_right);
      await tester.tap(rightChevron);
      await tester.pumpAndSettle();

      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('renders timestamps with relative labels', (tester) async {
      final events = [
        EncounterActivityEvent(
          timestamp: _now.subtract(const Duration(hours: 2)),
          snr: 8,
        ),
      ];

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: [
            nodeActivityTimelineProvider(
              _testNodeNum,
            ).overrideWith((ref) => Future.value(events)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Should contain a relative time indicator
      expect(find.textContaining('ago'), findsOneWidget);
    });

    testWidgets('renders encounter session with count and duration', (
      tester,
    ) async {
      // A grouped encounter session: 8 encounters over 35 min.
      final sessionEnd = _now.subtract(const Duration(minutes: 5));
      final sessionStart = _now.subtract(const Duration(minutes: 40));
      final events = <NodeActivityEvent>[
        EncounterActivityEvent(
          timestamp: sessionEnd,
          sessionStart: sessionStart,
          count: 8,
          snr: 12,
        ),
      ];

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: [
            nodeActivityTimelineProvider(
              _testNodeNum,
            ).overrideWith((ref) => Future.value(events)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('8 encounters over 35 min'), findsOneWidget);
    });

    testWidgets('shows loading indicator while events load', (tester) async {
      // Use a Completer that never completes to keep the provider
      // in its loading state without leaving pending timers.
      final completer = Completer<List<NodeActivityEvent>>();

      await tester.pumpWidget(
        _buildTestWidget(
          overrides: [
            nodeActivityTimelineProvider(
              _testNodeNum,
            ).overrideWith((ref) => completer.future),
          ],
        ),
      );
      // Don't pump and settle — check during loading
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  // ===========================================================================
  // NodeActivityEvent model tests
  // ===========================================================================

  group('NodeActivityEvent', () {
    test('sorts descending by timestamp (newest first)', () {
      final events = _mixedEvents();
      events.sort();

      for (int i = 0; i < events.length - 1; i++) {
        expect(
          events[i].timestamp.isAfter(events[i + 1].timestamp) ||
              events[i].timestamp.isAtSameMomentAs(events[i + 1].timestamp),
          isTrue,
          reason: 'Event at index $i should be after event at index ${i + 1}',
        );
      }
    });

    test('each variant has correct type discriminator', () {
      expect(
        EncounterActivityEvent(timestamp: _now).type,
        NodeActivityEventType.encounter,
      );
      expect(
        MessageActivityEvent(
          timestamp: _now,
          text: 'test',
          outgoing: false,
        ).type,
        NodeActivityEventType.message,
      );
      expect(
        PresenceChangeActivityEvent(
          timestamp: _now,
          fromState: PresenceConfidence.active,
          toState: PresenceConfidence.fading,
        ).type,
        NodeActivityEventType.presenceChange,
      );
      expect(
        SignalActivityEvent(
          timestamp: _now,
          content: 'test',
          signalId: 'x',
        ).type,
        NodeActivityEventType.signal,
      );
      expect(
        MilestoneActivityEvent(
          timestamp: _now,
          kind: MilestoneKind.firstSeen,
          label: 'test',
        ).type,
        NodeActivityEventType.milestone,
      );
    });

    test('milestone kinds are exhaustive', () {
      expect(MilestoneKind.values.length, equals(2));
      expect(MilestoneKind.values, contains(MilestoneKind.firstSeen));
      expect(MilestoneKind.values, contains(MilestoneKind.encounterMilestone));
    });

    test(
      'EncounterActivityEvent defaults to count=1, sessionStart=timestamp',
      () {
        final event = EncounterActivityEvent(timestamp: _now, snr: 10);
        expect(event.count, equals(1));
        expect(event.sessionStart, equals(_now));
      },
    );

    test('EncounterActivityEvent session fields work correctly', () {
      final sessionStart = _now.subtract(const Duration(minutes: 30));
      final event = EncounterActivityEvent(
        timestamp: _now,
        sessionStart: sessionStart,
        count: 5,
        distanceMeters: 800,
        snr: 12,
      );
      expect(event.count, equals(5));
      expect(event.sessionStart, equals(sessionStart));
      expect(event.distanceMeters, equals(800));
      expect(event.snr, equals(12));
    });
  });
}
