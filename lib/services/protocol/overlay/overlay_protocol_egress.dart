// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Real-transport [OverlayLinkEgress] implementation.
///
/// Encodes an [OverlayLinkFrame] to MRRP v0.2 wire bytes and asks a
/// SIP sink (wired by the provider graph to
/// `ProtocolService.sendSipPayload`) to wrap it in a SIP `mrrpData`
/// envelope and transmit it.
///
/// The adapter never imports [ProtocolService] directly — the sink is
/// a narrow function typedef. That keeps the engine side decoupled
/// from the broader service and keeps this file unit-testable.
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import '../sip/sip_types.dart';
import 'overlay_feature_flag.dart';
import 'overlay_link_codec.dart';
import 'overlay_link_egress.dart';

/// Narrow callback abstracting `ProtocolService.sendSipPayload`.
///
/// Takes already-encoded MRRP bytes (the SIP `payload`) plus the SIP
/// `msg_type` to attribute the TX (used by the existing SIP counter).
/// Returns `true` if the payload was handed to the transport.
typedef OverlaySipSink =
    Future<bool> Function(Uint8List mrrpBytes, SipMessageType type);

/// Egress adapter that routes link frames through the real SIP sink.
class OverlayProtocolEgress implements OverlayLinkEgress {
  final OverlaySipSink _sipSink;
  final OverlayFeatureFlags Function() _flags;

  /// Construct a new adapter.
  ///
  /// [flags] is a getter so the egress can cheaply re-read the flag
  /// on each send. P2 expects the provider to supply a constant but
  /// the indirection is there so a runtime toggle in P3 does not
  /// require a new API.
  OverlayProtocolEgress({
    required OverlaySipSink sipSink,
    required OverlayFeatureFlags Function() flags,
  }) : _sipSink = sipSink,
       _flags = flags;

  @override
  Future<bool> send(OverlayLinkFrame frame, int peerNodeNum) async {
    if (!_flags().linkEnabled) {
      AppLogging.overlay(
        'egress refused: linkEnabled=false '
        'msg=${frame.msgType.name}',
      );
      return false;
    }

    final wire = OverlayLinkCodec.encode(frame);
    if (wire == null) {
      AppLogging.overlay(
        'egress refused: encode returned null msg=${frame.msgType.name}',
      );
      return false;
    }

    try {
      final ok = await _sipSink(wire, SipMessageType.mrrpData);
      if (!ok) {
        AppLogging.overlay(
          'egress dropped by SIP sink msg=${frame.msgType.name} '
          'bytes=${wire.length}',
        );
      }
      return ok;
    } catch (e) {
      AppLogging.overlay('egress sipSink threw: $e');
      return false;
    }
  }
}
