// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/logging.dart';

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
/// Messages are stored per-conversation (keyed by contact pubkey hex or channel index).
class MeshCoreMessageStore {
  static const String _contactPrefix = 'meshcore_messages_contact_';
  static const String _channelPrefix = 'meshcore_messages_channel_';
  static const int _maxMessagesPerConversation = 500;

  SharedPreferences? _prefs;

  MeshCoreMessageStore();

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  SharedPreferences get _preferences {
    if (_prefs == null) {
      throw StateError('MeshCoreMessageStore not initialized');
    }
    return _prefs!;
  }

  /// Save messages for a contact conversation.
  Future<void> saveContactMessages(
    String contactKeyHex,
    List<MeshCoreStoredMessage> messages,
  ) async {
    await init();
    final key = '$_contactPrefix$contactKeyHex';
    final trimmed = _trimMessages(messages);
    final jsonList = trimmed.map((m) => m.toJson()).toList();
    await _preferences.setString(key, jsonEncode(jsonList));
    AppLogging.storage(
      'Saved ${trimmed.length} messages for contact $contactKeyHex',
    );
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
  /// store's per-contact partition key) — used as the recipient
  /// prefix for outbound MMFs in the backfill.
  Future<List<MeshCoreStoredMessage>> loadContactMessages(
    String contactKeyHex,
  ) async {
    await init();
    final key = '$_contactPrefix$contactKeyHex';
    final jsonString = _preferences.getString(key);
    if (jsonString == null) return [];

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
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
    await init();
    final key = '$_channelPrefix$channelIndex';
    final trimmed = _trimMessages(messages);
    final jsonList = trimmed.map((m) => m.toJson()).toList();
    await _preferences.setString(key, jsonEncode(jsonList));
    AppLogging.storage(
      'Saved ${trimmed.length} messages for channel $channelIndex',
    );
  }

  /// Load messages for a channel conversation.
  ///
  /// D33: pre-D33 records get an MMF backfilled at parse time when
  /// `channelIndex` and `timestamp` (firmware-supplied seconds) are
  /// present — the same fields the receiver-side D19 deterministic
  /// id is derived from, so this is exactly the cross-device-stable
  /// data the MMF needs. Idempotent: post-D33 records with an
  /// existing `mmf` are not mutated.
  Future<List<MeshCoreStoredMessage>> loadChannelMessages(
    int channelIndex,
  ) async {
    await init();
    final key = '$_channelPrefix$channelIndex';
    final jsonString = _preferences.getString(key);
    if (jsonString == null) return [];

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
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
  /// outbound records we use the partition's `contactKeyHex` —
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
  /// Inbound records use `senderKey` (the OTHER end's pubkey from
  /// the receiver's perspective).
  /// Outbound records use the partition's [contactKeyHex] (the
  /// recipient's pubkey from the sender's perspective).
  /// Both branches converge on the same per-pair MMF.
  ///
  /// Idempotent + side-effect-free. Records that lack the necessary
  /// data (e.g. inbound with empty `senderKey`) stay `mmf = null`.
  MeshCoreStoredMessage _backfillContactMmf(
    MeshCoreStoredMessage m,
    String contactKeyHex,
  ) {
    if (m.mmf != null) return m;

    // Pick the source of the 6-byte peer prefix. Inbound: senderKey.
    // Outbound: the partition's full contact pubkey hex.
    String? prefixHex;
    if (m.isOutgoing) {
      if (contactKeyHex.length >= 12) {
        prefixHex = contactKeyHex.substring(0, 12).toLowerCase();
      }
    } else {
      if (m.senderKey.length >= 6) {
        prefixHex = m.senderKey
            .sublist(0, 6)
            .map((b) => b.toRadixString(16).padLeft(2, '0'))
            .join();
      }
    }
    if (prefixHex == null) return m;
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
    await init();
    await _preferences.remove('$_contactPrefix$contactKeyHex');
  }

  /// Clear messages for a channel.
  Future<void> clearChannelMessages(int channelIndex) async {
    await init();
    await _preferences.remove('$_channelPrefix$channelIndex');
  }

  /// Clear all MeshCore messages.
  Future<void> clearAll() async {
    await init();
    final keys = _preferences.getKeys();
    for (final key in keys) {
      if (key.startsWith(_contactPrefix) || key.startsWith(_channelPrefix)) {
        await _preferences.remove(key);
      }
    }
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
