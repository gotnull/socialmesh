// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// SIP ephemeral DM session manager.
///
/// Manages session-scoped DM threads created after successful SIP-1
/// handshakes. Sessions are identified by the handshake-derived
/// session_tag and expire after a configurable TTL (default 24h).
///
/// Key constraints:
/// - Messages are channel-encrypted (PSK) + session-tag-scoped.
/// - All sends counted against the SIP token-bucket budget.
/// - User can pin sessions to prevent expiry.
/// - Expired sessions are lazily cleaned up on access.
library;

import 'dart:typed_data';

import '../../../core/logging.dart';
import 'sip_codec.dart';
import 'sip_constants.dart';
import 'sip_counters.dart';
import 'sip_frame.dart';
import 'sip_messages_dm.dart';
import 'sip_rate_limiter.dart';
import 'sip_types.dart';

/// Status of a DM session.
enum SipDmSessionStatus {
  /// Active session, messages can be sent/received.
  active,

  /// Session has expired and will be cleaned up.
  expired,

  /// Session was explicitly closed by the user.
  closed,
}

/// A single ephemeral DM session.
class SipDmSession {
  /// Session tag from the handshake.
  final int sessionTag;

  /// Peer node ID.
  final int peerNodeId;

  /// Session creation timestamp (ms since epoch).
  final int createdAtMs;

  /// TTL in seconds.
  final int ttlS;

  /// Whether this session is pinned (no expiry).
  bool isPinned;

  /// Current session status.
  SipDmSessionStatus status;

  /// Message history for this session.
  final List<SipDmHistoryEntry> messages;

  SipDmSession({
    required this.sessionTag,
    required this.peerNodeId,
    required this.createdAtMs,
    required this.ttlS,
    this.isPinned = false,
    this.status = SipDmSessionStatus.active,
    List<SipDmHistoryEntry>? messages,
  }) : messages = messages ?? [];

  /// Check if this session has expired based on [nowMs].
  bool isExpired(int nowMs) {
    if (isPinned) return false;
    if (status == SipDmSessionStatus.closed) return true;
    final expiresAtMs = createdAtMs + (ttlS * 1000);
    return nowMs >= expiresAtMs;
  }
}

/// Direction of a DM message.
enum SipDmDirection {
  /// Message sent by the local user.
  outbound,

  /// Message received from the peer.
  inbound,
}

/// A single message in the DM history.
class SipDmHistoryEntry {
  /// The text content.
  final String text;

  /// Timestamp of the message (ms since epoch).
  final int timestampMs;

  /// Whether this message was sent or received.
  final SipDmDirection direction;

  /// The text being replied to, if this is a quote-reply.
  final String? replyToText;

  /// Reaction emoji from the local user (index into SipDmReactionEmojis.all).
  int? localReaction;

  /// Reaction emoji from the peer (index into SipDmReactionEmojis.all).
  int? peerReaction;

  SipDmHistoryEntry({
    required this.text,
    required this.timestampMs,
    required this.direction,
    this.replyToText,
    this.localReaction,
    this.peerReaction,
  });
}

/// Result of trying to send a DM.
class SipDmSendResult {
  /// The encoded SIP frame ready to transmit, or null on failure.
  final SipFrame? frame;

  /// Error reason if frame is null.
  final SipDmSendError? error;

  const SipDmSendResult._({this.frame, this.error});

  /// Successful send.
  factory SipDmSendResult.ok(SipFrame frame) => SipDmSendResult._(frame: frame);

  /// Failed send.
  factory SipDmSendResult.fail(SipDmSendError error) =>
      SipDmSendResult._(error: error);

  bool get isOk => frame != null;
}

/// Reasons a DM send can fail.
enum SipDmSendError {
  /// Session tag not found or expired.
  sessionNotFound,

  /// Text is empty.
  emptyText,

  /// Text exceeds max byte length.
  textTooLong,

  /// Rate limiter rejected the send.
  budgetExhausted,

