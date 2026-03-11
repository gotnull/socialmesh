// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/logging.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';

/// Coordinator for DM confirmation-timeout and bounded auto-retry.
///
/// ## What it does
/// 1. **Timeout → Unconfirmed**: Every [DmRetryConstants.coordinatorTickInterval]
///    the coordinator scans outbound DMs in the [MessageStatus.sent] state.
///    If a message has been waiting for an ACK longer than
///    [DmRetryConstants.ackTimeout] it transitions to [MessageStatus.unconfirmed].
///
/// 2. **Manual resend**: Callers invoke [scheduleResend] from the UI layer.
///    The method immediately dispatches a new send attempt and updates retry
///    state on the message record.
///
/// 3. **Bounded auto-retry**: When [autoRetryEnabled] is true on a message,
///    the coordinator automatically resends every [DmRetryConstants.retryInterval]
///    until one of the stop conditions is met:
///    - An ACK is received (message transitions to [MessageStatus.delivered]).
///    - [DmRetryConstants.maxAutoRetries] attempts have been made.
///    - [DmRetryConstants.autoRetryWindow] has elapsed since the first send.
///    - The user cancels via [disableAutoRetry].
///
/// ## Lifecycle
/// - Foreground-only: the ticker runs on a [Timer.periodic] which is only
///   active while the app process is alive. Retries are NOT fired in the
///   background. This is documented and intentional — true background retry
///   would require platform-specific background execution that is outside
///   the current scope.
/// - On **app restart** the coordinator calls [_resetStaleRetrying] to
///   transition any messages stuck in [MessageStatus.retrying] back to
///   [MessageStatus.unconfirmed]. Auto-retry eligibility is preserved
///   through the persisted [Message.autoRetryEnabled] flag and the timer
///   will re-trigger on the next tick within the expiry window.
///
/// ## Provider wiring
/// Instantiated and started by [dmRetryCoordinatorProvider]. The provider is
/// kept alive by [MessagesNotifier] which `watch`es it during its [build]
/// lifecycle to ensure the coordinator is always running.
class DmRetryCoordinator {
  final Ref _ref;
  Timer? _tickTimer;
  bool _started = false;
  bool _disposed = false;

  DmRetryCoordinator(this._ref);

  /// Start the periodic ticker.  Idempotent — safe to call multiple times.
  void start() {
    if (_started || _disposed) return;
    _started = true;

    // On start: reset any messages stuck in retrying state from a previous
    // session (the timer was cancelled when the app was killed).
    _resetStaleRetrying();

    _tickTimer = Timer.periodic(
      DmRetryConstants.coordinatorTickInterval,
      (_) => _tick(),
    );
    AppLogging.messages('DmRetryCoordinator started');
  }

  void dispose() {
    _disposed = true;
    _tickTimer?.cancel();
    _tickTimer = null;
    AppLogging.messages('DmRetryCoordinator disposed');
  }

  // ---------------------------------------------------------------------------
  // Public API — called from UI layer
  // ---------------------------------------------------------------------------

  /// Immediately resend [message] as a manual one-shot attempt.
  /// Updates [Message.retryCount], [Message.lastAttemptAt], and sets
  /// status to [MessageStatus.retrying] while the send is in flight.
  ///
  /// Safe to call from a widget — the send is dispatched asynchronously and
  /// does not require [BuildContext].
  Future<void> scheduleResend(Message message) async {
    if (_disposed) return;
    if (!message.isDirect) return; // Only DMs

    final notifier = _ref.read(messagesProvider.notifier);
    final now = DateTime.now();

    // Guard: don't double-resend
    if (message.status == MessageStatus.retrying) return;

    // Mark as retrying before the async send so the UI updates immediately
    notifier.updateMessage(
      message.id,
      message.copyWith(
        status: MessageStatus.retrying,
        lastAttemptAt: now,
        retryCount: message.retryCount + 1,
        errorMessage: null,
        routingError: null,
      ),
    );

    await _dispatchSend(message.id);
  }

  /// Enable bounded auto-retry for [messageId].
  /// The coordinator will resend autonomously every
  /// [DmRetryConstants.retryInterval] until a stop condition is met.
  void enableAutoRetry(String messageId) {
    if (_disposed) return;
    final messages = _ref.read(messagesProvider);
    final message = messages.where((m) => m.id == messageId).firstOrNull;
    if (message == null || !message.isDirect) return;

    _ref
        .read(messagesProvider.notifier)
        .updateMessage(messageId, message.copyWith(autoRetryEnabled: true));
    AppLogging.messages(
      'DmRetryCoordinator: auto-retry enabled for $messageId',
    );
  }

  /// Disable auto-retry for [messageId].
  /// If the message is currently in [MessageStatus.retrying], it reverts to
  /// [MessageStatus.unconfirmed].
  void disableAutoRetry(String messageId) {
    if (_disposed) return;
    final messages = _ref.read(messagesProvider);
    final message = messages.where((m) => m.id == messageId).firstOrNull;
    if (message == null) return;

    final newStatus = message.status == MessageStatus.retrying
        ? MessageStatus.unconfirmed
        : message.status;

    _ref
        .read(messagesProvider.notifier)
        .updateMessage(
          messageId,
          message.copyWith(status: newStatus, autoRetryEnabled: false),
        );
    AppLogging.messages(
      'DmRetryCoordinator: auto-retry disabled for $messageId',
    );
  }

  // ---------------------------------------------------------------------------
  // Internal tick
  // ---------------------------------------------------------------------------

  void _tick() {
    if (_disposed) return;

    final messages = _ref.read(messagesProvider);
    final now = DateTime.now();

    for (final message in messages) {
      if (!_isEligible(message)) continue;

      if (message.status == MessageStatus.sent) {
        _maybeTimeout(message, now);
      } else if (message.status == MessageStatus.unconfirmed &&
          message.autoRetryEnabled) {
        _maybeAutoRetry(message, now);
      }
    }
  }

