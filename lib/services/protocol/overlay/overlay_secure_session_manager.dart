// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Per-link table of [OverlaySecureSession] instances plus the glue
/// that drives them against the overlay link layer.
///
/// The manager is an optional collaborator of [OverlayLinkEngine].
/// When attached (via the engine's `secureSessionManager` argument),
/// the engine forwards three lifecycle hooks:
///
/// - [onLinkActivated] — fired after `LINK_OPEN_OK` installs an
///   active link. On the initiator side, if policy + capability
///   permit, the manager emits a `LINK_SECURE_INIT` and starts
///   awaiting the peer's `LINK_SECURE_ACK`.
/// - [onSecureInbound] — the engine forwards every
///   `linkSecureInit / linkSecureAck / linkSecureData` frame here.
///   Fail-closed: failures do not propagate to the link state.
/// - [onLinkTerminated] — called on any terminal transition
///   (`failed`/`closed`). The manager discards the session and its
///   in-memory key material.
///
/// Sessions are stored in-memory only, keyed by canonical `linkId`.
/// See `docs/sip/OVERLAY_V0_2.md §25.8` for lifetime invariants.
library;

import 'dart:async';
import 'dart:typed_data';

import '../../../core/logging.dart';
import 'overlay_endpoint_manager.dart';
import 'overlay_link_egress.dart';
import 'overlay_link_codec.dart';
import 'overlay_link_models.dart';
import 'overlay_link_store.dart';
import 'overlay_secure_session.dart';
import 'overlay_types.dart';

/// Event emitted by the manager when a secure DATA frame successfully
/// decrypts. Phase 2 consumers (encrypted DM text, reactions, RPC)
/// listen here.
class OverlaySecureInboundPayload {
  final int linkId;
  final OverlaySecureDataSubtype subtype;
  final int seq;
  final Uint8List cleartext;

  const OverlaySecureInboundPayload({
    required this.linkId,
    required this.subtype,
    required this.seq,
    required this.cleartext,
  });
}

class OverlaySecureSessionManager {
  final OverlayLinkStore _store;
  final OverlayLinkEgress _egress;
  final OverlayEndpointManager _endpointManager;
  final bool Function() _enabledFlag;

  final Map<int, OverlaySecureSession> _sessions = {};
  final StreamController<OverlaySecureInboundPayload> _inbound =
      StreamController<OverlaySecureInboundPayload>.broadcast();

  OverlaySecureSessionManager({
    required OverlayLinkStore store,
    required OverlayLinkEgress egress,
    required OverlayEndpointManager endpointManager,
    required bool Function() enabledFlag,
  }) : _store = store,
       _egress = egress,
       _endpointManager = endpointManager,
       _enabledFlag = enabledFlag;

  /// Broadcast stream of successfully decrypted secure DATA payloads.
  /// Phase 2 subscribers plug their handlers here.
  Stream<OverlaySecureInboundPayload> get inbound => _inbound.stream;

  /// Whether a secure session for [linkId] is in a key-installed
  /// state (either initiator-active or responder-established).
  bool isEstablished(int linkId) {
    return _sessions[linkId]?.isEstablished ?? false;
  }

  /// Count of live sessions (diagnostics / tests).
  int get sessionCount => _sessions.length;

  // -----------------------------------------------------------------
  // Hooks driven by [OverlayLinkEngine]
  // -----------------------------------------------------------------

  /// Called after a link becomes `active`. Initiator side attempts to
  /// start a secure session if policy permits; responder side is a
  /// no-op (it awaits the inbound `LINK_SECURE_INIT`).
  Future<void> onLinkActivated(OverlayLinkRecord record) async {
    if (!_enabledFlag()) return;
    if (!record.isInitiator) return;
    if (_sessions.containsKey(record.linkId)) return;
    if (!_peerSupportsSecure(record)) {
      AppLogging.overlay(
        'SECURE skip: peer=${record.peerNodeNum} on linkId=0x'
        '${record.linkId.toRadixString(16)} did not advertise secureV03',
      );
      return;
    }
    final session = await _buildSessionFor(record, initiator: true);
    if (session == null) return;
    try {
      final initPayload = await session.start();
      _sessions[record.linkId] = session;
      await _sendFrame(record, OverlayLinkMsgType.linkSecureInit, initPayload);
    } catch (e, st) {
      AppLogging.overlay(
        'SECURE_INIT start failed linkId=0x'
        '${record.linkId.toRadixString(16)}: $e\n$st',
      );
      _sessions.remove(record.linkId);
    }
  }