  /// Session has been closed.
  sessionClosed,

  /// Encoding failed.
  encodingFailed,
}

/// Manages ephemeral DM sessions and message exchange.
///
/// Sessions are created from [SipHandshakeResult] data after a
/// successful handshake. Each session has a TTL (default 24h) and
/// can be pinned to prevent expiry.
class SipDmManager {
  /// Creates a DM manager.
  ///
  /// [rateLimiter] is used to enforce the SIP airtime budget.
  /// [clock] can be injected for testing (returns ms since epoch).
  SipDmManager({
    required SipRateLimiter rateLimiter,
    SipCounters? counters,
    int Function()? clock,
  }) : _rateLimiter = rateLimiter,
       _counters = counters,
       _clock = clock ?? _defaultClock;

  final SipRateLimiter _rateLimiter;
  final SipCounters? _counters;
  final int Function() _clock;

  /// Called whenever DM state changes (session created, message received, etc.)
  /// so the UI layer can rebuild.
  void Function()? onStateChanged;

  /// Called when a typing indicator is received for a session.
  /// The parameter is the session tag.
  void Function(int sessionTag)? onTypingReceived;

  /// Active sessions keyed by session_tag.
  final Map<int, SipDmSession> _sessions = {};

  /// Tracks which sessions have an active peer typing indicator.
  /// Maps session_tag -> expiry timestamp (ms).
  final Map<int, int> _peerTyping = {};

  /// Rate-limits outbound typing indicators per session.
  /// Maps session_tag -> last send timestamp (ms).
  final Map<int, int> _typingSentAt = {};

  static int _defaultClock() => DateTime.now().millisecondsSinceEpoch;

  // ---------------------------------------------------------------------------
  // Session lifecycle
  // ---------------------------------------------------------------------------

  /// Create a new DM session from a completed handshake.
  ///
  /// Returns the created session, or null if a session with this
  /// tag already exists.
  SipDmSession? createSession({
    required int sessionTag,
    required int peerNodeId,
    int? ttlS,
  }) {
    if (_sessions.containsKey(sessionTag)) {
      AppLogging.sip(
        'SIP_DM: session already exists for '
        'tag=0x${sessionTag.toRadixString(16)}',
      );
      return null;
    }

    final session = SipDmSession(
      sessionTag: sessionTag,
      peerNodeId: peerNodeId,
      createdAtMs: _clock(),
      ttlS: ttlS ?? SipConstants.dmTtlDefaultS,
    );
    _sessions[sessionTag] = session;

    AppLogging.sip(
      'SIP_DM: session created, tag=0x${sessionTag.toRadixString(16)}, '
      'ttl=${session.ttlS}s, peer=0x${peerNodeId.toRadixString(16)}',
    );

    onStateChanged?.call();

    return session;
  }

  /// Get a session by tag. Returns null if not found or expired.
  SipDmSession? getSession(int sessionTag) {
    final session = _sessions[sessionTag];
    if (session == null) return null;

    if (session.isExpired(_clock())) {
      _expireSession(sessionTag);
      return null;
    }

    return session;
  }

  /// Returns true if the session exists and has been explicitly closed
  /// (by either peer sending DM_CLOSE).
  bool isSessionClosed(int sessionTag) {
    final session = _sessions[sessionTag];
    return session?.status == SipDmSessionStatus.closed;
  }

  /// Get all active (non-expired) sessions.
  List<SipDmSession> get activeSessions {
    _cleanExpired();
    return List.unmodifiable(
      _sessions.values.where((s) => s.status == SipDmSessionStatus.active),
    );
  }

  /// Pin a session to prevent expiry.
  ///
  /// Returns false if session not found.
  bool pinSession(int sessionTag) {
    final session = _sessions[sessionTag];
    if (session == null) return false;

    if (session.isExpired(_clock())) {
      _expireSession(sessionTag);
      return false;
    }

    session.isPinned = true;
    AppLogging.sip(
      'SIP_DM: session pinned, tag=0x${sessionTag.toRadixString(16)}',
    );
    return true;
  }

