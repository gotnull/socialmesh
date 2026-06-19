// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:async';
import 'dart:typed_data';

import '../../core/logging.dart';
import '../protocol/socialmesh/sm_constants.dart';
import '../protocol/socialmesh/sm_file_transfer.dart';
import 'spp_constants.dart';
import 'spp_protocol.dart';
import 'spp_types.dart';

/// Callback type for sending an SPP packet over the mesh.
typedef SppSendCallback =
    Future<bool> Function(
      Uint8List payload, {
      int? destinationNode,
      int hopLimit,
    });

/// Callback type for checking if a node is trusted.
typedef SppTrustCheck = bool Function(int nodeNum);

/// Callback type for getting current total stored payload bytes.
typedef SppStorageCheck = int Function();

/// The SPP negotiation layer.
///
/// Manages the OFFER → ACCEPT/DECLINE handshake for inbound transfers
/// and the OFFER → wait-for-ACCEPT flow for outbound transfers.
///
/// This layer sits between the protocol service (which decodes packets)
/// and the file transfer engine (which manages chunks). It gates all
/// transfers through mandatory negotiation.
///
/// Spec: docs/protocols/SPP_v1.md §7 (Negotiation Rules)
class PayloadNegotiation {
  final SppSendCallback _sendPacket;
  final SppTrustCheck _isTrusted;
  final SppStorageCheck _getStorageUsed;

  /// Active negotiation sessions indexed by payloadId hex.
  final Map<String, SppPayloadOffer> _sessions = {};

  /// Original SmFileOffer objects for accepted sessions (needed by engine).
  final Map<String, SmFileOffer> _originalOffers = {};

  /// Timers for negotiation timeouts (outbound: waiting for response).
  final Map<String, Timer> _timeouts = {};

  /// Track declined/aborted payloadIds to handle duplicate offers.
  final Map<String, int> _respondedOffers = {};

  /// Auto-accept configuration.
  SppAutoAcceptConfig _autoAcceptConfig;

  /// Stream controller for offers that need user decision.
  final _pendingOffersController =
      StreamController<SppPayloadOffer>.broadcast();

  /// Stream controller for negotiation state changes.
  final _stateChangedController = StreamController<SppPayloadOffer>.broadcast();

  /// Pending offers that need user decision.
  Stream<SppPayloadOffer> get pendingOffers => _pendingOffersController.stream;

  /// Negotiation state changes (accept, decline, abort, timeout).
  Stream<SppPayloadOffer> get stateChanges => _stateChangedController.stream;

  /// Retrieve the original SmFileOffer for a given payloadId hex.
  SmFileOffer? getOriginalOffer(String payloadIdHex) =>
      _originalOffers[payloadIdHex];

  /// Active sessions count.
  int get activeSessionCount => _sessions.values
      .where(
        (s) =>
            s.state == SppNegotiationState.accepted ||
            s.state == SppNegotiationState.offerPending,
      )
      .length;

  /// Active inbound sessions count.
  int get activeInboundCount => _sessions.values
      .where(
        (s) =>
            s.state == SppNegotiationState.offerPending ||
            s.state == SppNegotiationState.accepted,
      )
      .length;

  /// Count of active inbound sessions from a specific node.
  int activeFromNode(int nodeNum) => _sessions.values
      .where(
        (s) =>
            s.sourceNodeNum == nodeNum &&
            (s.state == SppNegotiationState.offerPending ||
                s.state == SppNegotiationState.accepted),
      )
      .length;

  /// All pending offers awaiting user decision.
  List<SppPayloadOffer> get pendingOffersList => _sessions.values
      .where((s) => s.state == SppNegotiationState.offerPending)
      .toList();

  /// Whether a negotiation session exists for the given payload ID.
  bool hasSession(String payloadIdHex) => _sessions.containsKey(payloadIdHex);

  /// Whether the session for [payloadIdHex] has been accepted by the remote.
  bool isAccepted(String payloadIdHex) =>
      _sessions[payloadIdHex]?.state == SppNegotiationState.accepted;

