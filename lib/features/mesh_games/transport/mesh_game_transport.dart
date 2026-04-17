// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Outbound mesh-game transport.
///
/// Wraps [MrrpDeliveryTracker] with mesh-game semantics: encodes
/// frames via [MeshGameCodec], prepends the 16-byte instance-ID
/// prefix expected by [MeshServicesHandler], and surfaces a typed
/// result per the spec § 6.2.
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import '../../../services/protocol/sip/mrrp_frame.dart';
import '../../../services/protocol/sip/mrrp_types.dart';
import '../../mesh_services/services/mesh_service_engine.dart'
    show
        MeshServicesAction,
        MeshServicesHandler,
        kMeshServicesInstanceServiceId;
import '../../mesh_services/services/mrrp_delivery_tracker.dart';
import '../models/mesh_game_session.dart';
import '../models/mesh_game_status.dart';
import 'mesh_game_codec.dart';

/// Result of a mesh-game send attempt.
class MeshGameSendResult {
  final MrrpDeliveryState delivery;

  /// Convenience — whether the send is considered successful.
  bool get ok => delivery.statusCode == MrrpStatusCode.ok;

  const MeshGameSendResult(this.delivery);
}

/// Outbound mesh-game transport. Requires a [MrrpDeliveryTracker]
/// which in turn requires a live [MrrpEngine]; both are injected by
/// the provider layer.
class MeshGameTransport {
  final MrrpDeliveryTracker _tracker;

  const MeshGameTransport({required MrrpDeliveryTracker tracker})
    : _tracker = tracker;

  Future<MeshGameSendResult> sendMove({
    required MeshGameSession session,
    required int revision,
    required Uint8List moveData,
  }) {
    final body = MeshGameCodec.encodeMove(
      revision: revision,
      moveData: moveData,
    );
    return _send(
      session: session,
      frameBytes: body,
      retryPolicy: MrrpRetryPolicy.none,
      opcodeName: 'MOVE',
    );
  }

  Future<MeshGameSendResult> sendJoin({
    required MeshGameSession session,
    required int revision,
  }) {
    final body = MeshGameCodec.encodeJoin(
      revision: revision,
      status: MeshGameStatus.active.code,
    );
    return _send(
      session: session,
      frameBytes: body,
      retryPolicy: MrrpRetryPolicy.none,
      opcodeName: 'JOIN',
    );
  }

  Future<MeshGameSendResult> requestStatus({required MeshGameSession session}) {
    final body = MeshGameCodec.encodeStateReq();
    return _send(
      session: session,
      frameBytes: body,
      retryPolicy: MrrpRetryPolicy.idempotent,
      opcodeName: 'STATE_REQ',
    );
  }

  Future<MeshGameSendResult> sendQuit({
    required MeshGameSession session,
    required int revision,
    required int reason,
  }) {
    final body = MeshGameCodec.encodeQuit(revision: revision, reason: reason);
    return _send(
      session: session,
      frameBytes: body,
      retryPolicy: MrrpRetryPolicy.none,
      opcodeName: 'QUIT',
    );
  }

  Future<MeshGameSendResult> _send({
    required MeshGameSession session,
    required Uint8List frameBytes,
    required MrrpRetryPolicy retryPolicy,
    required String opcodeName,
  }) async {
    final payload = _withInstancePrefix(session.instanceId, frameBytes);
    final request = MrrpFrame(
      versionMajor: 0,
      versionMinor: 1,
      msgType: MrrpMessageType.request,
      flags: MrrpFlags.ackRequired,
      headerLen: 20,
      requestId: 0,
      serviceId: kMeshServicesInstanceServiceId,
      actionId: MeshServicesAction.interact,
      payloadLen: payload.length,
      payload: payload,
    );
    AppLogging.meshGameTransport(
      'send op=$opcodeName instance=${session.instanceId} '
      'rev=${session.revision} bytes=${payload.length}',
    );
    final delivery = await _tracker.trackRequest(
      request,
      retryPolicy: retryPolicy,
    );
    AppLogging.meshGameTransport(
      'send terminal instance=${session.instanceId} '
      'phase=${delivery.phase.name} status=${delivery.statusCode?.name}',
    );
    return MeshGameSendResult(delivery);
  }

  static Uint8List _withInstancePrefix(String instanceId, Uint8List body) {
    final prefix = MeshServicesHandler.encodeInstanceId(instanceId);
    final out = Uint8List(prefix.length + body.length);
    out.setRange(0, prefix.length, prefix);
    out.setRange(prefix.length, out.length, body);
    return out;
  }
}
