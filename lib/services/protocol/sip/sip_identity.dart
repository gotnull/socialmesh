// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SIP-1 identity exchange handler.
///
/// Manages sending and receiving identity claims/requests with Ed25519
/// signature creation and verification. User-initiated only -- never
/// broadcast automatically.
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import 'sip_codec.dart';
import 'sip_constants.dart';
import 'sip_frame.dart';
import 'sip_identity_store.dart';
import 'sip_keypair.dart';
import 'sip_messages_id.dart';
import 'sip_types.dart';

/// Outbound identity frame ready to send.
class SipIdentityOutbound {
  final SipFrame frame;
  final Uint8List encoded;

  const SipIdentityOutbound({required this.frame, required this.encoded});
}

/// Result of processing an inbound identity claim.
class SipIdentityInboundResult {
  final SipIdentityState state;
  final SipIdClaim claim;
  final bool signatureValid;
  final bool rateLimited;

  const SipIdentityInboundResult({
    required this.state,
    required this.claim,
    required this.signatureValid,
    this.rateLimited = false,
  });
}

/// Handles SIP-1 identity exchange: requests, claims, and responses.
///
/// Usage:
///   - Call [buildIdReq] to create an ID_REQ frame to request a peer's identity
///   - Call [buildIdClaim] to create a signed ID_CLAIM frame to share identity
///   - Call [handleInboundClaim] to process a received ID_CLAIM/ID_RESP
///   - Call [handleInboundReq] to process a received ID_REQ and auto-respond
class SipIdentityHandler {
  /// Creates a handler with the required dependencies.
  SipIdentityHandler({
    required SipKeypair keypair,
    required SipIdentityStore store,
    int localNodeId = 0,
    String displayName = '',
    String status = '',
    String deviceModel = '',
    int claimTtlS = 86400,
    int Function()? clock,
  }) : _keypair = keypair,
       _store = store,
       _localNodeId = localNodeId,
       _displayName = displayName,
       _status = status,
       _deviceModel = deviceModel,
       _claimTtlS = claimTtlS,
       _clock = clock;

  final SipKeypair _keypair;
  final SipIdentityStore _store;

  /// Local node ID used in identity claims.
  int get localNodeId => _localNodeId;
  final int _localNodeId;

  /// Whether profile sharing is enabled.
  ///
  /// When false, auto-responses to ID_REQ and outbound ID_CLAIM broadcasts
  /// are suppressed. Set by the provider layer from the mesh privacy setting.
  bool isProfileSharingEnabled = false;

  final String _displayName;
  final String _status;
  final String _deviceModel;
  final int _claimTtlS;
  final int Function()? _clock;

  /// Rate limiter: peer node_id -> last outbound claim timestamp (ms).
  final Map<int, int> _lastOutboundClaimMs = {};

  /// Minimum interval between outbound claims to the same peer (ms).
  static const int _minClaimIntervalMs = 300 * 1000;

  int _nowMs() => _clock?.call() ?? DateTime.now().millisecondsSinceEpoch;

  int _nowS() => _nowMs() ~/ 1000;

  // ---------------------------------------------------------------------------
  // Outbound: ID_REQ
  // ---------------------------------------------------------------------------

  /// Build an ID_REQ frame to request identity from [peerNodeId].
  SipIdentityOutbound? buildIdReq({
    SipIdRequestMode mode = SipIdRequestMode.basic,
  }) {
    final payload = SipIdMessages.encodeIdReq(SipIdReq(mode: mode));
    final frame = SipFrame(
      versionMajor: SipConstants.sipVersionMajor,
      versionMinor: SipConstants.sipVersionMinor,
      msgType: SipMessageType.idReq,
      flags: 0,
      headerLen: SipConstants.sipWrapperMin,
      sessionId: 0,
      nonce: SipCodec.generateNonce(),
      timestampS: _nowS(),
      payloadLen: payload.length,
      payload: payload,
    );

    final encoded = SipCodec.encode(frame);
    if (encoded == null) return null;

    AppLogging.sip('SIP_ID: -> ID_REQ, mode=${mode.name}');

    return SipIdentityOutbound(frame: frame, encoded: encoded);
  }

  // ---------------------------------------------------------------------------
  // Outbound: ID_CLAIM
  // ---------------------------------------------------------------------------

