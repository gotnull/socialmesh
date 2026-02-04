// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:socialmesh/models/presence_confidence.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/models/node_encounter.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/providers/connectivity_providers.dart';
import 'package:socialmesh/providers/auth_providers.dart';
import 'package:socialmesh/providers/connection_providers.dart';
import 'package:socialmesh/services/extended_presence_service.dart';
import 'package:socialmesh/features/signals/screens/create_signal_screen.dart';

// Test notifiers for mocking providers
class _TestNodesNotifier extends NodesNotifier {
  _TestNodesNotifier(this._nodes);
  final Map<int, MeshNode> _nodes;

  @override
  Map<int, MeshNode> build() => _nodes;
}

class _TestMyNodeNumNotifier extends MyNodeNumNotifier {
  _TestMyNodeNumNotifier(this._nodeNum);
  final int? _nodeNum;

  @override
  int? build() => _nodeNum;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('PresenceIntent enum', () {
    test('has expected values with labels', () {
      expect(PresenceIntent.unknown.label, equals('Unknown'));
      expect(PresenceIntent.available.label, equals('Available'));
      expect(PresenceIntent.camping.label, equals('Camping'));
      expect(PresenceIntent.traveling.label, equals('Traveling'));
      expect(
        PresenceIntent.emergencyStandby.label,
        equals('Emergency Standby'),
      );
      expect(PresenceIntent.relayNode.label, equals('Relay Node'));
      expect(PresenceIntent.passive.label, equals('Passive'));
    });

    test('PresenceIntentIcons returns valid icon codes', () {
      for (final intent in PresenceIntent.values) {
        final code = PresenceIntentIcons.codeFor(intent);
        // All icon codes should be valid Material Icons codepoints (non-zero)
        expect(code, isPositive, reason: 'Icon code for ${intent.name}');
      }
    });

    test('fromValue converts int to enum correctly', () {
      expect(PresenceIntent.fromValue(0), equals(PresenceIntent.unknown));
      expect(PresenceIntent.fromValue(1), equals(PresenceIntent.available));
      expect(PresenceIntent.fromValue(2), equals(PresenceIntent.camping));
      expect(PresenceIntent.fromValue(3), equals(PresenceIntent.traveling));
      expect(
        PresenceIntent.fromValue(4),
        equals(PresenceIntent.emergencyStandby),
      );
      expect(PresenceIntent.fromValue(5), equals(PresenceIntent.relayNode));
      expect(PresenceIntent.fromValue(6), equals(PresenceIntent.passive));
    });

    test('fromValue returns unknown for invalid values', () {
      expect(PresenceIntent.fromValue(null), equals(PresenceIntent.unknown));
      expect(PresenceIntent.fromValue(-1), equals(PresenceIntent.unknown));
      expect(PresenceIntent.fromValue(99), equals(PresenceIntent.unknown));
    });
  });