  PayloadNegotiation({
    required this._sendPacket,
    required this._isTrusted,
    required this._getStorageUsed,
    this._autoAcceptConfig = const SppAutoAcceptConfig(),
  });

  /// Update auto-accept configuration.
  void updateAutoAcceptConfig(SppAutoAcceptConfig config) {
    _autoAcceptConfig = config;
    AppLogging.spp(
      'auto-accept config updated: enabled=${config.enabled}, '
      'trustedOnly=${config.trustedOnly}, '
      'maxSize=${config.maxSizeBytes}',
    );
  }

  // ─── Inbound Offer Handling ──────────────────────────────────────

  /// Handle an incoming OFFER. Evaluates auto-accept rules and either
  /// auto-accepts, prompts the user, or auto-declines.
  ///
  /// Returns the negotiation decision:
  /// - `SppNegotiationState.accepted` if auto-accepted
  /// - `SppNegotiationState.offerPending` if user must decide
  /// - `SppNegotiationState.declined` if auto-declined
  SppNegotiationState handleIncomingOffer(
    SmFileOffer offer, {
    int? sourceNodeNum,
  }) {
    final idHex = fileIdToHex(offer.fileId);

    AppLogging.sppNegotiation(
      'offer received (payload=$idHex, type=${offer.mimeType}, '
      'size=${offer.totalBytes}, from=${sourceNodeNum?.toRadixString(16)})',
    );

    // Check for duplicate offer
    if (_sessions.containsKey(idHex)) {
      final existing = _sessions[idHex]!;
      AppLogging.sppNegotiation(
        'duplicate offer ignored (payload=$idHex, '
        'state=${existing.state.name})',
      );
      // Re-send previous response for idempotency
      _resendResponse(existing);
      return existing.state;
    }

    // Check previously responded offers
    if (_respondedOffers.containsKey(idHex)) {
      AppLogging.sppNegotiation('previously responded offer (payload=$idHex)');
      return SppNegotiationState.declined;
    }

    // Determine payload type from MIME type
    final payloadType = _inferPayloadType(offer.mimeType);

    final session = SppPayloadOffer(
      payloadIdHex: idHex,
      payloadId: offer.fileId,
      payloadType: payloadType,
      filename: offer.filename,
      mimeType: offer.mimeType,
      payloadSize: offer.totalBytes,
      sourceNodeNum: sourceNodeNum,
      receivedAt: DateTime.now(),
      state: SppNegotiationState.offerPending,
    );

    // Store original offer for engine forwarding on accept.
    _originalOffers[idHex] = offer;

    // --- Evaluate auto-decline rules ---

    // Rate limit: per-node
    if (sourceNodeNum != null &&
        activeFromNode(sourceNodeNum) >= SppRateLimit.maxPerNode) {
      AppLogging.sppNegotiation(
        'offer auto-declined (payload=$idHex, '
        'reason=rate_limited, node=$sourceNodeNum)',
      );
      _sendDecline(
        offer.fileId,
        SppDeclineReason.rateLimited,
        destinationNode: sourceNodeNum,
      );
      _respondedOffers[idHex] = SppDeclineReason.rateLimited;
      return SppNegotiationState.declined;
    }

    // Rate limit: total concurrent inbound
    if (activeInboundCount >= SppRateLimit.maxConcurrentInbound) {
      AppLogging.sppNegotiation(
        'offer auto-declined (payload=$idHex, reason=rate_limited, '
        'concurrent=$activeInboundCount)',
      );
      _sendDecline(
        offer.fileId,
        SppDeclineReason.rateLimited,
        destinationNode: sourceNodeNum,
      );
      _respondedOffers[idHex] = SppDeclineReason.rateLimited;
      return SppNegotiationState.declined;
    }

    // Size limit
    if (offer.totalBytes > SppLimits.maxPayloadSize) {
      AppLogging.sppNegotiation(
        'offer auto-declined (payload=$idHex, reason=too_large, '
        'size=${offer.totalBytes})',
      );
      _sendDecline(
        offer.fileId,
        SppDeclineReason.tooLarge,
        destinationNode: sourceNodeNum,
      );
      _respondedOffers[idHex] = SppDeclineReason.tooLarge;
      return SppNegotiationState.declined;
    }

    // Storage quota
    final currentStorage = _getStorageUsed();
    if (currentStorage + offer.totalBytes > SppLimits.maxTotalStorage) {
      AppLogging.sppNegotiation(
        'offer auto-declined (payload=$idHex, reason=storage_full, '
        'used=$currentStorage)',
      );
      _sendDecline(
        offer.fileId,
        SppDeclineReason.storageFull,
        destinationNode: sourceNodeNum,
      );
      _respondedOffers[idHex] = SppDeclineReason.storageFull;
      return SppNegotiationState.declined;
    }

    // --- Evaluate auto-accept rules ---

    final isTrusted = sourceNodeNum != null && _isTrusted(sourceNodeNum);

    if (_autoAcceptConfig.shouldAutoAccept(
      payloadType: payloadType,
      payloadSize: offer.totalBytes,
      isTrusted: isTrusted,
    )) {
      AppLogging.sppNegotiation('offer auto-accepted (payload=$idHex)');
      _sessions[idHex] = session.copyWith(state: SppNegotiationState.accepted);
      _sendAccept(offer.fileId, destinationNode: sourceNodeNum);
      _stateChangedController.add(_sessions[idHex]!);
      return SppNegotiationState.accepted;
    }

    // --- Require user decision ---
    _sessions[idHex] = session;
    _pendingOffersController.add(session);
    _stateChangedController.add(session);

    AppLogging.sppNegotiation('offer pending user decision (payload=$idHex)');

    return SppNegotiationState.offerPending;
  }

