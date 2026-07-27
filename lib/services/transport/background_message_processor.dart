// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';
import 'dart:convert';

import 'package:characters/characters.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging.dart';
import '../../core/transport.dart';
import '../../features/nodedex/services/nodedex_database.dart';
import '../../features/nodedex/services/nodedex_sqlite_store.dart';
import '../../generated/meshtastic/mesh.pb.dart' as pb;
import '../../generated/meshtastic/portnums.pbenum.dart' as pn;
import '../../models/mesh_models.dart';
import '../../services/carplay/carplay_feature_flags.dart';
import '../../services/mesh_packet_dedupe_store.dart';
import '../../services/protocol/mesh_packet_rx_metadata.dart';
import '../../services/notifications/channel_mute_prefs.dart';
import '../../services/notifications/notification_service.dart';
import '../../services/storage/message_database.dart';
import '../../utils/text_sanitizer.dart';
import '../../utils/validation.dart';

// =============================================================================
// Background Identity Resolver
// =============================================================================

/// Resolves a Meshtastic node number to a human-readable display name by
/// querying the NodeDex SQLite database directly.
///
/// Riverpod-free. Falls back to `!HEXID` format when no entry exists.
class BackgroundIdentityResolver {
  NodeDexSqliteStore? _store;
  NodeDexDatabase? _db;
  bool _initialized = false;
  final Completer<void> _initCompleter = Completer<void>();

  /// Initialise the NodeDex database connection.
  ///
  /// Safe to call multiple times; subsequent calls are no-ops.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    try {
      _db = NodeDexDatabase();
      _store = NodeDexSqliteStore(_db!);
      await _store!.init();
      AppLogging.ble('BackgroundIdentityResolver: init complete');
      _initCompleter.complete();
    } catch (e) {
      AppLogging.ble('BackgroundIdentityResolver: init error: $e');
      _store = null;
      _db = null;
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  /// Return the display name for [nodeNum], or `!HEXID` as a fallback.
  Future<String> resolve(int nodeNum) async {
    await _initCompleter.future;
    if (_store == null) return _fallbackName(nodeNum);

    try {
      final entry = await _store!.getEntry(nodeNum);
      if (entry != null) {
        final nickname = _sanitizedOrNull(entry.localNickname);
        if (nickname != null) return nickname;
        final lastKnown = _sanitizedOrNull(entry.lastKnownName);
        if (lastKnown != null) return lastKnown;
      }
    } catch (e) {
      AppLogging.ble('BackgroundIdentityResolver: resolve($nodeNum) error: $e');
    }
    return _fallbackName(nodeNum);
  }

  /// Sanitised form of [value], or null when it is absent or sanitises away.
  ///
  /// NodeDex rows are not sanitised on write and the cloud-sync pull path
  /// writes names straight from Firestore, so this is the last boundary
  /// before the name reaches a notification payload.
  static String? _sanitizedOrNull(String? value) {
    if (value == null || value.isEmpty) return null;
    final sanitized = sanitizeExternalText(value);
    return sanitized.isEmpty ? null : sanitized;
  }

  /// Return the short name for [nodeNum], or `null` if unavailable.
  ///
  /// NodeDex does not store a separate short name; this extracts the first
  /// 4 characters of the long name as a best-effort match of the Meshtastic
  /// short-name convention.
  Future<String?> resolveShortName(int nodeNum) async {
    await _initCompleter.future;
    if (_store == null) return null;

    try {
      final entry = await _store!.getEntry(nodeNum);
      final name = _sanitizedOrNull(entry?.lastKnownName);
      if (name != null && name.characters.length >= 2) {
        return safeTruncate(name, maxAvatarNameLength);
      }
    } catch (_) {
      // Fall through to null.
    }
    return null;
  }

  static String _fallbackName(int nodeNum) {
    return '!${nodeNum.toRadixString(16).toUpperCase().padLeft(8, '0')}';
  }

  /// Release the database connection.
  void dispose() {
    _store = null;
    _db?.close();
    _db = null;
  }
}

// =============================================================================
// Background Message Processor
// =============================================================================

