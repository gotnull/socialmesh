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

/// A configurable tapback option
class TapbackConfig {
  final String id;
  final TapbackType type;
  final String emoji;
  final String label;
  final int sortOrder;
  final bool enabled;

  TapbackConfig({
    String? id,
    required this.type,
    required this.emoji,
    required this.label,
    this.sortOrder = 0,
    this.enabled = true,
  }) : id = id ?? const Uuid().v4();

  TapbackConfig copyWith({
    String? id,
    TapbackType? type,
    String? emoji,
    String? label,
    int? sortOrder,
    bool? enabled,
  }) {
    return TapbackConfig(
      id: id ?? this.id,
      type: type ?? this.type,
      emoji: emoji ?? this.emoji,
      label: label ?? this.label,
      sortOrder: sortOrder ?? this.sortOrder,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'emoji': emoji,
    'label': label,
    'sortOrder': sortOrder,
    'enabled': enabled,
  };

  factory TapbackConfig.fromJson(Map<String, dynamic> json) {
    return TapbackConfig(
      id: json['id'] as String?,
      type: TapbackType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => TapbackType.like,
      ),
      emoji: json['emoji'] as String,
      label: json['label'] as String,
      sortOrder: json['sortOrder'] as int? ?? 0,
      enabled: json['enabled'] as bool? ?? true,
    );
  }
}

/// Default tapback configurations matching Meshtastic iOS
class DefaultTapbacks {
  static List<TapbackConfig> get all => [
    TapbackConfig(
      id: 'default_wave',
      type: TapbackType.wave,
      emoji: '👋',
      label: 'Wave',
      sortOrder: 0,
    ),
    TapbackConfig(
      id: 'default_heart',
      type: TapbackType.heart,
      emoji: '❤️',
      label: 'Heart',
      sortOrder: 1,
    ),
    TapbackConfig(
      id: 'default_like',
      type: TapbackType.like,
      emoji: '👍',
      label: 'Thumbs Up',
      sortOrder: 2,
    ),
    TapbackConfig(
      id: 'default_dislike',
      type: TapbackType.dislike,
      emoji: '👎',
      label: 'Thumbs Down',
      sortOrder: 3,
    ),
    TapbackConfig(
      id: 'default_laugh',
      type: TapbackType.laugh,
      emoji: '🤣',
      label: 'HaHa',
      sortOrder: 4,
    ),
    TapbackConfig(
      id: 'default_exclamation',
      type: TapbackType.exclamation,
      emoji: '‼️',
      label: 'Exclamation',
      sortOrder: 5,
    ),
    TapbackConfig(
      id: 'default_question',
      type: TapbackType.question,
      emoji: '❓',
      label: 'Question',
      sortOrder: 6,
    ),
    TapbackConfig(
      id: 'default_poop',
      type: TapbackType.poop,
      emoji: '💩',
      label: 'Poop',
      sortOrder: 7,
    ),
  ];
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