  /// Returns true for outbound DMs that are eligible for timeout/retry
  /// tracking.
  bool _isEligible(Message message) {
    // Only outbound DMs (not received, not broadcast)
    if (message.received) return false;
    if (message.isBroadcast) return false;
    // Skip terminal states
    if (message.status == MessageStatus.delivered) return false;
    if (message.status == MessageStatus.failed) return false;
    if (message.status == MessageStatus.pending) return false;
    // Skip legacy messages with no sentAt — we cannot compute a timeout
    if (message.status == MessageStatus.sent && message.sentAt == null) {
      return false;
    }
    return true;
  }

  void _maybeTimeout(Message message, DateTime now) {
    final sentAt = message.sentAt!;
    if (now.difference(sentAt) < DmRetryConstants.ackTimeout) return;

    final notifier = _ref.read(messagesProvider.notifier);

    if (message.autoRetryEnabled) {
      _maybeAutoRetry(message, now);
    } else {
      notifier.updateMessage(
        message.id,
        message.copyWith(status: MessageStatus.unconfirmed),
      );
      AppLogging.messages(
        'DmRetryCoordinator: message ${message.id} timed out → unconfirmed',
      );
    }
  }

  void _maybeAutoRetry(Message message, DateTime now) {
    final notifier = _ref.read(messagesProvider.notifier);
    final sentAt = message.sentAt ?? message.timestamp;

    // Stop: expiry window
    if (now.difference(sentAt) >= DmRetryConstants.autoRetryWindow) {
      notifier.updateMessage(
        message.id,
        message.copyWith(
          status: MessageStatus.unconfirmed,
          autoRetryEnabled: false,
        ),
      );
      AppLogging.messages(
        'DmRetryCoordinator: auto-retry expired for ${message.id}',
      );
      return;
    }

    // Stop: max attempts reached
    if (message.retryCount >= DmRetryConstants.maxAutoRetries) {
      notifier.updateMessage(
        message.id,
        message.copyWith(
          status: MessageStatus.unconfirmed,
          autoRetryEnabled: false,
        ),
      );
      AppLogging.messages(
        'DmRetryCoordinator: max retries reached for ${message.id}',
      );
      return;
    }

    // Throttle: wait at least retryInterval since last attempt
    if (message.lastAttemptAt != null) {
      final sinceLastAttempt = now.difference(message.lastAttemptAt!);
      if (sinceLastAttempt < DmRetryConstants.retryInterval) return;
    }

    // Trigger retry
    notifier.updateMessage(
      message.id,
      message.copyWith(
        status: MessageStatus.retrying,
        lastAttemptAt: now,
        retryCount: message.retryCount + 1,
        errorMessage: null,
        routingError: null,
      ),
    );
    AppLogging.messages(
      'DmRetryCoordinator: auto-retry ${message.retryCount + 1}/'
      '${DmRetryConstants.maxAutoRetries} for ${message.id}',
    );

    unawaited(_dispatchSend(message.id));
  }

  // ---------------------------------------------------------------------------
  // Reset stale state from a prior session
  // ---------------------------------------------------------------------------

  void _resetStaleRetrying() {
    final messages = _ref.read(messagesProvider);
    final notifier = _ref.read(messagesProvider.notifier);
    for (final message in messages) {
      if (message.status == MessageStatus.retrying) {
        notifier.updateMessage(
          message.id,
          message.copyWith(status: MessageStatus.unconfirmed),
        );
        AppLogging.messages(
          'DmRetryCoordinator: reset stale retrying → unconfirmed: ${message.id}',
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Send dispatch (shared by manual and auto paths)
  // ---------------------------------------------------------------------------

  Future<void> _dispatchSend(String messageId) async {
    if (_disposed) return;

    final notifier = _ref.read(messagesProvider.notifier);

    Message? current() =>
        _ref.read(messagesProvider).where((m) => m.id == messageId).firstOrNull;

    final msg = current();
    if (msg == null) return;

    try {
      final protocol = _ref.read(protocolServiceProvider);

      // Remove stale packet tracking for the old packetId to prevent a
      // delivery failure on the old packet from incorrectly overwriting the
      // in-flight state of the resend attempt.
      if (msg.packetId != null) {
        notifier.untrackPacket(msg.packetId!);
      }

      final packetId = await protocol.sendMessageWithPreTracking(
        text: msg.text,
        to: msg.to,
        channel: 0,
        wantAck: true,
        messageId: messageId,
        onPacketIdGenerated: (id) {
          notifier.trackPacket(id, messageId);
        },
        source: msg.source,
        replyId: msg.replyId,
      );

      // Transition to sent-awaiting-confirmation; preserve retry metadata
      final latest = current() ?? msg;
      notifier.updateMessage(
        messageId,
        latest.copyWith(
          status: MessageStatus.sent,
          packetId: packetId,
          sentAt: latest.sentAt ?? DateTime.now(),
          errorMessage: null,
          routingError: null,
        ),
      );

      AppLogging.messages(
        'DmRetryCoordinator: resend dispatched for $messageId → packetId=$packetId',
      );
    } catch (e) {
      // Give up this attempt; fall back to unconfirmed so the user can retry
      // manually or the auto-retry interval can try again.
      final latest = current() ?? msg;
      notifier.updateMessage(
        messageId,
        latest.copyWith(
          status: MessageStatus.unconfirmed,
          errorMessage: e.toString(),
        ),
      );
      AppLogging.messages(
        'DmRetryCoordinator: resend failed for $messageId — $e',
      );
    }
  }
}