  /// Engine forwards every secure-family inbound frame here. Routes to
  /// the matching session handler. All failures are swallowed and
  /// logged; the link is never torn down by secure-layer errors.
  Future<void> onSecureInbound(
    OverlayLinkFrame frame,
    int senderNodeNum,
  ) async {
    if (!_enabledFlag()) return;
    final record = await _store.getByLinkId(frame.linkId);
    // Accept secure traffic on any non-terminal link. A `stale`
    // canonical record (restored from a prior run, §21.1) is still a
    // valid identity anchor — the arrival of an inbound secure frame
    // is fresh proof of peer reachability, which is semantically the
    // same signal the link layer uses to un-stale records. Rejecting
    // stale here would break the reuse path where both sides restore
    // an old canonical and one initiates SECURE_INIT on it.
    if (record == null ||
        record.state == OverlayLinkState.failed ||
        record.state == OverlayLinkState.closed) {
      AppLogging.overlay(
        'SECURE drop: ${frame.msgType.name} on terminal '
        'linkId=0x${frame.linkId.toRadixString(16)}',
      );
      return;
    }

    switch (frame.msgType) {
      case OverlayLinkMsgType.linkSecureInit:
        await _handleInboundInit(record, frame);
      case OverlayLinkMsgType.linkSecureAck:
        await _handleInboundAck(record, frame);
      case OverlayLinkMsgType.linkSecureData:
        await _handleInboundData(record, frame);
      default:
        break;
    }
  }

  /// Called when a link transitions to any terminal state. Drops the
  /// associated session plus all key material.
  void onLinkTerminated(int linkId) {
    final removed = _sessions.remove(linkId) != null;
    if (removed) {
      AppLogging.overlay(
        'SECURE session dropped on link terminate linkId=0x'
        '${linkId.toRadixString(16)}',
      );
    }
  }

  // -----------------------------------------------------------------
  // Inbound handlers
  // -----------------------------------------------------------------

  Future<void> _handleInboundInit(
    OverlayLinkRecord record,
    OverlayLinkFrame frame,
  ) async {
    if (_sessions.containsKey(record.linkId)) {
      AppLogging.overlay(
        'SECURE_INIT ignored: session already present for linkId=0x'
        '${record.linkId.toRadixString(16)}',
      );
      return;
    }
    final session = await _buildSessionFor(record, initiator: false);
    if (session == null) return;
    try {
      final ackPayload = await session.handleInit(frame.payload);
      if (ackPayload == null) {
        AppLogging.overlay(
          'SECURE_INIT verify failed for linkId=0x'
          '${record.linkId.toRadixString(16)}',
        );
        return;
      }
      _sessions[record.linkId] = session;
      await _sendFrame(record, OverlayLinkMsgType.linkSecureAck, ackPayload);
      AppLogging.overlay(
        'SECURE established (responder) linkId=0x'
        '${record.linkId.toRadixString(16)}',
      );
    } catch (e) {
      AppLogging.overlay(
        'SECURE_INIT handler threw linkId=0x'
        '${record.linkId.toRadixString(16)}: $e',
      );
    }
  }

  Future<void> _handleInboundAck(
    OverlayLinkRecord record,
    OverlayLinkFrame frame,
  ) async {
    final session = _sessions[record.linkId];
    if (session == null) {
      AppLogging.overlay(
        'SECURE_ACK ignored: no session for linkId=0x'
        '${record.linkId.toRadixString(16)}',
      );
      return;
    }
    try {
      final ok = await session.handleAck(frame.payload);
      if (!ok) {
        AppLogging.overlay(
          'SECURE_ACK verify failed linkId=0x'
          '${record.linkId.toRadixString(16)}',
        );
        _sessions.remove(record.linkId);
        return;
      }
      AppLogging.overlay(
        'SECURE active (initiator) linkId=0x'
        '${record.linkId.toRadixString(16)}',
      );
    } catch (e) {
      AppLogging.overlay(
        'SECURE_ACK handler threw linkId=0x'
        '${record.linkId.toRadixString(16)}: $e',
      );
      _sessions.remove(record.linkId);
    }
  }

