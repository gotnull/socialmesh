// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Simulated MRRP peer model for harness testing.
///
/// Simulated peers are local-only constructs that inject responses
/// directly into the MRRP dispatcher path without involving the radio.
/// They appear in the peer inspector with a "[SIM]" badge.
library;

import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../../../core/logging.dart';
import 'mrrp_constants.dart';
import 'mrrp_frame.dart';
import 'mrrp_types.dart';

/// Response modes for a simulated peer.
enum SimResponseMode {
  /// Immediate OK with echo payload.
  normal,

  /// Delayed response (configurable seconds).
  delayed,

  /// Error response with configurable status code.
  error,

  /// No response (request times out).
  timeout,

  /// Response sent twice (duplicate).
  duplicate,

  /// Return malformed payload.
  malformed,
}

/// Configuration for a simulated MRRP peer.
class MrrpSimulatedPeer {
  /// Auto-generated ID (SIM-1, SIM-2, ...).
  final String simId;

  /// Fake node ID for this simulated peer.
  final int nodeId;

  /// Which services this peer advertises.
  final List<int> serviceIds;

  /// Current response mode.
  SimResponseMode mode;

  /// Delay in seconds (for [SimResponseMode.delayed]).
  int delaySeconds;

  /// Error status code (for [SimResponseMode.error]).
  MrrpStatusCode errorStatus;

  /// When this peer was created.
  final DateTime createdAt;

  MrrpSimulatedPeer({
    required this.simId,
    required this.nodeId,
    required this.serviceIds,
    this.mode = SimResponseMode.normal,
    this.delaySeconds = 3,
    this.errorStatus = MrrpStatusCode.busy,
  }) : createdAt = DateTime.now();

  /// Handle an inbound REQUEST by applying the configured response mode.
  ///
  /// Returns a list of response frames to inject (may be 0, 1, or 2).
  Future<List<MrrpFrame>> handleRequest(MrrpFrame request) async {
    AppLogging.mrrpHarness(
      'MRRP_SIM: $simId received REQUEST '
      'req_id=0x${request.requestId.toRadixString(16)} '
      '-> responding with mode=${mode.name}', // lint-allow: hardcoded-string
    );

    switch (mode) {
      case SimResponseMode.normal:
        return [_buildOkResponse(request)];

      case SimResponseMode.delayed:
        await Future<void>.delayed(Duration(seconds: delaySeconds));
        return [_buildOkResponse(request)];

      case SimResponseMode.error:
        return [_buildErrorResponse(request, errorStatus)];

      case SimResponseMode.timeout:
        // No response — let the request time out.
        return [];

      case SimResponseMode.duplicate:
        final resp = _buildOkResponse(request);
        return [resp, resp];

      case SimResponseMode.malformed:
        return [_buildMalformedResponse(request)];
    }
  }

  MrrpFrame _buildOkResponse(MrrpFrame request) {
    return MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.response,
      flags: MrrpFlags.isResponse,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: request.requestId,
      serviceId: request.serviceId,
      actionId: request.actionId,
      payloadLen: request.payload.length,
      payload: request.payload, // echo back
    );
  }

  MrrpFrame _buildErrorResponse(MrrpFrame request, MrrpStatusCode status) {
    return MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.error,
      flags: MrrpFlags.isResponse | MrrpFlags.isError,
      headerLen: MrrpConstants.mrrpHeaderMin + 3, // TLV: status_code(1+1+1)
      requestId: request.requestId,
      serviceId: request.serviceId,
      actionId: request.actionId,
      payloadLen: 0,
      headerExtensions: [
        MrrpTlvEntry(
          type: MrrpTlvType.statusCode.code,
          value: Uint8List.fromList([status.code]),
        ),
      ],
      payload: Uint8List(0),
    );
  }

  MrrpFrame _buildMalformedResponse(MrrpFrame request) {
    // Random garbage payload.
    final rng = Random();
    final garbage = Uint8List(8);
    for (var i = 0; i < garbage.length; i++) {
      garbage[i] = rng.nextInt(256);
    }
    return MrrpFrame(
      versionMajor: 0xFF, // invalid version
      versionMinor: 0xFF,
      msgType: MrrpMessageType.response,
      flags: MrrpFlags.isResponse,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: request.requestId,
      serviceId: request.serviceId,
      actionId: request.actionId,
      payloadLen: garbage.length,
      payload: garbage,
    );
  }

  /// Generate a fake node ID for simulated peers.
  static int generateNodeId(int simIndex) {
    // Use 0xSIM0xxxx range to distinguish from real nodes.
    return 0x51400000 | (simIndex & 0xFFFF);
  }
}