  /// User accepts a pending offer.
  void acceptOffer(String payloadIdHex) {
    final session = _sessions[payloadIdHex];
    if (session == null) {
      AppLogging.sppNegotiation(
        'accept failed: session not found (payload=$payloadIdHex)',
      );
      return;
    }
    if (session.state != SppNegotiationState.offerPending) {
      AppLogging.sppNegotiation(
        'accept failed: not pending (payload=$payloadIdHex, '
        'state=${session.state.name})',
      );
      return;
    }

    _sessions[payloadIdHex] = session.copyWith(
      state: SppNegotiationState.accepted,
    );
    _sendAccept(session.payloadId, destinationNode: session.sourceNodeNum);
    _stateChangedController.add(_sessions[payloadIdHex]!);

    AppLogging.sppNegotiation('offer accepted (payload=$payloadIdHex)');
  }

  /// User declines a pending offer.
  void declineOffer(String payloadIdHex, {int? reason}) {
    final session = _sessions[payloadIdHex];
    if (session == null) {
      AppLogging.sppNegotiation(
        'decline failed: session not found (payload=$payloadIdHex)',
      );
      return;
    }
    if (session.state != SppNegotiationState.offerPending) {
      AppLogging.sppNegotiation(
        'decline failed: not pending (payload=$payloadIdHex, '
        'state=${session.state.name})',
      );
      return;
    }

    final declineReason = reason ?? SppDeclineReason.userDeclined;
    _sessions[payloadIdHex] = session.copyWith(
      state: SppNegotiationState.declined,
    );
    _sendDecline(
      session.payloadId,
      declineReason,
      destinationNode: session.sourceNodeNum,
    );
    _respondedOffers[payloadIdHex] = declineReason;
    _stateChangedController.add(_sessions[payloadIdHex]!);

    AppLogging.sppNegotiation(
      'offer declined (payload=$payloadIdHex, '
      'reason=${SppDeclineReason.name(declineReason)})',
    );
  }

  // ─── Outbound Negotiation ────────────────────────────────────────

