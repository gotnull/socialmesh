// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Thin inbound dispatcher that glues
/// `ProtocolService.attachOverlayInbound` callbacks to
/// [OverlayLinkEngine].
///
/// This is the entire "ingress integration" layer per P2. Its
/// responsibilities are intentionally narrow:
///
/// 1. Accept raw MRRP v0.2 wire bytes handed over by
///    [ProtocolService] after the overlay sniffer claims the frame.
/// 2. Decode. If the decode fails, log and drop — no contamination of
///    the legacy MRRP path.
/// 3. Record a capability observation (the peer just sent a well-
///    formed v0.2 frame, which is proof of link support).
/// 4. Hand the decoded frame to [OverlayLinkEngine.handleInbound].
///
/// No state mutation lives here. No policy decisions. No retries. Any
/// business logic belongs in [OverlayLinkEngine] or
/// [OverlayCapabilityCoordinator].
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import 'overlay_capability_coordinator.dart';
import 'overlay_link_codec.dart';
import 'overlay_link_engine.dart';
import 'overlay_link_models.dart';

/// Inbound dispatcher. One instance per engine.
class OverlayIngressDispatcher {
  final OverlayLinkEngine _engine;
  final OverlayCapabilityCoordinator _coordinator;
  bool _disposed = false;

  /// Number of frames handled since construction (for observability /
  /// test assertions).
  int get handledCount => _handledCount;
  int _handledCount = 0;

  /// Number of frames dropped because decode failed.
  int get decodeFailures => _decodeFailures;
  int _decodeFailures = 0;

  /// Construct a dispatcher bound to [_engine] and [_coordinator].
  OverlayIngressDispatcher({required this._engine, required this._coordinator});

  /// Entry point invoked by [ProtocolService] once it has sniffed a
  /// v0.2 link frame.
  ///
  /// [senderNodeNum] is the Meshtastic node num of the peer.
  /// [mrrpPayload] is the raw MRRP v0.2 wire bytes (the SIP frame's
  /// payload field for `mrrpData`).
  Future<void> handleInboundMrrpBytes(
    int senderNodeNum,
    Uint8List mrrpPayload,
  ) async {
    if (_disposed) return;

    final result = OverlayLinkCodec.decode(mrrpPayload);
    if (!result.isOk) {
      _decodeFailures++;
      AppLogging.overlay(
        'ingress decode failed sender=$senderNodeNum '
        'error=${result.error?.name} ${result.message}',
      );
      return;
    }
    final frame = result.frame!;

    // The mere arrival of a well-formed v0.2 frame proves the peer
    // supports the link layer. Record before handing to the engine
    // so that, by the time the engine's events fire, any
    // openLocal-gating callers can consult the coordinator.
    _coordinator.record(
      senderNodeNum,
      const OverlayLinkCapabilities(
        supportedFeatures: 0x01, // OverlayCapabilityFeature.linkV02
      ),
      OverlayCapabilityObservationSource.linkFrame,
    );

    _handledCount++;
    AppLogging.overlay(
      'ingress sender=$senderNodeNum msg=${frame.msgType.name} '
      'linkId=0x${frame.linkId.toRadixString(16).padLeft(8, "0")} '
      'seq=${frame.seq}',
    );
    await _engine.handleInbound(frame, senderNodeNum);
  }

  /// Mark disposed so further callbacks are ignored. The coordinator
  /// and engine remain owned by the provider layer and are closed by
  /// their own `ref.onDispose` hooks.
  void dispose() {
    _disposed = true;
  }

  /// True if [dispose] has been called.
  bool get isDisposed => _disposed;
}