  /// Build a signed ID_CLAIM frame to share local identity with a peer.
  ///
  /// Returns null if rate-limited (sent claim to this peer within 300s).
  Future<SipIdentityOutbound?> buildIdClaim({
    required int peerNodeId,
    SipMessageType msgType = SipMessageType.idClaim,
  }) async {
    // Rate limit outbound claims per peer.
    final nowMs = _nowMs();
    final lastMs = _lastOutboundClaimMs[peerNodeId];
    if (lastMs != null && nowMs - lastMs < _minClaimIntervalMs) {
      AppLogging.sip(
        'SIP_ID: outbound claim to node=0x${peerNodeId.toRadixString(16)} '
        'rate-limited (${(nowMs - lastMs) ~/ 1000}s < 300s)',
      );
      return null;
    }

    final pubkey = _keypair.getPublicKeyBytes();
    final personaId = _keypair.getPersonaId();

    final claim = SipIdClaim(
      keyType: sipSigTypeEd25519,
      displayName: _displayName,
      status: _status,
      deviceModel: _deviceModel,
      createdAt: _nowS(),
      personaId: personaId,
      pubkey: pubkey,
      claimTtlS: _claimTtlS,
    );

    final claimPayload = SipIdMessages.encodeIdClaim(claim);

    // Build the frame header for signature computation.
    final frame = SipFrame(
      versionMajor: SipConstants.sipVersionMajor,
      versionMinor: SipConstants.sipVersionMinor,
      msgType: msgType,
      flags: SipFlags.hasSignature,
      headerLen: SipConstants.sipWrapperMin,
      sessionId: 0,
      nonce: SipCodec.generateNonce(),
      timestampS: _nowS(),
      payloadLen: claimPayload.length + SipConstants.sipSignatureTrailer,
      payload: Uint8List(0), // placeholder; we build the real payload below
    );

    // Serialize the header for signature.
    final headerOnly = SipCodec.encode(
      SipFrame(
        versionMajor: frame.versionMajor,
        versionMinor: frame.versionMinor,
        msgType: frame.msgType,
        flags: frame.flags,
        headerLen: frame.headerLen,
        sessionId: frame.sessionId,
        nonce: frame.nonce,
        timestampS: frame.timestampS,
        payloadLen: frame.payloadLen,
        payload: Uint8List(frame.payloadLen),
      ),
    );
    if (headerOnly == null) return null;

    final headerBytes = Uint8List.fromList(
      headerOnly.sublist(0, frame.headerLen),
    );

    // Build data-to-sign: header + claim payload (no signature trailer).
    final dataToSign = SipIdMessages.buildSignedData(headerBytes, claimPayload);
    final signature = await _keypair.sign(dataToSign);

    // Append signature trailer to claim payload.
    final fullPayload = SipIdMessages.appendSignature(claimPayload, signature);

    // Build the final frame with the real payload.
    final signedFrame = SipFrame(
      versionMajor: frame.versionMajor,
      versionMinor: frame.versionMinor,
      msgType: frame.msgType,
      flags: frame.flags,
      headerLen: frame.headerLen,
      sessionId: frame.sessionId,
      nonce: frame.nonce,
      timestampS: frame.timestampS,
      payloadLen: fullPayload.length,
      payload: fullPayload,
    );

    final encoded = SipCodec.encode(signedFrame);
    if (encoded == null) return null;

    _lastOutboundClaimMs[peerNodeId] = nowMs;

    AppLogging.sip(
      'SIP_ID: -> ${msgType.name} to node=0x${peerNodeId.toRadixString(16)}, '
      'name=\'$_displayName\', pubkey_hint=${_keypair.getPublicKeyHint()}',
    );

    return SipIdentityOutbound(frame: signedFrame, encoded: encoded);
  }

  // ---------------------------------------------------------------------------
  // Inbound: ID_CLAIM / ID_RESP
  // ---------------------------------------------------------------------------

