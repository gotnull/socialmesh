// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:socialmesh/features/signals/widgets/signal_card.dart';
import 'package:socialmesh/features/signals/widgets/signal_presence_context.dart';
import 'package:socialmesh/models/social.dart';
import 'package:socialmesh/models/presence_confidence.dart';
import 'package:socialmesh/providers/auth_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SignalPresenceContext widget', () {
    testWidgets('renders nothing when all values are null/default', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: SignalPresenceContext())),
      );

      // Should not find any intent chip, status, or badges
      expect(find.byIcon(Icons.help_outline), findsNothing);
      expect(find.textContaining('Seen'), findsNothing);
      expect(find.text('Back nearby'), findsNothing);
    });

    testWidgets('renders intent chip when intent is set', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SignalPresenceContext(intent: PresenceIntent.camping),
          ),
        ),
      );

      // Should show the intent label
      expect(find.text('Camping'), findsOneWidget);
    });

    testWidgets('renders short status as italic text with quote icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SignalPresenceContext(shortStatus: 'Out hiking today'),
          ),
        ),
      );

      // Should show the short status text (no quotes in widget)
      expect(find.text('Out hiking today'), findsOneWidget);
      // Should show the quote icon
      expect(find.byIcon(Icons.format_quote), findsOneWidget);
    });

    testWidgets('renders both intent and status together', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SignalPresenceContext(
              intent: PresenceIntent.traveling,
              shortStatus: 'Road trip',
            ),
          ),
        ),
      );

      expect(find.text('Traveling'), findsOneWidget);
      expect(find.text('Road trip'), findsOneWidget);
    });

    testWidgets('renders encounter count badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SignalPresenceContext(encounterCount: 5)),
        ),
      );

      expect(find.text('Seen 5×'), findsOneWidget);
    });

    testWidgets('renders encounter count with thousands separator', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SignalPresenceContext(encounterCount: 1107)),
        ),
      );

      expect(find.text('Seen 1,107×'), findsOneWidget);
    });

    testWidgets('does not render encounter count when 0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SignalPresenceContext(encounterCount: 0)),
        ),
      );

      expect(find.textContaining('Seen'), findsNothing);
    });

    testWidgets('renders last seen bucket', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SignalPresenceContext(
              lastSeenBucket: LastSeenBucket.seenToday,
            ),
          ),
        ),
      );

      expect(find.text('Seen today'), findsOneWidget);
    });

    testWidgets('renders back nearby badge', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SignalPresenceContext(isBackNearby: true)),
        ),
      );

      expect(find.text('Back nearby'), findsOneWidget);
    });

    testWidgets('does not render back nearby when false', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SignalPresenceContext(isBackNearby: false)),
        ),
      );

      expect(find.text('Back nearby'), findsNothing);
    });

    testWidgets('renders all elements together without overflow', (
      tester,
    ) async {
      // Set a constrained width to test Wrap behavior
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              child: const SignalPresenceContext(
                intent: PresenceIntent.emergencyStandby,
                shortStatus: 'Monitoring for emergencies',
                encounterCount: 12,
                lastSeenBucket: LastSeenBucket.activeRecently,
                isBackNearby: true,
              ),
            ),
          ),
        ),
      );

      // All elements should render
      expect(find.text('Emergency Standby'), findsOneWidget);
      expect(find.text('Monitoring for emergencies'), findsOneWidget);
      expect(find.text('Seen 12×'), findsOneWidget);
      expect(find.text('Active recently'), findsOneWidget);
      expect(find.text('Back nearby'), findsOneWidget);

      // No overflow errors should occur (tester would throw if RenderFlex overflow)
    });

    testWidgets('chips wrap correctly in narrow container', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200, // Very narrow
              child: const SignalPresenceContext(
                intent: PresenceIntent.camping,
                encounterCount: 5,
                lastSeenBucket: LastSeenBucket.seenThisWeek,
                isBackNearby: true,
              ),
            ),
          ),
        ),
      );

      // All chips should still render (Wrap handles layout)
      expect(find.text('Camping'), findsOneWidget);
      expect(find.text('Seen 5×'), findsOneWidget);
      expect(find.text('Seen this week'), findsOneWidget);
      expect(find.text('Back nearby'), findsOneWidget);

      // No overflow (Wrap handles this)
    });

    testWidgets('does not render unknown intent', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SignalPresenceContext(intent: PresenceIntent.unknown),
          ),
        ),
      );

      // Unknown intent should not render a chip
      expect(find.text('Unknown'), findsNothing);
    });

    testWidgets('does not render empty or whitespace-only status', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: SignalPresenceContext(shortStatus: '   ')),
        ),
      );

      // Empty status should not render quotes
      expect(find.textContaining('"'), findsNothing);
    });
  });

  group('SignalCard with embedded presenceInfo', () {
    testWidgets('renders presence context from signal.presenceInfo', (
      tester,
    ) async {
      // Create a Post with embedded presenceInfo
      final post = Post(
        id: 'sig-presence-test',
        authorId: 'mesh_author123',
        content: 'Test signal with presence',
        createdAt: DateTime.now(),
        postMode: PostMode.signal,
        origin: SignalOrigin.mesh,
        meshNodeId: 12345,
        presenceInfo: {'i': 2, 's': 'At campsite'},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUserProvider.overrideWith((ref) => null)],
          child: MaterialApp(
            home: Scaffold(body: SignalCard(signal: post)),
          ),
        ),
      );

      await tester.pump();

      // The presence info should be rendered
      expect(find.text('Camping'), findsOneWidget);
      expect(find.text('At campsite'), findsOneWidget);
    });

    testWidgets('renders nothing when meshNodeId is null', (tester) async {
      // Create a cloud signal without meshNodeId
      final post = Post(
        id: 'sig-cloud-test',
        authorId: 'cloud_author456',
        content: 'Cloud signal',
        createdAt: DateTime.now(),
        postMode: PostMode.signal,
        origin: SignalOrigin.cloud,
        // No meshNodeId
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUserProvider.overrideWith((ref) => null)],
          child: MaterialApp(
            home: Scaffold(body: SignalCard(signal: post)),
          ),
        ),
      );

      await tester.pump();

      // SignalPresenceContext should not appear (returns SizedBox.shrink)
      expect(find.byType(SignalPresenceContext), findsNothing);
    });

    testWidgets('renders presence context with only intent from presenceInfo', (
      tester,
    ) async {
      final post = Post(
        id: 'sig-intent-only',
        authorId: 'mesh_author789',
        content: 'Intent only signal',
        createdAt: DateTime.now(),
        postMode: PostMode.signal,
        origin: SignalOrigin.mesh,
        meshNodeId: 54321,
        presenceInfo: {'i': 3}, // Traveling, no status
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [currentUserProvider.overrideWith((ref) => null)],
          child: MaterialApp(
            home: Scaffold(body: SignalCard(signal: post)),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Traveling'), findsOneWidget);
      // No status quotes should appear
      expect(find.textContaining('"'), findsNothing);
    });
  });

  group('Post.presenceInfo serialization', () {
    test('Post includes presenceInfo in toFirestore', () {
      final post = Post(
        id: 'test-id',
        authorId: 'author',
        content: 'content',
        createdAt: DateTime.now(),
        postMode: PostMode.signal,
        origin: SignalOrigin.mesh,
        presenceInfo: {'i': 1, 's': 'Available now'},
      );

      final map = post.toFirestore();
      expect(map['presenceInfo'], equals({'i': 1, 's': 'Available now'}));
    });

    test('Post constructor accepts presenceInfo', () {
      final post = Post(
        id: 'test-id',
        authorId: 'author',
        content: 'content',
        createdAt: DateTime.now(),
        postMode: PostMode.signal,
        origin: SignalOrigin.mesh,
        presenceInfo: {'i': 4, 's': 'Emergency'},
      );

      expect(post.presenceInfo, equals({'i': 4, 's': 'Emergency'}));
    });

    test('Post.copyWith updates presenceInfo', () {
      final original = Post(
        id: 'test-id',
        authorId: 'author',
        content: 'content',
        createdAt: DateTime.now(),
        postMode: PostMode.signal,
        origin: SignalOrigin.mesh,
        presenceInfo: {'i': 1},
      );

      final updated = original.copyWith(
        presenceInfo: {'i': 2, 's': 'Updated status'},
      );

      expect(updated.presenceInfo, equals({'i': 2, 's': 'Updated status'}));
      expect(original.presenceInfo, equals({'i': 1})); // Original unchanged
    });

    test('Post.copyWith preserves presenceInfo when not overridden', () {
      final original = Post(
        id: 'test-id',
        authorId: 'author',
        content: 'content',
        createdAt: DateTime.now(),
        postMode: PostMode.signal,
        origin: SignalOrigin.mesh,
        presenceInfo: {'i': 3},
      );

      final updated = original.copyWith(content: 'new content');

      expect(updated.presenceInfo, equals({'i': 3}));
    });
  });

  group('ExtendedPresenceInfo fromJson round-trip', () {
    test('parses intent and shortStatus from compact JSON', () {
      final json = {'i': 2, 's': 'Camping trip'};
      final info = ExtendedPresenceInfo.fromJson(json);

      expect(info.intent, equals(PresenceIntent.camping));
      expect(info.shortStatus, equals('Camping trip'));
    });

    test('parses intent only', () {
      final json = {'i': 5};
      final info = ExtendedPresenceInfo.fromJson(json);

      expect(info.intent, equals(PresenceIntent.relayNode));
      expect(info.shortStatus, isNull);
    });

    test('returns defaults for empty JSON', () {
      final info = ExtendedPresenceInfo.fromJson({});

      expect(info.intent, equals(PresenceIntent.unknown));
      expect(info.shortStatus, isNull);
    });

    test('handles null JSON gracefully', () {
      final info = ExtendedPresenceInfo.fromJson(null);

      expect(info.intent, equals(PresenceIntent.unknown));
      expect(info.shortStatus, isNull);
    });
  });
}
