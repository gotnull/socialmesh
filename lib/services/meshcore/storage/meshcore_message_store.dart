// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/logging.dart';
import '../../storage/encrypted_database.dart';

/// Message status for MeshCore messages.
enum MeshCoreMessageStatus { pending, sent, delivered, failed }

/// A stored MeshCore message.
class MeshCoreStoredMessage {
  final String id;
  final Uint8List senderKey;
  final String text;
  final DateTime timestamp;
  final bool isOutgoing;
  final MeshCoreMessageStatus status;
  final String? messageId;
  final int retryCount;
  final Uint8List? expectedAckHash;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final int? tripTimeMs;
  final int? pathLength;
  final Uint8List pathBytes;
  final bool isChannelMessage;
  final int? channelIndex;

  /// Signed link SNR encoded by the firmware in quarter-dB units (D30
  /// inbound metadata). Persisted so the inbound bubble keeps its
  /// SNR readout across cold reloads. Null on outbound or when the
  /// firmware did not surface SNR for this frame.
  final int? snrQuarter;

  /// D33: cross-device MeshCore Message Fingerprint (MMF) for THIS
  /// message. See [`docs/protocol/MESHCORE_REPLIES_D33_IMPLEMENTATION_PLAN.md`]
  /// for derivation rules. Set on inbound at receive time, on outbound
  /// at send time. Null on records that pre-date D33 AND cannot be
  /// safely backfilled (e.g. legacy outbound messages whose recipient
  /// pubkey wasn't preserved in storage).
  ///
  /// Hex-string form: `"01:<idx>:<ts>"` for channel,
  /// `"02:<peerPrefix12hex>:<ts>"` for contact.
  final String? mmf;

  /// D33: MMF of the message THIS message replies to. Null when this
  /// message is not a reply. Resolves to the local target by
  /// string-equal lookup on another stored message's [mmf]. Replies
  /// to messages that aren't in the local store render a fallback
  /// preview ("Reply to a message you don't have").
  final String? replyToMmf;

  MeshCoreStoredMessage({
    required this.id,
    required this.senderKey,
    required this.text,
    required this.timestamp,
    required this.isOutgoing,
    this.status = MeshCoreMessageStatus.pending,
    this.messageId,
    this.retryCount = 0,
    this.expectedAckHash,
    this.sentAt,
    this.deliveredAt,
    this.tripTimeMs,
    this.pathLength,
    Uint8List? pathBytes,
    this.isChannelMessage = false,
    this.channelIndex,
    this.snrQuarter,
    this.mmf,
    this.replyToMmf,
  }) : pathBytes = pathBytes ?? Uint8List(0);

  String get senderKeyHex => _bytesToHex(senderKey);

  MeshCoreStoredMessage copyWith({
    MeshCoreMessageStatus? status,
    int? retryCount,
    Uint8List? expectedAckHash,
    DateTime? sentAt,
    DateTime? deliveredAt,
    int? tripTimeMs,
    int? pathLength,
    Uint8List? pathBytes,
    int? snrQuarter,
    String? mmf,
    String? replyToMmf,
  }) {
    return MeshCoreStoredMessage(
      id: id,
      senderKey: senderKey,
      text: text,
      timestamp: timestamp,
      isOutgoing: isOutgoing,
      status: status ?? this.status,
      messageId: messageId,
      retryCount: retryCount ?? this.retryCount,
      expectedAckHash: expectedAckHash ?? this.expectedAckHash,
      sentAt: sentAt ?? this.sentAt,
      deliveredAt: deliveredAt ?? this.deliveredAt,
      tripTimeMs: tripTimeMs ?? this.tripTimeMs,
      pathLength: pathLength ?? this.pathLength,
      pathBytes: pathBytes ?? this.pathBytes,
      isChannelMessage: isChannelMessage,
      channelIndex: channelIndex,
      snrQuarter: snrQuarter ?? this.snrQuarter,
      mmf: mmf ?? this.mmf,
      replyToMmf: replyToMmf ?? this.replyToMmf,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderKey': base64Encode(senderKey),
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isOutgoing': isOutgoing,
      'status': status.index,
      'messageId': messageId,
      'retryCount': retryCount,
      'expectedAckHash': expectedAckHash != null
          ? base64Encode(expectedAckHash!)
          : null,
      'sentAt': sentAt?.millisecondsSinceEpoch,
      'deliveredAt': deliveredAt?.millisecondsSinceEpoch,
      'tripTimeMs': tripTimeMs,
      'pathLength': pathLength,
      'pathBytes': pathBytes.isNotEmpty ? base64Encode(pathBytes) : null,
      'isChannelMessage': isChannelMessage,
      'channelIndex': channelIndex,
      'snrQuarter': snrQuarter,
      // D33: MMF + replyToMmf round-trip. Optional; legacy records
      // (pre-D33) load with both null and stay readable.
      'mmf': mmf,
      'replyToMmf': replyToMmf,
    };
  }