  Future<void> _handleInboundData(
    OverlayLinkRecord record,
    OverlayLinkFrame frame,
  ) async {
    final session = _sessions[record.linkId];
    if (session == null || !session.isEstablished) {
      AppLogging.overlay(
        'SECURE_DATA drop: notEstablished linkId=0x'
        '${record.linkId.toRadixString(16)}',
      );
      return;
    }
    final result = await session.unwrap(frame.payload);
    if (!result.ok) {
      AppLogging.overlay(
        'SECURE_DATA drop: ${result.failure?.name} linkId=0x'
        '${record.linkId.toRadixString(16)}',
      );
      return;
    }
    _inbound.add(
      OverlaySecureInboundPayload(
        linkId: record.linkId,
        subtype: result.subtype!,
        seq: result.seq!,
        cleartext: result.cleartext!,
      ),
    );
  }

  // -----------------------------------------------------------------
  // Outbound (Phase 2 DM wrap path will use this)
  // -----------------------------------------------------------------

  /// Wrap [cleartext] under the session for [linkId] and dispatch it
  /// via egress. Returns true if the frame was handed to the
  /// transport, false if the session isn't ready (Phase 2 callers
  /// should then fall back to the plaintext path per policy).
  Future<bool> sendEncrypted(
    int linkId,
    Uint8List cleartext, {
    OverlaySecureDataSubtype subtype = OverlaySecureDataSubtype.generic,
  }) async {
    final session = _sessions[linkId];
    if (session == null || !session.isEstablished) return false;
    final record = await _store.getByLinkId(linkId);
    if (record == null ||
        record.state == OverlayLinkState.failed ||
        record.state == OverlayLinkState.closed) {
      return false;
    }
    final wrapped = await session.wrap(cleartext: cleartext, subtype: subtype);
    return _sendFrame(
      record,
      OverlayLinkMsgType.linkSecureData,
      wrapped.payload,
    );
  }

  // -----------------------------------------------------------------
  // Internals
  // -----------------------------------------------------------------

  bool _peerSupportsSecure(OverlayLinkRecord record) {
    final bits = record.capabilities.supportedFeatures;
    return (bits & OverlayCapabilityFeature.secureV03) ==
        OverlayCapabilityFeature.secureV03;
  }

  Future<OverlaySecureSession?> _buildSessionFor(
    OverlayLinkRecord record, {
    required bool initiator,
  }) async {
    final localPub = _endpointManager.localPublicKey();
    final localEndpointId = _endpointManager.localEndpointId();
    final peer = await _endpointManager.resolvePeerByHints(
      personaHint: record.peerPersonaHint,
      peerNodeNum: record.peerNodeNum,
    );
    if (peer == null) {
      AppLogging.overlay(
        'SECURE build skip: no endpoint for peer=${record.peerNodeNum} '
        'linkId=0x${record.linkId.toRadixString(16)}',
      );
      return null;
    }

    // Canonicalize init/resp endpoint ids by the link's role.
    final initEndpointId = initiator ? localEndpointId : peer.endpointId;
    final respEndpointId = initiator ? peer.endpointId : localEndpointId;

    return OverlaySecureSession(
      linkId: record.linkId,
      initEndpointId: initEndpointId,
      respEndpointId: respEndpointId,
      localPersonaPubEd: localPub,
      peerPersonaPubEd: peer.personaPubEd,
      sign: _endpointManager.sign,
      initiator: initiator,
    );
  }

  Future<bool> _sendFrame(
    OverlayLinkRecord record,
    OverlayLinkMsgType msgType,
    Uint8List payload,
  ) async {
    final frame = OverlayLinkFrame(
      msgType: msgType,
      flags: OverlayLinkFlags.linkFrame,
      requestId: 0,
      serviceId: 0,
      actionId: 0,
      payloadLen: payload.length,
      linkId: record.linkId,
      seq: 0,
      ackHi: 0,
      payload: payload,
    );
    return _egress.send(frame, record.peerNodeNum);
  }

  /// Close all sessions and release resources. Safe to call multiple
  /// times.
  Future<void> dispose() async {
    _sessions.clear();
    await _inbound.close();
  }
}
