// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:socialmesh/core/constants.dart';
import 'package:socialmesh/models/mesh_models.dart';
import 'package:socialmesh/providers/app_providers.dart';
import 'package:socialmesh/services/messaging/dm_retry_coordinator.dart';

// ---------------------------------------------------------------------------
// Minimal in-memory MessagesNotifier — bypasses DB entirely
// ---------------------------------------------------------------------------

class _InMemoryMessagesNotifier extends MessagesNotifier {
  final List<Message> _seed;

  _InMemoryMessagesNotifier(this._seed);

  @override
  List<Message> build() => List<Message>.from(_seed);

  @override
  void addMessage(Message message) {
    state = [...state, message];
  }

  @override
  void updateMessage(String id, Message updated) {
    state = [
      for (final m in state)
        if (m.id == id) updated else m,
    ];
  }

  @override
  void trackPacket(int packetId, String messageId) {}

  @override
  void untrackPacket(int packetId) {}
}

// ---------------------------------------------------------------------------
// Test container factory
// Returns a configured [ProviderContainer] and the [DmRetryCoordinator]
// wired to its internal Ref (captured from inside dmRetryCoordinatorProvider).
// ---------------------------------------------------------------------------

/// Capture the coordinator created by [dmRetryCoordinatorProvider] without
/// calling start() so tests can drive ticks manually.
DmRetryCoordinator? _capturedCoordinator;

(ProviderContainer container, DmRetryCoordinator coordinator) _makeContainer(
  List<Message> seed,
) {
  _capturedCoordinator = null;

  final container = ProviderContainer(
    overrides: [
      messagesProvider.overrideWith(() => _InMemoryMessagesNotifier(seed)),
      dmRetryCoordinatorProvider.overrideWith((ref) {
        final coordinator = DmRetryCoordinator(ref);
        _capturedCoordinator = coordinator;
        ref.onDispose(coordinator.dispose);
        return coordinator;
      }),
    ],
  );

  // Force the coordinator provider to build so _capturedCoordinator is set
  container.read(dmRetryCoordinatorProvider);
  final coordinator = _capturedCoordinator!;
  return (container, coordinator);
}

// ---------------------------------------------------------------------------
// Test DM message factory
// ---------------------------------------------------------------------------

Message _makeDm({
  String id = 'msg-1',
  MessageStatus status = MessageStatus.sent,
  DateTime? sentAt,
  DateTime? lastAttemptAt,
  int retryCount = 0,
  bool autoRetryEnabled = false,
  int? packetId,
}) {
  return Message(
    id: id,
    from: 1,
    to: 2,
    text: 'hello',
    channel: 0,
    sent: true,
    status: status,
    source: MessageSource.manual,
    sentAt: sentAt ?? DateTime.now(),
    lastAttemptAt: lastAttemptAt,
    retryCount: retryCount,
    autoRetryEnabled: autoRetryEnabled,
    packetId: packetId,
    received: false,
  );
}

