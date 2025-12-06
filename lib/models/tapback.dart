import 'package:uuid/uuid.dart';

/// Message tapback reaction
enum TapbackType {
  like('👍'),
  dislike('👎'),
  heart('❤️'),
  laugh('😂'),
  exclamation('‼️'),
  question('❓'),
  poop('💩'),
  wave('👋');

  const TapbackType(this.emoji);
  final String emoji;

  static TapbackType? fromEmoji(String emoji) {
    for (final type in TapbackType.values) {
      if (type.emoji == emoji) return type;
    }
    return null;
  }
}

/// Tapback reaction to a message
class MessageTapback {
  final String id;
  final String messageId;
  final int fromNodeNum;
  final TapbackType type;
  final DateTime timestamp;

  MessageTapback({
    String? id,
    required this.messageId,
    required this.fromNodeNum,
    required this.type,
    DateTime? timestamp,
  }) : id = id ?? const Uuid().v4(),
       timestamp = timestamp ?? DateTime.now();

  factory MessageTapback.fromJson(Map<String, dynamic> json) {
    return MessageTapback(
      id: json['id'] as String?,
      messageId: json['messageId'] as String,
      fromNodeNum: json['fromNodeNum'] as int,
      type: TapbackType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => TapbackType.like,
      ),
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'messageId': messageId,
    'fromNodeNum': fromNodeNum,
    'type': type.name,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };
}

/// Message thread for reply support
class MessageThread {
  final String parentMessageId;
  final List<String> replyMessageIds;

  MessageThread({
    required this.parentMessageId,
    this.replyMessageIds = const [],
  });

  MessageThread copyWith({
    String? parentMessageId,
    List<String>? replyMessageIds,
  }) {
    return MessageThread(
      parentMessageId: parentMessageId ?? this.parentMessageId,
      replyMessageIds: replyMessageIds ?? this.replyMessageIds,
    );
  }

  factory MessageThread.fromJson(Map<String, dynamic> json) {
    return MessageThread(
      parentMessageId: json['parentMessageId'] as String,
      replyMessageIds:
          (json['replyMessageIds'] as List?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'parentMessageId': parentMessageId,
    'replyMessageIds': replyMessageIds,
  };
}
