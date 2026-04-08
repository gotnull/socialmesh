// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Maps MRRP engine request/response lifecycle to [DeliveryPhase]
/// for the UI layer.
///
/// Wraps [MrrpEngine.sendRequest] and emits phase transitions that
/// [DeliveryProgressCard] can display. The engine itself is a simple
/// request/response model; this tracker synthesizes intermediate
/// phases (preparing → sending → sentToMesh → delivered/failed) for
/// user-friendly progress feedback.
library;

import 'dart:async';

import '../../../core/widgets/delivery_progress_card.dart';
import '../../../services/protocol/sip/mrrp_dispatcher.dart';
import '../../../services/protocol/sip/mrrp_engine.dart';
import '../../../services/protocol/sip/mrrp_frame.dart';
import '../../../services/protocol/sip/mrrp_types.dart';

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

  const MrrpDeliveryState({
    required this.deliveryId,
    required this.phase,
    this.statusCode,
    this.latency,
    this.response,
  });

  MrrpDeliveryState copyWith({
    DeliveryPhase? phase,
    MrrpStatusCode? statusCode,
    Duration? latency,
    MrrpFrame? response,
  }) {
    return MrrpDeliveryState(
      deliveryId: deliveryId,
      phase: phase ?? this.phase,
      statusCode: statusCode ?? this.statusCode,
      latency: latency ?? this.latency,
      response: response ?? this.response,
    );
  }
}

/// Tracks MRRP request deliveries, emitting [DeliveryPhase] transitions.
class MrrpDeliveryTracker {
  final MrrpEngine _engine;
  int _counter = 0;

  /// Stream of delivery state changes.
  Stream<MrrpDeliveryState> get stateChanges => _controller.stream;
  final _controller = StreamController<MrrpDeliveryState>.broadcast();

  /// Current state of all active deliveries.
  final Map<String, MrrpDeliveryState> _deliveries = {};

  MrrpDeliveryTracker(this._engine);

  /// Get the current state of a delivery by ID.
  MrrpDeliveryState? getState(String deliveryId) => _deliveries[deliveryId];

  /// Send an MRRP request and track its delivery lifecycle.
  ///
  /// Returns the delivery ID immediately. Listen to [stateChanges]
  /// for phase transitions. The returned future completes when delivery
  /// reaches a terminal state.
  Future<MrrpDeliveryState> trackRequest(MrrpFrame request) async {
    final deliveryId = 'delivery_${++_counter}'; // lint-allow: hardcoded-string

    // Phase: preparing
    _emit(
      MrrpDeliveryState(deliveryId: deliveryId, phase: DeliveryPhase.preparing),
    );

    // Phase: sending
    _emit(
      MrrpDeliveryState(deliveryId: deliveryId, phase: DeliveryPhase.sending),
    );

    // Dispatch through engine
    final result = await _engine.sendRequest(request);

    // Phase: terminal (delivered, failed, or needsAttention)
    final terminalPhase = _mapResultToPhase(result);
    final terminalState = MrrpDeliveryState(
      deliveryId: deliveryId,
      phase: terminalPhase,
      statusCode: result.status,
      latency: result.latency,
      response: result.response,
    );
    _emit(terminalState);

    return terminalState;
  }

  void _emit(MrrpDeliveryState state) {
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
    _deliveries.clear();
    _controller.close();
  }
}