  /// Register an outbound offer and start waiting for ACCEPT/DECLINE.
  void registerOutboundOffer(SmFileOffer offer, {int? targetNodeNum}) {
    final idHex = fileIdToHex(offer.fileId);
    final payloadType = _inferPayloadType(offer.mimeType);

    _sessions[idHex] = SppPayloadOffer(
      payloadIdHex: idHex,
      payloadId: offer.fileId,
      payloadType: payloadType,
      filename: offer.filename,
      mimeType: offer.mimeType,
      payloadSize: offer.totalBytes,
      sourceNodeNum: targetNodeNum,
      receivedAt: DateTime.now(),
      state: SppNegotiationState.offerSent,
    );

    // Start negotiation timeout
    _timeouts[idHex]?.cancel();
    _timeouts[idHex] = Timer(SppRateLimit.negotiationTimeout, () {
      _handleNegotiationTimeout(idHex);
    });

    AppLogging.sppNegotiation(
      'outbound offer registered (payload=$idHex, '
      'timeout=${SppRateLimit.negotiationTimeout.inSeconds}s)',
    );
  }

  /// Handle incoming ACCEPT for an outbound offer.
  ///
  /// Returns true if the accept was valid and the transfer should proceed.
  bool handleIncomingAccept(SppAccept accept) {
    final idHex = accept.payloadIdHex;
    final session = _sessions[idHex];

    if (session == null) {
      AppLogging.sppNegotiation(
        'accept ignored: session not found (payload=$idHex)',
      );
      return false;
    }

    if (session.state != SppNegotiationState.offerSent) {
      AppLogging.sppNegotiation(
        'accept ignored: not awaiting (payload=$idHex, '
        'state=${session.state.name})',
      );
      return false;
    }

    _timeouts[idHex]?.cancel();
    _timeouts.remove(idHex);

    _sessions[idHex] = session.copyWith(state: SppNegotiationState.accepted);
    _stateChangedController.add(_sessions[idHex]!);

    AppLogging.sppNegotiation(
      'outbound offer accepted by receiver (payload=$idHex)',
    );
    return true;
  }

  /// Handle incoming DECLINE for an outbound offer.
  void handleIncomingDecline(SppDecline decline) {
    final idHex = decline.payloadIdHex;
    final session = _sessions[idHex];

    if (session == null) {
      AppLogging.sppNegotiation(
        'decline ignored: session not found (payload=$idHex)',
      );
      return;
    }

    if (session.state != SppNegotiationState.offerSent) {
      AppLogging.sppNegotiation(
        'decline ignored: not awaiting (payload=$idHex, '
        'state=${session.state.name})',
      );
      return;
    }

    _timeouts[idHex]?.cancel();
    _timeouts.remove(idHex);

    _sessions[idHex] = session.copyWith(state: SppNegotiationState.declined);
    _stateChangedController.add(_sessions[idHex]!);

    AppLogging.sppNegotiation(
      'outbound offer declined (payload=$idHex, '
      'reason=${SppDeclineReason.name(decline.reason)})',
    );
  }

  // ─── Abort Handling ──────────────────────────────────────────────

  /// Handle incoming ABORT from either party.
  void handleIncomingAbort(SppAbort abort) {
    final idHex = abort.payloadIdHex;
    final session = _sessions[idHex];

    if (session == null) {
      AppLogging.sppNegotiation(
        'abort ignored: session not found (payload=$idHex)',
      );
      return;
    }

    _timeouts[idHex]?.cancel();
    _timeouts.remove(idHex);

    _sessions[idHex] = session.copyWith(state: SppNegotiationState.aborted);
    _stateChangedController.add(_sessions[idHex]!);

    AppLogging.sppNegotiation(
      'transfer aborted (payload=$idHex, '
      'reason=${SppAbortReason.name(abort.reason)})',
    );
  }

  /// Send an ABORT for an active transfer.
  Future<void> abortTransfer(String payloadIdHex, {int reason = 0}) async {
    final session = _sessions[payloadIdHex];
    if (session == null) return;

    final payloadId = fileIdFromHex(payloadIdHex);
    if (payloadId == null) return;

    final abort = SppAbort(payloadId: payloadId, reason: reason);
    final encoded = abort.encode();
    if (encoded == null) return;

    await _sendPacket(
      encoded,
      destinationNode: session.sourceNodeNum,
      hopLimit: SmTransport.fileTransferHopLimit,
    );

    _sessions[payloadIdHex] = session.copyWith(
      state: SppNegotiationState.aborted,
    );
    _stateChangedController.add(_sessions[payloadIdHex]!);

    AppLogging.sppNegotiation(
      'transfer aborted (payload=$payloadIdHex, '
      'reason=${SppAbortReason.name(reason)})',
    );
  }

