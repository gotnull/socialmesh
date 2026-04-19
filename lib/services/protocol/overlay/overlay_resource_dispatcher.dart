// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Capability-gated entry point for overlay resource sends (P5).
///
/// This is the "fallback bridge". Callers submit an intent to send a
/// resource to a specific peer; the dispatcher evaluates:
///
///   1. Is `OVERLAY_LINK_ENABLED` on?
///   2. Is `OVERLAY_RESOURCE_ENABLED` on?
///   3. Is the peer known to support overlay links (via
///      [OverlayCapabilityCoordinator])?
///
/// And returns a typed [OverlayResourceDispatchResult] telling the
/// caller one of three things:
///
///   - `overlayAccepted`: the dispatcher has created a resource record
///     via [OverlayResourceEngine.offerLocal]; the caller should do
///     nothing further.
///   - `fallbackRequired`: the overlay path declined (flag off, peer
///     not capable, or capability unknown); the caller SHOULD route
///     via the legacy `SM_FILE_TRANSFER` v1 system if the product
///     flow expects a file send. The dispatcher itself never calls
///     into v1 — decoupling is deliberate.
///   - `rejected`: the dispatcher declined and no fallback is
///     meaningful (e.g., a hard policy or payload validation failure).
///
/// Locked P5 rule: unknown peer capability → `fallbackRequired` (no
/// optimistic overlay attempts, no mesh chatter).
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import 'overlay_capability_coordinator.dart';
import 'overlay_feature_flag.dart';
import 'overlay_resource_engine.dart';
import 'overlay_resource_models.dart';

/// Typed dispatch result.
enum OverlayResourceDispatchOutcome {
  /// Resource record created; overlay path engaged.
  overlayAccepted,

  /// Overlay declined for a reason the caller should handle via
  /// legacy transport if available.
  fallbackRequired,

  /// Overlay declined and legacy fallback is not meaningful.
  rejected,
}

/// Reason code carried alongside the outcome for diagnostics and
/// test assertions.
enum OverlayResourceDispatchReason {
  /// Overlay accepted the send.
  ok,

  /// `OVERLAY_LINK_ENABLED` is off.
  linkDisabled,

  /// `OVERLAY_RESOURCE_ENABLED` is off.
  resourceDisabled,

  /// Peer has no capability record — explicitly not a "try and see".
  peerCapabilityUnknown,

  /// Peer's capability record says overlay link is not supported.
  peerNotOverlayCapable,

  /// Payload is empty or exceeds the resource cap.
  badPayload,

  /// Underlying engine rejected the offer (rare — covers engine
  /// invariant violations such as duplicate openings).
  engineRejected,
}

/// Dispatch result carrying the outcome + reason + optional record.
class OverlayResourceDispatchResult {
  final OverlayResourceDispatchOutcome outcome;
  final OverlayResourceDispatchReason reason;

  /// Set only when [outcome] is [OverlayResourceDispatchOutcome.overlayAccepted].
  final OverlayResourceRecord? record;

  /// Diagnostic detail.
  final String? detail;

  const OverlayResourceDispatchResult({
    required this.outcome,
    required this.reason,
    this.record,
    this.detail,
  });

  bool get isOverlayAccepted =>
      outcome == OverlayResourceDispatchOutcome.overlayAccepted;

  bool get needsLegacyFallback =>
      outcome == OverlayResourceDispatchOutcome.fallbackRequired;

  @override
  String toString() =>
      'OverlayResourceDispatchResult(${outcome.name}, '
      'reason=${reason.name}, detail=$detail)';
}

/// Capability-gated resource dispatcher.
class OverlayResourceDispatcher {
  final OverlayResourceEngine _engine;
  final OverlayCapabilityCoordinator _capability;
  final OverlayFeatureFlags Function() _flags;

  OverlayResourceDispatcher({
    required OverlayResourceEngine engine,
    required OverlayCapabilityCoordinator capability,
    required OverlayFeatureFlags Function() flags,
  }) : _engine = engine,
       _capability = capability,
       _flags = flags;

  /// Submit a resource send intent. The dispatcher decides the
  /// routing (overlay, fallback, reject) and returns a typed result
  /// without ever invoking the legacy system itself.
  Future<OverlayResourceDispatchResult> submit({
    required Uint8List peerEndpointHint,
    required int peerNodeNum,
    required Uint8List payload,
    int? linkId,
    int chunkSize = 128,
    String? mimeType,
    String? filename,
  }) async {
    final flags = _flags();
    if (!flags.linkEnabled) {
      return _fallback(
        OverlayResourceDispatchReason.linkDisabled,
        'link flag off',
      );
    }
    if (!flags.resourceEnabled) {
      return _fallback(
        OverlayResourceDispatchReason.resourceDisabled,
        'resource flag off',
      );
    }
    if (payload.isEmpty) {
      return const OverlayResourceDispatchResult(
        outcome: OverlayResourceDispatchOutcome.rejected,
        reason: OverlayResourceDispatchReason.badPayload,
        detail: 'payload empty',
      );
    }
    final snapshot = _capability.forPeer(peerNodeNum);
    if (snapshot == null) {
      return _fallback(
        OverlayResourceDispatchReason.peerCapabilityUnknown,
        'peer capability unknown',
      );
    }
    if (!snapshot.supportsLink) {
      return _fallback(
        OverlayResourceDispatchReason.peerNotOverlayCapable,
        'peer does not advertise linkV02',
      );
    }
    try {
      final record = await _engine.offerLocal(
        peerEndpointHint: peerEndpointHint,
        peerNodeNum: peerNodeNum,
        payload: payload,
        chunkSize: chunkSize,
        linkId: linkId,
        mimeType: mimeType,
        filename: filename,
      );
      AppLogging.overlay(
        'resource dispatch overlayAccepted id=0x'
        '${record.resourceId.toRadixString(16)}',
      );
      return OverlayResourceDispatchResult(
        outcome: OverlayResourceDispatchOutcome.overlayAccepted,
        reason: OverlayResourceDispatchReason.ok,
        record: record,
      );
    } catch (e) {
      AppLogging.overlay('resource dispatch engine rejected: $e');
      return OverlayResourceDispatchResult(
        outcome: OverlayResourceDispatchOutcome.rejected,
        reason: OverlayResourceDispatchReason.engineRejected,
        detail: e.toString(),
      );
    }
  }

  OverlayResourceDispatchResult _fallback(
    OverlayResourceDispatchReason reason,
    String detail,
  ) {
    AppLogging.overlay(
      'resource dispatch fallbackRequired reason=${reason.name} '
      'detail=$detail',
    );
    return OverlayResourceDispatchResult(
      outcome: OverlayResourceDispatchOutcome.fallbackRequired,
      reason: reason,
      detail: detail,
    );
  }
}