  /// Unpin a session (re-enables TTL expiry).
  ///
  /// Returns false if session not found or not pinned.
  bool unpinSession(int sessionTag) {
    final session = _sessions[sessionTag];
    if (session == null) return false;

    if (!session.isPinned) return false;

    session.isPinned = false;
    AppLogging.sip(
      'SIP_DM: session unpinned, tag=0x${sessionTag.toRadixString(16)}',
    );
    return true;
  }

  /// Close a session explicitly and build a DM_CLOSE frame to notify the peer.
  ///
  /// Returns the encoded frame bytes to transmit, or null if the session was
  /// not found or rate-limited.
  Uint8List? closeSession(int sessionTag) {
    final session = _sessions[sessionTag];
    if (session == null) return null;

    session.status = SipDmSessionStatus.closed;
    AppLogging.sip(
      'SIP_DM: session closed, tag=0x${sessionTag.toRadixString(16)}',
    );

    // Build the DM_CLOSE frame (header-only, no payload).
    const frameSize = SipConstants.sipWrapperMin;
    Uint8List? encoded;
    if (_rateLimiter.canSend(frameSize)) {
      _rateLimiter.recordSend(frameSize);
      final frame = SipFrame(
        versionMajor: SipConstants.sipVersionMajor,
        versionMinor: SipConstants.sipVersionMinor,
        msgType: SipMessageType.dmClose,
        flags: 0,
        headerLen: SipConstants.sipWrapperMin,
        sessionId: sessionTag,
        nonce: SipCodec.generateNonce(),
        timestampS: _clock() ~/ 1000,
        payloadLen: 0,
        payload: Uint8List(0),
      );
      encoded = SipCodec.encode(frame);
    }

    onStateChanged?.call();
    return encoded;
  }

  /// Handle an inbound DM_CLOSE frame from the peer.
  ///
  /// Marks the local session as closed and fires [onStateChanged] so the UI
  /// can navigate back.
  void handleInboundClose(SipFrame frame) {
    if (frame.msgType != SipMessageType.dmClose) return;

    final sessionTag = frame.sessionId;
    final session = _sessions[sessionTag];
    if (session == null) return;

    session.status = SipDmSessionStatus.closed;
    AppLogging.sip(
      'SIP_DM: <- CLOSE from peer, '
      'session=0x${sessionTag.toRadixString(16)}',
    );
    onStateChanged?.call();
  }

  // ---------------------------------------------------------------------------
  // Typing indicators
  // ---------------------------------------------------------------------------

  /// Minimum interval between outbound typing indicators (ms).
  static const int _typingSendIntervalMs = 10000;

  /// How long a peer typing indicator stays visible (ms).
  static const int _typingDisplayDurationMs = 12000;

  /// Check if the peer is currently typing in [sessionTag].
  bool isPeerTyping(int sessionTag) {
    final expiresAt = _peerTyping[sessionTag];
    if (expiresAt == null) return false;
    if (_clock() >= expiresAt) {
      _peerTyping.remove(sessionTag);
      return false;
    }
    return true;
  }

  /// Build a DM_TYPING frame for the given session.
  ///
  /// Returns the encoded bytes ready to transmit, or null if rate-limited
  /// or budget exhausted. Typing indicators are best-effort — failures are
  /// silently swallowed.
  Uint8List? buildTypingIndicator({required int sessionTag}) {
    final session = _sessions[sessionTag];
    if (session == null || session.isExpired(_clock())) return null;
    if (session.status != SipDmSessionStatus.active) return null;

    // Rate limit: max one per _typingSendIntervalMs.
    final lastSent = _typingSentAt[sessionTag] ?? 0;
    if (_clock() - lastSent < _typingSendIntervalMs) return null;

    // Check budget (22 bytes for header-only frame).
    const frameSize = SipConstants.sipWrapperMin;
    if (!_rateLimiter.canSend(frameSize)) return null;

    _rateLimiter.recordSend(frameSize);
    _typingSentAt[sessionTag] = _clock();

    final frame = SipFrame(
      versionMajor: SipConstants.sipVersionMajor,
      versionMinor: SipConstants.sipVersionMinor,
      msgType: SipMessageType.dmTyping,
      flags: 0,
      headerLen: SipConstants.sipWrapperMin,
      sessionId: sessionTag,
      nonce: SipCodec.generateNonce(),
      timestampS: _clock() ~/ 1000,
      payloadLen: 0,
      payload: Uint8List(0),
    );

    final encoded = SipCodec.encode(frame);
    if (encoded == null) return null;

    AppLogging.sip(
      'SIP_DM: -> TYPING to '
      'session=0x${sessionTag.toRadixString(16)}',
    );

    return encoded;
  }

