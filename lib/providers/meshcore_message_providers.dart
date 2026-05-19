// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCore message provider with real-time message handling.
//
// This provider:
// - Listens to incoming messages from MeshCore session
// - Persists messages to storage
// - Tracks unread counts
// - Provides the conversation list

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging.dart';
import '../core/meshcore_constants.dart';
import '../features/automations/automation_engine.dart';
import '../features/automations/automation_providers.dart';
import '../features/automations/models/automation.dart';
import '../features/meshcore/parsers/meshcore_message_frame_parser.dart';
import '../models/mesh_models.dart' as mesh;
import '../models/meshcore_contact.dart';
import '../services/meshcore/protocol/meshcore_chat_meta_envelope.dart';
import '../services/meshcore/protocol/meshcore_frame.dart';
import '../services/meshcore/protocol/meshcore_messages.dart' as msgs;
import '../services/meshcore/protocol/meshcore_session.dart';
import '../services/meshcore/storage/meshcore_message_store.dart';
import '../services/meshcore/storage/meshcore_contact_store.dart';
import '../services/notifications/notification_service.dart';
import 'app_lifecycle_provider.dart';
import 'app_providers.dart';
import 'meshcore_contact_block_provider.dart';
import 'meshcore_providers.dart';

// ---------------------------------------------------------------------------
// Message Models
// ---------------------------------------------------------------------------

/// A conversation (contact or channel) with message state.
class MeshCoreConversation {
  /// Conversation identifier (pubKeyHex for contacts, "channel_N" for channels).
  final String id;

  /// Display name.
  final String name;

  /// Whether this is a channel (vs contact).
  final bool isChannel;

  /// Channel index if this is a channel.
  final int? channelIndex;

  /// Contact if this is a contact conversation.
  final MeshCoreContact? contact;

  /// Last message text (preview).
  final String? lastMessageText;

  /// Last message timestamp.
  final DateTime? lastMessageTime;

  /// Unread message count.
  final int unreadCount;

