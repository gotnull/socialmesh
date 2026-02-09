import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/models/presence_confidence.dart';

void main() {
  group('MessageStatus', () {
    test('has all expected values', () {
      expect(MessageStatus.values.length, 4);
      expect(MessageStatus.values, contains(MessageStatus.pending));
      expect(MessageStatus.values, contains(MessageStatus.sent));
      expect(MessageStatus.values, contains(MessageStatus.delivered));
      expect(MessageStatus.values, contains(MessageStatus.failed));
    });
  });

  group('RoutingError', () {
    test('has all expected values', () {
      expect(RoutingError.values.length, 17);
    });

    test('none has correct code and message', () {
      expect(RoutingError.none.code, 0);
      expect(RoutingError.none.message, 'Delivered');
      expect(RoutingError.none.isSuccess, true);
    });

    test('noRoute has correct code', () {
      expect(RoutingError.noRoute.code, 1);
      expect(RoutingError.noRoute.isRetryable, true);
    });

    test('gotNak has correct code', () {
      expect(RoutingError.gotNak.code, 2);
    });

    test('timeout has correct code and is retryable', () {
      expect(RoutingError.timeout.code, 3);
      expect(RoutingError.timeout.isRetryable, true);
    });

    test('maxRetransmit is retryable', () {
      expect(RoutingError.maxRetransmit.code, 5);
      expect(RoutingError.maxRetransmit.isRetryable, true);
    });

    test('dutyCycleLimit is retryable', () {
      expect(RoutingError.dutyCycleLimit.code, 9);
      expect(RoutingError.dutyCycleLimit.isRetryable, true);
    });

    test('badRequest is not retryable', () {
      expect(RoutingError.badRequest.code, 32);
      expect(RoutingError.badRequest.isRetryable, false);
    });

    test('fromCode returns correct error', () {
      expect(RoutingError.fromCode(0), RoutingError.none);
      expect(RoutingError.fromCode(1), RoutingError.noRoute);
      expect(RoutingError.fromCode(3), RoutingError.timeout);
      expect(RoutingError.fromCode(32), RoutingError.badRequest);
    });

    test('fromCode returns none for unknown code', () {
      expect(RoutingError.fromCode(99), RoutingError.none);
      expect(RoutingError.fromCode(-1), RoutingError.none);
    });
  });

  group('Message', () {
    test('creates with required fields', () {
      final message = Message(from: 123, to: 456, text: 'Hello');

      expect(message.id, isNotEmpty);
      expect(message.from, 123);
      expect(message.to, 456);
      expect(message.text, 'Hello');
      expect(message.timestamp, isNotNull);
      expect(message.channel, isNull);
      expect(message.sent, false);
      expect(message.received, false);
      expect(message.acked, false);
      expect(message.status, MessageStatus.sent);
    });

    test('creates with all fields', () {
      final timestamp = DateTime(2024, 1, 1);
      final message = Message(
        id: 'custom-id',
        from: 123,
        to: 456,
        text: 'Test message',
        timestamp: timestamp,
        channel: 1,
        sent: true,
        received: true,
        acked: true,
        status: MessageStatus.delivered,
        errorMessage: 'No error',
        routingError: RoutingError.none,
        packetId: 99,
      );

      expect(message.id, 'custom-id');
      expect(message.timestamp, timestamp);
      expect(message.channel, 1);
      expect(message.sent, true);
      expect(message.received, true);
      expect(message.acked, true);
      expect(message.status, MessageStatus.delivered);
      expect(message.packetId, 99);
    });

    test('isBroadcast returns true for broadcast address', () {
      final broadcast = Message(from: 123, to: 0xFFFFFFFF, text: 'Broadcast');
      expect(broadcast.isBroadcast, true);
      expect(broadcast.isDirect, false);
    });

    test('isDirect returns true for specific address', () {
      final direct = Message(from: 123, to: 456, text: 'Direct');
      expect(direct.isDirect, true);
      expect(direct.isBroadcast, false);
    });

    test('isFailed returns true for failed status', () {
      final failed = Message(
        from: 123,
        to: 456,
        text: 'Failed',
        status: MessageStatus.failed,
      );
      expect(failed.isFailed, true);
    });

    test('isPending returns true for pending status', () {
      final pending = Message(
        from: 123,
        to: 456,
        text: 'Pending',
        status: MessageStatus.pending,
      );
      expect(pending.isPending, true);
    });

    test('isRetryable reflects routing error', () {
      final retryable = Message(
        from: 123,
        to: 456,
        text: 'Test',
        routingError: RoutingError.timeout,
      );
      expect(retryable.isRetryable, true);

      final notRetryable = Message(
        from: 123,
        to: 456,
        text: 'Test',
        routingError: RoutingError.badRequest,
      );
      expect(notRetryable.isRetryable, false);

      final noError = Message(from: 123, to: 456, text: 'Test');
      expect(noError.isRetryable, false);
    });

    test('copyWith preserves unmodified values', () {
      final original = Message(
        id: 'test-id',
        from: 123,
        to: 456,
        text: 'Original',
        channel: 1,
        status: MessageStatus.sent,
      );

      final copied = original.copyWith(status: MessageStatus.delivered);

      expect(copied.id, 'test-id');
      expect(copied.from, 123);
      expect(copied.to, 456);
      expect(copied.text, 'Original');
      expect(copied.channel, 1);
      expect(copied.status, MessageStatus.delivered);
    });

    test('toString returns readable representation', () {
      final message = Message(from: 123, to: 456, text: 'Test');
      expect(message.toString(), 'Message(from: 123, to: 456, text: Test)');
    });
  });

  group('MessageDeliveryUpdate', () {
    test('creates with required fields', () {
      final update = MessageDeliveryUpdate(packetId: 123, delivered: true);

      expect(update.packetId, 123);
      expect(update.delivered, true);
      expect(update.error, isNull);
    });

    test('isSuccess returns true for successful delivery', () {
      final success = MessageDeliveryUpdate(packetId: 123, delivered: true);
      expect(success.isSuccess, true);
      expect(success.isFailed, false);
    });

    test('isSuccess returns true for delivery with none error', () {
      final success = MessageDeliveryUpdate(
        packetId: 123,
        delivered: true,
        error: RoutingError.none,
      );
      expect(success.isSuccess, true);
    });

    test('isFailed returns true for failed delivery', () {
      final failed = MessageDeliveryUpdate(packetId: 123, delivered: false);
      expect(failed.isFailed, true);
      expect(failed.isSuccess, false);
    });

    test('isFailed returns true for delivery with error', () {
      final failed = MessageDeliveryUpdate(
        packetId: 123,
        delivered: true,
        error: RoutingError.timeout,
      );
      expect(failed.isFailed, true);
    });
  });

  group('MeshNode', () {
    test('creates with required fields', () {
      final node = MeshNode(nodeNum: 123);

      expect(node.nodeNum, 123);
      expect(node.longName, isNull);
      expect(node.shortName, isNull);
      expect(node.presenceConfidence, PresenceConfidence.unknown);
      expect(node.isFavorite, false);
    });

    test('creates with all basic fields', () {
      final lastHeard = DateTime.now();
      final node = MeshNode(
        nodeNum: 456,
        longName: 'Test Node',
        shortName: 'TEST',
        userId: 'user123',
        latitude: -33.8688,
        longitude: 151.2093,
        altitude: 100,
        lastHeard: lastHeard,
        snr: 10,
        rssi: -70,
        batteryLevel: 85,
        temperature: 25.5,
        humidity: 60.0,
        firmwareVersion: '2.3.0',
        hardwareModel: 'TBEAM',
        role: 'ROUTER',
        distance: 1500.0,
        isFavorite: true,
        avatarColor: 0xFF00FF00,
        hasPublicKey: true,
      );

      expect(node.nodeNum, 456);
      expect(node.longName, 'Test Node');
      expect(node.shortName, 'TEST');
      expect(node.latitude, -33.8688);
      expect(node.longitude, 151.2093);
      expect(node.altitude, 100);
      expect(node.batteryLevel, 85);
      expect(node.presenceConfidence, PresenceConfidence.active);
      expect(node.isFavorite, true);
      expect(node.hasPublicKey, true);
    });

    test('displayName returns longName when available', () {
      final node = MeshNode(
        nodeNum: 123,
        longName: 'Long Name',
        shortName: 'SHORT',
      );
      expect(node.displayName, 'Long Name');
    });

    test('displayName returns shortName when longName is null', () {
      final node = MeshNode(nodeNum: 123, shortName: 'SHORT');
      expect(node.displayName, 'SHORT');
    });

    test('displayName returns Meshtastic XXXX when both names are null', () {
      final node = MeshNode(nodeNum: 123);
      expect(node.displayName, 'Meshtastic 007B');
    });

    test('hasPosition returns true for valid position', () {
      final node = MeshNode(
        nodeNum: 123,
        latitude: -33.8688,
        longitude: 151.2093,
      );
      expect(node.hasPosition, true);
    });

    test('hasPosition returns false for null position', () {
      final node = MeshNode(nodeNum: 123);
      expect(node.hasPosition, false);

      final nodePartial = MeshNode(nodeNum: 123, latitude: -33.8688);
      expect(nodePartial.hasPosition, false);
    });

    test('hasPosition returns false for 0,0 position', () {
      final node = MeshNode(nodeNum: 123, latitude: 0.0, longitude: 0.0);
      expect(node.hasPosition, false);
    });

    test('copyWith preserves unmodified values', () {
      final original = MeshNode(
        nodeNum: 123,
        longName: 'Original',
        shortName: 'ORIG',
        batteryLevel: 80,
        lastHeard: DateTime.now(), // online
      );

      final copied = original.copyWith(batteryLevel: 50);

      expect(copied.nodeNum, 123);
      expect(copied.longName, 'Original');
      expect(copied.shortName, 'ORIG');
      expect(copied.batteryLevel, 50);
      expect(copied.presenceConfidence, PresenceConfidence.active);
    });

    test('equality based on nodeNum', () {
      final node1 = MeshNode(nodeNum: 123, longName: 'Node 1');
      final node2 = MeshNode(nodeNum: 123, longName: 'Node 2');
      final node3 = MeshNode(nodeNum: 456, longName: 'Node 1');

      expect(node1, equals(node2));
      expect(node1, isNot(equals(node3)));
    });

    test('hashCode based on nodeNum', () {
      final node1 = MeshNode(nodeNum: 123);
      final node2 = MeshNode(nodeNum: 123);

      expect(node1.hashCode, node2.hashCode);
    });

    test('toString returns readable representation', () {
      final node = MeshNode(nodeNum: 123, longName: 'Test Node');
      expect(node.toString(), 'MeshNode(Test Node, num: 123)');
    });
  });

  group('ChannelConfig', () {
    test('creates with required fields', () {
      final channel = ChannelConfig(index: 0, name: 'Primary', psk: [1, 2, 3]);

      expect(channel.index, 0);
      expect(channel.name, 'Primary');
      expect(channel.psk, [1, 2, 3]);
      expect(channel.uplink, false);
      expect(channel.downlink, false);
      expect(channel.role, 'SECONDARY');
      expect(channel.positionPrecision, 0);
    });

    test('creates with all fields', () {
      final channel = ChannelConfig(
        index: 1,
        name: 'Custom',
        psk: [4, 5, 6],
        uplink: true,
        downlink: true,
        role: 'PRIMARY',
        positionPrecision: 32,
      );

      expect(channel.index, 1);
      expect(channel.name, 'Custom');
      expect(channel.uplink, true);
      expect(channel.downlink, true);
      expect(channel.role, 'PRIMARY');
      expect(channel.positionPrecision, 32);
    });

    test('positionEnabled returns true when precision > 0', () {
      final enabled = ChannelConfig(
        index: 0,
        name: 'Test',
        psk: [],
        positionPrecision: 32,
      );
      expect(enabled.positionEnabled, true);

      final disabled = ChannelConfig(
        index: 0,
        name: 'Test',
        psk: [],
        positionPrecision: 0,
      );
      expect(disabled.positionEnabled, false);
    });

    test('copyWith preserves unmodified values', () {
      final original = ChannelConfig(
        index: 0,
        name: 'Original',
        psk: [1, 2, 3],
        uplink: true,
        role: 'PRIMARY',
      );

      final copied = original.copyWith(name: 'Modified');

      expect(copied.index, 0);
      expect(copied.name, 'Modified');
      expect(copied.psk, [1, 2, 3]);
      expect(copied.uplink, true);
      expect(copied.role, 'PRIMARY');
    });

    test('toString returns readable representation', () {
      final channel = ChannelConfig(index: 1, name: 'TestChannel', psk: []);
      expect(channel.toString(), 'ChannelConfig(TestChannel, index: 1)');
    });
  });
}