  /// Handle an inbound DM_TYPING frame.
  void handleInboundTyping(SipFrame frame) {
    if (frame.msgType != SipMessageType.dmTyping) return;

    final sessionTag = frame.sessionId;
    final session = _sessions[sessionTag];
    if (session == null) return;
    if (session.isExpired(_clock())) {
      _expireSession(sessionTag);
      return;
    }
    if (session.status != SipDmSessionStatus.active) return;

    _peerTyping[sessionTag] = _clock() + _typingDisplayDurationMs;

    AppLogging.sip(
      'SIP_DM: <- TYPING from '
      'session=0x${sessionTag.toRadixString(16)}',
    );

    onTypingReceived?.call(sessionTag);
  }

  /// Clear typing indicator for a session (e.g. when a real message arrives).
  void _clearPeerTyping(int sessionTag) {
    _peerTyping.remove(sessionTag);
  }

  // ---------------------------------------------------------------------------
  // Reactions
  // ---------------------------------------------------------------------------

  /// Build a DM_REACTION frame for the given session and message.
  ///
  /// [emojiIndex] is the index into [SipDmReactionEmojis.all] (0–6).
  /// [targetEntry] is the message being reacted to.
  ///
  /// Returns the encoded bytes ready to transmit, or null if budget
  /// exhausted or session invalid.
  Uint8List? buildDmReaction({
    required int sessionTag,
    required int emojiIndex,
    required SipDmHistoryEntry targetEntry,
  }) {
    final session = _sessions[sessionTag];
    if (session == null || session.isExpired(_clock())) return null;
    if (session.status != SipDmSessionStatus.active) return null;

    final payload = SipDmMessages.encodeReaction(
      emojiIndex: emojiIndex,
      targetTimestampS: targetEntry.timestampMs ~/ 1000,
    );
    if (payload == null) return null;

    // Check budget (22-byte header + 5-byte payload = 27 bytes).
    final frameSize = SipConstants.sipWrapperMin + payload.length;
    if (!_rateLimiter.canSend(frameSize)) return null;

    _rateLimiter.recordSend(frameSize);

    // Store local reaction on the entry.
    targetEntry.localReaction = emojiIndex;

    final frame = SipFrame(
      versionMajor: SipConstants.sipVersionMajor,
      versionMinor: SipConstants.sipVersionMinor,
      msgType: SipMessageType.dmReaction,
      flags: 0,
      headerLen: SipConstants.sipWrapperMin,
      sessionId: sessionTag,
      nonce: SipCodec.generateNonce(),
      timestampS: _clock() ~/ 1000,
      payloadLen: payload.length,
      payload: payload,
    );

    final encoded = SipCodec.encode(frame);
    if (encoded == null) return null;

    AppLogging.sip(
      'SIP_DM: -> REACTION ${SipDmReactionEmojis.all[emojiIndex]} to '
      'session=0x${sessionTag.toRadixString(16)}',
    );

    onStateChanged?.call();
    return encoded;
  }