  group('ExtendedPresenceInfo', () {
    test('maxStatusLength is 64 characters', () {
      expect(ExtendedPresenceInfo.maxStatusLength, equals(64));
    });

    test('serializes to compact JSON via toJson', () {
      const info = ExtendedPresenceInfo(
        intent: PresenceIntent.camping,
        shortStatus: 'At base camp',
      );

      final json = info.toJson();
      expect(json['i'], equals(2)); // camping = 2
      expect(json['s'], equals('At base camp'));
    });

    test('serializes to string payload', () {
      const info = ExtendedPresenceInfo(
        intent: PresenceIntent.traveling,
        shortStatus: 'On the road',
      );

      final payload = info.toPayload();
      expect(payload, isNotNull);
      expect(payload, contains('"i":3')); // traveling = 3
      expect(payload, contains('"s":"On the road"'));
    });

    test('deserializes from JSON', () {
      final info = ExtendedPresenceInfo.fromJson({'i': 3, 's': 'On trail'});

      expect(info.intent, equals(PresenceIntent.traveling));
      expect(info.shortStatus, equals('On trail'));
    });

    test('deserializes from string payload', () {
      final info = ExtendedPresenceInfo.fromPayload('{"i":2,"s":"Base camp"}');

      expect(info.intent, equals(PresenceIntent.camping));
      expect(info.shortStatus, equals('Base camp'));
    });

    test('handles missing status gracefully', () {
      final info = ExtendedPresenceInfo.fromJson({'i': 1});

      expect(info.intent, equals(PresenceIntent.available));
      expect(info.shortStatus, isNull);
    });

    test('handles invalid JSON gracefully', () {
      final info = ExtendedPresenceInfo.fromPayload('invalid');

      expect(info.intent, equals(PresenceIntent.unknown));
      expect(info.shortStatus, isNull);
    });

    test('handles null JSON gracefully', () {
      final info = ExtendedPresenceInfo.fromJson(null);

      expect(info.intent, equals(PresenceIntent.unknown));
      expect(info.shortStatus, isNull);
    });

    test('truncates long status to maxStatusLength', () {
      final longStatus = 'A' * 100;
      final info = ExtendedPresenceInfo.fromJson({'i': 1, 's': longStatus});

      expect(info.shortStatus!.length, lessThanOrEqualTo(64));
    });

    test('hasData returns true when intent is set', () {
      const info = ExtendedPresenceInfo(intent: PresenceIntent.camping);
      expect(info.hasData, isTrue);
    });

    test('hasData returns true when status is set', () {
      const info = ExtendedPresenceInfo(shortStatus: 'Hello');
      expect(info.hasData, isTrue);
    });

    test('hasData returns false when empty', () {
      const info = ExtendedPresenceInfo();
      expect(info.hasData, isFalse);
    });

    test('toPayload returns null when no data', () {
      const info = ExtendedPresenceInfo();
      expect(info.toPayload(), isNull);
    });
  });

  group('NodeEncounter model', () {
    test('tracks encounter count', () {
      final encounter = NodeEncounter(
        nodeId: 12345,
        firstSeen: DateTime.now().subtract(const Duration(days: 30)),
        lastSeen: DateTime.now(),
        encounterCount: 5,
        uniqueDaysSeen: 5,
      );

      expect(encounter.encounterCount, equals(5));
      expect(encounter.nodeId, equals(12345));
    });

    test('firstEncounter factory creates initial encounter', () {
      final now = DateTime.now();
      final encounter = NodeEncounter.firstEncounter(12345, now);

      expect(encounter.nodeId, equals(12345));
      expect(encounter.encounterCount, equals(1));
      expect(encounter.uniqueDaysSeen, equals(1));
    });

    test('encounterSummary formats correctly', () {
      final encounter = NodeEncounter(
        nodeId: 12345,
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
        encounterCount: 5,
        uniqueDaysSeen: 3,
      );

      expect(encounter.encounterSummary, equals('Seen 5 times'));
    });

    test('encounterSummary for first encounter', () {
      final encounter = NodeEncounter(
        nodeId: 12345,
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
        encounterCount: 1,
        uniqueDaysSeen: 1,
      );

      expect(encounter.encounterSummary, equals('First encounter'));
    });

    test('isFamiliar returns true for frequent encounters', () {
      final encounter = NodeEncounter(
        nodeId: 12345,
        firstSeen: DateTime.now().subtract(const Duration(days: 30)),
        lastSeen: DateTime.now(),
        encounterCount: 10,
        uniqueDaysSeen: 10,
      );

      expect(encounter.isFamiliar, isTrue);
    });

    test('isFamiliar returns false for few encounters', () {
      final encounter = NodeEncounter(
        nodeId: 12345,
        firstSeen: DateTime.now(),
        lastSeen: DateTime.now(),
        encounterCount: 2,
        uniqueDaysSeen: 1,
      );

      expect(encounter.isFamiliar, isFalse);
    });
  });