/// Lightweight processor that decodes incoming BLE packets and persists text
/// messages without Riverpod.
///
/// Non-text packets are buffered in [pendingPackets] so the foreground
/// providers can process them on resume.
///
/// Lifecycle (managed by [BackgroundBleService]):
///   1. [init] — opens databases.
///   2. [start] — subscribes to [DeviceTransport.dataStream].
///   3. [stop] — cancels subscription, flushes resources.
///   4. [dispose] — closes databases.
class BackgroundMessageProcessor {
  BackgroundMessageProcessor._();
  static final BackgroundMessageProcessor instance =
      BackgroundMessageProcessor._();

  // Dependencies — initialised lazily.
  MessageDatabase? _messageDb;
  MeshPacketDedupeStore? _dedupeStore;
  BackgroundIdentityResolver? _identityResolver;

  StreamSubscription<List<int>>? _dataSubscription;
  bool _initialized = false;
  bool _running = false;

  /// Raw `FromRadio` bytes for non-text packets received while backgrounded.
  ///
  /// Drained by the foreground handoff logic (W2.3) on app resume.
  final List<List<int>> pendingPackets = [];

  /// IDs of messages persisted during the current background session.
  ///
  /// Used by the foreground handoff to skip re-notification (W2.3).
  final Set<String> persistedMessageIds = {};

  /// IDs of messages for which a local notification was already shown
  /// during this background session. Prevents double-notification on
  /// foreground resume.
  final Set<String> notifiedMessageIds = {};

  /// Whether background packet processing is enabled.
  ///
  /// Defaults to `false` so that the foreground [ProtocolService] is the
  /// sole processor after connection. Set to `true` only when the app
  /// transitions to the background (`paused`) so incoming BLE data is
  /// persisted independently of Riverpod.
  bool processingEnabled = false;

  /// Whether notification dispatch is enabled.
  ///
  /// Defaults to `false`. Set to `true` together with [processingEnabled]
  /// when the app is in the background so messages produce local
  /// notifications (W2.3 handoff).
  bool notificationsEnabled = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Open databases. Call once before [start].
  Future<void> init() async {
    if (_initialized) return;

    try {
      _messageDb = MessageDatabase();
      await _messageDb!.init();

      _dedupeStore = MeshPacketDedupeStore();
      await _dedupeStore!.init();

      _identityResolver = BackgroundIdentityResolver();
      await _identityResolver!.init();

      _initialized = true;
      AppLogging.ble('BackgroundMessageProcessor: init complete');
    } catch (e) {
      AppLogging.ble('BackgroundMessageProcessor: init error: $e');
    }
  }

  /// Test-only initialiser that injects pre-built databases.
  ///
  /// Allows tests to pass in-memory or temp-directory backed databases
  /// without requiring `path_provider`.
  @visibleForTesting
  void initForTest({
    required MessageDatabase messageDb,
    required MeshPacketDedupeStore dedupeStore,
  }) {
    _messageDb = messageDb;
    _dedupeStore = dedupeStore;
    _identityResolver = null; // Identity resolution is best-effort.
    _initialized = true;
  }

  /// Begin listening for incoming BLE data from [transport].
  void start(DeviceTransport transport) {
    if (!_initialized) {
      AppLogging.ble(
        'BackgroundMessageProcessor: start() called before init(), ignoring',
      );
      return;
    }
    if (_running) {
      AppLogging.ble(
        'BackgroundMessageProcessor: already running, ignoring start()',
      );
      return;
    }
    _running = true;
    _dataSubscription = transport.dataStream.listen(
      _handleData,
      onError: (Object error) {
        AppLogging.ble('BackgroundMessageProcessor: dataStream error: $error');
      },
    );
    AppLogging.ble('BackgroundMessageProcessor: started');
  }

  /// Stop processing. Does not close databases (call [dispose] for that).
  void stop() {
    _dataSubscription?.cancel();
    _dataSubscription = null;
    _running = false;
    AppLogging.ble('BackgroundMessageProcessor: stopped');
  }