  /// Handle an inbound ID_CLAIM or ID_RESP frame.
  ///
  /// Verifies the Ed25519 signature and stores the identity claim.
  /// Returns null if the frame is invalid (bad decode, bad signature).
  Future<SipIdentityInboundResult?> handleInboundClaim({
    required SipFrame frame,
    required Uint8List rawFrameBytes,
    required int senderNodeId,
  }) async {
    final hasSig = (frame.flags & SipFlags.hasSignature) != 0;

    // Decode claim fields.
    final claim = SipIdMessages.decodeIdClaim(frame.payload, hasSig: hasSig);
    if (claim == null) {
      AppLogging.sip(
        'SIP_ID: <- ${frame.msgType.name} from node=0x${senderNodeId.toRadixString(16)} '
        'decode FAILED',
      );
      return null;
    }

    AppLogging.sip(
      'SIP_ID: <- ${frame.msgType.name} from node=0x${senderNodeId.toRadixString(16)}, '
      'pubkey_hint=${claim.pubkey.sublist(0, 4).map((b) => b.toRadixString(16).padLeft(2, '0')).join()}, '
      'name=\'${claim.displayName}\'',
    );

    // Signature verification.
    var signatureValid = false;
    if (hasSig) {
      final sigData = SipIdMessages.extractSignature(frame.payload);
      if (sigData == null) {
        AppLogging.sip(
          'SIP_ID: signature extraction FAILED for node=0x${senderNodeId.toRadixString(16)}',
        );
        return null;
      }

      // Build data-to-sign from header + payload without signature.
      final headerBytes = Uint8List.fromList(
        rawFrameBytes.sublist(0, frame.headerLen),
      );
      final payloadWithoutSig = Uint8List.fromList(
        frame.payload.sublist(
          0,
          frame.payload.length - SipConstants.sipSignatureTrailer,
        ),
      );
      final dataToVerify = SipIdMessages.buildSignedData(
        headerBytes,
        payloadWithoutSig,
      );

      signatureValid = await _keypair.verify(
        dataToVerify,
        sigData.signature,
        claim.pubkey,
      );

      AppLogging.sip(
        'SIP_ID: signature ${signatureValid ? 'VERIFIED' : 'FAILED'} '
        'for node=0x${senderNodeId.toRadixString(16)}',
      );
    } else {
      AppLogging.sip(
        'SIP_ID: no signature on ${frame.msgType.name} from '
        'node=0x${senderNodeId.toRadixString(16)} -- treating as unverified',
      );
    }

    if (!signatureValid) {
      // Store as unverified.
      return SipIdentityInboundResult(
        state: SipIdentityState.unverified,
        claim: claim,
        signatureValid: false,
      );
    }

    // Store the verified claim.
    final state = _store.storeClaim(
      nodeId: senderNodeId,
      pubkey: claim.pubkey,
      personaId: claim.personaId,
      displayName: claim.displayName,
      status: claim.status,
      deviceModel: claim.deviceModel,
      createdAt: claim.createdAt,
      claimTtlS: claim.claimTtlS,
    );

    if (state == null) {
      // Rate-limited by the store.
      return SipIdentityInboundResult(
        state: SipIdentityState.unverified,
        claim: claim,
        signatureValid: true,
        rateLimited: true,
      );
    }

    AppLogging.sip('SIP_ID: identity_state=${state.name}');

    return SipIdentityInboundResult(
      state: state,
      claim: claim,
      signatureValid: true,
    );
  }

  // ---------------------------------------------------------------------------
  // Inbound: ID_REQ -> auto-respond with ID_RESP
  // ---------------------------------------------------------------------------

  /// Handle an inbound ID_REQ and build an ID_RESP.
  ///
  /// Returns null if we decline to respond (e.g., rate-limited).
  Future<SipIdentityOutbound?> handleInboundReq({
    required SipFrame frame,
    required int senderNodeId,
  }) async {
    // Privacy gate: suppress auto-respond when profile sharing is off.
    if (!isProfileSharingEnabled) {
      AppLogging.sip(
        'SIP_ID: ID_REQ from node=0x${senderNodeId.toRadixString(16)} '
        'suppressed (profileSharing=false)',
      );
      return null;
    }

    final req = SipIdMessages.decodeIdReq(frame.payload);
    if (req == null) {
      AppLogging.sip(
        'SIP_ID: <- ID_REQ from node=0x${senderNodeId.toRadixString(16)} '
        'decode FAILED',
      );
      return null;
    }

    AppLogging.sip(
      'SIP_ID: <- ID_REQ from node=0x${senderNodeId.toRadixString(16)}, '
      'mode=${req.mode.name}',
    );

    // Build and return an ID_RESP (same format as ID_CLAIM).
    return buildIdClaim(
      peerNodeId: senderNodeId,
      msgType: SipMessageType.idResp,
    );
  }
}