  // ─── Chunk Validation ────────────────────────────────────────────

  /// Check if a chunk should be accepted (has an active accepted session).
  ///
  /// Returns true if the payloadId has a session in `accepted` state.
  /// Unsolicited chunks (no matching session) are rejected.
  bool isChunkAuthorized(Uint8List payloadId) {
    final idHex = fileIdToHex(payloadId);
    final session = _sessions[idHex];
    return session?.state == SppNegotiationState.accepted;
  }

  /// Check if a v0 legacy offer should be auto-accepted.
  ///
  /// v0 offers have no negotiation. For backward compatibility,
  /// they are auto-accepted but logged as legacy.
  bool isLegacyOffer(Uint8List data) {
    if (data.isEmpty) return false;
    final version = (data[0] >> 4) & 0x0F;
    return version == SppVersion.v0;
  }

  // ─── Session Management ──────────────────────────────────────────

  /// Get session state for a payloadId.
  SppPayloadOffer? getSession(String payloadIdHex) => _sessions[payloadIdHex];

  /// Remove a completed/terminal session.
  void removeSession(String payloadIdHex) {
    _sessions.remove(payloadIdHex);
    _originalOffers.remove(payloadIdHex);
    _timeouts[payloadIdHex]?.cancel();
    _timeouts.remove(payloadIdHex);
  }

  /// Clean up all resources.
  void dispose() {
    for (final timer in _timeouts.values) {
      timer.cancel();
    }
    _timeouts.clear();
    _sessions.clear();
    _originalOffers.clear();
    _respondedOffers.clear();
    _pendingOffersController.close();
    _stateChangedController.close();
  }

  // ─── Private ─────────────────────────────────────────────────────

  void _handleNegotiationTimeout(String payloadIdHex) {
    final session = _sessions[payloadIdHex];
    if (session == null) return;
    if (session.state != SppNegotiationState.offerSent) return;

    _sessions[payloadIdHex] = session.copyWith(
      state: SppNegotiationState.timedOut,
    );
    _stateChangedController.add(_sessions[payloadIdHex]!);
    _timeouts.remove(payloadIdHex);

    AppLogging.sppNegotiation('negotiation timed out (payload=$payloadIdHex)');
  }

  Future<void> _sendAccept(Uint8List payloadId, {int? destinationNode}) async {
    final accept = SppAccept(payloadId: payloadId);
    final encoded = accept.encode();
    if (encoded == null) return;

    await _sendPacket(
      encoded,
      destinationNode: destinationNode,
      hopLimit: SmTransport.fileTransferHopLimit,
    );
  }

  Future<void> _sendDecline(
    Uint8List payloadId,
    int reason, {
    int? destinationNode,
  }) async {
    final decline = SppDecline(payloadId: payloadId, reason: reason);
    final encoded = decline.encode();
    if (encoded == null) return;

    await _sendPacket(
      encoded,
      destinationNode: destinationNode,
      hopLimit: SmTransport.fileTransferHopLimit,
    );
  }

  void _resendResponse(SppPayloadOffer session) {
    switch (session.state) {
      case SppNegotiationState.accepted:
        _sendAccept(session.payloadId, destinationNode: session.sourceNodeNum);
      case SppNegotiationState.declined:
        final reason =
            _respondedOffers[session.payloadIdHex] ??
            SppDeclineReason.userDeclined;
        _sendDecline(
          session.payloadId,
          reason,
          destinationNode: session.sourceNodeNum,
        );
      case SppNegotiationState.offerPending:
      case SppNegotiationState.offerSent:
      case SppNegotiationState.aborted:
      case SppNegotiationState.timedOut:
        break;
    }
  }

  SppPayload _inferPayloadType(String mimeType) {
    if (mimeType.startsWith('image/')) return SppPayload.image;
    if (mimeType == 'audio/x-codec2') return SppPayload.voice;
    return SppPayload.file;
  }
}