  /// Close databases and release resources.
  void dispose() {
    stop();
    _dedupeStore?.dispose();
    _dedupeStore = null;
    _identityResolver?.dispose();
    _identityResolver = null;
    // MessageDatabase does not expose a close(); it auto-manages via sqflite.
    _messageDb = null;
    _initialized = false;
    pendingPackets.clear();
    persistedMessageIds.clear();
    notifiedMessageIds.clear();
    processingEnabled = false;
    notificationsEnabled = false;
    AppLogging.ble('BackgroundMessageProcessor: disposed');
  }

  /// Drain buffered non-message packets and clear the buffer.
  ///
  /// Called by the foreground handoff (W2.3) when the app resumes.
  List<List<int>> drainPendingPackets() {
    final drained = List<List<int>>.from(pendingPackets);
    pendingPackets.clear();
    return drained;
  }

  // ---------------------------------------------------------------------------
  // Packet handling
  // ---------------------------------------------------------------------------

  void _handleData(List<int> rawBytes) {
    // Offload to microtask so the BLE stream listener returns quickly.
    unawaited(_processPacketAsync(rawBytes));
  }

  Future<void> _processPacketAsync(List<int> rawBytes) async {
    if (!processingEnabled) return;
    try {
      final fromRadio = pb.FromRadio.fromBuffer(rawBytes);

      if (!fromRadio.hasPacket()) {
        // Non-mesh-packet payload (config, nodeinfo, log, etc.)  — buffer.
        pendingPackets.add(rawBytes);
        return;
      }

      final packet = fromRadio.packet;

      // Only decode un-encrypted (application-layer) payloads.
      if (!packet.hasDecoded()) {
        pendingPackets.add(rawBytes);
        return;
      }

      final data = packet.decoded;

      if (data.portnum == pn.PortNum.TEXT_MESSAGE_APP) {
        await _handleTextMessage(packet, data);
      } else {
        // Non-text-message mesh packet — buffer for foreground.
        pendingPackets.add(rawBytes);
      }
    } catch (e) {
      AppLogging.ble('BackgroundMessageProcessor: packet decode error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Text message handling
  // ---------------------------------------------------------------------------

  /// Dedup TTL matching the foreground ProtocolService (120 min).
  static const Duration _messageDeduplicateTtl = Duration(minutes: 120);

  /// Minimum plausible Unix epoch (2020-01-01) — matches ProtocolService.
  static const int _minPlausibleEpoch = 1577836800;

  /// Maximum future tolerance: 1 day — matches ProtocolService.
  static const int _maxFutureSlack = 86400;

  /// Validate rxTime and return a plausible [DateTime].
  ///
  /// Mirrors [ProtocolService._plausibleTimestamp] so foreground and
  /// background paths produce identical timestamps for the same packet.
  ///
  /// When validation fails, `useChronologicalFallback: true` returns the
  /// [_minPlausibleEpoch] sentinel so unknown-time chat packets sink to
  /// the top of the conversation rather than being re-stamped to
  /// [DateTime.now] and appearing newer than freshly-sent local messages.
  static DateTime _plausibleTimestamp(
    pb.MeshPacket packet, {
    bool useChronologicalFallback = false,
  }) {
    if (packet.hasRxTime() && packet.rxTime > 0) {
      final rxEpoch = packet.rxTime;
      final nowEpoch = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      if (rxEpoch >= _minPlausibleEpoch &&
          rxEpoch <= nowEpoch + _maxFutureSlack) {
        return DateTime.fromMillisecondsSinceEpoch(rxEpoch * 1000);
      }
    }
    final fallback = useChronologicalFallback
        ? DateTime.fromMillisecondsSinceEpoch(_minPlausibleEpoch * 1000)
        : DateTime.now();
    final rxTimeRepr = packet.hasRxTime() ? '${packet.rxTime}' : 'missing';
    AppLogging.ble(
      'BackgroundMessageProcessor: rxTime fallback '
      'from=${packet.from} packetId=${packet.id} '
      'rxTime=$rxTimeRepr fallback=$fallback '
      'chronological=$useChronologicalFallback',
    );
    return fallback;
  }

  Future<void> _handleTextMessage(pb.MeshPacket packet, pb.Data data) async {
    // ---- Deduplication via packet dedupe store --------------------------
    final dedupeKey = MeshPacketKey(
      packetType: 'channel_message',
      senderNodeId: packet.from,
      packetId: packet.id,
      channelIndex: packet.channel,
    );

    if (_dedupeStore != null) {
      final seen = await _dedupeStore!.hasSeen(
        dedupeKey,
        ttl: _messageDeduplicateTtl,
      );
      if (seen) {
        AppLogging.ble(
          'BackgroundMessageProcessor: dedup hit, skipping packet ${packet.id}',
        );
        return;
      }
      await _dedupeStore!.markSeen(dedupeKey, ttl: _messageDeduplicateTtl);
    }

    // ---- Decode text ---------------------------------------------------
    final sanitized = sanitizeExternalTextWithStats(
      utf8.decode(data.payload, allowMalformed: true),
    );
    final text = sanitized.text;
    if (text.trim().isEmpty) {
      final digest = sha256.convert(data.payload).toString().substring(0, 8);
      AppLogging.ble(
        'rx_text_dropped reason=sanitized_empty '
        'len=${data.payload.length}B '
        'ctrl=${sanitized.stats.controlsStripped} '
        'surrogate_repairs=${sanitized.stats.surrogateRepairs} '
        'digest=$digest',
      );
      return;
    }

    // ---- Resolve sender identity from NodeDex --------------------------
    String? senderLongName;
    String? senderShortName;
    if (_identityResolver != null) {
      senderLongName = await _identityResolver!.resolve(packet.from);
      senderShortName = await _identityResolver!.resolveShortName(packet.from);
    }

    // ---- Create Message ------------------------------------------------
    // Use rxTime from the radio firmware (same as foreground path) so
    // timestamps are consistent regardless of which path processed the
    // message. rxTime is when the radio actually received the packet.
    //
    // Validate plausibility: devices without a time source may report 0
    // or a small uptime value. Reject anything before 2020-01-01 or more
    // than 1 day into the future. useChronologicalFallback: true keeps
    // chat ordering correct when the firmware lacks a clock by sinking
    // those packets to the epoch sentinel.
    final timestamp = _plausibleTimestamp(
      packet,
      useChronologicalFallback: true,
    );

    final message = Message(
      id: Message.deterministicId(packetId: packet.id, fromNode: packet.from),
      from: packet.from,
      to: packet.to,
      text: text,
      timestamp: timestamp,
      channel: packet.channel,
      received: true,
      source: data.emoji != 0 ? MessageSource.tapback : MessageSource.unknown,
      packetId: packet.id,
      // Receive-path metadata, mirroring the foreground ingest in
      // ProtocolService._handleTextMessage so a message carries the same
      // transport/hop/signal data regardless of which path stored it.
      hopCount: computeHopCount(packet),
      rxSnr: packet.hasRxSnr() ? packet.rxSnr.toDouble() : null,
      rxRssi: packet.hasRxRssi() ? packet.rxRssi : null,
      viaMqtt: receiveViaMqtt(packet),
      relayNode: packet.hasRelayNode() ? packet.relayNode : null,
      senderLongName: senderLongName,
      senderShortName: senderShortName,
      replyId: data.replyId != 0 ? data.replyId : null,
      isEmoji: data.emoji != 0,
    );

    // ---- Persist to MessageDatabase ------------------------------------
    if (_messageDb != null) {
      await _messageDb!.saveMessage(message);
      persistedMessageIds.add(message.id);
      AppLogging.ble(
        'BackgroundMessageProcessor: persisted message ${message.id} '
        'from ${packet.from} (${senderLongName ?? "unknown"})',
      );
    }

    // ---- Background notification dispatch (W2.2) -----------------------
    if (notificationsEnabled) {
      await _dispatchNotification(
        message: message,
        senderLongName: senderLongName,
        senderShortName: senderShortName,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Notification dispatch (W2.2)
  // ---------------------------------------------------------------------------

  /// SharedPreferences keys for notification toggles.
  ///
  /// The processor checks the same notification preferences as the foreground
  /// path: master toggle, per-type toggle, and per-channel mute.
  static const String _kMasterToggle = 'notifications_enabled';
  static const String _kChannelToggle = 'channel_notifications_enabled';
  static const String _kDmToggle = 'dm_notifications_enabled';

  /// Fire a local notification for a received text message.
  ///
  /// Reads notification preferences directly from [SharedPreferences] to
  /// avoid Riverpod. Returns silently if notifications are disabled or the
  /// message was already notified.
  Future<void> _dispatchNotification({
    required Message message,
    required String? senderLongName,
    required String? senderShortName,
  }) async {
    // Skip if already notified (e.g. rapid duplicate delivery).
    if (notifiedMessageIds.contains(message.id)) return;

    // When the CarPlay communication banner is guaranteed to post, it is the
    // single user-facing banner, so suppress the standard background
    // notification to avoid a duplicate. This gate is false unless a native
    // banner will actually fire (see
    // CarPlayFeatureFlags.suppressesStandardNotification); enabling the writer
    // alone must never silence message notifications.
    if (CarPlayFeatureFlags.fromEnv().suppressesStandardNotification &&
        message.text.trim().isNotEmpty) {
      AppLogging.ble(
        'BackgroundMessageProcessor: CarPlay banner will post, '
        'standard notification suppressed for ${message.id}',
      );
      notifiedMessageIds.add(message.id);
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Master toggle.
      if (!(prefs.getBool(_kMasterToggle) ?? true)) return;

      // Respect per-channel mute. Broadcasts only - a DM carries a channel
      // index but must never be silenced by a channel mute. A broadcast with an
      // unresolved channel index is treated as the primary channel (0).
      final muteChannelIndex = muteIndexForMessage(
        isBroadcast: message.isBroadcast,
        channel: message.channel,
      );
      if (muteChannelIndex != null &&
          isChannelMutedInPrefs(prefs, muteChannelIndex)) {
        AppLogging.ble(
          'BackgroundMessageProcessor: channel $muteChannelIndex is '
          'muted, skipping notification',
        );
        return;
      }

      // Channel messages are broadcasts (to == 0xFFFFFFFF). This includes
      // Primary Channel (index 0) which was previously excluded by the
      // `channel > 0` heuristic.
      final isChannelMessage = message.isBroadcast;

      // Per-type notification toggle from Settings → Notifications.
      if (isChannelMessage) {
        if (!(prefs.getBool(_kChannelToggle) ?? true)) return;
      } else {
        if (!(prefs.getBool(_kDmToggle) ?? true)) return;
      }

      final ns = NotificationService();
      final displayName =
          senderLongName ?? '!${message.from.toRadixString(16).toUpperCase()}';

      if (isChannelMessage) {
        // Channel names are not available in the background (stored in
        // ProtocolService, a provider-bound object). Use "Channel N" as
        // a best-effort label.
        final channelIndex = message.channel ?? 0;
        final channelName =
            'Channel $channelIndex'; // lint-allow: hardcoded-string
        await ns.showChannelMessageNotification(
          senderName: displayName,
          senderShortName: senderShortName,
          channelName: channelName,
          message: message.text,
          channelIndex: channelIndex,
          fromNodeNum: message.from,
          replyPacketId: message.packetId,
        );
      } else {
        await ns.showNewMessageNotification(
          senderName: displayName,
          senderShortName: senderShortName,
          message: message.text,
          fromNodeNum: message.from,
          replyPacketId: message.packetId,
        );
      }

      notifiedMessageIds.add(message.id);
      AppLogging.ble(
        'BackgroundMessageProcessor: notification dispatched for '
        '${message.id} (${isChannelMessage ? "channel" : "DM"})',
      );
    } catch (e) {
      AppLogging.ble('BackgroundMessageProcessor: notification error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Public accessors for notification dispatch (W2.2)
  // ---------------------------------------------------------------------------

  /// Whether the processor has been initialised.
  bool get isInitialized => _initialized;

  /// Whether the processor is currently listening to the data stream.
  bool get isRunning => _running;

  /// The message database used for persistence. `null` before [init].
  MessageDatabase? get messageDb => _messageDb;

  /// The identity resolver. `null` before [init].
  BackgroundIdentityResolver? get identityResolver => _identityResolver;
}
