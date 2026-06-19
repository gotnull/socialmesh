// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// MRRP meetup.v1 service handler.
///
/// Manages short-lived rendezvous tokens for mesh meetups. Each token has
/// an 8-byte random ID, an expiry TTL, and tracks the party count. The
/// in-memory store is bounded at 8 active meetups.
///
/// Actions:
/// - **create** (0x0001): Create a new meetup token.
/// - **accept** (0x0002): Accept (join) an existing token.
/// - **cancel** (0x0003): Cancel (delete) a token.
/// - **inspect** (0x0004): Query current token state.
library;

import 'dart:math';
import 'dart:typed_data';

import '../../../core/logging.dart';
import 'mrrp_constants.dart';
import 'mrrp_frame.dart';
import 'mrrp_service_handler.dart';
import 'mrrp_types.dart';

/// Maximum number of active meetup tokens.
const int _maxActiveMeetups = 8;

/// Maximum meetup TTL in seconds.
const int _maxMeetupTtlS = 3600;

/// Default meetup TTL in seconds.
const int _defaultMeetupTtlS = 1800;

/// A single meetup token.
class MeetupToken {
  /// 8-byte random token identifier.
  final Uint8List tokenId;

  /// Node ID of the creator.
  final int creatorNodeId;

  /// Intent type.
  final MeetupIntentType intent;

  /// Expiry time.
  final DateTime expiresAt;

  /// Number of participants who accepted.
  int partyCount;

  /// Current state.
  MeetupTokenState state;

  MeetupToken({
    required this.tokenId,
    required this.creatorNodeId,
    required this.intent,
    required this.expiresAt,
    this.partyCount = 1,
    this.state = MeetupTokenState.pending,
  });

  /// Whether this token has expired relative to the given time.
  bool isExpiredAt(DateTime now) => now.isAfter(expiresAt);

  /// Token ID as hex string for map keys.
  String get tokenIdHex =>
      tokenId.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

/// meetup.v1 handler.
class MrrpServiceMeetup implements MrrpServiceHandler {
  /// Injectable random for testing.
  final Random _random;

  /// Injectable clock for testing.
  final DateTime Function()? _clock;

  /// Active meetup tokens, keyed by token_id hex.
  final Map<String, MeetupToken> _tokens = {};

  MrrpServiceMeetup({Random? random, this._clock})
    : _random = random ?? Random.secure();

  @override
  int get serviceId => MrrpServiceId.meetupV1;

  @override
  Set<int> get supportedActions => const {
    MeetupAction.create,
    MeetupAction.accept,
    MeetupAction.cancel,
    MeetupAction.inspect,
  };

  DateTime _now() => _clock?.call() ?? DateTime.now();

  /// Visible for testing.
  int get activeTokenCount {
    final now = _now();
    return _tokens.values
        .where(
          (t) =>
              !t.isExpiredAt(now) &&
              (t.state == MeetupTokenState.pending ||
                  t.state == MeetupTokenState.accepted),
        )
        .length;
  }

  @override
  Future<MrrpFrame> handleRequest(MrrpFrame request, int senderNodeId) async {
    switch (request.actionId) {
      case MeetupAction.create:
        return _handleCreate(request, senderNodeId);
      case MeetupAction.accept:
        return _handleAccept(request, senderNodeId);
      case MeetupAction.cancel:
        return _handleCancel(request, senderNodeId);
      case MeetupAction.inspect:
        return _handleInspect(request);
      default:
        return _buildError(request, MrrpStatusCode.unsupported);
    }
  }

  // ---------------------------------------------------------------------------
  // Create
  // ---------------------------------------------------------------------------

  /// Request payload: intent(1) + ttl_s(2, LE) = 3 bytes minimum.
  MrrpFrame _handleCreate(MrrpFrame request, int senderNodeId) {
    _purgeExpired();
    if (_tokens.length >= _maxActiveMeetups) {
      AppLogging.mrrp(
        'MRRP_SERVICE: meetup.v1 create rejected, '
        '${_tokens.length}/$_maxActiveMeetups active', // lint-allow: hardcoded-string
      );
      return _buildError(request, MrrpStatusCode.busy);
    }

    int intentCode = 0;
    int ttlS = _defaultMeetupTtlS;
    if (request.payload.isNotEmpty) {
      intentCode = request.payload[0];
    }
    if (request.payload.length >= 3) {
      ttlS = ByteData.sublistView(request.payload).getUint16(1, Endian.little);
    }
    ttlS = ttlS.clamp(1, _maxMeetupTtlS);

    final intent =
        MeetupIntentType.fromCode(intentCode) ?? MeetupIntentType.general;
    final tokenId = Uint8List(8);
    for (var i = 0; i < 8; i++) {
      tokenId[i] = _random.nextInt(256);
    }

    final token = MeetupToken(
      tokenId: tokenId,
      creatorNodeId: senderNodeId,
      intent: intent,
      expiresAt: _now().add(Duration(seconds: ttlS)),
    );
    _tokens[token.tokenIdHex] = token;

    AppLogging.mrrp(
      'MRRP_SERVICE: meetup.v1 create token=${token.tokenIdHex}, '
      'expires_in=${ttlS}s', // lint-allow: hardcoded-string
    );

    // Response: token_id(8) + state(1) + intent(1) + ttl_s(2) + party_count(1) = 13 bytes.
    final payload = Uint8List(13);
    payload.setRange(0, 8, tokenId);
    payload[8] = token.state.code;
    payload[9] = intent.code;
    ByteData.sublistView(payload).setUint16(10, ttlS, Endian.little);
    payload[12] = token.partyCount;

    return _buildResponse(request, payload);
  }

