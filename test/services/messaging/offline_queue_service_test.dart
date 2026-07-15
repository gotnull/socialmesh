// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/services/messaging/offline_queue_service.dart';

QueuedMessage _msg(String id, {int channel = 1}) => QueuedMessage(
  id: id,
  text: 'text-$id',
  to: 0xFFFFFFFF,
  channel: channel,
  wantAck: true,
);

void main() {
  // OfflineQueueService is a singleton; each test resets its state and
  // installs fresh callbacks.
  late OfflineQueueService service;
  late List<String> sentIds;
  late Map<String, MessageStatus> statusUpdates;
  late Map<String, String?> errorUpdates;
  late bool ready;
  late bool sendShouldFail;

  setUp(() {
    service = OfflineQueueService();
    service.clear();
    service.setConnectionState(false);
    sentIds = [];
    statusUpdates = {};
    errorUpdates = {};
    ready = true;
    sendShouldFail = false;
    var nextPacketId = 100;
    service.initialize(
      sendCallback:
          ({
            required String text,
            required int to,
            required int channel,
            required bool wantAck,
            required String messageId,
          }) async {
            if (sendShouldFail) {
              throw Exception('radio unavailable');
            }
            sentIds.add(messageId);
            return nextPacketId++;
          },
      updateCallback:
          (
            String messageId,
            MessageStatus status, {
            int? packetId,
            String? errorMessage,
          }) {
            statusUpdates[messageId] = status;
            errorUpdates[messageId] = errorMessage;
          },
      readyToSendCallback: () => ready,
    );
  });

  tearDown(() {
    service.clear();
    service.setConnectionState(false);
  });

  test('drains queued messages in order on connect edge', () {
    fakeAsync((async) {
      service.enqueue(_msg('a'));
      service.enqueue(_msg('b'));
      async.flushMicrotasks();
      expect(sentIds, isEmpty);
      expect(service.pendingCount, 2);

      service.setConnectionState(true);
      async.elapse(const Duration(seconds: 2));

      expect(sentIds, ['a', 'b']);
      expect(service.pendingCount, 0);
      expect(statusUpdates['a'], MessageStatus.sent);
      expect(statusUpdates['b'], MessageStatus.sent);
    });
  });

  test('readiness timeout re-arms and drains once ready flips', () {
    fakeAsync((async) {
      ready = false;
      service.enqueue(_msg('a'));
      service.setConnectionState(true);

      // Readiness wait gives up after 10s and arms a 5s retry.
      async.elapse(const Duration(seconds: 11));
      expect(sentIds, isEmpty);
      expect(service.pendingCount, 1);

      ready = true;
      async.elapse(const Duration(seconds: 6));

      expect(sentIds, ['a']);
      expect(service.pendingCount, 0);
    });
  });

  test('concurrent triggers during readiness wait send each message once', () {
    fakeAsync((async) {
      ready = false;
      service.enqueue(_msg('a'));
      service.enqueue(_msg('b'));
      service.setConnectionState(true);
      async.elapse(const Duration(milliseconds: 500));

      // Fire every other trigger while the first drain waits on readiness.
      service.processQueueIfNeeded();
      service.processQueueIfNeeded();
      service.enqueue(_msg('c'));
      async.elapse(const Duration(milliseconds: 500));

      ready = true;
      async.elapse(const Duration(seconds: 5));

      expect(sentIds, ['a', 'b', 'c']);
      expect(service.pendingCount, 0);
    });
  });

  test('marks message failed after three send failures', () {
    fakeAsync((async) {
      sendShouldFail = true;
      service.enqueue(_msg('a'));
      service.setConnectionState(true);

      // Two retry backoffs (2s each) plus slack.
      async.elapse(const Duration(seconds: 10));

      expect(sentIds, isEmpty);
      expect(service.pendingCount, 0);
      expect(statusUpdates['a'], MessageStatus.failed);
      expect(errorUpdates['a'], isNotNull);
    });
  });

  test('aborts when disconnected mid-wait and drains on reconnect', () {
    fakeAsync((async) {
      ready = false;
      service.enqueue(_msg('a'));
      service.setConnectionState(true);
      async.elapse(const Duration(seconds: 1));

      service.setConnectionState(false);
      async.elapse(const Duration(seconds: 30));
      expect(sentIds, isEmpty);
      expect(service.pendingCount, 1);

      ready = true;
      service.setConnectionState(true);
      async.elapse(const Duration(seconds: 2));

      expect(sentIds, ['a']);
      expect(service.pendingCount, 0);
    });
  });
}
