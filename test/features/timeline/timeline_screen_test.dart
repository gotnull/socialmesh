import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/timeline/timeline_screen.dart';

void main() {
  group('TimelineEventType', () {
    test('has all expected values', () {
      expect(
        TimelineEventType.values,
        containsAll([
          TimelineEventType.message,
          TimelineEventType.nodeJoined,
          TimelineEventType.nodeLeft,
          TimelineEventType.signalChange,
          TimelineEventType.waypoint,
          TimelineEventType.channelActivity,
        ]),
      );
    });

    test('count is 6', () {
      expect(TimelineEventType.values.length, 6);
    });
  });

  group('TimelineEvent', () {
    test('creates valid instance', () {
      final event = TimelineEvent(
        id: 'test_id',
        type: TimelineEventType.message,
        timestamp: DateTime(2024, 1, 15, 10, 30),
        nodeNum: 12345,
        nodeName: 'TestNode',
        title: 'Test Event',
        subtitle: 'Test subtitle',
        metadata: {'key': 'value'},
      );

      expect(event.id, 'test_id');
      expect(event.type, TimelineEventType.message);
      expect(event.timestamp, DateTime(2024, 1, 15, 10, 30));
      expect(event.nodeNum, 12345);
      expect(event.nodeName, 'TestNode');
      expect(event.title, 'Test Event');
      expect(event.subtitle, 'Test subtitle');
      expect(event.metadata, {'key': 'value'});
    });

    test('creates instance with minimal fields', () {
      final event = TimelineEvent(
        id: 'minimal',
        type: TimelineEventType.nodeJoined,
        timestamp: DateTime.now(),
        title: 'Minimal Event',
      );

      expect(event.id, 'minimal');
      expect(event.nodeNum, isNull);
      expect(event.nodeName, isNull);
      expect(event.subtitle, isNull);
      expect(event.metadata, isNull);
    });

    test('icon returns correct icon for each type', () {
      final messageEvent = TimelineEvent(
        id: '1',
        type: TimelineEventType.message,
        timestamp: DateTime.now(),
        title: 'Message',
      );
      expect(messageEvent.icon, Icons.message);

      final nodeJoinedEvent = TimelineEvent(
        id: '2',
        type: TimelineEventType.nodeJoined,
        timestamp: DateTime.now(),
        title: 'Node Joined',
      );
      expect(nodeJoinedEvent.icon, Icons.person_add);

      final nodeLeftEvent = TimelineEvent(
        id: '3',
        type: TimelineEventType.nodeLeft,
        timestamp: DateTime.now(),
        title: 'Node Left',
      );
      expect(nodeLeftEvent.icon, Icons.person_remove);

      final signalEvent = TimelineEvent(
        id: '4',
        type: TimelineEventType.signalChange,
        timestamp: DateTime.now(),
        title: 'Signal',
      );
      expect(signalEvent.icon, Icons.signal_cellular_alt);

      final waypointEvent = TimelineEvent(
        id: '5',
        type: TimelineEventType.waypoint,
        timestamp: DateTime.now(),
        title: 'Waypoint',
      );
      expect(waypointEvent.icon, Icons.place);

      final channelEvent = TimelineEvent(
        id: '6',
        type: TimelineEventType.channelActivity,
        timestamp: DateTime.now(),
        title: 'Channel',
      );
      expect(channelEvent.icon, Icons.wifi_tethering);
    });

    test('color returns non-null color for each type', () {
      for (final type in TimelineEventType.values) {
        final event = TimelineEvent(
          id: 'test',
          type: type,
          timestamp: DateTime.now(),
          title: 'Test',
        );
        expect(event.color, isNotNull);
      }
    });
  });

  group('TimelineFilter', () {
    test('has all expected values', () {
      expect(
        TimelineFilter.values,
        containsAll([
          TimelineFilter.all,
          TimelineFilter.messages,
          TimelineFilter.nodes,
          TimelineFilter.signals,
          TimelineFilter.waypoints,
        ]),
      );
    });

    test('count is 5', () {
      expect(TimelineFilter.values.length, 5);
    });

    test('label returns correct labels', () {
      expect(TimelineFilter.all.label, 'All');
      expect(TimelineFilter.messages.label, 'Messages');
      expect(TimelineFilter.nodes.label, 'Nodes');
      expect(TimelineFilter.signals.label, 'Signals');
      expect(TimelineFilter.waypoints.label, 'Waypoints');
    });

    test('icon returns non-null icon for each filter', () {
      for (final filter in TimelineFilter.values) {
        expect(filter.icon, isNotNull);
      }
    });

    test('all filter matches everything', () {
      for (final type in TimelineEventType.values) {
        expect(TimelineFilter.all.matches(type), isTrue);
      }
    });

    test('messages filter matches only messages', () {
      expect(
        TimelineFilter.messages.matches(TimelineEventType.message),
        isTrue,
      );
      expect(
        TimelineFilter.messages.matches(TimelineEventType.nodeJoined),
        isFalse,
      );
      expect(
        TimelineFilter.messages.matches(TimelineEventType.waypoint),
        isFalse,
      );
    });

    test('nodes filter matches nodeJoined and nodeLeft', () {
      expect(
        TimelineFilter.nodes.matches(TimelineEventType.nodeJoined),
        isTrue,
      );
      expect(TimelineFilter.nodes.matches(TimelineEventType.nodeLeft), isTrue);
      expect(TimelineFilter.nodes.matches(TimelineEventType.message), isFalse);
      expect(TimelineFilter.nodes.matches(TimelineEventType.waypoint), isFalse);
    });

    test('signals filter matches only signalChange', () {
      expect(
        TimelineFilter.signals.matches(TimelineEventType.signalChange),
        isTrue,
      );
      expect(
        TimelineFilter.signals.matches(TimelineEventType.message),
        isFalse,
      );
      expect(
        TimelineFilter.signals.matches(TimelineEventType.waypoint),
        isFalse,
      );
    });

    test('waypoints filter matches only waypoint', () {
      expect(
        TimelineFilter.waypoints.matches(TimelineEventType.waypoint),
        isTrue,
      );
      expect(
        TimelineFilter.waypoints.matches(TimelineEventType.message),
        isFalse,
      );
      expect(
        TimelineFilter.waypoints.matches(TimelineEventType.nodeJoined),
        isFalse,
      );
    });
  });
}
