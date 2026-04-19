// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MRRP echo.test service handler.
///
/// Harness-only service for testing MRRP end-to-end. Only registered when
/// `MRRP_HARNESS_ENABLED=true`. Supports three actions:
///
/// - **echo** (0x0001): Returns the request payload unchanged.
/// - **echo_error** (0x0002): Returns an ERROR frame with the status code
///   extracted from the first byte of the request payload.
/// - **echo_delay** (0x0003): Returns the request payload after a delay
///   read from the first two bytes (uint16 LE, capped at 10 000 ms).
library;

import 'dart:math';
import 'dart:typed_data';

import '../../../core/logging.dart';
import 'mrrp_constants.dart';
import 'mrrp_frame.dart';
import 'mrrp_service_handler.dart';
import 'mrrp_types.dart';

/// echo.test handler — only for MRRP harness testing.
class MrrpServiceEcho implements MrrpServiceHandler {
  @override
  int get serviceId => MrrpServiceId.echoTest;

  @override
  Set<int> get supportedActions => const {
    EchoAction.echo,
    EchoAction.echoError,
    EchoAction.echoDelay,
  };

  /// Maximum echo delay in milliseconds.
  static const int _maxDelayMs = 10000;

  @override
  Future<MrrpFrame> handleRequest(MrrpFrame request, int senderNodeId) async {
    switch (request.actionId) {
      case EchoAction.echo:
        return _handleEcho(request);
      case EchoAction.echoError:
        return _handleEchoError(request);
      case EchoAction.echoDelay:
        return _handleEchoDelay(request);
      default:
        return _buildError(request, MrrpStatusCode.unsupported);
    }
  }

  MrrpFrame _handleEcho(MrrpFrame request) {
    AppLogging.mrrp(
      'MRRP_SERVICE: echo.test echo ${request.payloadLen}B '
      '-> ${request.payloadLen}B', // lint-allow: hardcoded-string
    );
    return MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.response,
      flags: MrrpFlags.isResponse,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: request.requestId,
      serviceId: serviceId,
      actionId: request.actionId,
      payloadLen: request.payloadLen,
      payload: request.payload,
    );
  }

  MrrpFrame _handleEchoError(MrrpFrame request) {
    final statusCode = request.payload.isNotEmpty
        ? request.payload[0]
        : MrrpStatusCode.internal.code;
    AppLogging.mrrp(
      'MRRP_SERVICE: echo.test echo_error '
      'status=$statusCode', // lint-allow: hardcoded-string
    );
    return _buildError(
      request,
      MrrpStatusCode.fromCode(statusCode) ?? MrrpStatusCode.internal,
    );
  }

  Future<MrrpFrame> _handleEchoDelay(MrrpFrame request) async {
    int delayMs = 0;
    if (request.payload.length >= 2) {
      delayMs = ByteData.sublistView(
        request.payload,
      ).getUint16(0, Endian.little);
    }
    delayMs = min(delayMs, _maxDelayMs);

    AppLogging.mrrp(
      'MRRP_SERVICE: echo.test echo_delay '
      '${delayMs}ms', // lint-allow: hardcoded-string
    );

    await Future<void>.delayed(Duration(milliseconds: delayMs));

    return MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.response,
      flags: MrrpFlags.isResponse,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: request.requestId,
      serviceId: serviceId,
      actionId: request.actionId,
      payloadLen: request.payloadLen,
      payload: request.payload,
    );
  }

  MrrpFrame _buildError(MrrpFrame request, MrrpStatusCode status) {
    final payload = Uint8List(1)..[0] = status.code;
    return MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.error,
      flags: MrrpFlags.isResponse | MrrpFlags.isError,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: request.requestId,
      serviceId: serviceId,
      actionId: request.actionId,
      payloadLen: 1,
      payload: payload,
      headerExtensions: [
        MrrpTlvEntry(
          type: MrrpTlvType.statusCode.code,
          value: Uint8List.fromList([status.code]),
        ),
      ],
    );
  }
}