  /// Handle an inbound DM_REACTION frame.
  void handleInboundReaction(SipFrame frame) {
    if (frame.msgType != SipMessageType.dmReaction) return;

    final sessionTag = frame.sessionId;
    final session = _sessions[sessionTag];
    if (session == null) return;
    if (session.isExpired(_clock())) {
      _expireSession(sessionTag);
      return;
    }
    if (session.status != SipDmSessionStatus.active) return;

    final reaction = SipDmMessages.decodeReaction(frame.payload);
    if (reaction == null) return;

    // Find the target message by timestamp (seconds precision).
    for (final entry in session.messages) {
      if (entry.timestampMs ~/ 1000 == reaction.targetTimestampS) {
        entry.peerReaction = reaction.emojiIndex;
        break;
      }
    }

    AppLogging.sip(
      'SIP_DM: <- REACTION ${reaction.emoji} from '
      'session=0x${sessionTag.toRadixString(16)}',
    );

    onStateChanged?.call();
  }

  /// Remove a message from a session's history (local delete only).
  bool removeMessage(int sessionTag, SipDmHistoryEntry entry) {
    final session = _sessions[sessionTag];
    if (session == null) return false;
    return session.messages.remove(entry);
  }

  // ---------------------------------------------------------------------------
  // Delete (remote)
  // ---------------------------------------------------------------------------

  /// Build a DM_DELETE frame for the given session and message.
  ///
  /// Removes the message locally and returns the encoded bytes to
  /// transmit so the peer also removes it. Returns null if the session
  /// is invalid or budget exhausted.
  Uint8List? buildDmDelete({
    required int sessionTag,
    required SipDmHistoryEntry targetEntry,
  }) {
    final session = _sessions[sessionTag];
    if (session == null || session.isExpired(_clock())) return null;
    if (session.status != SipDmSessionStatus.active) return null;

    final payload = SipDmMessages.encodeDelete(
      targetTimestampS: targetEntry.timestampMs ~/ 1000,
    );

    // Check budget (22-byte header + 4-byte payload = 26 bytes).
    final frameSize = SipConstants.sipWrapperMin + payload.length;
    if (!_rateLimiter.canSend(frameSize)) return null;

    _rateLimiter.recordSend(frameSize);

    // Remove locally.
    session.messages.remove(targetEntry);

    final frame = SipFrame(
      versionMajor: SipConstants.sipVersionMajor,
      versionMinor: SipConstants.sipVersionMinor,
      msgType: SipMessageType.dmDelete,
      flags: 0,
      headerLen: SipConstants.sipWrapperMin,
      sessionId: sessionTag,
      nonce: SipCodec.generateNonce(),
      timestampS: _clock() ~/ 1000,
      payloadLen: payload.length,
      payload: payload,
    );

    final encoded = SipCodec.encode(frame);
    if (encoded == null) return null;

    AppLogging.sip(
      'SIP_DM: -> DELETE message at '
      'ts=${targetEntry.timestampMs ~/ 1000}s in '
      'session=0x${sessionTag.toRadixString(16)}',
    );

    onStateChanged?.call();
    return encoded;
  }

  /// Handle an inbound DM_DELETE frame.
  void handleInboundDelete(SipFrame frame) {
    if (frame.msgType != SipMessageType.dmDelete) return;

    final sessionTag = frame.sessionId;
    final session = _sessions[sessionTag];
    if (session == null) return;
    if (session.isExpired(_clock())) {
      _expireSession(sessionTag);
      return;
    }
    if (session.status != SipDmSessionStatus.active) return;

    final targetTimestampS = SipDmMessages.decodeDelete(frame.payload);
    if (targetTimestampS == null) return;

    // Find and remove the target message by timestamp (seconds precision).
    session.messages.removeWhere(
      (entry) => entry.timestampMs ~/ 1000 == targetTimestampS,
    );

    AppLogging.sip(
      'SIP_DM: <- DELETE message at ts=${targetTimestampS}s from '
      'session=0x${sessionTag.toRadixString(16)}',
    );

    onStateChanged?.call();
  }

