// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/features/sky_scanner/models/sky_node.dart';

void main() {
  group('SkyNode', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final now = DateTime.now();
        final skyNode = SkyNode(
          id: 'test-id',
          nodeId: '!abc123',
          flightNumber: 'UA123',
          departure: 'LAX',
          arrival: 'JFK',
          scheduledDeparture: now,
          userId: 'user-123',
          createdAt: now,
        );

        expect(skyNode.id, 'test-id');
        expect(skyNode.nodeId, '!abc123');
        expect(skyNode.flightNumber, 'UA123');
        expect(skyNode.departure, 'LAX');
        expect(skyNode.arrival, 'JFK');
        expect(skyNode.scheduledDeparture, now);
        expect(skyNode.userId, 'user-123');
        expect(skyNode.createdAt, now);
        expect(skyNode.isActive, false);
        expect(skyNode.receptionCount, 0);
      });

      test('creates instance with all optional fields', () {
        final departure = DateTime(2025, 6, 15, 10, 0);
        final arrival = DateTime(2025, 6, 15, 18, 0);
        final created = DateTime(2025, 6, 1, 12, 0);

        final skyNode = SkyNode(
          id: 'full-id',
          nodeId: '!def456',
          nodeName: 'TestNode',
          flightNumber: 'BA456',
          airline: 'British Airways',
          departure: 'LHR',
          arrival: 'SFO',
          scheduledDeparture: departure,
          scheduledArrival: arrival,
          userId: 'user-456',
          userName: 'Test User',
          notes: 'Window seat, row 12',
          isActive: true,
          createdAt: created,
          receptionCount: 5,
        );

        expect(skyNode.nodeName, 'TestNode');
        expect(skyNode.airline, 'British Airways');
        expect(skyNode.scheduledArrival, arrival);
        expect(skyNode.userName, 'Test User');
        expect(skyNode.notes, 'Window seat, row 12');
        expect(skyNode.isActive, true);
        expect(skyNode.receptionCount, 5);
      });
    });

    group('fromJson', () {
      test('parses required fields correctly', () {
        final now = DateTime(2025, 6, 15, 10, 0);
        final json = {
          'nodeId': '!abc123',
          'flightNumber': 'UA123',
          'departure': 'LAX',
          'arrival': 'JFK',
          'scheduledDeparture': Timestamp.fromDate(now),
          'userId': 'user-123',
          'createdAt': Timestamp.fromDate(now),
        };

        final skyNode = SkyNode.fromJson(json, 'doc-id');

        expect(skyNode.id, 'doc-id');
        expect(skyNode.nodeId, '!abc123');
        expect(skyNode.flightNumber, 'UA123');
        expect(skyNode.departure, 'LAX');
        expect(skyNode.arrival, 'JFK');
        expect(skyNode.scheduledDeparture, now);
        expect(skyNode.userId, 'user-123');
        expect(skyNode.isActive, false);
        expect(skyNode.receptionCount, 0);
      });

      test('parses optional fields when present', () {
        final departure = DateTime(2025, 6, 15, 10, 0);
        final arrival = DateTime(2025, 6, 15, 18, 0);
        final created = DateTime(2025, 6, 1, 12, 0);

        final json = {
          'nodeId': '!def456',
          'nodeName': 'MyNode',
          'flightNumber': 'BA456',
          'airline': 'British Airways',
          'departure': 'LHR',
          'arrival': 'SFO',
          'scheduledDeparture': Timestamp.fromDate(departure),
          'scheduledArrival': Timestamp.fromDate(arrival),
          'userId': 'user-456',
          'userName': 'John Doe',
          'notes': 'Test notes',
          'isActive': true,
          'createdAt': Timestamp.fromDate(created),
          'receptionCount': 10,
        };

        final skyNode = SkyNode.fromJson(json, 'full-doc-id');

        expect(skyNode.nodeName, 'MyNode');
        expect(skyNode.airline, 'British Airways');
        expect(skyNode.scheduledArrival, arrival);
        expect(skyNode.userName, 'John Doe');
        expect(skyNode.notes, 'Test notes');
        expect(skyNode.isActive, true);
        expect(skyNode.receptionCount, 10);
      });

      test('handles null optional fields gracefully', () {
        final now = DateTime(2025, 6, 15, 10, 0);
        final json = {
          'nodeId': '!abc123',
          'nodeName': null,
          'flightNumber': 'UA123',
          'airline': null,
          'departure': 'LAX',
          'arrival': 'JFK',
          'scheduledDeparture': Timestamp.fromDate(now),
          'scheduledArrival': null,
          'userId': 'user-123',
          'userName': null,
          'notes': null,
          'isActive': null,
          'createdAt': Timestamp.fromDate(now),
          'receptionCount': null,
        };

        final skyNode = SkyNode.fromJson(json, 'doc-id');

        expect(skyNode.nodeName, isNull);
        expect(skyNode.airline, isNull);
        expect(skyNode.scheduledArrival, isNull);
        expect(skyNode.userName, isNull);
        expect(skyNode.notes, isNull);
        expect(skyNode.isActive, false);
        expect(skyNode.receptionCount, 0);
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final departure = DateTime(2025, 6, 15, 10, 0);
        final arrival = DateTime(2025, 6, 15, 18, 0);
        final created = DateTime(2025, 6, 1, 12, 0);

        final skyNode = SkyNode(
          id: 'test-id',
          nodeId: '!abc123',
          nodeName: 'TestNode',
          flightNumber: 'UA123',
          airline: 'United',
          departure: 'LAX',
          arrival: 'JFK',
          scheduledDeparture: departure,
          scheduledArrival: arrival,
          userId: 'user-123',
          userName: 'Test User',
          notes: 'Test notes',
          isActive: true,
          createdAt: created,
          receptionCount: 5,
        );

        final json = skyNode.toJson();

        expect(json['nodeId'], '!abc123');
        expect(json['nodeName'], 'TestNode');
        expect(json['flightNumber'], 'UA123');
        expect(json['airline'], 'United');
        expect(json['departure'], 'LAX');
        expect(json['arrival'], 'JFK');
        expect((json['scheduledDeparture'] as Timestamp).toDate(), departure);
        expect((json['scheduledArrival'] as Timestamp).toDate(), arrival);
        expect(json['userId'], 'user-123');
        expect(json['userName'], 'Test User');
        expect(json['notes'], 'Test notes');
        expect(json['isActive'], true);
        expect((json['createdAt'] as Timestamp).toDate(), created);
        expect(json['receptionCount'], 5);
      });

      test('serializes null scheduledArrival correctly', () {
        final now = DateTime.now();
        final skyNode = SkyNode(
          id: 'test-id',
          nodeId: '!abc123',
          flightNumber: 'UA123',
          departure: 'LAX',
          arrival: 'JFK',
          scheduledDeparture: now,
          scheduledArrival: null,
          userId: 'user-123',
          createdAt: now,
        );

        final json = skyNode.toJson();

        expect(json['scheduledArrival'], isNull);
      });

      test('does not include id in json output', () {
        final now = DateTime.now();
        final skyNode = SkyNode(
          id: 'test-id',
          nodeId: '!abc123',
          flightNumber: 'UA123',
          departure: 'LAX',
          arrival: 'JFK',
          scheduledDeparture: now,
          userId: 'user-123',
          createdAt: now,
        );

        final json = skyNode.toJson();

        expect(json.containsKey('id'), false);
      });
    });

    group('copyWith', () {
      test('copies all fields when none specified', () {
        final now = DateTime.now();
        final original = SkyNode(
          id: 'test-id',
          nodeId: '!abc123',
          nodeName: 'TestNode',
          flightNumber: 'UA123',
          airline: 'United',
          departure: 'LAX',
          arrival: 'JFK',
          scheduledDeparture: now,
          userId: 'user-123',
          isActive: true,
          createdAt: now,
          receptionCount: 5,
        );

        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.nodeId, original.nodeId);
        expect(copy.nodeName, original.nodeName);
        expect(copy.flightNumber, original.flightNumber);
        expect(copy.airline, original.airline);
        expect(copy.departure, original.departure);
        expect(copy.arrival, original.arrival);
        expect(copy.scheduledDeparture, original.scheduledDeparture);
        expect(copy.userId, original.userId);
        expect(copy.isActive, original.isActive);
        expect(copy.createdAt, original.createdAt);
        expect(copy.receptionCount, original.receptionCount);
      });

      test('overrides specified fields only', () {
        final now = DateTime.now();
        final original = SkyNode(
          id: 'test-id',
          nodeId: '!abc123',
          flightNumber: 'UA123',
          departure: 'LAX',
          arrival: 'JFK',
          scheduledDeparture: now,
          userId: 'user-123',
          isActive: false,
          createdAt: now,
          receptionCount: 0,
        );

        final copy = original.copyWith(
          isActive: true,
          receptionCount: 10,
          notes: 'New notes',
        );

        expect(copy.id, original.id);
        expect(copy.nodeId, original.nodeId);
        expect(copy.flightNumber, original.flightNumber);
        expect(copy.isActive, true);
        expect(copy.receptionCount, 10);
        expect(copy.notes, 'New notes');
      });
    });

    // NOTE: The isUpcoming, isPast, and statusText getters call DateTime.now()
    // internally, which makes them inherently time-sensitive. These tests
    // verify the logic works correctly at test execution time. The getters
    // compare against the real clock, so we use generous time margins.
    group('status properties', () {
      group('isUpcoming', () {
        test('returns true for flight 12 hours in future', () {
          // Use a comfortable margin well within the 24-hour window
          final skyNode = SkyNode(
            id: 'test',
            nodeId: '!abc',
            flightNumber: 'UA123',
            departure: 'LAX',
            arrival: 'JFK',
            scheduledDeparture: DateTime.now().add(const Duration(hours: 12)),
            userId: 'user',
            createdAt: DateTime.now(),
          );

          expect(skyNode.isUpcoming, true);
        });

        test('returns true for flight 1 minute in future', () {
          // Just barely in the future - should be upcoming
          final skyNode = SkyNode(
            id: 'test',
            nodeId: '!abc',
            flightNumber: 'UA123',
            departure: 'LAX',
            arrival: 'JFK',
            scheduledDeparture: DateTime.now().add(const Duration(minutes: 1)),
            userId: 'user',
            createdAt: DateTime.now(),
          );

          expect(skyNode.isUpcoming, true);
        });

        test('returns false for flight 48 hours in future', () {
          // Use a large margin well beyond the 24-hour window
          final skyNode = SkyNode(
            id: 'test',
            nodeId: '!abc',
            flightNumber: 'UA123',
            departure: 'LAX',
            arrival: 'JFK',
            scheduledDeparture: DateTime.now().add(const Duration(hours: 48)),
            userId: 'user',
            createdAt: DateTime.now(),
          );

          expect(skyNode.isUpcoming, false);
        });

        test('returns false for flight 1 hour in the past', () {
          final skyNode = SkyNode(
            id: 'test',
            nodeId: '!abc',
            flightNumber: 'UA123',
            departure: 'LAX',
            arrival: 'JFK',
            scheduledDeparture: DateTime.now().subtract(
              const Duration(hours: 1),
            ),
            userId: 'user',
            createdAt: DateTime.now(),
          );

          expect(skyNode.isUpcoming, false);
        });
      });

      group('isPast', () {
        test('returns true when 2 hours past scheduled arrival', () {
          final skyNode = SkyNode(
            id: 'test',
            nodeId: '!abc',
            flightNumber: 'UA123',
            departure: 'LAX',
            arrival: 'JFK',
            scheduledDeparture: DateTime.now().subtract(
              const Duration(hours: 10),
            ),
            scheduledArrival: DateTime.now().subtract(const Duration(hours: 2)),
            userId: 'user',
            createdAt: DateTime.now(),
          );

          expect(skyNode.isPast, true);
        });

        test('returns false when scheduled arrival is 2 hours in future', () {
          final skyNode = SkyNode(
            id: 'test',
            nodeId: '!abc',
            flightNumber: 'UA123',
            departure: 'LAX',
            arrival: 'JFK',
            scheduledDeparture: DateTime.now().subtract(
              const Duration(hours: 2),
            ),
            scheduledArrival: DateTime.now().add(const Duration(hours: 2)),
            userId: 'user',
            createdAt: DateTime.now(),
          );

          expect(skyNode.isPast, false);
        });

        test('returns true when 14 hours past departure with no arrival', () {
          // Well past the 12-hour assumed max flight time
          final skyNode = SkyNode(
            id: 'test',
            nodeId: '!abc',
            flightNumber: 'UA123',
            departure: 'LAX',
            arrival: 'JFK',
            scheduledDeparture: DateTime.now().subtract(
              const Duration(hours: 14),
            ),
            scheduledArrival: null,
            userId: 'user',
            createdAt: DateTime.now(),
          );

          expect(skyNode.isPast, true);
        });

        test('returns false when 6 hours past departure with no arrival', () {
          // Well within the 12-hour assumed max flight time
          final skyNode = SkyNode(
            id: 'test',
            nodeId: '!abc',
            flightNumber: 'UA123',
            departure: 'LAX',
            arrival: 'JFK',
            scheduledDeparture: DateTime.now().subtract(
              const Duration(hours: 6),
            ),
            scheduledArrival: null,
            userId: 'user',
            createdAt: DateTime.now(),
          );

          expect(skyNode.isPast, false);
        });
      });

      group('statusText', () {
        test('returns "In Flight" when active', () {
          final skyNode = SkyNode(
            id: 'test',
            nodeId: '!abc',
            flightNumber: 'UA123',
            departure: 'LAX',
            arrival: 'JFK',
            scheduledDeparture: DateTime.now().subtract(
              const Duration(hours: 2),
            ),
            userId: 'user',
            createdAt: DateTime.now(),
            isActive: true,
          );

          expect(skyNode.statusText, 'In Flight');
        });

        test('returns "Completed" when past', () {
          // 24 hours past - definitely completed
          final skyNode = SkyNode(
            id: 'test',
            nodeId: '!abc',
            flightNumber: 'UA123',
            departure: 'LAX',
            arrival: 'JFK',
            scheduledDeparture: DateTime.now().subtract(
              const Duration(hours: 24),
            ),
            userId: 'user',
            createdAt: DateTime.now(),
            isActive: false,
          );

          expect(skyNode.statusText, 'Completed');
        });

        test('returns "Upcoming" when 5 hours in future', () {
          final skyNode = SkyNode(
            id: 'test',
            nodeId: '!abc',
            flightNumber: 'UA123',
            departure: 'LAX',
            arrival: 'JFK',
            scheduledDeparture: DateTime.now().add(const Duration(hours: 5)),
            userId: 'user',
            createdAt: DateTime.now(),
            isActive: false,
          );

          expect(skyNode.statusText, 'Upcoming');
        });

        test('returns "Scheduled" when 3 days in future', () {
          final skyNode = SkyNode(
            id: 'test',
            nodeId: '!abc',
            flightNumber: 'UA123',
            departure: 'LAX',
            arrival: 'JFK',
            scheduledDeparture: DateTime.now().add(const Duration(days: 3)),
            userId: 'user',
            createdAt: DateTime.now(),
            isActive: false,
          );

          expect(skyNode.statusText, 'Scheduled');
        });
      });
    });
  });

  group('ReceptionReport', () {
    group('constructor', () {
      test('creates instance with required fields', () {
        final now = DateTime.now();
        final report = ReceptionReport(
          id: 'report-id',
          skyNodeId: 'skynode-id',
          flightNumber: 'UA123',
          reporterId: 'reporter-id',
          receivedAt: now,
          createdAt: now,
        );

        expect(report.id, 'report-id');
        expect(report.skyNodeId, 'skynode-id');
        expect(report.flightNumber, 'UA123');
        expect(report.reporterId, 'reporter-id');
        expect(report.receivedAt, now);
        expect(report.createdAt, now);
      });

      test('creates instance with all optional fields', () {
        final received = DateTime(2025, 6, 15, 14, 30);
        final created = DateTime(2025, 6, 15, 14, 31);

        final report = ReceptionReport(
          id: 'full-report',
          skyNodeId: 'skynode-id',
          flightNumber: 'BA456',
          reporterId: 'reporter-id',
          reporterName: 'Ground Station Alpha',
          reporterNodeId: '!ground123',
          latitude: 34.0522,
          longitude: -118.2437,
          altitude: 100.0,
          snr: 12.5,
          rssi: -95.0,
          estimatedDistance: 150.5,
          notes: 'Clear reception at FL350',
          receivedAt: received,
          createdAt: created,
        );

        expect(report.reporterName, 'Ground Station Alpha');
        expect(report.reporterNodeId, '!ground123');
        expect(report.latitude, 34.0522);
        expect(report.longitude, -118.2437);
        expect(report.altitude, 100.0);
        expect(report.snr, 12.5);
        expect(report.rssi, -95.0);
        expect(report.estimatedDistance, 150.5);
        expect(report.notes, 'Clear reception at FL350');
      });
    });

    group('fromJson', () {
      test('parses required fields correctly', () {
        final received = DateTime(2025, 6, 15, 14, 30);
        final created = DateTime(2025, 6, 15, 14, 31);

        final json = {
          'skyNodeId': 'skynode-id',
          'flightNumber': 'UA123',
          'reporterId': 'reporter-id',
          'receivedAt': Timestamp.fromDate(received),
          'createdAt': Timestamp.fromDate(created),
        };

        final report = ReceptionReport.fromJson(json, 'doc-id');

        expect(report.id, 'doc-id');
        expect(report.skyNodeId, 'skynode-id');
        expect(report.flightNumber, 'UA123');
        expect(report.reporterId, 'reporter-id');
        expect(report.receivedAt, received);
        expect(report.createdAt, created);
      });

      test('parses optional numeric fields correctly', () {
        final now = DateTime.now();
        final json = {
          'skyNodeId': 'skynode-id',
          'flightNumber': 'UA123',
          'reporterId': 'reporter-id',
          'latitude': 34.0522,
          'longitude': -118.2437,
          'altitude': 100,
          'snr': 12,
          'rssi': -95,
          'estimatedDistance': 150,
          'receivedAt': Timestamp.fromDate(now),
          'createdAt': Timestamp.fromDate(now),
        };

        final report = ReceptionReport.fromJson(json, 'doc-id');

        expect(report.latitude, 34.0522);
        expect(report.longitude, -118.2437);
        expect(report.altitude, 100.0);
        expect(report.snr, 12.0);
        expect(report.rssi, -95.0);
        expect(report.estimatedDistance, 150.0);
      });

      test('handles null optional fields gracefully', () {
        final now = DateTime.now();
        final json = {
          'skyNodeId': 'skynode-id',
          'flightNumber': 'UA123',
          'reporterId': 'reporter-id',
          'reporterName': null,
          'reporterNodeId': null,
          'latitude': null,
          'longitude': null,
          'altitude': null,
          'snr': null,
          'rssi': null,
          'estimatedDistance': null,
          'notes': null,
          'receivedAt': Timestamp.fromDate(now),
          'createdAt': Timestamp.fromDate(now),
        };

        final report = ReceptionReport.fromJson(json, 'doc-id');

        expect(report.reporterName, isNull);
        expect(report.reporterNodeId, isNull);
        expect(report.latitude, isNull);
        expect(report.longitude, isNull);
        expect(report.altitude, isNull);
        expect(report.snr, isNull);
        expect(report.rssi, isNull);
        expect(report.estimatedDistance, isNull);
        expect(report.notes, isNull);
      });
    });

    group('toJson', () {
      test('serializes all fields correctly', () {
        final received = DateTime(2025, 6, 15, 14, 30);
        final created = DateTime(2025, 6, 15, 14, 31);

        final report = ReceptionReport(
          id: 'report-id',
          skyNodeId: 'skynode-id',
          flightNumber: 'UA123',
          reporterId: 'reporter-id',
          reporterName: 'Ground Station',
          reporterNodeId: '!ground123',
          latitude: 34.0522,
          longitude: -118.2437,
          altitude: 100.0,
          snr: 12.5,
          rssi: -95.0,
          estimatedDistance: 150.5,
          notes: 'Test notes',
          receivedAt: received,
          createdAt: created,
        );

        final json = report.toJson();

        expect(json['skyNodeId'], 'skynode-id');
        expect(json['flightNumber'], 'UA123');
        expect(json['reporterId'], 'reporter-id');
        expect(json['reporterName'], 'Ground Station');
        expect(json['reporterNodeId'], '!ground123');
        expect(json['latitude'], 34.0522);
        expect(json['longitude'], -118.2437);
        expect(json['altitude'], 100.0);
        expect(json['snr'], 12.5);
        expect(json['rssi'], -95.0);
        expect(json['estimatedDistance'], 150.5);
        expect(json['notes'], 'Test notes');
        expect((json['receivedAt'] as Timestamp).toDate(), received);
        expect((json['createdAt'] as Timestamp).toDate(), created);
      });

      test('does not include id in json output', () {
        final now = DateTime.now();
        final report = ReceptionReport(
          id: 'report-id',
          skyNodeId: 'skynode-id',
          flightNumber: 'UA123',
          reporterId: 'reporter-id',
          receivedAt: now,
          createdAt: now,
        );

        final json = report.toJson();

        expect(json.containsKey('id'), false);
      });
    });
  });
}
