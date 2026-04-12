// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Maps MRRP engine request/response lifecycle to [DeliveryPhase]
/// for the UI layer.
///
/// Wraps [MrrpEngine.sendRequest] and emits phase transitions that
/// [DeliveryProgressCard] can display. The engine itself is a simple
/// request/response model; this tracker synthesizes intermediate
/// phases (preparing → sending → retrying → delivered/failed) for
/// user-friendly progress feedback.
///
/// Supports bounded automatic retry for idempotent MRRP requests.
/// Retry is opt-in via [MrrpRetryPolicy] to protect non-idempotent
/// operations from unsafe re-sends.
library;

import 'dart:async';

import '../../../core/logging.dart';
import '../../../core/widgets/delivery_progress_card.dart';
import '../../../services/protocol/sip/mrrp_dispatcher.dart';
import '../../../services/protocol/sip/mrrp_engine.dart';
import '../../../services/protocol/sip/mrrp_frame.dart';
import '../../../services/protocol/sip/mrrp_types.dart';

// ---------------------------------------------------------------------------
// Retry policy
// ---------------------------------------------------------------------------

/// Controls whether automatic retry is enabled for an MRRP request.
///
/// Only idempotent / read-style requests should use [idempotent].
/// Non-idempotent operations (writes, state mutations) must use [none].
enum MrrpRetryPolicy {
  /// No automatic retry. A single attempt is made.
  none,

  /// Retry on timeout (safe for idempotent / read operations).
  ///
  /// Up to [MrrpRetryConfig.maxAttempts] total attempts with bounded
  /// delay between retries.
  idempotent,
}

/// Retry configuration constants for MRRP request delivery.
///
/// Kept in a named class for discoverability and testability.
abstract final class MrrpRetryConfig {
  /// Total attempts including the initial send.
  static const int maxAttempts = 3;

  /// Delay before retry attempt 2.
  static const Duration retryDelay1 = Duration(seconds: 2);

  /// Delay before retry attempt 3 (slightly longer).
  static const Duration retryDelay2 = Duration(seconds: 4);

  /// Returns the delay before the given retry attempt (1-indexed retry,
  /// i.e. retry 1 = second overall attempt).
  static Duration delayForRetry(int retryNumber) {
    return retryNumber <= 1 ? retryDelay1 : retryDelay2;
  }
}

// ---------------------------------------------------------------------------
// Delivery state
// ---------------------------------------------------------------------------

/// State snapshot for a single tracked delivery.
class MrrpDeliveryState {
  /// Unique ID for this delivery.
  final String deliveryId;

  /// Current delivery phase.
  final DeliveryPhase phase;

  /// MRRP status code (null until response arrives).
  final MrrpStatusCode? statusCode;

  /// Round-trip latency (null until response arrives).
  final Duration? latency;

  /// The response frame (null until response arrives).
  final MrrpFrame? response;

  /// Total attempts made (1 = single attempt, 2+ = retried).
  final int attemptsMade;

  const MrrpDeliveryState({
    required this.deliveryId,
    required this.phase,
    this.statusCode,
    this.latency,
    this.response,
    this.attemptsMade = 1,
  });

  MrrpDeliveryState copyWith({
    DeliveryPhase? phase,
    MrrpStatusCode? statusCode,
    Duration? latency,
    MrrpFrame? response,
    int? attemptsMade,
  }) {
    return MrrpDeliveryState(
      deliveryId: deliveryId,
      phase: phase ?? this.phase,
      statusCode: statusCode ?? this.statusCode,
      latency: latency ?? this.latency,
      response: response ?? this.response,
      attemptsMade: attemptsMade ?? this.attemptsMade,
    );
  }
}

// ---------------------------------------------------------------------------
// Delivery tracker
// ---------------------------------------------------------------------------

/// Tracks MRRP request deliveries, emitting [DeliveryPhase] transitions.
///
/// Supports bounded automatic retry for idempotent requests. The retry
/// loop lives here (not in the dispatcher) because the dispatcher is the
/// low-level single-attempt engine and should not own retry policy.
class MrrpDeliveryTracker {
  final MrrpEngine _engine;
  int _counter = 0;
  bool _disposed = false;

  /// Stream of delivery state changes.
  ///
  /// Uses a synchronous broadcast controller so that listeners receive
  /// events inline during [_emit] — this makes phase transitions
  /// deterministic and observable without microtask flushing.
  Stream<MrrpDeliveryState> get stateChanges => _controller.stream;
  final _controller = StreamController<MrrpDeliveryState>.broadcast(sync: true);

  /// Current state of all active deliveries.
  final Map<String, MrrpDeliveryState> _deliveries = {};

  MrrpDeliveryTracker(this._engine);

  /// Get the current state of a delivery by ID.
  MrrpDeliveryState? getState(String deliveryId) => _deliveries[deliveryId];

