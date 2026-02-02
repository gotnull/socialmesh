// SPDX-License-Identifier: GPL-3.0-or-later

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
  Future<List<MeshCoreStoredMessage>> loadContactMessages(
    String contactKeyHex,
  ) async {
    await init();
    final key = '$_contactPrefix$contactKeyHex';
    final jsonString = _preferences.getString(key);
    if (jsonString == null) return [];

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map(
            (json) =>
                MeshCoreStoredMessage.fromJson(json as Map<String, dynamic>),
          )
          .toList();
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
  Future<List<MeshCoreStoredMessage>> loadChannelMessages(
    int channelIndex,
  ) async {
    await init();
    final key = '$_channelPrefix$channelIndex';
    final jsonString = _preferences.getString(key);
    if (jsonString == null) return [];

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map(
            (json) =>
                MeshCoreStoredMessage.fromJson(json as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      AppLogging.storage('Error loading channel messages: $e');
      return [];
    }
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