void main() {
  group('DmRetryConstants', () {
    test('ackTimeout is 5 minutes', () {
      expect(DmRetryConstants.ackTimeout, const Duration(minutes: 5));
    });

    test('retryInterval is 60 seconds', () {
      expect(DmRetryConstants.retryInterval, const Duration(seconds: 60));
    });

    test('maxAutoRetries is 5', () {
      expect(DmRetryConstants.maxAutoRetries, 5);
    });

    test('autoRetryWindow is 10 minutes', () {
      expect(DmRetryConstants.autoRetryWindow, const Duration(minutes: 10));
    });

    test('coordinatorTickInterval is 15 seconds', () {
      expect(
        DmRetryConstants.coordinatorTickInterval,
        const Duration(seconds: 15),
      );
    });
  });

  group('Message computed getters', () {
    test('isUnconfirmed is true only for unconfirmed status', () {
      expect(_makeDm(status: MessageStatus.unconfirmed).isUnconfirmed, isTrue);
      expect(_makeDm(status: MessageStatus.sent).isUnconfirmed, isFalse);
      expect(_makeDm(status: MessageStatus.retrying).isUnconfirmed, isFalse);
      expect(_makeDm(status: MessageStatus.delivered).isUnconfirmed, isFalse);
      expect(_makeDm(status: MessageStatus.failed).isUnconfirmed, isFalse);
    });

    test('isRetrying is true only for retrying status', () {
      expect(_makeDm(status: MessageStatus.retrying).isRetrying, isTrue);
      expect(_makeDm(status: MessageStatus.unconfirmed).isRetrying, isFalse);
      expect(_makeDm(status: MessageStatus.sent).isRetrying, isFalse);
    });

    test('canResend: true for unconfirmed DM not already retrying', () {
      expect(_makeDm(status: MessageStatus.unconfirmed).canResend, isTrue);
      expect(_makeDm(status: MessageStatus.failed).canResend, isTrue);
    });

    test('canResend: false when retrying', () {
      expect(_makeDm(status: MessageStatus.retrying).canResend, isFalse);
    });

    test('canResend: false for delivered or pending', () {
      expect(_makeDm(status: MessageStatus.delivered).canResend, isFalse);
      expect(_makeDm(status: MessageStatus.pending).canResend, isFalse);
    });

    test('canEnableAutoRetry: true for unconfirmed without auto-retry', () {
      expect(
        _makeDm(
          status: MessageStatus.unconfirmed,
          autoRetryEnabled: false,
        ).canEnableAutoRetry,
        isTrue,
      );
    });

    test('canEnableAutoRetry: false if already enabled', () {
      expect(
        _makeDm(
          status: MessageStatus.unconfirmed,
          autoRetryEnabled: true,
        ).canEnableAutoRetry,
        isFalse,
      );
    });

    test('canStopAutoRetry: true if autoRetryEnabled', () {
      expect(_makeDm(autoRetryEnabled: true).canStopAutoRetry, isTrue);
    });

    test('canStopAutoRetry: true if currently retrying', () {
      expect(_makeDm(status: MessageStatus.retrying).canStopAutoRetry, isTrue);
    });

    test('canStopAutoRetry: false if neither', () {
      expect(
        _makeDm(
          status: MessageStatus.unconfirmed,
          autoRetryEnabled: false,
        ).canStopAutoRetry,
        isFalse,
      );
    });
  });

  group('Message.copyWith retry fields', () {
    test('copyWith updates sentAt', () {
      final t = DateTime(2025, 1, 1);
      final updated = _makeDm().copyWith(sentAt: t);
      expect(updated.sentAt, t);
    });

    test('clearSentAt removes sentAt', () {
      final msg = _makeDm(sentAt: DateTime(2025, 1, 1));
      expect(msg.copyWith(clearSentAt: true).sentAt, isNull);
    });

    test('copyWith updates lastAttemptAt', () {
      final t = DateTime(2025, 6, 1, 12);
      expect(_makeDm().copyWith(lastAttemptAt: t).lastAttemptAt, t);
    });

    test('clearLastAttemptAt removes lastAttemptAt', () {
      final msg = _makeDm(lastAttemptAt: DateTime(2025, 6, 1));
      expect(msg.copyWith(clearLastAttemptAt: true).lastAttemptAt, isNull);
    });

    test('copyWith updates retryCount', () {
      expect(_makeDm(retryCount: 2).copyWith(retryCount: 4).retryCount, 4);
    });

    test('copyWith updates autoRetryEnabled', () {
      expect(
        _makeDm(
          autoRetryEnabled: false,
        ).copyWith(autoRetryEnabled: true).autoRetryEnabled,
        isTrue,
      );
    });
  });

  group('DmRetryCoordinator — start / dispose', () {
    test('start() is idempotent', () {
      final (container, coordinator) = _makeContainer([]);
      addTearDown(container.dispose);
      coordinator.start();
      coordinator.start(); // no-op second call
      coordinator.dispose();
    });

    test('dispose() after start does not throw', () {
      final (container, coordinator) = _makeContainer([]);
      addTearDown(container.dispose);
      coordinator.start();
      coordinator.dispose();
    });
  });

  group('DmRetryCoordinator — start() does not reset retrying', () {
    test('retrying messages are unchanged after start', () {
      final retrying = _makeDm(status: MessageStatus.retrying);
      final (container, coordinator) = _makeContainer([retrying]);
      addTearDown(() {
        coordinator.dispose();
        container.dispose();
      });

      coordinator.start();

      final messages = container.read(messagesProvider);
      expect(messages.length, 1);
      expect(messages.first.status, MessageStatus.retrying);
    });

    test('non-retrying messages are unchanged after start', () {
      final sent = _makeDm(status: MessageStatus.sent);
      final delivered = _makeDm(id: 'msg-2', status: MessageStatus.delivered);
      final (container, coordinator) = _makeContainer([sent, delivered]);
      addTearDown(() {
        coordinator.dispose();
        container.dispose();
      });

      coordinator.start();

      final messages = container.read(messagesProvider);
      expect(
        messages.firstWhere((m) => m.id == 'msg-1').status,
        MessageStatus.sent,
      );
      expect(
        messages.firstWhere((m) => m.id == 'msg-2').status,
        MessageStatus.delivered,
      );
    });
  });

  group('DmRetryCoordinator — enableAutoRetry / disableAutoRetry', () {
    test('enableAutoRetry sets autoRetryEnabled to true', () {
      final msg = _makeDm(status: MessageStatus.unconfirmed);
      final (container, coordinator) = _makeContainer([msg]);
      addTearDown(() {
        coordinator.dispose();
        container.dispose();
      });
      coordinator.start();

      coordinator.enableAutoRetry(msg.id);

      expect(container.read(messagesProvider).first.autoRetryEnabled, isTrue);
    });

    test('disableAutoRetry clears autoRetryEnabled', () {
      final msg = _makeDm(
        status: MessageStatus.unconfirmed,
        autoRetryEnabled: true,
      );
      final (container, coordinator) = _makeContainer([msg]);
      addTearDown(() {
        coordinator.dispose();
        container.dispose();
      });
      coordinator.start();

      coordinator.disableAutoRetry(msg.id);

      expect(container.read(messagesProvider).first.autoRetryEnabled, isFalse);
    });

    test('disableAutoRetry when retrying reverts status to unconfirmed', () {
      final msg = _makeDm(
        status: MessageStatus.retrying,
        autoRetryEnabled: true,
      );
      final (container, coordinator) = _makeContainer([msg]);
      addTearDown(() {
        coordinator.dispose();
        container.dispose();
      });
      coordinator.start();

      coordinator.disableAutoRetry(msg.id);

      final updated = container.read(messagesProvider).first;
      expect(updated.status, MessageStatus.unconfirmed);
      expect(updated.autoRetryEnabled, isFalse);
    });

    test('enableAutoRetry is no-op for broadcast messages', () {
      final broadcast = Message(
        id: 'bcast-1',
        from: 1,
        to: 0xFFFFFFFF,
        text: 'hi',
        channel: 0,
        sent: true,
        status: MessageStatus.unconfirmed,
        source: MessageSource.manual,
        received: false,
      );
      final (container, coordinator) = _makeContainer([broadcast]);
      addTearDown(() {
        coordinator.dispose();
        container.dispose();
      });
      coordinator.start();

      coordinator.enableAutoRetry(broadcast.id);

      // Broadcast is not a DM; autoRetryEnabled must stay false
      expect(container.read(messagesProvider).first.autoRetryEnabled, isFalse);
    });
  });

  group('DmRetryCoordinator — ineligibility guards', () {
    test('delivered messages are not touched by start', () {
      final delivered = _makeDm(status: MessageStatus.delivered);
      final (container, coordinator) = _makeContainer([delivered]);
      addTearDown(() {
        coordinator.dispose();
        container.dispose();
      });
      coordinator.start();
      expect(
        container.read(messagesProvider).first.status,
        MessageStatus.delivered,
      );
    });

    test('pending messages are not touched by start', () {
      final pending = _makeDm(status: MessageStatus.pending, sentAt: null);
      final (container, coordinator) = _makeContainer([pending]);
      addTearDown(() {
        coordinator.dispose();
        container.dispose();
      });
      coordinator.start();
      expect(
        container.read(messagesProvider).first.status,
        MessageStatus.pending,
      );
    });

    test('legacy sent messages without sentAt are not touched', () {
      final legacy = Message(
        id: 'legacy-1',
        from: 1,
        to: 2,
        text: 'old',
        channel: 0,
        sent: true,
        status: MessageStatus.sent,
        source: MessageSource.manual,
        received: false,
        // sentAt intentionally omitted
      );
      final (container, coordinator) = _makeContainer([legacy]);
      addTearDown(() {
        coordinator.dispose();
        container.dispose();
      });
      coordinator.start();
      final msg = container.read(messagesProvider).first;
      expect(msg.status, MessageStatus.sent);
      expect(msg.sentAt, isNull);
    });
  });

  group('DmRetryCoordinator — scheduleResend guards', () {
    test('scheduleResend is no-op after dispose', () async {
      final msg = _makeDm(status: MessageStatus.unconfirmed);
      final (container, coordinator) = _makeContainer([msg]);
      coordinator.start();
      coordinator.dispose();
      container.dispose();

      // Should not throw
      await coordinator.scheduleResend(msg);
    });

    test('scheduleResend is no-op for broadcast messages', () async {
      final broadcast = Message(
        id: 'bcast-1',
        from: 1,
        to: 0xFFFFFFFF,
        text: 'hi',
        channel: 0,
        sent: true,
        status: MessageStatus.unconfirmed,
        source: MessageSource.manual,
        received: false,
      );
      final (container, coordinator) = _makeContainer([broadcast]);
      addTearDown(() {
        coordinator.dispose();
        container.dispose();
      });
      coordinator.start();

      await coordinator.scheduleResend(broadcast);

      // Status must not have changed (no protocol available in test)
      // The method guards on isDirect and returns early
      final msg = container.read(messagesProvider).first;
      expect(msg.status, MessageStatus.unconfirmed);
    });

    test(
      'scheduleResend is no-op when passed message is already retrying',
      () async {
        // start() no longer resets stale retrying messages (that logic moved
        // to MessagesNotifier._loadFromStorage()). scheduleResend is called
        // with the original message object (status == retrying) so the guard
        // fires early — the message stays retrying because no reset happened.
        final msg = _makeDm(status: MessageStatus.retrying);
        final (container, coordinator) = _makeContainer([msg]);
        addTearDown(() {
          coordinator.dispose();
          container.dispose();
        });
        coordinator.start();

        // Pass the stale retrying message — guard fires, scheduleResend is a no-op
        await coordinator.scheduleResend(msg);

        // The stored status remains retrying since start() no longer resets it.
        final stored = container.read(messagesProvider).first;
        expect(stored.status, MessageStatus.retrying);
      },
    );
  });
}