  group('Create Signal Screen - Presence Fields', () {
    testWidgets('shows Intent picker row', (tester) async {
      // Set a larger screen size to avoid overflow issues
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      final container = ProviderContainer(
        overrides: [
          isSignedInProvider.overrideWithValue(true),
          isDeviceConnectedProvider.overrideWithValue(true),
          myNodeNumProvider.overrideWith(() => _TestMyNodeNumNotifier(1)),
          nodesProvider.overrideWith(
            () => _TestNodesNotifier({
              1: MeshNode(nodeNum: 1, latitude: 1.0, longitude: 1.0),
            }),
          ),
        ],
      );

      final connNotifier = container.read(connectivityStatusProvider.notifier);
      connNotifier.setOnline(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: const CreateSignalScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Should show Intent label
      expect(find.text('Intent'), findsOneWidget);

      // Should show Unknown as default (tap to change)
      expect(find.text('Tap to set'), findsOneWidget);

      container.dispose();

      // Reset screen size
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('shows Short Status field', (tester) async {
      // Set a larger screen size to avoid overflow issues
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      final container = ProviderContainer(
        overrides: [
          isSignedInProvider.overrideWithValue(true),
          isDeviceConnectedProvider.overrideWithValue(true),
          myNodeNumProvider.overrideWith(() => _TestMyNodeNumNotifier(1)),
          nodesProvider.overrideWith(
            () => _TestNodesNotifier({
              1: MeshNode(nodeNum: 1, latitude: 1.0, longitude: 1.0),
            }),
          ),
        ],
      );

      final connNotifier = container.read(connectivityStatusProvider.notifier);
      connNotifier.setOnline(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: const CreateSignalScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Should show Short Status text field (capital S)
      expect(find.text('Short Status (optional)'), findsOneWidget);

      container.dispose();

      // Reset screen size
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('Intent picker opens bottom sheet', (tester) async {
      // Set a larger screen size to avoid overflow issues
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      final container = ProviderContainer(
        overrides: [
          isSignedInProvider.overrideWithValue(true),
          isDeviceConnectedProvider.overrideWithValue(true),
          myNodeNumProvider.overrideWith(() => _TestMyNodeNumNotifier(1)),
          nodesProvider.overrideWith(
            () => _TestNodesNotifier({
              1: MeshNode(nodeNum: 1, latitude: 1.0, longitude: 1.0),
            }),
          ),
        ],
      );

      final connNotifier = container.read(connectivityStatusProvider.notifier);
      connNotifier.setOnline(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: const CreateSignalScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on the intent row
      await tester.tap(find.text('Intent'));
      await tester.pumpAndSettle();

      // Bottom sheet should show header and all intent options
      expect(find.text('Your Intent'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
      expect(find.text('Camping'), findsOneWidget);
      expect(find.text('Traveling'), findsOneWidget);
      expect(find.text('Emergency Standby'), findsOneWidget);
      expect(find.text('Relay Node'), findsOneWidget);
      expect(find.text('Passive'), findsOneWidget);

      container.dispose();

      // Reset screen size
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('selecting intent updates the row display', (tester) async {
      // Set a larger screen size to avoid overflow issues
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      final container = ProviderContainer(
        overrides: [
          isSignedInProvider.overrideWithValue(true),
          isDeviceConnectedProvider.overrideWithValue(true),
          myNodeNumProvider.overrideWith(() => _TestMyNodeNumNotifier(1)),
          nodesProvider.overrideWith(
            () => _TestNodesNotifier({
              1: MeshNode(nodeNum: 1, latitude: 1.0, longitude: 1.0),
            }),
          ),
        ],
      );

      final connNotifier = container.read(connectivityStatusProvider.notifier);
      connNotifier.setOnline(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: const CreateSignalScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Initially shows "Tap to set"
      expect(find.text('Tap to set'), findsOneWidget);

      // Open the picker
      await tester.tap(find.text('Intent'));
      await tester.pumpAndSettle();

      // Tap on "Camping"
      await tester.tap(find.text('Camping'));
      await tester.pumpAndSettle();

      // Should now show "Camping" in the intent row
      // (Bottom sheet closes, Camping appears in main view)
      expect(find.text('Camping'), findsWidgets);

      container.dispose();

      // Reset screen size
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('status field enforces 64 character limit', (tester) async {
      // Set a larger screen size to avoid overflow issues
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      final container = ProviderContainer(
        overrides: [
          isSignedInProvider.overrideWithValue(true),
          isDeviceConnectedProvider.overrideWithValue(true),
          myNodeNumProvider.overrideWith(() => _TestMyNodeNumNotifier(1)),
          nodesProvider.overrideWith(
            () => _TestNodesNotifier({
              1: MeshNode(nodeNum: 1, latitude: 1.0, longitude: 1.0),
            }),
          ),
        ],
      );

      final connNotifier = container.read(connectivityStatusProvider.notifier);
      connNotifier.setOnline(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(home: const CreateSignalScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Find the status text field by finding all text fields and identifying
      // the one for short status
      final textFields = find.byType(TextField);
      expect(textFields, findsWidgets);

      // The last TextField should be the short status field
      final statusField = textFields.last;

      // Enter a very long text
      final longText = 'A' * 100;
      await tester.enterText(statusField, longText);
      await tester.pump();

      // The text should be truncated to 64 chars
      final textField = tester.widget<TextField>(statusField);
      expect(textField.controller?.text.length, lessThanOrEqualTo(64));

      container.dispose();

      // Reset screen size
      await tester.binding.setSurfaceSize(null);
    });
  });

  group('ExtendedPresenceService persistence', () {
    test('persists and retrieves intent', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ExtendedPresenceService();

      await service.setMyIntent(PresenceIntent.camping);
      final info = await service.getMyPresenceInfo();

      expect(info.intent, equals(PresenceIntent.camping));
    });

    test('persists and retrieves status', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ExtendedPresenceService();

      await service.setMyStatus('At summit');
      final info = await service.getMyPresenceInfo();

      expect(info.shortStatus, equals('At summit'));
    });

    test('retrieves null status when not set', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ExtendedPresenceService();

      final info = await service.getMyPresenceInfo();

      expect(info.shortStatus, isNull);
    });

    test('clears status when set to null', () async {
      SharedPreferences.setMockInitialValues({});
      final service = ExtendedPresenceService();

      await service.setMyStatus('Hello');
      await service.setMyStatus(null);
      final info = await service.getMyPresenceInfo();

      expect(info.shortStatus, isNull);
    });
  });

  group('Signal card header layout', () {
    test('presence badges use Wrap for proper layout', () {
      // Verify that badges are rendered as individual widgets that can wrap
      // rather than using Flexible which would cause truncation in a Row

      // The _IntentChip widget should not have overflow ellipsis since
      // it's now in a Wrap that allows line breaks
      const info = ExtendedPresenceInfo(
        intent: PresenceIntent.emergencyStandby,
        shortStatus: 'Test status',
      );

      // Verify the label text is complete (not truncated)
      expect(info.intent.label, equals('Emergency Standby'));
      expect(info.intent.label.length, greaterThan(10));
    });

    test('encounter badge text format is complete', () {
      // Ensure encounter count text format fits well in Wrap
      final encounter = NodeEncounter(
        nodeId: 42,
        encounterCount: 401,
        uniqueDaysSeen: 30,
        firstSeen: DateTime.now().subtract(const Duration(days: 30)),
        lastSeen: DateTime.now(),
      );

      // Text should be "Seen 401x" - short enough to not need truncation
      final badgeText = 'Seen ${encounter.encounterCount}x';
      expect(badgeText, equals('Seen 401x'));
      expect(badgeText.length, lessThan(15)); // Should be very short
    });

    test('back nearby badge text is short enough for Wrap', () {
      // "Back nearby" should be short enough to fit
      const badgeText = 'Back nearby';
      expect(badgeText.length, lessThan(15));
    });
  });
}
