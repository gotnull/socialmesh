// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Production-path [OverlayResourceEgress] that routes resource frames
/// through the live overlay link layer.
///
/// Encodes the SPP v0.2 frame to wire bytes and hands them to
/// [OverlayLinkEngine.sendData], which wraps them in a LINK_DATA frame
/// and transmits through the existing SIP → MRRP → Meshtastic pipeline.
/// The adapter never imports [ProtocolService] — the layering rule
/// from P4 is preserved: resources ride exclusively inside LINK_DATA.
///
/// Failure semantics:
///   - Flag off → returns `false`, no link traffic.
///   - `linkId == null` → returns `false`; the caller's record will
///     refresh its linkId on the next inbound frame from the peer,
///     at which point a retry can succeed.
///   - `linkEngine.sendData` returns null (link not active, encode
///     failed, egress refused) → returns `false`. The resource engine
///     already treats false as "deferred send".
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import 'overlay_feature_flag.dart';
import 'overlay_link_engine.dart';
import 'overlay_resource_codec.dart';
import 'overlay_resource_egress.dart';

/// Production adapter wrapping resource frames in LINK_DATA.
class OverlayResourceProtocolEgress implements OverlayResourceEgress {
  final OverlayLinkEngine _linkEngine;
  final OverlayFeatureFlags Function() _flags;

  /// Construct the adapter. [flags] is a getter so the adapter re-
  /// reads the flag on each send — a runtime toggle (future phase)
  /// takes effect immediately without rebuilding the engine.
  OverlayResourceProtocolEgress({
    required OverlayLinkEngine linkEngine,
    required OverlayFeatureFlags Function() flags,
  }) : _linkEngine = linkEngine,
       _flags = flags;

  @override
  Future<bool> sendFrame({
    required OverlayResourceFrame frame,
    required Uint8List peerEndpointHint,
    required int peerNodeNum,
    int? linkId,
  }) async {
    final flags = _flags();
    if (!flags.resourceActive) {
      AppLogging.overlay(
        'resource egress refused: resourceActive=false '
        '(link=${flags.linkEnabled} resource=${flags.resourceEnabled})',
      );
      return false;
    }
    if (linkId == null) {
      AppLogging.overlay('resource egress refused: no active linkId for peer');
      return false;
    }
    final wire = OverlayResourceCodec.encode(frame);
    if (wire == null) {
      AppLogging.overlay(
        'resource egress refused: encode returned null for '
        'type=${frame.type.name}',
      );
      return false;
    }
    try {
      final result = await _linkEngine.sendData(linkId, wire);
      if (result == null) {
        AppLogging.overlay(
          'resource egress deferred: link sendData returned null '
          'linkId=0x${linkId.toRadixString(16)} type=${frame.type.name}',
        );
        return false;
      }
      return true;
    } catch (e) {
      AppLogging.overlay('resource egress link error: $e');
      return false;
    }
  }
}
