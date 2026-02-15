// SPDX-License-Identifier: GPL-3.0-or-later

import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/protocol/admin_ack_tracker.dart';
import 'package:socialmesh/services/protocol/admin_target.dart';

/// Convenience helper to create a RemoteAdminTarget for tests.
RemoteAdminTarget _remote(int nodeNum) =>
    AdminTarget.remote(nodeNum) as RemoteAdminTarget;

void main() {
  group('AdminAckResult', () {
    test('acked result isSuccess', () {
      const result = AdminAckSuccess();
      expect(result.isSuccess, isTrue);
      expect(result.toString(), 'AdminAckResult.acked()');
    });

    test('failed result is not success', () {
      const result = AdminAckFailure(RoutingError.noRoute);
      expect(result.isSuccess, isFalse);
      expect(result.toString(), 'AdminAckResult.failed(noRoute)');
    });

    test('timedOut result is not success', () {
      const result = AdminAckTimeout();
      expect(result.isSuccess, isFalse);
      expect(result.toString(), 'AdminAckResult.timedOut()');
    });

    test('cancelled result is not success', () {
      const result = AdminAckCancelled();
      expect(result.isSuccess, isFalse);
      expect(result.toString(), 'AdminAckResult.cancelled()');
    });

    test('sealed class exhaustive switch', () {
      const AdminAckResult result = AdminAckSuccess();
      final description = switch (result) {
        AdminAckSuccess() => 'success',
        AdminAckFailure(:final error) => 'failed: ${error.name}',
        AdminAckTimeout() => 'timeout',
        AdminAckCancelled() => 'cancelled',
      };
      expect(description, 'success');
    });
  });

  group('AdminAckTracker', () {
    late AdminAckTracker tracker;

    setUp(() {
      tracker = AdminAckTracker();
    });

    test('registerRemoteAdmin returns the packetId', () {
      final id = tracker.registerRemoteAdmin(42, _remote(0xABCD));
      expect(id, 42);
      expect(tracker.pendingCount, 1);
      expect(tracker.isTracking(42), isTrue);
    });

    test('registerRemoteAdmin throws on duplicate packetId', () {
      tracker.registerRemoteAdmin(42, _remote(0xABCD));
      expect(
        () => tracker.registerRemoteAdmin(42, _remote(0xABCD)),
        throwsA(isA<StateError>()),
      );
    });

    test('awaitAck completes with acked on successful delivery', () async {
      tracker.registerRemoteAdmin(100, _remote(0x1234));

      // Simulate ACK arriving
      final future = tracker.awaitAck(100);
      tracker.onDeliveryUpdate(
        MessageDeliveryUpdate(packetId: 100, delivered: true),
      );

      final result = await future;
      expect(result, isA<AdminAckSuccess>());
      expect(result.isSuccess, isTrue);
      expect(tracker.pendingCount, 0);
    });

    test('awaitAck completes with failed on routing error', () async {
      tracker.registerRemoteAdmin(200, _remote(0x5678));

      final future = tracker.awaitAck(200);
      tracker.onDeliveryUpdate(
        MessageDeliveryUpdate(
          packetId: 200,
          delivered: false,
          error: RoutingError.noRoute,
        ),
      );

      final result = await future;
      expect(result, isA<AdminAckFailure>());
      expect((result as AdminAckFailure).error, RoutingError.noRoute);
      expect(tracker.pendingCount, 0);
    });

    test('awaitAck times out cleanly', () async {
      tracker.registerRemoteAdmin(300, _remote(0x9ABC));

      final result = await tracker.awaitAck(
        300,
        timeout: const Duration(milliseconds: 50),
      );

      expect(result, isA<AdminAckTimeout>());
      expect(tracker.pendingCount, 0);
    });

    test(
      'awaitAck for unregistered packet returns timedOut immediately',
      () async {
        final result = await tracker.awaitAck(999);
        expect(result, isA<AdminAckTimeout>());
      },
    );

    test('onDeliveryUpdate is a no-op for untracked packets', () {
      // Should not throw
      tracker.onDeliveryUpdate(
        MessageDeliveryUpdate(packetId: 555, delivered: true),
      );
      expect(tracker.pendingCount, 0);
    });

    test('multiple concurrent packets tracked independently', () async {
      tracker.registerRemoteAdmin(10, _remote(0x100));
      tracker.registerRemoteAdmin(20, _remote(0x200));
      tracker.registerRemoteAdmin(30, _remote(0x300));
      expect(tracker.pendingCount, 3);

      final future10 = tracker.awaitAck(10);
      final future20 = tracker.awaitAck(20);

      // ACK packet 10
      tracker.onDeliveryUpdate(
        MessageDeliveryUpdate(packetId: 10, delivered: true),
      );

      // NAK packet 20
      tracker.onDeliveryUpdate(
        MessageDeliveryUpdate(
          packetId: 20,
          delivered: false,
          error: RoutingError.timeout,
        ),
      );

      final result10 = await future10;
      final result20 = await future20;

      expect(result10, isA<AdminAckSuccess>());
      expect(result20, isA<AdminAckFailure>());
      expect(tracker.pendingCount, 1); // packet 30 still pending
      expect(tracker.isTracking(30), isTrue);
    });

    test('cancelAll completes all pending with cancelled', () async {
      tracker.registerRemoteAdmin(1, _remote(0xA));
      tracker.registerRemoteAdmin(2, _remote(0xB));
      tracker.registerRemoteAdmin(3, _remote(0xC));

      final future1 = tracker.awaitAck(1);
      final future2 = tracker.awaitAck(2);
      final future3 = tracker.awaitAck(3);

      tracker.cancelAll();

      final results = await Future.wait([future1, future2, future3]);
      for (final result in results) {
        expect(result, isA<AdminAckCancelled>());
      }
      expect(tracker.pendingCount, 0);
    });

    test('unregister completes with cancelled and removes entry', () async {
      tracker.registerRemoteAdmin(42, _remote(0xDEAD));
      final future = tracker.awaitAck(42);

      tracker.unregister(42);

      final result = await future;
      expect(result, isA<AdminAckCancelled>());
      expect(tracker.isTracking(42), isFalse);
    });

    test('delivery update after cancelAll is a no-op', () {
      tracker.registerRemoteAdmin(1, _remote(0xBEEF));
      tracker.cancelAll();

      // Should not throw
      tracker.onDeliveryUpdate(
        MessageDeliveryUpdate(packetId: 1, delivered: true),
      );
      expect(tracker.pendingCount, 0);
    });

    test('failed delivery with null error uses noResponse', () async {
      tracker.registerRemoteAdmin(50, _remote(0xCAFE));
      final future = tracker.awaitAck(50);

      tracker.onDeliveryUpdate(
        MessageDeliveryUpdate(packetId: 50, delivered: false),
      );

      final result = await future;
      expect(result, isA<AdminAckFailure>());
      expect((result as AdminAckFailure).error, RoutingError.noResponse);
    });
  });
}
