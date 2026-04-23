// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MRRP pet.v1 service handler.
///
/// Serves an opt-in, ≤8-byte public summary of the owner's Node Pet
/// (stage, branch, mood class, age, flags). The handler itself is a pure
/// responder — it takes a byte-provider callback and returns the bytes
/// on request. Owner state resolution and codec live in the feature
/// layer (`lib/features/pet/`), preserving the protocol directory's
/// no-features-imports invariant.
///
/// Wire format for get_summary (action 0x0001):
///   REQUEST payload: empty.
///   RESPONSE payload: 8 bytes matching PetPublicStateCodec v1,
///     or empty (0 B) when no pet is bound to the local node yet.
///   ERROR: UNAUTHORIZED when pet sharing is disabled.
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import 'mrrp_constants.dart';
import 'mrrp_frame.dart';
import 'mrrp_service_handler.dart';
import 'mrrp_types.dart';

/// Callback returning the encoded owner pet public-state bytes, or null
/// when no pet is bound yet. Must return a copy (callers may retain it).
typedef PetPublicBytesProvider = Uint8List? Function();

/// pet.v1 handler. See library doc comment for wire format.
class MrrpServicePet implements MrrpServiceHandler {
  final PetPublicBytesProvider _bytesProvider;

  /// Whether pet sharing is enabled. Wired from the feature-flag +
  /// (future) privacy toggle via the provider layer. Default false so
  /// the handler is safe to register even when the feature is off.
  bool isPetSharingEnabled = false;

  MrrpServicePet({required PetPublicBytesProvider bytesProvider})
    : _bytesProvider = bytesProvider;

  @override
  int get serviceId => MrrpServiceId.petV1;

  @override
  Set<int> get supportedActions => const {PetAction.getSummary};

  @override
  Future<MrrpFrame> handleRequest(MrrpFrame request, int senderNodeId) async {
    if (!isPetSharingEnabled) {
      AppLogging.mrrp(
        'MRRP_SERVICE: pet.v1 request rejected — '
        'pet sharing disabled', // lint-allow: hardcoded-string
      );
      return _buildError(request, MrrpStatusCode.unauthorized);
    }
    switch (request.actionId) {
      case PetAction.getSummary:
        return _handleGetSummary(request);
      default:
        return _buildError(request, MrrpStatusCode.unsupported);
    }
  }

  MrrpFrame _handleGetSummary(MrrpFrame request) {
    final bytes = _bytesProvider();
    final payload = bytes ?? Uint8List(0);
    AppLogging.mrrp(
      'MRRP_SERVICE: pet.v1 get_summary '
      '-> ${payload.length}B response', // lint-allow: hardcoded-string
    );
    return _buildResponse(request, payload);
  }

  MrrpFrame _buildResponse(MrrpFrame request, Uint8List payload) {
    return MrrpFrame(
      versionMajor: MrrpConstants.mrrpVersionMajor,
      versionMinor: MrrpConstants.mrrpVersionMinor,
      msgType: MrrpMessageType.response,
      flags: MrrpFlags.isResponse,
      headerLen: MrrpConstants.mrrpHeaderMin,
      requestId: request.requestId,
      serviceId: serviceId,
      actionId: request.actionId,
      payloadLen: payload.length,
      payload: payload,
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