  factory MeshCoreStoredMessage.fromJson(Map<String, dynamic> json) {
    return MeshCoreStoredMessage(
      id: json['id'] as String,
      senderKey: Uint8List.fromList(base64Decode(json['senderKey'] as String)),
      text: json['text'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      isOutgoing: json['isOutgoing'] as bool,
      status: MeshCoreMessageStatus.values[json['status'] as int],
      messageId: json['messageId'] as String?,
      retryCount: json['retryCount'] as int? ?? 0,
      expectedAckHash: json['expectedAckHash'] != null
          ? Uint8List.fromList(base64Decode(json['expectedAckHash'] as String))
          : null,
      sentAt: json['sentAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['sentAt'] as int)
          : null,
      deliveredAt: json['deliveredAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['deliveredAt'] as int)
          : null,
      tripTimeMs: json['tripTimeMs'] as int?,
      pathLength: json['pathLength'] as int?,
      pathBytes: json['pathBytes'] != null
          ? Uint8List.fromList(base64Decode(json['pathBytes'] as String))
          : null,
      isChannelMessage: json['isChannelMessage'] as bool? ?? false,
      channelIndex: json['channelIndex'] as int?,
      snrQuarter: json['snrQuarter'] as int?,
      // D33: tolerate missing fields on pre-D33 records. The
      // store-level `_backfillMmf` post-load step computes MMFs
      // deterministically when enough stable fields exist
      // (channelIndex + timestamp for channel; senderKey + timestamp
      // for inbound contact). Outbound contact records pre-D33 have
      // no recipient pubkey persisted and thus stay `mmf = null`.
      mmf: json['mmf'] as String?,
      replyToMmf: json['replyToMmf'] as String?,
    );
  }

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

/// Storage service for MeshCore messages.
///
/// Messages are stored per conversation (a contact's public key hex or a
/// channel index) in the encrypted `meshcore_messages.db`, one row per
/// message holding its [MeshCoreStoredMessage.toJson] body in conversation
/// order. Every instance shares one database handle. The database is not
/// radio-scoped yet: MeshCore scoping needs the connect path to move the
/// scope (docs/engineering/RADIO_SCOPED_STORAGE.md).
///
/// Builds that kept messages in SharedPreferences are migrated on first
/// open, one conversation at a time: copied in a transaction, then the
/// preference key is removed. A key whose conversation already has rows is
/// only removed, so a migration cut short never duplicates or loses data.
class MeshCoreMessageStore {
  static const String _dbName = 'meshcore_messages.db';
  static const int _dbVersion = 1;
  // SharedPreferences keys used before the database, read only to migrate.
  static const String _contactPrefix = 'meshcore_messages_contact_';
  static const String _channelPrefix = 'meshcore_messages_channel_';
  static const int _maxMessagesPerConversation = 500;

  static _MessageBackend? _backend;
  static Future<_MessageBackend>? _opening;
  static _MessageBackend Function()? _testBackend;

  MeshCoreMessageStore();

  /// Points every store at a fresh database at [path] opened with
  /// [factory] (the ffi factory in tests), closing the previous one.
  @visibleForTesting
  static Future<void> debugUseDatabaseAt(
    String path, {
    required DatabaseFactory factory,
  }) async {
    await _replaceBackend(
      () => _SqliteBackend.pending(
        factory.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: _dbVersion,
            onCreate: _SqliteBackend.createTables,
            singleInstance: false,
          ),
        ),
      ),
    );
  }

  /// Points every store at a fresh in-memory backend. Widget tests run
  /// under fake async, where a real database never answers.
  @visibleForTesting
  static Future<void> debugUseInMemory() => _replaceBackend(_MemoryBackend.new);

  static Future<void> _replaceBackend(_MessageBackend Function() make) async {
    final previous = _backend;
    _backend = null;
    _opening = null;
    _testBackend = make;
    await previous?.close();
  }

  Future<void> init() async {
    await _store();
  }

  static Future<_MessageBackend> _store() async {
    final ready = _backend;
    if (ready != null) return ready;
    final pending = _opening ??= _open();
    try {
      return _backend = await pending;
    } catch (_) {
      // Let the next call try again rather than caching the failure.
      if (identical(_opening, pending)) _opening = null;
      rethrow;
    }
  }

  static Future<_MessageBackend> _open() async {
    final make = _testBackend;
    final _MessageBackend backend;
    if (make != null) {
      backend = make();
    } else {
      final dir = await getApplicationDocumentsDirectory();
      backend = _SqliteBackend(
        await openEncryptedDatabase(
          p.join(dir.path, _dbName),
          version: _dbVersion,
          onCreate: _SqliteBackend.createTables,
        ),
      );
    }
    await _migrateFromPreferences(backend);
    return backend;
  }

  static Future<void> _migrateFromPreferences(_MessageBackend backend) async {
    final SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      AppLogging.storage(
        'event=meshcore.store.migrate.skipped reason=${e.runtimeType}',
      );
      return;
    }
    final keys = prefs
        .getKeys()
        .where(
          (k) => k.startsWith(_contactPrefix) || k.startsWith(_channelPrefix),
        )
        .toList();
    var moved = 0;
    for (final key in keys) {
      final partition = key.startsWith(_contactPrefix)
          ? _contactPartition(key.substring(_contactPrefix.length))
          : 'h:${key.substring(_channelPrefix.length)}';
      try {
        final existing = await backend.load(partition);
        final raw = prefs.getString(key);
        if (existing.isEmpty && raw != null) {
          final entries = jsonDecode(raw) as List<dynamic>;
          await backend.replace(partition, [
            for (final entry in entries) jsonEncode(entry),
          ]);
          moved++;
        }
        await prefs.remove(key);
      } catch (e) {
        // The preference key stays, so the next launch tries again.
        AppLogging.storage(
          'event=meshcore.store.migrate.failed reason=${e.runtimeType}',
        );
      }
    }
    if (keys.isNotEmpty) {
      AppLogging.storage(
        'event=meshcore.store.migrated conversations=$moved keys=${keys.length}',
      );
    }
  }

  static String _contactPartition(String contactKeyHex) => 'c:$contactKeyHex';

  static String _channelPartition(int channelIndex) => 'h:$channelIndex';

  Future<void> _savePartition(
    String partition,
    List<MeshCoreStoredMessage> messages,
  ) async {
    final backend = await _store();
    await backend.replace(partition, [
      for (final m in _trimMessages(messages)) jsonEncode(m.toJson()),
    ]);
  }

  // Stored bodies in conversation order; a body that is not valid JSON is
  // returned as null so the caller skips it like any malformed record.
  Future<List<Object?>> _loadPartition(String partition) async {
    final backend = await _store();
    return [
      for (final body in await backend.load(partition))
        () {
          try {
            return jsonDecode(body);
          } on FormatException {
            return null;
          }
        }(),
    ];
  }

  /// Save messages for a contact conversation.
  Future<void> saveContactMessages(
    String contactKeyHex,
    List<MeshCoreStoredMessage> messages,
  ) async {
    await _savePartition(_contactPartition(contactKeyHex), messages);
  }

  /// Load messages for a contact conversation.
  ///
  /// D33: any record with `mmf == null` AFTER the JSON parse is
  /// passed through [_backfillContactMmf] which deterministically
  /// derives the MMF from already-stored fields when safe. Records
  /// that don't have enough stable data to derive an MMF (e.g.
  /// pre-D33 outbound contact records that never persisted the
  /// recipient pubkey) load with `mmf = null` and the chat surface
  /// hides Reply for those messages. Backfill is idempotent: post-
  /// D33 records with an existing `mmf` are not mutated.
  ///
  /// [contactKeyHex] is the FULL 32-byte contact pubkey hex (the
  /// store's per-contact partition key) - used as the recipient
  /// prefix for outbound MMFs in the backfill.
  Future<List<MeshCoreStoredMessage>> loadContactMessages(
    String contactKeyHex,
  ) async {
    try {
      final jsonList = await _loadPartition(_contactPartition(contactKeyHex));
      final out = <MeshCoreStoredMessage>[];
      for (final entry in jsonList) {
        if (entry is! Map<String, dynamic>) {
          AppLogging.storage(
            'event=meshcore.store.skip reason=non_object_entry '
            'partition=contact',
          );
          continue;
        }
        try {
          final parsed = MeshCoreStoredMessage.fromJson(entry);
          out.add(_backfillContactMmf(parsed, contactKeyHex));
        } catch (e) {
          // D33 migration rule: malformed legacy records are skipped
          // with a safe log, the rest of the partition stays
          // readable. We do NOT log the message text or any pubkey.
          AppLogging.storage(
            'event=meshcore.store.skip reason=malformed_record '
            'partition=contact err=${e.runtimeType}',
          );
          continue;
        }
      }
      return out;
    } catch (e) {
      AppLogging.storage('Error loading contact messages: $e');
      return [];
    }
  }

  /// Save messages for a channel conversation.
  Future<void> saveChannelMessages(
    int channelIndex,
    List<MeshCoreStoredMessage> messages,
  ) async {
    await _savePartition(_channelPartition(channelIndex), messages);
  }

  /// Load messages for a channel conversation.
  ///
  /// D33: pre-D33 records get an MMF backfilled at parse time when
  /// `channelIndex` and `timestamp` (firmware-supplied seconds) are
  /// present - the same fields the receiver-side D19 deterministic
  /// id is derived from, so this is exactly the cross-device-stable
  /// data the MMF needs. Idempotent: post-D33 records with an
  /// existing `mmf` are not mutated.
  Future<List<MeshCoreStoredMessage>> loadChannelMessages(
    int channelIndex,
  ) async {
    try {
      final jsonList = await _loadPartition(_channelPartition(channelIndex));
      final out = <MeshCoreStoredMessage>[];
      for (final entry in jsonList) {
        if (entry is! Map<String, dynamic>) {
          AppLogging.storage(
            'event=meshcore.store.skip reason=non_object_entry '
            'partition=channel',
          );
          continue;
        }
        try {
          final parsed = MeshCoreStoredMessage.fromJson(entry);
          out.add(_backfillChannelMmf(parsed, channelIndex));
        } catch (e) {
          AppLogging.storage(
            'event=meshcore.store.skip reason=malformed_record '
            'partition=channel err=${e.runtimeType}',
          );
          continue;
        }
      }
      return out;
    } catch (e) {
      AppLogging.storage('Error loading channel messages: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // D43-A1: windowed loads for paging older history
  // ---------------------------------------------------------------------------

  // Load older messages for a contact partition with a compound cursor.
  //
  // Cursor semantics:
  //   - `before == null` returns the newest [limit] messages.
  //   - `before != null` requires [beforeId]; throws [ArgumentError]
  //     otherwise.
  //   - With both supplied, a record qualifies iff
  //       `timestamp < before` OR
  //       `(timestamp == before AND id < beforeId)`.
  //     Strict-less, so the boundary record is never re-included.
  //
  // Result is ordered ascending by `(timestamp, id)` so callers can
  // prepend directly to their chat render list. [limit] is clamped to
  // the partition cap.
  Future<List<MeshCoreStoredMessage>> loadContactMessagesBefore(
    String contactKeyHex, {
    DateTime? before,
    String? beforeId,
    int limit = 50,
  }) async {
    _assertCursorShape(before: before, beforeId: beforeId);
    final clamped = _clampLimit(limit);
    final all = await loadContactMessages(contactKeyHex);
    return _windowBefore(
      all,
      before: before,
      beforeId: beforeId,
      limit: clamped,
    );
  }

  // Load older messages for a channel partition. Mirrors
  // [loadContactMessagesBefore] for the channel-indexed key space.
  Future<List<MeshCoreStoredMessage>> loadChannelMessagesBefore(
    int channelIndex, {
    DateTime? before,
    String? beforeId,
    int limit = 50,
  }) async {
    _assertCursorShape(before: before, beforeId: beforeId);
    final clamped = _clampLimit(limit);
    final all = await loadChannelMessages(channelIndex);
    return _windowBefore(
      all,
      before: before,
      beforeId: beforeId,
      limit: clamped,
    );
  }

  void _assertCursorShape({DateTime? before, String? beforeId}) {
    if (before != null && beforeId == null) {
      throw ArgumentError(
        'beforeId is required when before is non-null (compound cursor)',
      );
    }
  }

  int _clampLimit(int limit) {
    if (limit <= 0) return 0;
    return limit > _maxMessagesPerConversation
        ? _maxMessagesPerConversation
        : limit;
  }

  List<MeshCoreStoredMessage> _windowBefore(
    List<MeshCoreStoredMessage> all, {
    required DateTime? before,
    required String? beforeId,
    required int limit,
  }) {
    if (limit == 0) return const [];
    // Sort ascending defensively. The on-disk JSON order is not
    // guaranteed sorted until the 500-row trim writes a sort back,
    // and `addContactMessage` / `addChannelMessage` simply append on
    // the no-trim path.
    final sorted = [...all]
      ..sort((a, b) {
        final t = a.timestamp.compareTo(b.timestamp);
        return t != 0 ? t : a.id.compareTo(b.id);
      });
    Iterable<MeshCoreStoredMessage> filtered;
    if (before == null) {
      filtered = sorted;
    } else {
      filtered = sorted.where((m) {
        final t = m.timestamp.compareTo(before);
        if (t < 0) return true;
        if (t > 0) return false;
        return m.id.compareTo(beforeId!) < 0;
      });
    }
    final list = filtered.toList();
    if (list.length <= limit) return list;
    // Take the newest [limit] rows from the qualifying set so the
    // returned slice is the "most-recent older page" the chat screen
    // wants for "load older messages".
    return list.sublist(list.length - limit);
  }

  // ---------------------------------------------------------------------------
  // D33: deterministic MMF backfill for pre-D33 records
  // ---------------------------------------------------------------------------

  /// Lowercase-hex string MMF for a channel record, or null when
  /// the input doesn't carry enough data for a safe derivation.
  /// Format mirrors `MeshCoreMmf.toStableString()` so the in-memory
  /// codec and the store agree byte-for-byte.
  static String? _channelMmfString({
    required int channelIndex,
    required DateTime timestamp,
  }) {
    if (channelIndex < 0 || channelIndex > 0xFF) return null;
    final tsSec = timestamp.millisecondsSinceEpoch ~/ 1000;
    if (tsSec < 0 || tsSec > 0xFFFFFFFF) return null;
    final idxHex = channelIndex.toRadixString(16).padLeft(2, '0');
    final tsHex = tsSec.toRadixString(16).padLeft(8, '0');
    return '01:$idxHex:$tsHex';
  }

  /// Lowercase-hex string MMF for a contact record, or null when
  /// the prefix or timestamp can't be safely derived.
  ///
  /// [peerPubkeyPrefixHex] is the OTHER party's first 6 bytes (12
  /// hex chars). For inbound records we use `senderKey`; for
  /// outbound records we use the partition's `contactKeyHex` -
  /// both ends of the conversation see the same MMF.
  static String? _contactMmfString({
    required String peerPubkeyPrefixHex,
    required DateTime timestamp,
  }) {
    if (peerPubkeyPrefixHex.length != 12) return null;
    if (!_isHex(peerPubkeyPrefixHex)) return null;
    final tsSec = timestamp.millisecondsSinceEpoch ~/ 1000;
    if (tsSec < 0 || tsSec > 0xFFFFFFFF) return null;
    final tsHex = tsSec.toRadixString(16).padLeft(8, '0');
    return '02:${peerPubkeyPrefixHex.toLowerCase()}:$tsHex';
  }

  static bool _isHex(String s) {
    final re = RegExp(r'^[0-9a-fA-F]+$');
    return re.hasMatch(s);
  }

  /// Backfill MMF on a channel record when missing AND the input has
  /// enough stable fields. Returns the input unchanged when MMF is
  /// already present (idempotency) or cannot be safely derived.
  MeshCoreStoredMessage _backfillChannelMmf(
    MeshCoreStoredMessage m,
    int channelIndex,
  ) {
    if (m.mmf != null) return m;
    final mmf = _channelMmfString(
      channelIndex: channelIndex,
      timestamp: m.timestamp,
    );
    if (mmf == null) return m;
    return m.copyWith(mmf: mmf);
  }

  /// Backfill MMF on a contact record when missing AND the input has
  /// enough stable fields.
  ///
  /// **Author-prefix rule** (post-2026-05-07 fix): both inbound and
  /// outbound records derive the MMF from `senderKey` - the chat
  /// surface persists `senderKey` as the AUTHOR's pubkey for both
  /// directions (inbound: contact who wrote it; outbound: self via
  /// `selfInfo.pubKey`). This guarantees both ends of a conversation
  /// derive `02:<author_prefix>:<ts>` for the same logical message.
  ///
  /// Pre-fix the outbound branch used the partition's contact pubkey
  /// (the recipient), which produced asymmetric MMFs and broke
  /// cross-device reply target resolution. The [contactKeyHex]
  /// parameter is retained for API stability but no longer
  /// participates in derivation.
  ///
  /// Idempotent + side-effect-free. Records that lack a usable
  /// senderKey (length < 6 OR all-zero bytes from a legacy persist
  /// where `selfInfo.pubKey` was unavailable) stay `mmf = null`.
  MeshCoreStoredMessage _backfillContactMmf(
    MeshCoreStoredMessage m,
    String contactKeyHex,
  ) {
    if (m.mmf != null) return m;
    if (m.senderKey.length < 6) return m;
    final headSix = m.senderKey.sublist(0, 6);
    // Sentinel guard: legacy outbound records persisted before
    // selfInfo loaded saved a Uint8List(32) of zeros. Those cannot
    // be safely backfilled to a meaningful MMF, so skip rather
    // than invent a `02:000000000000:<ts>` that won't resolve.
    if (headSix.every((b) => b == 0)) return m;
    final prefixHex = headSix
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final mmf = _contactMmfString(
      peerPubkeyPrefixHex: prefixHex,
      timestamp: m.timestamp,
    );
    if (mmf == null) return m;
    return m.copyWith(mmf: mmf);
  }

  /// Add or update a single message to a contact conversation.
  Future<void> addContactMessage(
    String contactKeyHex,
    MeshCoreStoredMessage message,
  ) async {
    final messages = await loadContactMessages(contactKeyHex);
    final index = messages.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      messages[index] = message;
    } else {
      messages.add(message);
    }
    await saveContactMessages(contactKeyHex, messages);
  }

  /// Add or update a single message to a channel conversation.
  Future<void> addChannelMessage(
    int channelIndex,
    MeshCoreStoredMessage message,
  ) async {
    final messages = await loadChannelMessages(channelIndex);
    final index = messages.indexWhere((m) => m.id == message.id);
    if (index >= 0) {
      messages[index] = message;
    } else {
      messages.add(message);
    }
    await saveChannelMessages(channelIndex, messages);
  }

  /// Delete a single message from a contact conversation by id.
  /// No-op when [messageId] is not present. Used by the D30 long-press
  /// "Delete locally" action; emits no wire frame.
  Future<bool> deleteContactMessage(
    String contactKeyHex,
    String messageId,
  ) async {
    final messages = await loadContactMessages(contactKeyHex);
    final initial = messages.length;
    messages.removeWhere((m) => m.id == messageId);
    if (messages.length == initial) return false;
    await saveContactMessages(contactKeyHex, messages);
    return true;
  }

  /// Delete a single message from a channel conversation by id.
  /// No-op when [messageId] is not present.
  Future<bool> deleteChannelMessage(int channelIndex, String messageId) async {
    final messages = await loadChannelMessages(channelIndex);
    final initial = messages.length;
    messages.removeWhere((m) => m.id == messageId);
    if (messages.length == initial) return false;
    await saveChannelMessages(channelIndex, messages);
    return true;
  }

  /// Clear messages for a contact.
  Future<void> clearContactMessages(String contactKeyHex) async {
    final backend = await _store();
    await backend.remove(_contactPartition(contactKeyHex));
  }

  /// Clear messages for a channel.
  Future<void> clearChannelMessages(int channelIndex) async {
    final backend = await _store();
    await backend.remove(_channelPartition(channelIndex));
  }

  /// Full public key hex of every contact with stored messages.
  Future<List<String>> contactKeys() async {
    final backend = await _store();
    return [
      for (final partition in await backend.partitions())
        if (partition.startsWith('c:')) partition.substring(2),
    ];
  }

  /// Clear all MeshCore messages.
  Future<void> clearAll() async {
    final backend = await _store();
    await backend.removeAll();
    AppLogging.storage('Cleared all MeshCore messages');
  }

  /// Trim messages to max count, keeping newest.
  List<MeshCoreStoredMessage> _trimMessages(
    List<MeshCoreStoredMessage> messages,
  ) {
    if (messages.length <= _maxMessagesPerConversation) {
      return messages;
    }
    // Sort by timestamp descending, take newest
    final sorted = List<MeshCoreStoredMessage>.from(messages)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(_maxMessagesPerConversation).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }
}

// Where conversations are kept: each is an ordered list of JSON bodies.
abstract class _MessageBackend {
  Future<List<String>> load(String partition);
  Future<void> replace(String partition, List<String> bodies);
  Future<void> remove(String partition);
  Future<List<String>> partitions();
  Future<void> removeAll();
  Future<void> close();
}

class _SqliteBackend implements _MessageBackend {
  _SqliteBackend(Database db) : _db = Future.value(db);
  _SqliteBackend.pending(this._db);

  static const String _table = 'meshcore_messages';
  final Future<Database> _db;

  static Future<void> createTables(Database db, int version) async {
    await db.execute(
      'CREATE TABLE $_table ('
      'partition TEXT NOT NULL, '
      'seq INTEGER NOT NULL, '
      'body TEXT NOT NULL, '
      'PRIMARY KEY (partition, seq))',
    );
  }

  @override
  Future<List<String>> load(String partition) async {
    final rows = await (await _db).query(
      _table,
      columns: ['body'],
      where: 'partition = ?',
      whereArgs: [partition],
      orderBy: 'seq',
    );
    return [for (final row in rows) row['body'] as String];
  }

  @override
  Future<void> replace(String partition, List<String> bodies) async {
    await (await _db).transaction((txn) async {
      await txn.delete(_table, where: 'partition = ?', whereArgs: [partition]);
      final batch = txn.batch();
      for (var i = 0; i < bodies.length; i++) {
        batch.insert(_table, {
          'partition': partition,
          'seq': i,
          'body': bodies[i],
        });
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> remove(String partition) async {
    await (await _db).delete(
      _table,
      where: 'partition = ?',
      whereArgs: [partition],
    );
  }

  @override
  Future<List<String>> partitions() async {
    final rows = await (await _db).rawQuery(
      'SELECT DISTINCT partition FROM $_table',
    );
    return [for (final row in rows) row['partition'] as String];
  }

  @override
  Future<void> removeAll() async {
    await (await _db).delete(_table);
  }

  @override
  Future<void> close() async {
    try {
      await (await _db).close();
    } catch (e) {
      AppLogging.storage(
        'event=meshcore.store.close.failed reason=${e.runtimeType}',
      );
    }
  }
}

class _MemoryBackend implements _MessageBackend {
  final Map<String, List<String>> _data = {};

  @override
  Future<List<String>> load(String partition) async =>
      List.of(_data[partition] ?? const []);

  @override
  Future<void> replace(String partition, List<String> bodies) async {
    if (bodies.isEmpty) {
      _data.remove(partition);
    } else {
      _data[partition] = List.of(bodies);
    }
  }

  @override
  Future<void> remove(String partition) async => _data.remove(partition);

  @override
  Future<List<String>> partitions() async => _data.keys.toList();

  @override
  Future<void> removeAll() async => _data.clear();

  @override
  Future<void> close() async => _data.clear();
}