  // ---------------------------------------------------------------------------
  // Accept
  // ---------------------------------------------------------------------------

  /// Request payload: token_id(8) = 8 bytes.
  MrrpFrame _handleAccept(MrrpFrame request, int senderNodeId) {
    if (request.payload.length < 8) {
      return _buildError(request, MrrpStatusCode.invalid);
    }

    final tokenIdHex = request.payload
        .sublist(0, 8)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final token = _tokens[tokenIdHex];

    if (token == null) {
      return _buildError(request, MrrpStatusCode.notFound);
    }
    if (token.isExpiredAt(_now())) {
      return _buildError(request, MrrpStatusCode.expired);
    }
    if (token.state == MeetupTokenState.cancelled) {
      return _buildError(request, MrrpStatusCode.expired);
    }

    token.partyCount++;
    if (token.state == MeetupTokenState.pending) {
      token.state = MeetupTokenState.accepted;
    }

    AppLogging.mrrp(
      'MRRP_SERVICE: meetup.v1 accept token=$tokenIdHex, '
      'party_count=${token.partyCount}', // lint-allow: hardcoded-string
    );

    return _buildTokenStateResponse(request, token);
  }

  // ---------------------------------------------------------------------------
  // Cancel
  // ---------------------------------------------------------------------------

  /// Request payload: token_id(8) = 8 bytes.
  MrrpFrame _handleCancel(MrrpFrame request, int senderNodeId) {
    if (request.payload.length < 8) {
      return _buildError(request, MrrpStatusCode.invalid);
    }

    final tokenIdHex = request.payload
        .sublist(0, 8)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final token = _tokens[tokenIdHex];

    if (token == null) {
      return _buildError(request, MrrpStatusCode.notFound);
    }

    token.state = MeetupTokenState.cancelled;

    AppLogging.mrrp(
      'MRRP_SERVICE: meetup.v1 cancel '
      'token=$tokenIdHex', // lint-allow: hardcoded-string
    );

    return _buildTokenStateResponse(request, token);
  }

  // ---------------------------------------------------------------------------
  // Inspect
  // ---------------------------------------------------------------------------

  /// Request payload: token_id(8) = 8 bytes.
  MrrpFrame _handleInspect(MrrpFrame request) {
    if (request.payload.length < 8) {
      return _buildError(request, MrrpStatusCode.invalid);
    }

    final tokenIdHex = request.payload
        .sublist(0, 8)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final token = _tokens[tokenIdHex];

    if (token == null) {
      return _buildError(request, MrrpStatusCode.notFound);
    }
    if (token.isExpiredAt(_now()) &&
        token.state != MeetupTokenState.cancelled) {
      token.state = MeetupTokenState.expired;
    }

    return _buildTokenStateResponse(request, token);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  MrrpFrame _buildTokenStateResponse(MrrpFrame request, MeetupToken token) {
    // Response: token_id(8) + state(1) + intent(1) + remaining_s(2) + party_count(1) = 13 bytes.
    final payload = Uint8List(13);
    payload.setRange(0, 8, token.tokenId);
    payload[8] = token.state.code;
    payload[9] = token.intent.code;
    final now = _now();
    final remaining = token.isExpiredAt(now)
        ? 0
        : token.expiresAt.difference(now).inSeconds;
    ByteData.sublistView(
      payload,
    ).setUint16(10, remaining.clamp(0, 65535), Endian.little);
    payload[12] = token.partyCount;
    return _buildResponse(request, payload);
  }

  void _purgeExpired() {
    final now = _now();
    _tokens.removeWhere(
      (_, t) => t.isExpiredAt(now) && t.state != MeetupTokenState.cancelled,
    );
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