  // ---------------------------------------------------------------------------
  // Message sending
  // ---------------------------------------------------------------------------

  /// Build a DM_MSG frame for the given session.
  ///
  /// Returns a [SipDmSendResult] with either the frame or an error.
  /// The message is also added to the session's history on success.
  SipDmSendResult buildDmMessage({
    required int sessionTag,
    required String text,
  }) {
    final session = _sessions[sessionTag];
    if (session == null || session.isExpired(_clock())) {
      if (session != null) _expireSession(sessionTag);
      return SipDmSendResult.fail(SipDmSendError.sessionNotFound);
    }

    if (session.status != SipDmSessionStatus.active) {
      return SipDmSendResult.fail(SipDmSendError.sessionClosed);
    }

    if (text.isEmpty) {
      return SipDmSendResult.fail(SipDmSendError.emptyText);
    }

    final payload = SipDmMessages.encodeDm(text);
    if (payload == null) {
      // Text exceeds max length after UTF-8 encoding.
      return SipDmSendResult.fail(SipDmSendError.textTooLong);
    }

    // Check airtime budget.
    final frameSize = SipConstants.sipWrapperMin + payload.length;
    if (!_rateLimiter.canSend(frameSize)) {
      AppLogging.sip(
        'SIP_DM: send blocked by budget for '
        'tag=0x${sessionTag.toRadixString(16)}',
      );
      _counters?.recordBudgetThrottle();
      return SipDmSendResult.fail(SipDmSendError.budgetExhausted);
    }

    // Deduct budget.
    _rateLimiter.recordSend(frameSize);

    // Use a single timestamp for both the frame and history entry
    // so reactions/deletes can cross-reference by seconds precision.
    final nowS = _clock() ~/ 1000;

    final frame = SipFrame(
      versionMajor: SipConstants.sipVersionMajor,
      versionMinor: SipConstants.sipVersionMinor,
      msgType: SipMessageType.dmMsg,
      flags: 0,
      headerLen: SipConstants.sipWrapperMin,
      sessionId: sessionTag,
      nonce: SipCodec.generateNonce(),
      timestampS: nowS,
      payloadLen: payload.length,
      payload: payload,
    );

    // Add to history using frame timestamp (ms = seconds * 1000).
    session.messages.add(
      SipDmHistoryEntry(
        text: text,
        timestampMs: nowS * 1000,
        direction: SipDmDirection.outbound,
        replyToText: _parseReplyToText(text),
      ),
    );

    AppLogging.sip(
      'SIP_DM: -> DM ${payload.length}B to '
      'session=0x${sessionTag.toRadixString(16)}',
    );

    return SipDmSendResult.ok(frame);
  }

  // ---------------------------------------------------------------------------
  // Message receiving
  // ---------------------------------------------------------------------------

  /// Handle an inbound DM_MSG frame.
  ///
  /// Returns the parsed [SipDmMessage] if the session_tag matches
  /// an active session, or null if dropped.
  SipDmMessage? handleInboundDm(SipFrame frame) {
    if (frame.msgType != SipMessageType.dmMsg) {
      AppLogging.sip('SIP_DM: handleInboundDm called with wrong msg_type');
      return null;
    }

    final sessionTag = frame.sessionId;
    final session = _sessions[sessionTag];

    if (session == null) {
      AppLogging.sip(
        'SIP_DM: inbound DM dropped: unknown '
        'session=0x${sessionTag.toRadixString(16)}',
      );
      return null;
    }

    if (session.isExpired(_clock())) {
      _expireSession(sessionTag);
      AppLogging.sip(
        'SIP_DM: inbound DM dropped: expired '
        'session=0x${sessionTag.toRadixString(16)}',
      );
      return null;
    }

    if (session.status != SipDmSessionStatus.active) {
      AppLogging.sip(
        'SIP_DM: inbound DM dropped: closed '
        'session=0x${sessionTag.toRadixString(16)}',
      );
      return null;
    }

    final message = SipDmMessages.decodeDm(frame.payload);
    if (message == null) return null;

    // Add to history using the frame's timestamp so both sides agree
    // on the message's identity (enables cross-device reactions/deletes).
    session.messages.add(
      SipDmHistoryEntry(
        text: message.text,
        timestampMs: frame.timestampS * 1000,
        direction: SipDmDirection.inbound,
        replyToText: _parseReplyToText(message.text),
      ),
    );

    // Clear typing indicator since we got a real message.
    _clearPeerTyping(sessionTag);

    AppLogging.sip(
      'SIP_DM: <- DM ${frame.payload.length}B from '
      'session=0x${sessionTag.toRadixString(16)}',
    );

    onStateChanged?.call();

    return message;
  }