  const MeshCoreConversation({
    required this.id,
    required this.name,
    required this.isChannel,
    this.channelIndex,
    this.contact,
    this.lastMessageText,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  MeshCoreConversation copyWith({
    String? lastMessageText,
    DateTime? lastMessageTime,
    int? unreadCount,
  }) {
    return MeshCoreConversation(
      id: id,
      name: name,
      isChannel: isChannel,
      channelIndex: channelIndex,
      contact: contact,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

/// Resolve the full-pubKey conversation id for an inbound frame's
/// 6-byte sender prefix (12 lowercase hex chars from
/// [MeshCoreContactMessageFrame.senderPrefixHex]). Returns the matching
/// conversation's id (full hex pubkey) when a known contact has been
/// discovered, or `null` when no contact in [conversations] starts with
/// the prefix. Channel conversations are ignored.
///
/// Visible for testing so the prefix-to-conversation routing rule is
/// regression-pinned independently of the Riverpod state machinery.
@visibleForTesting
String? meshCoreConversationIdForSenderPrefix(
  Iterable<MeshCoreConversation> conversations,
  String senderPrefixHex,
) {
  if (senderPrefixHex.length != 12) return null;
  final needle = senderPrefixHex.toLowerCase();
  for (final c in conversations) {
    if (c.isChannel) continue;
    if (c.id.toLowerCase().startsWith(needle)) return c.id;
  }
  return null;
}

/// 32-bit FNV-1a hash of a UTF-8 string, returned as 8 lowercase hex
/// chars. Fast, stable, no crypto dependency. Used by D19's
/// deterministic message-id scheme so the same inbound frame always
/// produces the same id and `MeshCoreMessageStore.add*Message`'s
/// indexWhere-by-id dedupe behaviour acts as a duplicate guard for
/// free.
///
/// Public so the chat widget can derive identical ids for in-memory
/// bubbles and have them merge cleanly with the persisted entry on
/// next chat reload. Not cryptographic; do not use for security
/// boundaries.
String meshCoreFnv1a32Hex(String input) {
  const prime = 0x01000193;
  const offset = 0x811c9dc5;
  var hash = offset;
  for (final byte in utf8.encode(input)) {
    hash = (hash ^ byte) & 0xffffffff;
    hash = (hash * prime) & 0xffffffff;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

/// Deterministic id for an inbound channel message. Same channel,
/// same firmware-supplied timestamp, same text => same id => the
/// store's add-then-update-by-id path collapses retries / re-flooded
/// duplicates into a single entry.
String meshCoreInboundChannelMessageId({
  required int channelIndex,
  required DateTime timestamp,
  required String text,
}) {
  final tsKey = timestamp.millisecondsSinceEpoch ~/ 1000;
  return 'mc_in_ch_${channelIndex}_${tsKey}_${meshCoreFnv1a32Hex(text)}';
}

/// Deterministic id for an inbound contact message. Same sender prefix,
/// same firmware-supplied timestamp, same text => same id.
String meshCoreInboundContactMessageId({
  required String senderPrefixHex,
  required DateTime timestamp,
  required String text,
}) {
  final tsKey = timestamp.millisecondsSinceEpoch ~/ 1000;
  return 'mc_in_ct_${senderPrefixHex.toLowerCase()}_${tsKey}_'
      '${meshCoreFnv1a32Hex(text)}';
}

/// A message in a MeshCore conversation.
class MeshCoreMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isOutgoing;
  final MeshCoreMessageDeliveryStatus status;
  final Uint8List? senderKey;
  final String? senderName;
  final int? pathLength;

  /// Signed link SNR encoded by the firmware in quarter-dB units.
  /// Convert with `snrQuarter / 4.0` for dB. Only meaningful for
  /// inbound messages; outbound is always null.
  final int? snrQuarter;

  /// D33: cross-device MeshCore Message Fingerprint (MMF) for THIS
  /// message — `01:<idx>:<ts>` for channel, `02:<peerPrefix>:<ts>`
  /// for contact. Set on send (outbound) and receive (inbound) so
  /// both ends derive the same id for the same logical message.
  /// Null on records pre-dating D33 OR records that lack enough
  /// stable fields to derive an MMF safely.
  final String? mmf;

  /// D33: MMF of the message THIS message replies to. Null when
  /// this message is not a reply.
  final String? replyToMmf;

  const MeshCoreMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isOutgoing,
    this.status = MeshCoreMessageDeliveryStatus.pending,
    this.senderKey,
    this.senderName,
    this.pathLength,
    this.snrQuarter,
    this.mmf,
    this.replyToMmf,
  });

  MeshCoreMessage copyWith({
    MeshCoreMessageDeliveryStatus? status,
    String? mmf,
    String? replyToMmf,
  }) {
    return MeshCoreMessage(
      id: id,
      text: text,
      timestamp: timestamp,
      isOutgoing: isOutgoing,
      status: status ?? this.status,
      senderKey: senderKey,
      senderName: senderName,
      pathLength: pathLength,
      snrQuarter: snrQuarter,
      mmf: mmf ?? this.mmf,
      replyToMmf: replyToMmf ?? this.replyToMmf,
    );
  }
}

/// Message delivery status.
enum MeshCoreMessageDeliveryStatus { pending, sent, delivered, failed }

// ---------------------------------------------------------------------------
// D22 — Drain coordination (heartbeat + manual + auto-tickle non-overlap)
// ---------------------------------------------------------------------------

/// Origin of an in-flight `CMD_SYNC_NEXT_MESSAGE` drain. Used by the
/// non-overlap guard so a heartbeat tick cannot collide with a `0x83`
/// auto-drain or a Tools-tile manual drain (and vice versa).
///
/// Public so tests can pin the skip-reason logged on overlap.
enum MeshCoreDrainSource { tickle, manual, heartbeat }

/// Classified outcome of a single drain attempt. Pinned shape so the
/// Tools tile snackbar and the heartbeat iteration loop can both
/// branch on the same enum without duplicating frame-code knowledge.
enum MeshCoreDrainOutcomeKind { message, noMore, timeout, skipped, failed }

/// Result of one [MeshCoreConversationsNotifier.drainOnce] call.
class MeshCoreDrainOutcome {
  final MeshCoreDrainOutcomeKind kind;

  /// Frame command code on `kind == message` or `kind == noMore`.
  final int? code;

  /// Frame payload size on `kind == message`.
  final int? size;

  /// Skip reason on `kind == skipped` (e.g. `already_draining_<source>`).
  final String? skipReason;

  /// Failure reason runtime-type name on `kind == failed`.
  final String? failureReason;

  const MeshCoreDrainOutcome._(
    this.kind, {
    this.code,
    this.size,
    this.skipReason,
    this.failureReason,
  });

  factory MeshCoreDrainOutcome.message(int code, int size) =>
      MeshCoreDrainOutcome._(
        MeshCoreDrainOutcomeKind.message,
        code: code,
        size: size,
      );

  factory MeshCoreDrainOutcome.noMore(int code) =>
      MeshCoreDrainOutcome._(MeshCoreDrainOutcomeKind.noMore, code: code);

  factory MeshCoreDrainOutcome.timeout() =>
      const MeshCoreDrainOutcome._(MeshCoreDrainOutcomeKind.timeout);

  factory MeshCoreDrainOutcome.skipped(String reason) => MeshCoreDrainOutcome._(
    MeshCoreDrainOutcomeKind.skipped,
    skipReason: reason,
  );

  factory MeshCoreDrainOutcome.failed(String reason) => MeshCoreDrainOutcome._(
    MeshCoreDrainOutcomeKind.failed,
    failureReason: reason,
  );
}

// ---------------------------------------------------------------------------
// Conversation List Provider
// ---------------------------------------------------------------------------

/// State for the conversation list.
class MeshCoreConversationsState {
  final List<MeshCoreConversation> conversations;
  final bool isLoading;
  final String? error;

  /// D28: source of the in-flight drain (null = idle). Pinned for the
  /// Tools queue-status card so the user can see whether a drain is
  /// currently running and what triggered it.
  final MeshCoreDrainSource? activeDrainSource;

  /// D28: last completed drain's source (null = no drain has run yet).
  final MeshCoreDrainSource? lastDrainSource;

  /// D28: last completed drain's outcome.
  final MeshCoreDrainOutcomeKind? lastDrainOutcome;

  /// D28: timestamp when the last drain completed.
  final DateTime? lastDrainAt;

  /// D28: whether the drain heartbeat timer is currently armed.
  final bool heartbeatActive;

  const MeshCoreConversationsState({
    this.conversations = const [],
    this.isLoading = false,
    this.error,
    this.activeDrainSource,
    this.lastDrainSource,
    this.lastDrainOutcome,
    this.lastDrainAt,
    this.heartbeatActive = false,
  });

  const MeshCoreConversationsState.initial()
    : conversations = const [],
      isLoading = false,
      error = null,
      activeDrainSource = null,
      lastDrainSource = null,
      lastDrainOutcome = null,
      lastDrainAt = null,
      heartbeatActive = false;

  MeshCoreConversationsState copyWith({
    List<MeshCoreConversation>? conversations,
    bool? isLoading,
    String? error,
    MeshCoreDrainSource? activeDrainSource,
    bool clearActiveDrainSource = false,
    MeshCoreDrainSource? lastDrainSource,
    MeshCoreDrainOutcomeKind? lastDrainOutcome,
    DateTime? lastDrainAt,
    bool? heartbeatActive,
  }) {
    return MeshCoreConversationsState(
      conversations: conversations ?? this.conversations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      activeDrainSource: clearActiveDrainSource
          ? null
          : (activeDrainSource ?? this.activeDrainSource),
      lastDrainSource: lastDrainSource ?? this.lastDrainSource,
      lastDrainOutcome: lastDrainOutcome ?? this.lastDrainOutcome,
      lastDrainAt: lastDrainAt ?? this.lastDrainAt,
      heartbeatActive: heartbeatActive ?? this.heartbeatActive,
    );
  }

  /// Total unread count across all conversations.
  int get totalUnreadCount =>
      conversations.fold(0, (sum, c) => sum + c.unreadCount);
}

/// Notifier for MeshCore conversations.
/// D33: parse a hex string into raw bytes. Tolerates upper/lower-case
/// and strips a single leading `0x` prefix. Returns an empty list if
/// any character isn't hex or the length is odd; callers treat that
/// as "no MMF derivable".
List<int> _hexToBytes(String hex) {
  final clean = hex.startsWith('0x') ? hex.substring(2) : hex;
  if (clean.length.isOdd) return const [];
  final out = <int>[];
  for (var i = 0; i < clean.length; i += 2) {
    final byte = int.tryParse(clean.substring(i, i + 2), radix: 16);
    if (byte == null) return const [];
    out.add(byte);
  }
  return out;
}

class MeshCoreConversationsNotifier
    extends Notifier<MeshCoreConversationsState> {
  StreamSubscription<MeshCoreFrame>? _frameSubscription;
  final MeshCoreMessageStore _messageStore = MeshCoreMessageStore();
  final MeshCoreContactStore _contactStore = MeshCoreContactStore();

  // D22.A: missed-tickle recovery drain heartbeat. Periodically fires
  // `CMD_SYNC_NEXT_MESSAGE` while connected so messages already in the
  // firmware queue (whose 0x83 tickle was missed) get pulled. The
  // timer is owned here because this notifier already owns inbound
  // frame routing, persistence, and the existing 0x83 auto-drain — so
  // the heartbeat naturally shares the same parser/persistence path.
  Timer? _heartbeatTimer;
  MeshCoreSession? _heartbeatSession;

  // D22 non-overlap guard. Set by [drainOnce] before sending the sync
  // command, cleared in `finally`. Tickle / manual / heartbeat all
  // consult and update this single field so two concurrent drains
  // can't interleave waiters on the broadcast frame stream.
  MeshCoreDrainSource? _activeDrain;

  // Flipped to true in `ref.onDispose` so async work (deferred
  // `_loadConversations`, in-flight drains) can bail out instead of
  // writing to `state` after the notifier is gone.
  bool _disposed = false;

  /// Test override for the heartbeat interval. Production code uses
  /// [kMeshCoreDrainHeartbeatSeconds]; tests can shorten this so the
  /// heartbeat fires deterministically without `pumpAndSettle` for
  /// 60 s. Reset via [debugResetHeartbeatInterval] in tearDown.
  @visibleForTesting
  static Duration debugHeartbeatInterval = const Duration(
    seconds: kMeshCoreDrainHeartbeatSeconds,
  );

  /// Reset the heartbeat interval to the production default. Always
  /// call from `tearDown` after using [debugHeartbeatInterval] so a
  /// short interval doesn't bleed into unrelated tests.
  @visibleForTesting
  static void debugResetHeartbeatInterval() {
    debugHeartbeatInterval = const Duration(
      seconds: kMeshCoreDrainHeartbeatSeconds,
    );
  }

  @override
  MeshCoreConversationsState build() {
    // Subscribe to incoming messages when session is available, and
    // start the missed-tickle heartbeat. Both lifecycles are bound to
    // the active session: when the session disappears or the notifier
    // is disposed, both are torn down.
    final session = ref.watch(meshCoreSessionProvider);
    if (session != null && session.isActive) {
      _subscribeToMessages(session);
      _startHeartbeat(session);
    } else {
      // Session went away (disconnect / device swap). Tear down so a
      // future reconnect re-arms cleanly via the next `build()`.
      _stopHeartbeat('session_unavailable');
    }

    // D22.B: app foreground transitions. When the app comes back to
    // the foreground we fire one extra drain so messages that arrived
    // while we were paused are pulled immediately, without waiting
    // for the next periodic tick. Skips silently when not connected
    // or when another drain is already in flight.
    ref.listen<bool>(appLifecycleProvider, (prev, isForeground) {
      if (prev == isForeground) return;
      if (!isForeground) return;
      final s = ref.read(meshCoreSessionProvider);
      if (s == null || !s.isActive) return;
      AppLogging.meshcore('event=msg_waiting.drain.foreground.requested');
      // Kick off via microtask so the listener returns synchronously.
      Future.microtask(() => _runHeartbeatDrain(reason: 'foreground'));
    });

    // Load initial conversations. Deferred via `Future(() => ...)`
    // so the first `state = state.copyWith(isLoading: true)` write
    // inside `_loadConversations` runs on a separate event-loop
    // turn, after `build()` has returned and the notifier's initial
    // state has been committed by Riverpod. Pre-D22 this was a
    // direct call which threw `Tried to read the state of an
    // uninitialized provider` whenever the notifier was instantiated
    // in a unit test (production happened to mask it because the
    // first call site never asserted on state during build).
    Future<void>(_loadConversations);

    ref.onDispose(() {
      _disposed = true;
      _frameSubscription?.cancel();
      _stopHeartbeat('disposed');
    });

    return const MeshCoreConversationsState.initial();
  }

  void _subscribeToMessages(MeshCoreSession session) {
    _frameSubscription?.cancel();
    _frameSubscription = session.frameStream.listen(_handleFrame);
    AppLogging.protocol('MeshCore Conversations: Subscribed to frame stream');
  }

  void _startHeartbeat(MeshCoreSession session) {
    // Idempotent: if we're already running for this exact session, just
    // re-publish the active flag and return. D28: re-publishing is
    // important on a Notifier rebuild (e.g. when session provider
    // cascades from a connection-state emit) — Riverpod replaces the
    // notifier state with build's return value (initial =
    // heartbeatActive=false) on every rebuild, so the publish has to
    // fire to bring the state back in line with the timer.
    if (_heartbeatTimer != null && identical(_heartbeatSession, session)) {
      _publishHeartbeatActive(true);
      return;
    }
    // Different session (reconnect, device swap) — cancel and re-arm.
    _stopHeartbeat('session_changed');
    _heartbeatSession = session;
    final interval = debugHeartbeatInterval;
    _heartbeatTimer = Timer.periodic(interval, (_) => _onHeartbeatTick());
    _publishHeartbeatActive(true);
    AppLogging.meshcore(
      'event=msg_waiting.heartbeat.started '
      'interval_ms=${interval.inMilliseconds}',
    );
  }

  void _stopHeartbeat(String reason) {
    // D28: even on a no-op tear-down (already stopped), re-publish the
    // false flag so a Notifier rebuild that occurred while the
    // heartbeat was idle still shows the right pill. Same reason as
    // `_startHeartbeat`'s re-publish branch.
    if (_heartbeatTimer == null && _heartbeatSession == null) {
      _publishHeartbeatActive(false);
      return;
    }
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatSession = null;
    _publishHeartbeatActive(false);
    AppLogging.meshcore('event=msg_waiting.heartbeat.stopped reason=$reason');
  }

  /// D28: publish heartbeat active/idle to the notifier state.
  ///
  /// Called from both `build()` (where `state` isn't initialised yet)
  /// and post-build flows. Uses a `Future` rather than `Future.microtask`
  /// so it runs on a separate event-loop turn AFTER build's initial
  /// state has been committed by Riverpod, mirroring the same pattern
  /// `_loadConversations` already uses to avoid the
  /// "uninitialized provider" exception.
  void _publishHeartbeatActive(bool active) {
    Future<void>(() {
      if (_disposed) return;
      // Re-check the live timer reference so a fast start/stop pair
      // doesn't overwrite the latest value with the older sentinel.
      final live = _heartbeatTimer != null;
      if (live != active) return;
      state = state.copyWith(heartbeatActive: active);
    });
  }

  void _onHeartbeatTick() {
    // Skip silently when session went stale between ticks.
    final s = ref.read(meshCoreSessionProvider);
    if (s == null || !s.isActive) {
      _stopHeartbeat('session_inactive');
      return;
    }
    Future.microtask(() => _runHeartbeatDrain(reason: 'tick'));
  }

  /// Iterative heartbeat drain. Pulls messages until the firmware
  /// returns `RESP_CODE_NO_MORE_MESSAGES`, a timeout, or a skip. Each
  /// pulled message frame is parsed + persisted by the existing
  /// [_handleFrame] listener; this loop only re-issues sync commands.
  Future<void> _runHeartbeatDrain({required String reason}) async {
    // Cap iterations so a misbehaving firmware can't lock the loop.
    const maxIterations = 16;
    for (var i = 0; i < maxIterations; i++) {
      final outcome = await drainOnce(MeshCoreDrainSource.heartbeat);
      switch (outcome.kind) {
        case MeshCoreDrainOutcomeKind.message:
          AppLogging.meshcore(
            'event=msg_waiting.drain.heartbeat.result result=message '
            'code=0x${outcome.code!.toRadixString(16).padLeft(2, '0')} '
            'size=${outcome.size ?? 0}',
          );
          // Loop and try again — there may be more queued.
          continue;
        case MeshCoreDrainOutcomeKind.noMore:
          AppLogging.meshcore(
            'event=msg_waiting.drain.heartbeat.result result=no_more',
          );
          return;
        case MeshCoreDrainOutcomeKind.timeout:
          AppLogging.meshcore(
            'event=msg_waiting.drain.heartbeat.result result=timeout',
            error: true,
          );
          return;
        case MeshCoreDrainOutcomeKind.skipped:
          AppLogging.meshcore(
            'event=msg_waiting.drain.heartbeat.skipped '
            'reason=${outcome.skipReason}',
          );
          return;
        case MeshCoreDrainOutcomeKind.failed:
          AppLogging.meshcore(
            'event=msg_waiting.drain.heartbeat.failed '
            'reason=${outcome.failureReason}',
            error: true,
          );
          return;
      }
    }
    AppLogging.meshcore(
      'event=msg_waiting.drain.heartbeat.result result=cap '
      'iterations=$maxIterations reason=$reason',
    );
  }

  /// Public manual drain entry — invoked by the Tools tile. Single
  /// shot, classified outcome (message / no_more / timeout / skipped
  /// / failed). The Tools UI maps the outcome to a snackbar.
  Future<MeshCoreDrainOutcome> manualDrain() async {
    return drainOnce(MeshCoreDrainSource.manual);
  }

  /// Test entry point — fire one heartbeat tick synchronously without
  /// waiting for the [Timer.periodic] interval. Same path as the
  /// production timer callback.
  @visibleForTesting
  Future<void> debugFireHeartbeatTick() async {
    final s = ref.read(meshCoreSessionProvider);
    if (s == null || !s.isActive) return;
    await _runHeartbeatDrain(reason: 'debug');
  }

  /// Whether the heartbeat timer is currently armed. Visible for tests
  /// that need to assert start/stop transitions.
  @visibleForTesting
  bool get debugIsHeartbeatActive => _heartbeatTimer?.isActive ?? false;

  /// Currently in-flight drain source, or null when idle. Visible for
  /// tests that need to observe the non-overlap guard transitions.
  @visibleForTesting
  MeshCoreDrainSource? get debugActiveDrain => _activeDrain;

  /// Send one `CMD_SYNC_NEXT_MESSAGE` and classify the response.
  ///
  /// Used by the heartbeat (loops until no_more), the Tools tile
  /// (single shot), and the 0x83 auto-tickle path (fire-and-forget,
  /// but still routed through this method so the non-overlap guard
  /// covers it). The message frame itself is parsed + persisted by
  /// the existing [_handleFrame] listener; this method only
  /// classifies + emits the structured log.
  ///
  /// Non-overlap: if another drain is already in flight, returns
  /// `MeshCoreDrainOutcome.skipped(reason)` immediately without
  /// sending anything.
  Future<MeshCoreDrainOutcome> drainOnce(MeshCoreDrainSource source) async {
    if (_activeDrain != null) {
      final reason = 'already_draining_${_activeDrain!.name}';
      // Source-specific skip log so the field log makes attribution
      // possible without parsing the wider event stream.
      AppLogging.meshcore(
        'event=msg_waiting.drain.${source.name}.skipped reason=$reason',
      );
      return MeshCoreDrainOutcome.skipped(reason);
    }

    final session = ref.read(meshCoreSessionProvider);
    if (session == null || !session.isActive) {
      AppLogging.meshcore(
        'event=msg_waiting.drain.${source.name}.failed '
        'reason=no_active_session',
        error: true,
      );
      return MeshCoreDrainOutcome.failed('no_active_session');
    }

    _activeDrain = source;
    if (!_disposed) state = state.copyWith(activeDrainSource: source);
    final classified = Completer<MeshCoreDrainOutcome>();
    StreamSubscription<MeshCoreFrame>? sub;
    MeshCoreDrainOutcome outcome;
    try {
      sub = session.frameStream.listen((frame) {
        final code = frame.command;
        if (code == MeshCoreResponses.noMoreMessages) {
          if (!classified.isCompleted) {
            classified.complete(MeshCoreDrainOutcome.noMore(code));
          }
        } else if (code == MeshCoreResponses.contactMsgRecv ||
            code == MeshCoreResponses.contactMsgRecvV3 ||
            code == MeshCoreResponses.channelMsgRecv ||
            code == MeshCoreResponses.channelMsgRecvV3) {
          if (!classified.isCompleted) {
            classified.complete(
              MeshCoreDrainOutcome.message(code, frame.payload.length),
            );
          }
        }
      });

      // Source-specific request log so the field log can attribute
      // each `result=` line to its origin.
      AppLogging.meshcore('event=msg_waiting.drain.${source.name}.requested');
      await session.sendCommand(MeshCoreCommands.syncNextMessage);
      outcome = await classified.future.timeout(
        const Duration(seconds: 3),
        onTimeout: MeshCoreDrainOutcome.timeout,
      );
    } catch (e) {
      AppLogging.meshcore(
        'event=msg_waiting.drain.${source.name}.failed '
        'reason=${e.runtimeType}',
        error: true,
      );
      outcome = MeshCoreDrainOutcome.failed(e.runtimeType.toString());
    } finally {
      await sub?.cancel();
      _activeDrain = null;
    }
    // D28: publish post-drain status outside the try/finally so the
    // outcome is the same value the caller observes. Do not write
    // state inside finally or we risk reading `outcome` before it
    // was assigned on the catch path.
    if (!_disposed) {
      state = state.copyWith(
        clearActiveDrainSource: true,
        lastDrainSource: source,
        lastDrainAt: DateTime.now(),
        lastDrainOutcome: outcome.kind,
      );
    }
    return outcome;
  }

  void _handleFrame(MeshCoreFrame frame) {
    // D17.A: provider routes inbound frames to the canonical D12
    // parser, removing the pre-D12 broken hand-parser that silently
    // dropped V3 frames at `<37`/`<38` length guards and assumed a
    // fictional 32-byte sender pubkey layout that firmware never
    // sends. The chat screen and the conversations provider now
    // agree on frame layout because they share the same parser.
    if (frame.command == MeshCoreResponses.contactMsgRecv ||
        frame.command == MeshCoreResponses.contactMsgRecvV3) {
      _handleIncomingContactMessage(frame);
    } else if (frame.command == MeshCoreResponses.channelMsgRecv ||
        frame.command == MeshCoreResponses.channelMsgRecvV3) {
      _handleIncomingChannelMessage(frame);
    } else if (frame.command == MeshCorePushCodes.sendConfirmed) {
      _handleSendConfirmed(frame);
    } else if (frame.command == MeshCorePushCodes.msgWaiting) {
      // D18: this was the load-bearing missing handler. Firmware
      // does NOT push received message frames to the companion
      // automatically. It writes them to an offline queue and emits
      // a one-byte `PUSH_CODE_MSG_WAITING` (0x83) tickle. The app
      // must respond with `CMD_SYNC_NEXT_MESSAGE` to drain the queue.
      // Without this handler every inbound message stayed on the
      // firmware screen but never surfaced to the app, regardless
      // of D12/D17.A parser correctness or RF settings.
      _handleMsgWaiting(frame);
    } else if (frame.command == MeshCorePushCodes.advert ||
        frame.command == MeshCorePushCodes.newAdvert) {
      // D17.C: peer name propagation. Firmware emits 0x80 / 0x8A
      // when an existing or new contact's advert is heard. Without
      // an app-side handler these were silently ignored, leaving
      // contact list names stale until the user manually tapped
      // "Refresh Contacts". Refetching is the simplest correct fix
      // (works for both push variants); a more targeted update via
      // `CMD_GET_CONTACT_BY_KEY` would also work but is deferred.
      _handleAdvertPush(frame);
    }
  }

  void _handleMsgWaiting(MeshCoreFrame frame) {
    // Send CMD_SYNC_NEXT_MESSAGE (0x0A) via the shared drain helper.
    // Firmware emits one tickle per arrival, so per-tickle this is a
    // single drain (no iterative loop here). The shared helper also
    // routes through the D22 non-overlap guard so a tickle that
    // races with the heartbeat or a manual tap is logged as skipped
    // rather than firing a second concurrent waiter.
    AppLogging.meshcore(
      'event=msg_waiting.observed code=0x83 size=${frame.payload.length}',
    );
    Future.microtask(() async {
      final outcome = await drainOnce(MeshCoreDrainSource.tickle);
      switch (outcome.kind) {
        case MeshCoreDrainOutcomeKind.message:
          AppLogging.meshcore(
            'event=msg_waiting.drain.tickle.result result=message '
            'code=0x${outcome.code!.toRadixString(16).padLeft(2, '0')} '
            'size=${outcome.size ?? 0}',
          );
          break;
        case MeshCoreDrainOutcomeKind.noMore:
          AppLogging.meshcore(
            'event=msg_waiting.drain.tickle.result result=no_more',
          );
          break;
        case MeshCoreDrainOutcomeKind.timeout:
          AppLogging.meshcore(
            'event=msg_waiting.drain.tickle.result result=timeout',
            error: true,
          );
          break;
        case MeshCoreDrainOutcomeKind.skipped:
        case MeshCoreDrainOutcomeKind.failed:
          // Already logged by drainOnce.
          break;
      }
    });
  }

  void _handleIncomingContactMessage(MeshCoreFrame frame) {
    final result = MeshCoreMessageFrameParser.parseContactMessage(frame);
    if (!result.ok) {
      AppLogging.meshcore(
        'event=message.parse.rejected scope=contact source=conversations '
        'code=0x${frame.command.toRadixString(16).padLeft(2, '0')} '
        'len=${frame.payload.length} reason=${result.rejectReason}',
        error: true,
      );
      return;
    }
    final parsed = result.value!;

    // D28 Part A: stamp latest SNR onto the matching contact (session
    // only, no persistence). Done before conversation matching so
    // the contacts list updates even when no conversation has been
    // created yet for this sender.
    if (parsed.snrQuarter != null) {
      ref
          .read(meshCoreContactsProvider.notifier)
          .recordSnrFromPrefix(parsed.senderPrefixHex, parsed.snrQuarter!);
    }

    // Resolve the 6-byte firmware-supplied sender prefix to the
    // matching conversation. Conversation IDs are full pubKeyHex (64
    // chars), so a prefix-startsWith match against the live
    // conversation list is the right shape. If no contact has been
    // discovered yet we fall back to the prefix itself as the
    // conversation id; a later contacts.fetch will correctly merge it.
    final senderPrefix = parsed.senderPrefixHex;
    // First try the conversations provider's own list (built from
    // `_contactStore`). If that misses, fall back to the firmware-
    // fetched contacts in `meshCoreContactsProvider`. The two stores
    // are separate: contacts shown in the UI come from the firmware
    // fetch, but `_contactStore` only contains contacts that were
    // explicitly saved client-side. Without this fallback, every
    // first-time inbound contact message is orphaned. (D19.A live
    // bridge test caught this: sim Contacts tile rendered "Unknown"
    // for the iPhone radio, but `state.conversations` was empty so
    // persistence was being skipped.)
    String? matchedId = meshCoreConversationIdForSenderPrefix(
      state.conversations,
      senderPrefix,
    );
    Uint8List? fullSenderKey;
    String? senderName;
    if (matchedId != null) {
      final matched = state.conversations.firstWhere((c) => c.id == matchedId);
      fullSenderKey = matched.contact?.publicKey;
      senderName = matched.contact?.name;
    } else {
      final contactsState = ref.read(meshCoreContactsProvider);
      for (final c in contactsState.contacts) {
        if (c.publicKeyHex.toLowerCase().startsWith(senderPrefix)) {
          matchedId = c.publicKeyHex;
          fullSenderKey = c.publicKey;
          senderName = c.name;
          break;
        }
      }
    }
    final String conversationId = matchedId ?? senderPrefix;

    final stableId = meshCoreInboundContactMessageId(
      senderPrefixHex: senderPrefix,
      timestamp: parsed.timestamp,
      text: parsed.text,
    );

    // D33: decode any chat-meta envelope embedded in the body. On a
    // recognised REPLY envelope we replace the displayed body with
    // the structured payload's body and stamp `replyToMmf` so the
    // chat surface can render the quote preview row. On a plain
    // text or unknown envelope, the body is rendered as-is.
    final decoded = ChatMetaEnvelopeCodec.decode(parsed.text);
    String displayText = parsed.text;
    String? replyToMmf;
    if (decoded.envelope != null && decoded.envelope!.op == ChatMetaOps.reply) {
      final reply = ChatMetaReplyPayload.parse(decoded.envelope!.payload);
      if (reply != null) {
        displayText = reply.body;
        replyToMmf = reply.target.toStableString();
        AppLogging.meshcore(
          'event=chat_meta.reply.received scope=contact '
          'target=${reply.target.toStableString()} '
          'body_size=${reply.body.length}',
        );
      }
    }

    // Compute the MMF for THIS message. Both ends of the
    // conversation observe the same `(senderPrefix, target_ts)`
    // pair, so receiver-derived and sender-derived MMFs agree.
    final ownMmf = MeshCoreMmf.contact(
      peerPubkeyPrefix: Uint8List.fromList(_hexToBytes(senderPrefix)),
      targetTimestampS: parsed.timestamp.millisecondsSinceEpoch ~/ 1000,
    ).toStableString();

    final message = MeshCoreMessage(
      id: stableId,
      text: displayText,
      timestamp: parsed.timestamp,
      isOutgoing: false,
      status: MeshCoreMessageDeliveryStatus.delivered,
      senderKey: fullSenderKey,
      senderName: senderName,
      pathLength: parsed.pathLen,
      snrQuarter: parsed.snrQuarter,
      mmf: ownMmf,
      replyToMmf: replyToMmf,
    );

    AppLogging.meshcore(
      'event=message.received scope=contact source=conversations '
      'protocol=${parsed.protocol.name} '
      'sender_prefix=$senderPrefix size=${displayText.length}',
    );

    // D19.A: persist inbound contact messages so the chat surfaces
    // them on next open. Skip when no matching contact has been
    // discovered yet (orphan path); a later `contacts.fetch` triggered
    // by the advert push will populate the contact, and the next
    // inbound message persists correctly. Persistence runs off-frame
    // so it does not block the broadcast stream listener.
    if (matchedId != null) {
      final persistKey = matchedId;
      Future.microtask(() async {
        try {
          await _messageStore.init();
          await _messageStore.addContactMessage(
            persistKey,
            MeshCoreStoredMessage(
              id: stableId,
              senderKey: fullSenderKey ?? Uint8List(32),
              // D33: store the displayed body (envelope stripped on
              // reply messages) so the chat surface never re-decodes
              // on each load. The original raw envelope bytes are
              // not retained — losing them is fine because the
              // structured payload (target MMF + body) is what we
              // actually need.
              text: displayText,
              timestamp: parsed.timestamp,
              isOutgoing: false,
              status: MeshCoreMessageStatus.delivered,
              pathLength: parsed.pathLen,
              isChannelMessage: false,
              snrQuarter: parsed.snrQuarter,
              mmf: ownMmf,
              replyToMmf: replyToMmf,
            ),
          );
          AppLogging.meshcore(
            'event=message.persisted scope=contact size=${parsed.text.length}',
          );
        } catch (e) {
          AppLogging.meshcore(
            'event=message.persist.failed scope=contact '
            'reason=${e.runtimeType}',
            error: true,
          );
        }
      });
    } else {
      AppLogging.meshcore(
        'event=message.persist.skipped scope=contact '
        'reason=no_matching_contact sender_prefix=$senderPrefix',
      );
      // D20.B: orphan-skip recovery. Firmware architecturally
      // guarantees an advert push (0x80 / 0x8A) before any contact
      // DM, because `onMessageRecv` takes a `ContactInfo&` and
      // contacts only enter the firmware table via
      // `onDiscoveredContact`. Hitting this branch implies a rare
      // race (app connected mid-stream, missed the advert push).
      // Trigger a contacts refresh so the NEXT inbound message
      // from this sender finds a matching contact and persists
      // correctly. The orphaned message itself is still dropped;
      // creating a prefix-keyed placeholder contact would risk
      // colliding with the full-key entry that arrives via the
      // refresh, so we accept losing the first message in this
      // edge case rather than corrupt the contacts table.
      Future.microtask(() {
        try {
          ref.read(meshCoreContactsProvider.notifier).refresh();
        } catch (e) {
          AppLogging.meshcore(
            'event=orphan.refresh.failed reason=${e.runtimeType}',
            error: true,
          );
        }
      });
    }

    _addMessageToConversation(conversationId, message, incrementUnread: true);

    // Phase 3 Slice A: fan out to automation engine + IFTTT service
    // tagged with `TriggerProtocol.meshcore`. The `from` int is the
    // first 4 pubkey bytes interpreted as a big-endian uint32 so
    // dedupe keys are stable per-contact across messages. Channel
    // index is null for DMs.
    _fireMeshCoreMessageToEngines(
      senderKey: fullSenderKey,
      senderName: senderName ?? '',
      text: displayText,
      channelIndex: null,
    );

    // D30 Part A: fire a local notification for inbound MeshCore DMs.
    // Gated on the existing app-wide notification toggles so the user's
    // master + per-category preferences apply uniformly across protocols.
    // Only inbound persisted messages reach this point — the parser at
    // the top of the handler runs only for `RESP_CODE_CONTACT_MSG_RECV*`
    // frames (firmware → app), so there's no risk of self-echo
    // notifications. Persistence ran via Future.microtask above; the
    // notification fire-and-forget here doesn't block the broadcast
    // listener.
    if (matchedId != null && fullSenderKey != null) {
      // D33: pass the envelope-stripped `displayText` (set above when a
      // REPLY envelope decoded successfully) so the iOS notification
      // banner doesn't surface raw `[mrrp]<base64>[/mrrp] You replied:
      // …` text. Live smoke 2026-05-07 caught the leak. For plain
      // (non-envelope) messages displayText == parsed.text so the
      // user-facing copy is unchanged.
      _maybeNotifyContactMessage(
        senderName: senderName ?? '',
        pubKeyHex: matchedId,
        text: displayText,
      );
    }
  }

  /// D30 Part A: dispatch the contact-DM notification, gated on
  /// `notificationsEnabled` + `directMessageNotificationsEnabled`. Reads
  /// settings via the same `settingsServiceProvider` the Meshtastic side
  /// uses, so toggling notifications off in the Settings screen
  /// suppresses MeshCore + Meshtastic alike.
  void _maybeNotifyContactMessage({
    required String senderName,
    required String pubKeyHex,
    required String text,
  }) {
    Future.microtask(() async {
      if (_disposed) return;
      try {
        final settings = await ref.read(settingsServiceProvider.future);
        if (!settings.notificationsEnabled) return;
        if (!settings.directMessageNotificationsEnabled) return;
        // D-Q8: per-contact block list. Blocked contacts still
        // appear on the radio's roster and their messages still
        // arrive (no wire change), but the OS notification is
        // suppressed so the user isn't nagged. Reading the
        // notifier synchronously is safe — the provider has been
        // hydrated by the time the first DM arrives in any
        // realistic flow, and a missed-on-cold-start notification
        // is an acceptable single-frame fallback.
        if (ref
            .read(meshCoreContactBlockProvider.notifier)
            .isBlocked(pubKeyHex)) {
          AppLogging.meshcore(
            'event=notification.suppressed scope=contact '
            'reason=blocked',
          );
          return;
        }
        await NotificationService().showMeshCoreContactMessageNotification(
          senderName: senderName.isNotEmpty ? senderName : 'MeshCore',
          pubKeyHex: pubKeyHex,
          message: text,
        );
      } catch (e) {
        AppLogging.meshcore(
          'event=notification.dispatch.failed scope=contact '
          'reason=${e.runtimeType}',
          error: true,
        );
      }
    });
  }

  /// D30 Part A: dispatch the channel notification.
  /// D37-A: per-channel mute gates the system notification. The in-app
  /// chat persistence path (above this call site) is unconditional —
  /// muted channels still receive and store messages; only the system
  /// notification is suppressed. Storage / provider read failures
  /// fail-open (deliver the notification) so the user never misses a
  /// message because of a SharedPreferences read error.
  /// D37-B-A: hide is intentionally NOT consulted here. A hidden
  /// channel still notifies unless it is also muted. Mute is the only
  /// notification suppression input; hide only affects the channels-
  // Phase 3 Slice A: dispatch an inbound MeshCore message to the
  // automation engine and IFTTT service, both tagged with
  // `TriggerProtocol.meshcore`. Existing automations / webhooks fire
  // if their `protocolFilter` is `any` or `meshcore`. Engine/IFTTT
  // run fire-and-forget off-frame to keep the broadcast listener
  // non-blocking; failures are logged and otherwise swallowed.
  //
  // `senderKey` is the full 32-byte MeshCore pubkey for DMs (null for
  // channel frames where firmware strips identity). `from` int is the
  // first 4 pubkey bytes as big-endian uint32: stable per contact,
  // identical across messages, so the engine's per-sender dedupe key
  // (`messageReceived_node{from}`) coalesces rapid-fire identical
  // messages from one peer the same way the Meshtastic side does.
  void _fireMeshCoreMessageToEngines({
    required Uint8List? senderKey,
    required String senderName,
    required String text,
    required int? channelIndex,
  }) {
    final from = meshCoreSenderIdFromKey(senderKey);
    final automationMessage = AutomationMessage(
      from: from,
      text: text,
      channel: channelIndex,
    );

    Future.microtask(() async {
      if (_disposed) return;
      try {
        final engine = ref.read(automationEngineProvider);
        await engine.processMessage(
          automationMessage,
          senderName: senderName,
          protocol: TriggerProtocol.meshcore,
        );
      } catch (e) {
        AppLogging.meshcore(
          'event=automation.fanout.failed scope=meshcore '
          'reason=${e.runtimeType}',
          error: true,
        );
      }
    });

    Future.microtask(() async {
      if (_disposed) return;
      try {
        final iftttService = ref.read(iftttServiceProvider);
        if (!iftttService.isActive) return;
        // IFTTT consumes the Meshtastic `Message` shape - reuse it
        // for the MeshCore-tagged call. Phase 4 will refactor IFTTT
        // to use AutomationMessage natively, but the typed wrapper
        // lets us thread protocol now without an IFTTT refactor.
        final iftttMessage = mesh.Message(
          from: from,
          to: 0,
          text: text,
          channel: channelIndex ?? 0,
        );
        await iftttService.processMessage(
          iftttMessage,
          senderName: senderName,
          protocol: TriggerProtocol.meshcore,
        );
      } catch (e) {
        AppLogging.meshcore(
          'event=ifttt.fanout.failed scope=meshcore '
          'reason=${e.runtimeType}',
          error: true,
        );
      }
    });
  }

  void _maybeNotifyChannelMessage({
    required String senderName,
    required String channelName,
    required int channelIndex,
    required String senderPrefixHex,
    required String text,
  }) {
    Future.microtask(() async {
      if (_disposed) return;
      try {
        final settings = await ref.read(settingsServiceProvider.future);
        if (!settings.notificationsEnabled) return;
        if (!settings.channelMessageNotificationsEnabled) return;
        // D37-A: per-channel mute gate. Read defensively — a failure to
        // read the muted set must NOT silently drop the notification.
        bool muted = false;
        try {
          muted = ref
              .read(meshCoreChannelMutedSetProvider)
              .contains(channelIndex);
        } catch (e) {
          AppLogging.meshcore(
            'event=channel.notification.mute_check.failed '
            'idx=$channelIndex reason=${e.runtimeType}',
            error: true,
          );
        }
        if (muted) {
          AppLogging.meshcore(
            'event=channel.notification.skipped reason=muted '
            'idx=$channelIndex',
          );
          return;
        }
        await NotificationService().showMeshCoreChannelMessageNotification(
          senderName: senderName.isNotEmpty ? senderName : 'MeshCore',
          channelName: channelName.isNotEmpty ? channelName : 'Channel',
          channelIndex: channelIndex,
          senderPrefixHex: senderPrefixHex,
          message: text,
        );
      } catch (e) {
        AppLogging.meshcore(
          'event=notification.dispatch.failed scope=channel '
          'reason=${e.runtimeType}',
          error: true,
        );
      }
    });
  }

  void _handleIncomingChannelMessage(MeshCoreFrame frame) {
    final result = MeshCoreMessageFrameParser.parseChannelMessage(frame);
    if (!result.ok) {
      AppLogging.meshcore(
        'event=message.parse.rejected scope=channel source=conversations '
        'code=0x${frame.command.toRadixString(16).padLeft(2, '0')} '
        'len=${frame.payload.length} reason=${result.rejectReason}',
        error: true,
      );
      return;
    }
    final parsed = result.value!;

    final stableId = meshCoreInboundChannelMessageId(
      channelIndex: parsed.channelIndex,
      timestamp: parsed.timestamp,
      text: parsed.text,
    );

    // D33: same envelope decode path as the contact handler. Replies
    // surface as `text=replyBody, replyToMmf=target.mmf`; plain text
    // and unknown envelopes pass through unchanged.
    final decoded = ChatMetaEnvelopeCodec.decode(parsed.text);
    String displayText = parsed.text;
    String? replyToMmf;
    if (decoded.envelope != null && decoded.envelope!.op == ChatMetaOps.reply) {
      final reply = ChatMetaReplyPayload.parse(decoded.envelope!.payload);
      if (reply != null) {
        displayText = reply.body;
        replyToMmf = reply.target.toStableString();
        AppLogging.meshcore(
          'event=chat_meta.reply.received scope=channel '
          'channel=${parsed.channelIndex} '
          'target=${reply.target.toStableString()} '
          'body_size=${reply.body.length}',
        );
      }
    }

    final ownMmf = MeshCoreMmf.channel(
      channelIndex: parsed.channelIndex,
      targetTimestampS: parsed.timestamp.millisecondsSinceEpoch ~/ 1000,
    ).toStableString();

    final message = MeshCoreMessage(
      id: stableId,
      text: displayText,
      timestamp: parsed.timestamp,
      isOutgoing: false,
      status: MeshCoreMessageDeliveryStatus.delivered,
      // Channel messages carry no sender identity in firmware.
      senderKey: null,
      pathLength: parsed.pathLen,
      snrQuarter: parsed.snrQuarter,
      mmf: ownMmf,
      replyToMmf: replyToMmf,
    );

    AppLogging.meshcore(
      'event=message.received scope=channel source=conversations '
      'protocol=${parsed.protocol.name} '
      'channel=${parsed.channelIndex} size=${displayText.length}',
    );

    // D19.A: persist inbound channel messages so the chat surfaces
    // them on next open. Channel slot is fixed wire information so
    // there is no orphan-skip path here. Re-flooded duplicates with
    // identical (channel, timestamp, text) collapse into one stored
    // entry via the deterministic id + store's add-by-id update.
    Future.microtask(() async {
      try {
        await _messageStore.init();
        await _messageStore.addChannelMessage(
          parsed.channelIndex,
          MeshCoreStoredMessage(
            id: stableId,
            senderKey: Uint8List(0),
            text: displayText,
            timestamp: parsed.timestamp,
            isOutgoing: false,
            status: MeshCoreMessageStatus.delivered,
            pathLength: parsed.pathLen,
            isChannelMessage: true,
            channelIndex: parsed.channelIndex,
            snrQuarter: parsed.snrQuarter,
            mmf: ownMmf,
            replyToMmf: replyToMmf,
          ),
        );
        AppLogging.meshcore(
          'event=message.persisted scope=channel '
          'channel=${parsed.channelIndex} size=${displayText.length}',
        );
      } catch (e) {
        AppLogging.meshcore(
          'event=message.persist.failed scope=channel '
          'reason=${e.runtimeType}',
          error: true,
        );
      }
    });

    _addMessageToConversation(
      'channel_${parsed.channelIndex}',
      message,
      incrementUnread: true,
      isChannel: true,
      channelIndex: parsed.channelIndex,
    );

    // Phase 3 Slice A: fan out to automation engine + IFTTT service.
    // MeshCore channel frames carry no per-sender identity (firmware
    // strips it), so `from` is 0 and senderName is empty - matches
    // the analogous limitation surfaced in the OS notification path
    // below.
    _fireMeshCoreMessageToEngines(
      senderKey: null,
      senderName: '',
      text: displayText,
      channelIndex: parsed.channelIndex,
    );

    // D30 Part A: fire a local notification for inbound MeshCore channel
    // messages. Channel frames carry no sender identity in firmware, so
    // we surface the channel name only. Resolve the channel display
    // name from the channels provider; fall back to a generic
    // "Channel <index>" label if the channel isn't known yet.
    final channels = ref.read(meshCoreChannelsProvider).channels;
    final channelName = channels
        .where((c) => c.index == parsed.channelIndex)
        .map((c) => c.name)
        .firstWhere((n) => n.isNotEmpty, orElse: () => '');
    // D33: pass the envelope-stripped `displayText` (set above when a
    // REPLY envelope decoded successfully) so the iOS notification
    // banner doesn't surface raw `[mrrp]…[/mrrp]` text. See the
    // contact-mirror at `_maybeNotifyContactMessage` callsite for the
    // matching note.
    _maybeNotifyChannelMessage(
      senderName: '',
      channelName: channelName,
      channelIndex: parsed.channelIndex,
      senderPrefixHex: '',
      text: displayText,
    );
  }

  void _handleSendConfirmed(MeshCoreFrame frame) {
    AppLogging.meshcore(
      'event=push.observed scope=conversations code=0x82 '
      'name=send_confirmed',
    );
    _markPendingAsDelivered();
  }

  void _handleAdvertPush(MeshCoreFrame frame) {
    // D17.C: a peer's contact entry on firmware was just updated
    // (renamed, path changed, freshly heard). Refetch contacts so
    // the conversations list picks up the new name. Lossless fallback
    // to the manual "Refresh Contacts" action that was previously the
    // only path.
    final isNew = frame.command == MeshCorePushCodes.newAdvert;
    AppLogging.meshcore(
      'event=advert.observed code=0x'
      '${frame.command.toRadixString(16).padLeft(2, '0')} '
      'new=$isNew size=${frame.payload.length}',
    );

    // D34b-A1: 0x80 carries the 32-byte pubkey of an already-heard
    // peer. Bump the recent-heard buffer's `lastHeard` so the
    // discovery screen reflects activity even when no full advert
    // has been observed in this session.
    if (!isNew && frame.payload.length >= 32) {
      final pubKey = Uint8List.fromList(frame.payload.sublist(0, 32));
      try {
        ref
            .read(meshCoreDiscoveredAdvertsProvider.notifier)
            .bumpLastHeard(pubKey);
      } catch (_) {
        // Swallow — discovery feed is a best-effort surface.
      }
    }

    // D24.B: only `PUSH_CODE_NEW_ADVERT` (0x8A) carries the full
    // ContactInfo (same shape as `RESP_CODE_CONTACT` / 0x03).
    // `PUSH_CODE_ADVERT` (0x80) is just the 32-byte pubkey of an
    // already-known contact: there's no name field to merge, so
    // the only useful response is the existing contacts refresh.
    if (isNew) {
      final result = msgs.parseContact(frame.payload);
      if (result.isSuccess) {
        final info = result.value!;
        // Size-only log of the parsed name length so the field log
        // can attribute heal attempts without leaking the name.
        AppLogging.meshcore(
          'event=contact.advert.name.observed name_len=${info.name.length}',
        );
        // D34b-A1: record the discovered advert before we attempt
        // any name-merge — the recent-heard feed should reflect a
        // newly-observed peer even when the local contact slot is
        // already populated and the merge bails on "preserved".
        try {
          ref
              .read(meshCoreDiscoveredAdvertsProvider.notifier)
              .recordAdvert(info, isNew: true);
        } catch (_) {
          // Swallow — discovery feed is a best-effort surface.
        }
        if (info.name.isNotEmpty) {
          AppLogging.meshcore('event=contact.advert.name.update.attempted');
          Future.microtask(() {
            try {
              final outcome = ref
                  .read(meshCoreContactsProvider.notifier)
                  .mergeAdvertName(info.publicKeyHex, info.name);
              switch (outcome) {
                case 'ok':
                  AppLogging.meshcore(
                    'event=contact.advert.name.update.succeeded',
                  );
                  break;
                case 'preserved':
                  AppLogging.meshcore(
                    'event=contact.advert.name.update.skipped '
                    'reason=existing_name_preserved',
                  );
                  break;
                case 'no_match':
                  AppLogging.meshcore(
                    'event=contact.advert.name.update.skipped '
                    'reason=unknown_contact_will_refresh',
                  );
                  break;
                case 'empty_advert':
                  // Defensive — already gated above.
                  AppLogging.meshcore(
                    'event=contact.advert.name.update.skipped '
                    'reason=empty_advert',
                  );
                  break;
              }
            } catch (e) {
              AppLogging.meshcore(
                'event=contact.advert.name.update.failed '
                'reason=${e.runtimeType}',
                error: true,
              );
            }
          });
        } else {
          AppLogging.meshcore(
            'event=contact.advert.name.update.skipped '
            'reason=empty_advert',
          );
        }
      } else {
        AppLogging.meshcore(
          'event=contact.advert.parse.failed reason=${result.error} '
          'size=${frame.payload.length}',
          error: true,
        );
      }
    }

    // Trigger a contacts refresh on the global contacts notifier.
    // Use Future.microtask so we don't block the frame stream listener.
    // For `'no_match'` outcomes above this is the recovery path:
    // firmware just added a brand-new contact and the next
    // `getContacts()` returns it.
    Future.microtask(() {
      try {
        ref.read(meshCoreContactsProvider.notifier).refresh();
      } catch (e) {
        AppLogging.meshcore(
          'event=advert.refresh.failed reason=${e.runtimeType}',
          error: true,
        );
      }
    });
    // Reload our own conversation list off the same refresh so the
    // updated contact name surfaces in the conversations provider too.
    Future.microtask(_loadConversations);
  }

  Future<void> _loadConversations() async {
    if (_disposed) return;
    state = state.copyWith(isLoading: true);

    try {
      await _messageStore.init();
      await _contactStore.init();
      if (_disposed) return;

      // Load contacts to build conversation list
      final contacts = await _contactStore.loadContacts();
      final conversations = <MeshCoreConversation>[];

      for (final contact in contacts) {
        final messages = await _messageStore.loadContactMessages(
          contact.publicKeyHex,
        );
        final lastMessage = messages.isNotEmpty ? messages.last : null;
        final unread = await _contactStore.getUnreadCount(contact.publicKeyHex);

        conversations.add(
          MeshCoreConversation(
            id: contact.publicKeyHex,
            name: contact.name,
            isChannel: false,
            contact: contact,
            lastMessageText: lastMessage?.text,
            lastMessageTime: lastMessage?.timestamp,
            unreadCount: unread,
          ),
        );
      }

      // Sort by last message time
      conversations.sort((a, b) {
        if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
        if (a.lastMessageTime == null) return 1;
        if (b.lastMessageTime == null) return -1;
        return b.lastMessageTime!.compareTo(a.lastMessageTime!);
      });

      // D38-A: rebuild channel conversation entries from the live
      // MeshCore channel list + the on-disk message store. Channel
      // unread badges and last-message previews must survive an app
      // restart - prior to this slice both were ephemeral.
      //
      // Channel entries are appended after the (time-sorted) contact
      // entries. The channels SCREEN looks up entries by id, not by
      // iteration order, so the D37-C user-defined channel order is
      // unaffected - this list is just a conversation cache.
      final pubKeyPrefix = ref.read(meshCoreSelfPubKeyPrefixProvider);
      final channelEntries = ref.read(meshCoreChannelsProvider).channels;
      for (final channel in channelEntries) {
        try {
          final messages = await _messageStore.loadChannelMessages(
            channel.index,
          );
          final lastMessage = messages.isNotEmpty ? messages.last : null;
          final unread = await _contactStore.getChannelUnreadCount(
            pubKeyPrefix,
            channel.index,
          );
          conversations.add(
            MeshCoreConversation(
              id: 'channel_${channel.index}',
              name: channel.displayName,
              isChannel: true,
              channelIndex: channel.index,
              lastMessageText: lastMessage?.text,
              lastMessageTime: lastMessage?.timestamp,
              unreadCount: unread,
            ),
          );
        } catch (e) {
          AppLogging.meshcore(
            'event=conversations.channel.rebuild.failed '
            'idx=${channel.index} reason=${e.runtimeType}',
            error: true,
          );
        }
      }

      // D28: preserve queue-status fields (heartbeatActive, last-drain
      // metadata) across the full-load reset. Pre-D28 this dropped them
      // back to defaults, which would clobber the heartbeat-active flag
      // set by `_publishHeartbeatActive` from `_startHeartbeat`.
      state = state.copyWith(conversations: conversations, isLoading: false);
    } catch (e) {
      AppLogging.storage('MeshCore: Error loading conversations: $e');
      AppLogging.meshcore(
        'event=provider.error scope=conversations.load reason=${e.runtimeType}',
        error: true,
      );
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void _addMessageToConversation(
    String conversationId,
    MeshCoreMessage message, {
    bool incrementUnread = false,
    bool isChannel = false,
    int? channelIndex,
  }) {
    final updated = List<MeshCoreConversation>.from(state.conversations);
    final index = updated.indexWhere((c) => c.id == conversationId);

    if (index >= 0) {
      final existing = updated[index];
      updated[index] = existing.copyWith(
        lastMessageText: message.text,
        lastMessageTime: message.timestamp,
        unreadCount: incrementUnread
            ? existing.unreadCount + 1
            : existing.unreadCount,
      );
    } else {
      // Create new conversation
      updated.add(
        MeshCoreConversation(
          id: conversationId,
          name: isChannel ? 'Channel $channelIndex' : conversationId,
          isChannel: isChannel,
          channelIndex: channelIndex,
          lastMessageText: message.text,
          lastMessageTime: message.timestamp,
          unreadCount: incrementUnread ? 1 : 0,
        ),
      );
    }

    // Re-sort by time
    updated.sort((a, b) {
      if (a.lastMessageTime == null && b.lastMessageTime == null) return 0;
      if (a.lastMessageTime == null) return 1;
      if (b.lastMessageTime == null) return -1;
      return b.lastMessageTime!.compareTo(a.lastMessageTime!);
    });

    state = state.copyWith(conversations: updated);

    // Update unread count in storage AND propagate to the contacts
    // notifier state so the Contacts list aggregate filter chip
    // reflects the new unread (D20.A). Pre-D20 the contact store
    // wrote SharedPreferences but `meshCoreContactsProvider.contacts`
    // was only re-read on full refresh, so the per-tile fallback was
    // accurate but the global "Unread N" filter chip stayed at 0.
    // Channels skip the contacts-notifier propagation since channels
    // don't live in the contacts list.
    if (incrementUnread && !isChannel) {
      Future.microtask(() async {
        try {
          await _contactStore.init();
          final newCount = await _contactStore.incrementUnreadCount(
            conversationId,
          );
          ref
              .read(meshCoreContactsProvider.notifier)
              .updateUnreadCount(conversationId, newCount);
        } catch (e) {
          AppLogging.meshcore(
            'event=unread.propagate.failed scope=contact '
            'reason=${e.runtimeType}',
            error: true,
          );
        }
      });
    }

    // D38-A: persist per-channel unread to SharedPreferences so the
    // badge survives an app restart. Channels are NOT propagated to
    // the contacts notifier (channels live on a different tab; the
    // aggregate "Unread N" Contacts chip must remain channel-blind).
    if (incrementUnread && isChannel && channelIndex != null) {
      Future.microtask(() async {
        try {
          await _contactStore.init();
          final prefix = ref.read(meshCoreSelfPubKeyPrefixProvider);
          if (prefix.isEmpty) return;
          await _contactStore.incrementChannelUnreadCount(prefix, channelIndex);
        } catch (e) {
          AppLogging.meshcore(
            'event=unread.propagate.failed scope=channel '
            'idx=$channelIndex reason=${e.runtimeType}',
            error: true,
          );
        }
      });
    }
  }

  void _markPendingAsDelivered() {
    // Mark the most recent pending outgoing message as delivered
    // Full implementation would use message IDs to match specific messages
  }

  /// Clear unread count for a conversation. D20.A propagates the
  /// clear to BOTH the contact store and the contacts notifier so
  /// the Contacts list aggregate chip and the per-tile badge stay
  /// in sync. The propagation runs unconditionally for any id that
  /// is not a `channel_*` id, even when `state.conversations`
  /// doesn't have a matching entry yet (e.g. fresh app start with
  /// an empty `_contactStore` but a contact known to firmware via
  /// `meshCoreContactsProvider`). Pre-D20 (and the first D20 cut)
  /// the propagation was gated on the conversations-list lookup, so
  /// reopening the chat after rebuild left the contacts notifier
  /// state at the stale unread count.
  Future<void> markAsRead(String conversationId) async {
    // Update in-memory conversation entry if present.
    final updated = List<MeshCoreConversation>.from(state.conversations);
    final index = updated.indexWhere((c) => c.id == conversationId);
    if (index >= 0) {
      updated[index] = updated[index].copyWith(unreadCount: 0);
      state = state.copyWith(conversations: updated);
    }

    // Channels don't live in the contacts notifier; skip the
    // contact-side propagation for them.
    final isChannelId = conversationId.startsWith('channel_');
    if (!isChannelId) {
      try {
        await _contactStore.init();
        await _contactStore.clearUnreadCount(conversationId);
      } catch (e) {
        AppLogging.meshcore(
          'event=mark_read.store_clear.failed reason=${e.runtimeType}',
          error: true,
        );
      }
      try {
        ref
            .read(meshCoreContactsProvider.notifier)
            .updateUnreadCount(conversationId, 0);
      } catch (e) {
        AppLogging.meshcore(
          'event=mark_read.contacts_notifier.failed reason=${e.runtimeType}',
          error: true,
        );
      }
      return;
    }

    // D38-A: channel id. Parse the slot index safely and clear the
    // persisted per-channel unread counter so the badge stays at zero
    // across an app restart.
    final idx = int.tryParse(conversationId.substring('channel_'.length));
    if (idx == null) {
      AppLogging.meshcore(
        'event=mark_read.channel.id_parse.failed',
        error: true,
      );
      return;
    }
    try {
      await _contactStore.init();
      final prefix = ref.read(meshCoreSelfPubKeyPrefixProvider);
      if (prefix.isEmpty) return;
      await _contactStore.clearChannelUnreadCount(prefix, idx);
    } catch (e) {
      AppLogging.meshcore(
        'event=mark_read.channel.store_clear.failed '
        'idx=$idx reason=${e.runtimeType}',
        error: true,
      );
    }
  }

  /// Refresh conversation list.
  Future<void> refresh() async {
    await _loadConversations();
  }
}

final meshCoreConversationsProvider =
    NotifierProvider<MeshCoreConversationsNotifier, MeshCoreConversationsState>(
      MeshCoreConversationsNotifier.new,
    );

// ---------------------------------------------------------------------------
// D43-A2: per-conversation chat history provider (paged window)
// ---------------------------------------------------------------------------

/// Compound cursor used by the chat history notifier to track the
/// oldest currently-loaded message. Pairs with the D43-A1 store
/// paging API (`loadContactMessagesBefore` / `loadChannelMessagesBefore`).
typedef MeshCoreChatHistoryCursor = ({DateTime timestamp, String id});

/// Family key for [meshCoreChatHistoryProvider]. Sealed so callers can
/// pattern-match on the conversation kind without leaking the
/// `channel_<n>` string-encoding the dead `MessageHistoryParams`
/// shape required.
sealed class MeshCoreChatHistoryKey {
  const MeshCoreChatHistoryKey();
}

class MeshCoreChatContactKey extends MeshCoreChatHistoryKey {
  final String pubKeyHex;
  const MeshCoreChatContactKey(this.pubKeyHex);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshCoreChatContactKey && other.pubKeyHex == pubKeyHex;

  @override
  int get hashCode => Object.hash(MeshCoreChatContactKey, pubKeyHex);
}

class MeshCoreChatChannelKey extends MeshCoreChatHistoryKey {
  final int channelIndex;
  const MeshCoreChatChannelKey(this.channelIndex);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshCoreChatChannelKey && other.channelIndex == channelIndex;

  @override
  int get hashCode => Object.hash(MeshCoreChatChannelKey, channelIndex);
}

/// Immutable window state for a single conversation's chat history.
///
/// [messages] is ALWAYS in ascending `(timestamp, id)` order — the
/// shape the chat screen renders bottom-up.
///
/// [oldestCursor] is a derived view of `messages.firstOrNull` and is
/// used as the strict-less compound cursor for the next [loadOlder]
/// call. It is never persisted as a separate field so the cursor
/// cannot drift out of sync with the loaded list.
class MeshCoreChatHistoryState {
  final List<MeshCoreMessage> messages;
  final bool isInitialLoading;
  final bool isLoadingOlder;

  /// `true` while another older page may still exist. Flips to
  /// `false` the moment a load returns fewer than the page size,
  /// whether that is the real bottom of history or the 500-cap trim
  /// wall — the provider cannot distinguish.
  final bool hasMore;

  /// Last error surface for the chat screen. Cleared on the next
  /// successful load.
  final String? lastError;

  const MeshCoreChatHistoryState({
    this.messages = const [],
    this.isInitialLoading = false,
    this.isLoadingOlder = false,
    this.hasMore = true,
    this.lastError,
  });

  const MeshCoreChatHistoryState.initial()
    : messages = const [],
      isInitialLoading = false,
      isLoadingOlder = false,
      hasMore = true,
      lastError = null;

  MeshCoreChatHistoryCursor? get oldestCursor {
    if (messages.isEmpty) return null;
    final m = messages.first;
    return (timestamp: m.timestamp, id: m.id);
  }

  MeshCoreChatHistoryState copyWith({
    List<MeshCoreMessage>? messages,
    bool? isInitialLoading,
    bool? isLoadingOlder,
    bool? hasMore,
    String? lastError,
    bool clearError = false,
  }) {
    return MeshCoreChatHistoryState(
      messages: messages ?? this.messages,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      hasMore: hasMore ?? this.hasMore,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

/// D43 page size. Matches the spec — small enough to keep JSON parse
/// + filter cheap, large enough that the median user never pages.
const int _kMeshCoreChatHistoryPageSize = 50;

/// Default bound for [MeshCoreChatHistoryNotifier.loadUntilContains].
const int _kMeshCoreChatHistoryDefaultMaxPages = 10;

/// Per-conversation chat history notifier.
///
/// Owns the in-memory window for one contact or channel conversation.
/// Reads through the D43-A1 store paging API; never writes to the
/// store — persistence stays on `MeshCoreConversationsNotifier` and
/// the chat screen's existing dual-write paths.
///
/// All mutators preserve the ascending-order invariant. Inbound and
/// outbound message appends dedupe by stable id so a re-delivery or
/// double-handler call cannot stack two bubbles for the same logical
/// message.
class MeshCoreChatHistoryNotifier extends Notifier<MeshCoreChatHistoryState> {
  MeshCoreChatHistoryNotifier(this.key);

  final MeshCoreChatHistoryKey key;
  final MeshCoreMessageStore _store = MeshCoreMessageStore();

  @override
  MeshCoreChatHistoryState build() => const MeshCoreChatHistoryState.initial();

  /// Load the newest page. Idempotent: a second call replaces the
  /// window with a fresh load.
  Future<void> loadInitial() async {
    state = state.copyWith(isInitialLoading: true, clearError: true);
    try {
      final stored = await _loadPage(before: null, beforeId: null);
      final messages = stored.map(_storedToMessage).toList();
      state = MeshCoreChatHistoryState(
        messages: messages,
        isInitialLoading: false,
        isLoadingOlder: false,
        hasMore: stored.length == _kMeshCoreChatHistoryPageSize,
        lastError: null,
      );
    } catch (e) {
      AppLogging.meshcore(
        'event=provider.error scope=chat_history.load_initial '
        'reason=${e.runtimeType}',
        error: true,
      );
      state = state.copyWith(isInitialLoading: false, lastError: e.toString());
    }
  }

  /// Page older. No-op when already loading, when no cursor exists
  /// (empty window), or when [MeshCoreChatHistoryState.hasMore] is
  /// false.
  Future<void> loadOlder() async {
    if (state.isInitialLoading || state.isLoadingOlder) return;
    if (!state.hasMore) return;
    final cursor = state.oldestCursor;
    if (cursor == null) return;

    state = state.copyWith(isLoadingOlder: true, clearError: true);
    try {
      final stored = await _loadPage(
        before: cursor.timestamp,
        beforeId: cursor.id,
      );
      if (stored.isEmpty) {
        state = state.copyWith(isLoadingOlder: false, hasMore: false);
        return;
      }
      final older = stored.map(_storedToMessage).toList();
      final merged = <MeshCoreMessage>[...older, ...state.messages];
      state = state.copyWith(
        messages: merged,
        isLoadingOlder: false,
        hasMore: stored.length == _kMeshCoreChatHistoryPageSize,
      );
    } catch (e) {
      AppLogging.meshcore(
        'event=provider.error scope=chat_history.load_older '
        'reason=${e.runtimeType}',
        error: true,
      );
      state = state.copyWith(isLoadingOlder: false, lastError: e.toString());
    }
  }

  /// Append an inbound message at the tail. Dedupe by id — repeat
  /// deliveries of the same logical message are ignored.
  ///
  /// Tail-append preserves today's chat-screen behaviour (an inbound
  /// with a slightly out-of-order timestamp lands visually at the
  /// bottom). Sorting on append would be a separate quality fix and
  /// is not part of D43.
  void appendInbound(MeshCoreMessage m) => _appendDedup(m);

  /// Append an outbound (pending) message at the tail. Dedupe by id —
  /// idempotent for retried sends that reuse the same stable id.
  void appendOutbound(MeshCoreMessage m) => _appendDedup(m);

  /// Replace a single message's delivery status in place. No-op if
  /// the id is not in the loaded window.
  void updateMessageStatus(String id, MeshCoreMessageDeliveryStatus status) {
    final idx = state.messages.indexWhere((m) => m.id == id);
    if (idx < 0) return;
    final updated = state.messages[idx].copyWith(status: status);
    final next = [...state.messages];
    next[idx] = updated;
    state = state.copyWith(messages: next);
  }

  /// Replace the loaded copy of a message by id with [m]. No-op when
  /// the id is not in the loaded window. Used by the retry path
  /// (rewrites MMF on a re-send) and any other flow that needs to
  /// rewrite multiple fields atomically — `updateMessageStatus`
  /// alone cannot express that.
  ///
  /// Asserts that [m.id] matches the target id implicitly: the find
  /// is by id, so a passed-in message with a different id finds
  /// nothing and the call no-ops.
  void replaceMessage(MeshCoreMessage m) {
    final idx = state.messages.indexWhere((existing) => existing.id == m.id);
    if (idx < 0) return;
    final next = [...state.messages];
    next[idx] = m;
    state = state.copyWith(messages: next);
  }

  /// Remove a message from the loaded window. No-op if absent.
  ///
  /// Caller is responsible for the store-side delete (the chat
  /// screen's existing `_messageStore.deleteContactMessage` /
  /// `deleteChannelMessage` paths). Skipping the store delete will
  /// cause the message to reappear on the next [loadOlder].
  void deleteLocal(String id) {
    final filtered = state.messages.where((m) => m.id != id).toList();
    if (filtered.length == state.messages.length) return;
    state = state.copyWith(messages: filtered);
  }

  /// Page older repeatedly until [id] appears in the loaded window
  /// or [maxPages] iterations elapse. Returns true iff [id] is in
  /// the window when the call returns.
  ///
  /// Used by the quote-jump path: a tap on a reply preview needs to
  /// scroll to the source message, which may be older than the
  /// currently-loaded page. The [maxPages] bound prevents an
  /// infinite loop if `hasMore` somehow stays true on a degenerate
  /// store.
  Future<bool> loadUntilContains(
    String id, {
    int maxPages = _kMeshCoreChatHistoryDefaultMaxPages,
  }) async {
    if (state.messages.any((m) => m.id == id)) return true;
    for (int i = 0; i < maxPages; i++) {
      if (!state.hasMore) break;
      await loadOlder();
      if (state.messages.any((m) => m.id == id)) return true;
    }
    return false;
  }

  void _appendDedup(MeshCoreMessage m) {
    if (state.messages.any((existing) => existing.id == m.id)) return;
    state = state.copyWith(messages: [...state.messages, m]);
  }

  Future<List<MeshCoreStoredMessage>> _loadPage({
    required DateTime? before,
    required String? beforeId,
  }) {
    final k = key;
    switch (k) {
      case MeshCoreChatContactKey():
        return _store.loadContactMessagesBefore(
          k.pubKeyHex,
          before: before,
          beforeId: beforeId,
          limit: _kMeshCoreChatHistoryPageSize,
        );
      case MeshCoreChatChannelKey():
        return _store.loadChannelMessagesBefore(
          k.channelIndex,
          before: before,
          beforeId: beforeId,
          limit: _kMeshCoreChatHistoryPageSize,
        );
    }
  }
}

MeshCoreMessage _storedToMessage(MeshCoreStoredMessage stored) {
  return MeshCoreMessage(
    id: stored.id,
    text: stored.text,
    timestamp: stored.timestamp,
    isOutgoing: stored.isOutgoing,
    status: _storedStatusToDelivery(stored.status),
    senderKey: stored.senderKey,
    pathLength: stored.pathLength,
    snrQuarter: stored.snrQuarter,
    mmf: stored.mmf,
    replyToMmf: stored.replyToMmf,
  );
}

MeshCoreMessageDeliveryStatus _storedStatusToDelivery(MeshCoreMessageStatus s) {
  switch (s) {
    case MeshCoreMessageStatus.pending:
      return MeshCoreMessageDeliveryStatus.pending;
    case MeshCoreMessageStatus.sent:
      return MeshCoreMessageDeliveryStatus.sent;
    case MeshCoreMessageStatus.delivered:
      return MeshCoreMessageDeliveryStatus.delivered;
    case MeshCoreMessageStatus.failed:
      return MeshCoreMessageDeliveryStatus.failed;
  }
}

final meshCoreChatHistoryProvider =
    NotifierProvider.family<
      MeshCoreChatHistoryNotifier,
      MeshCoreChatHistoryState,
      MeshCoreChatHistoryKey
    >(MeshCoreChatHistoryNotifier.new);

// First 4 bytes of `key` interpreted as a big-endian uint32, or 0
// when no key is available. Used as a stable per-contact `from` int
// for the `AutomationMessage` / `Message` plumbed into the
// automation engine + IFTTT service from MeshCore inbound message
// handlers. Channel frames (no per-sender identity in firmware) get
// 0. Top-level so the derivation can be regression-pinned in a unit
// test without instantiating the full conversations notifier.
int meshCoreSenderIdFromKey(Uint8List? key) {
  if (key == null || key.length < 4) return 0;
  return (key[0] << 24) | (key[1] << 16) | (key[2] << 8) | key[3];
}
