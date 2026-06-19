// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Thin inbound glue from the link layer to the resource layer.
///
/// Subscribes to [OverlayLinkEngine.events] and, on every
/// `dataDelivered` event (meaning: a LINK_DATA frame was accepted,
/// deduped, and the payload is available), attempts to decode the
/// payload as an SPP v0.2 frame. Valid frames are handed to
/// [OverlayResourceEngine.handleInbound]. Non-resource payloads and
/// malformed resource payloads are dropped silently — the link state
/// has already been mutated by the link engine, so dropping here
/// cannot poison link behavior.
///
/// Mirrors the P2 ingress pattern: no business logic, no state
/// mutation outside the engines.
library;

import 'dart:async';

import '../../../core/logging.dart';
import 'overlay_link_engine.dart';
import 'overlay_link_models.dart';
import 'overlay_resource_codec.dart';
import 'overlay_resource_engine.dart';

/// Subscribe / unsubscribe lifecycle for the inbound resource glue.
///
/// One instance per provider build. Attach + detach via `start()` /
/// `stop()` — the owning provider's `ref.onDispose` MUST call
/// `stop()` so the subscription reference is nulled.
class OverlayResourceIngressDispatcher {
  final OverlayLinkEngine _linkEngine;
  final OverlayResourceEngine _resourceEngine;

  StreamSubscription<OverlayLinkEvent>? _subscription;

  /// Number of SPP v0.2 frames decoded + dispatched.
  int handledCount = 0;

  /// Number of link data events that did not decode as valid SPP
  /// v0.2 frames (and were therefore dropped silently).
  int nonResourcePayloads = 0;

  /// Number of link data events with empty/null payload bytes.
  int emptyPayloadDrops = 0;

  OverlayResourceIngressDispatcher({
    required this._linkEngine,
    required this._resourceEngine,
  });

  /// Begin listening to `dataDelivered` events. Idempotent.
  void start() {
    if (_subscription != null) return;
    _subscription = _linkEngine.events.listen(_onLinkEvent);
    AppLogging.overlay('resource ingress started');
  }

  /// Stop listening. Nulls the subscription reference (same bug-
  /// avoidance discipline as the P1/P2 provider layer).
  Future<void> stop() async {
    final sub = _subscription;
    _subscription = null;
    if (sub != null) await sub.cancel();
    AppLogging.overlay('resource ingress stopped');
  }

  /// True if currently subscribed.
  bool get isRunning => _subscription != null;

  void _onLinkEvent(OverlayLinkEvent event) {
    if (event.kind != OverlayLinkEventKind.dataDelivered) return;
    final payload = event.payload;
    if (payload == null || payload.isEmpty) {
      emptyPayloadDrops++;
      return;
    }
    final decoded = OverlayResourceCodec.decode(payload);
    if (!decoded.isOk) {
      nonResourcePayloads++;
      return;
    }
    handledCount++;
    final record = event.record;
    // Fire-and-forget: the resource engine serialises mutations
    // internally, so two rapid deliveries queue behind each other.
    _resourceEngine.handleInbound(
      decoded.frame!,
      senderEndpointHint: record.peerPersonaHint,
      senderNodeNum: record.peerNodeNum,
      linkId: record.linkId,
    );
  }
}