  // ---------------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------------

  /// Remove all expired sessions.
  int cleanExpired() => _cleanExpired();

  /// Reset all state (disconnect/reconnect scenario).
  void reset() {
    _sessions.clear();
    _peerTyping.clear();
    _typingSentAt.clear();
    AppLogging.sip('SIP_DM: all sessions cleared');
  }

  /// Number of currently tracked sessions (including expired not yet cleaned).
  int get sessionCount => _sessions.length;

  /// Get message history for a session.
  List<SipDmHistoryEntry>? getHistory(int sessionTag) {
    final session = _sessions[sessionTag];
    if (session == null) return null;
    return List.unmodifiable(session.messages);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  int _cleanExpired() {
    final nowMs = _clock();
    final expired = <int>[];
    for (final entry in _sessions.entries) {
      if (entry.value.isExpired(nowMs)) {
        expired.add(entry.key);
      }
    }
    for (final tag in expired) {
      _expireSession(tag);
    }
    return expired.length;
  }

  void _expireSession(int sessionTag) {
    final session = _sessions[sessionTag];
    if (session != null && session.status == SipDmSessionStatus.active) {
      session.status = SipDmSessionStatus.expired;
      AppLogging.sip(
        'SIP_DM: session 0x${sessionTag.toRadixString(16)} expired '
        'after ${session.ttlS}s, cleaned up',
      );
    }
    _sessions.remove(sessionTag);
    _peerTyping.remove(sessionTag);
    _typingSentAt.remove(sessionTag);
  }

  // ---------------------------------------------------------------------------
  // Quote-reply parsing
  // ---------------------------------------------------------------------------

  /// Quote prefix used to encode reply-to-message text.
  ///
  /// A message like `> Hello\nGoodbye` means the user replied "Goodbye"
  /// to the original message "Hello".
  static const String _quotePrefix = '> ';

  /// Parse the reply-to text from a message, if present.
  ///
  /// Returns the quoted text (without prefix) if the message starts with
  /// `> quoted\n`, or null if no quote is present.
  static String? _parseReplyToText(String text) {
    if (!text.startsWith(_quotePrefix)) return null;
    final newlineIdx = text.indexOf('\n');
    if (newlineIdx < 0) return null;
    final quoted = text.substring(_quotePrefix.length, newlineIdx);
    return quoted.isEmpty ? null : quoted;
  }

  /// Extract the actual message text (without the quote prefix).
  ///
  /// If the message starts with `> quoted\n`, returns everything after
  /// the first newline. Otherwise returns the full text.
  static String extractReplyBody(String text) {
    if (!text.startsWith(_quotePrefix)) return text;
    final newlineIdx = text.indexOf('\n');
    if (newlineIdx < 0) return text;
    return text.substring(newlineIdx + 1);
  }

  /// Format a reply message with quote prefix.
  ///
  /// Encodes the reply as `> quotedText\nreplyText`.
  static String formatReplyMessage({
    required String quotedText,
    required String replyText,
  }) {
    // Truncate quoted text to keep within byte budget.
    // Use first 40 chars max to leave room for the reply.
    final truncated = quotedText.length > 40
        ? '${quotedText.substring(0, 37)}...'
        : quotedText;
    return '$_quotePrefix$truncated\n$replyText';
  }
}