  /// Send an MRRP request and track its delivery lifecycle.
  ///
  /// When [retryPolicy] is [MrrpRetryPolicy.idempotent], the request
  /// is automatically retried on timeout up to [MrrpRetryConfig.maxAttempts]
  /// total attempts with bounded delay between retries.
  ///
  /// Returns the terminal [MrrpDeliveryState]. Listen to [stateChanges]
  /// for intermediate phase transitions (preparing, sending, retrying).
  Future<MrrpDeliveryState> trackRequest(
    MrrpFrame request, {
    MrrpRetryPolicy retryPolicy = MrrpRetryPolicy.none,
  }) async {
    final deliveryId = 'delivery_${++_counter}'; // lint-allow: hardcoded-string
    final maxAttempts = retryPolicy == MrrpRetryPolicy.idempotent
        ? MrrpRetryConfig.maxAttempts
        : 1;

    AppLogging.mrrp(
      'MRRP_DELIVERY: $deliveryId created, '
      'service=0x${request.serviceId.toRadixString(16).padLeft(8, '0')}, '
      'action=0x${request.actionId.toRadixString(16).padLeft(4, '0')}, '
      'retry=${retryPolicy.name}, '
      'maxAttempts=$maxAttempts', // lint-allow: hardcoded-string
    );

    // Phase: preparing
    _emit(
      MrrpDeliveryState(deliveryId: deliveryId, phase: DeliveryPhase.preparing),
    );

    MrrpRequestResult? lastResult;
    var attempt = 0;

    while (attempt < maxAttempts) {
      attempt++;

      if (_disposed) {
        AppLogging.mrrp(
          'MRRP_DELIVERY: $deliveryId disposed before '
          'attempt $attempt, aborting', // lint-allow: hardcoded-string
        );
        break;
      }

      // Phase: sending (or retrying for attempt 2+)
      final phase = attempt == 1
          ? DeliveryPhase.sending
          : DeliveryPhase.retrying;
      _emit(
        MrrpDeliveryState(
          deliveryId: deliveryId,
          phase: phase,
          attemptsMade: attempt,
        ),
      );

      AppLogging.mrrp(
        'MRRP_DELIVERY: $deliveryId attempt $attempt/$maxAttempts '
        'sent', // lint-allow: hardcoded-string
      );

      // Dispatch through engine (single attempt with 15s timeout).
      lastResult = await _engine.sendRequest(request);

      if (_disposed) {
        AppLogging.mrrp(
          'MRRP_DELIVERY: $deliveryId disposed during '
          'attempt $attempt, aborting', // lint-allow: hardcoded-string
        );
        break;
      }

      // Success or definitive error — stop retrying.
      if (lastResult.status != MrrpStatusCode.timeout) {
        AppLogging.mrrp(
          'MRRP_DELIVERY: $deliveryId attempt $attempt '
          'terminal status=${lastResult.status.name}', // lint-allow: hardcoded-string
        );
        break;
      }

      AppLogging.mrrp(
        'MRRP_DELIVERY: $deliveryId attempt $attempt '
        'timed out', // lint-allow: hardcoded-string
      );

      // Timeout — retry if attempts remain.
      if (attempt < maxAttempts) {
        final delay = MrrpRetryConfig.delayForRetry(attempt);
        AppLogging.mrrp(
          'MRRP_DELIVERY: $deliveryId retry scheduled '
          'in ${delay.inSeconds}s', // lint-allow: hardcoded-string
        );
        await Future<void>.delayed(delay);
      }
    }

    // Terminal state.
    final terminalResult =
        lastResult ?? const MrrpRequestResult(status: MrrpStatusCode.timeout);
    final terminalPhase = _mapResultToPhase(terminalResult);

    AppLogging.mrrp(
      'MRRP_DELIVERY: $deliveryId terminal '
      'phase=${terminalPhase.name}, '
      'attempts=$attempt', // lint-allow: hardcoded-string
    );

    final terminalState = MrrpDeliveryState(
      deliveryId: deliveryId,
      phase: terminalPhase,
      statusCode: terminalResult.status,
      latency: terminalResult.latency,
      response: terminalResult.response,
      attemptsMade: attempt,
    );
    _emit(terminalState);

    return terminalState;
  }

  void _emit(MrrpDeliveryState state) {
    if (_disposed) return;
    _deliveries[state.deliveryId] = state;
    _controller.add(state);
  }

  DeliveryPhase _mapResultToPhase(MrrpRequestResult result) {
    if (result.isSuccess) return DeliveryPhase.delivered;
    switch (result.status) {
      case MrrpStatusCode.timeout:
        return DeliveryPhase.failed;
      case MrrpStatusCode.busy:
      case MrrpStatusCode.rateLimited:
        return DeliveryPhase.needsAttention;
      case MrrpStatusCode.notFound:
      case MrrpStatusCode.unauthorized:
      case MrrpStatusCode.invalid:
      case MrrpStatusCode.unsupported:
      case MrrpStatusCode.expired:
      case MrrpStatusCode.duplicate:
      case MrrpStatusCode.internal:
        return DeliveryPhase.failed;
      case MrrpStatusCode.ok:
        return DeliveryPhase.delivered;
    }
  }

  /// Dispose the tracker and close the stream.
  void dispose() {
    _disposed = true;
    _deliveries.clear();
    _controller.close();
  }
}
