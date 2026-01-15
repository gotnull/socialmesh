import 'package:uuid/uuid.dart';

/// A canned (quick) response for fast messaging
class CannedResponse {
  final String id;
  final String text;
  final int sortOrder;
  final bool isDefault;

  CannedResponse({
    String? id,
    required this.text,
    this.sortOrder = 0,
    this.isDefault = false,
  }) : id = id ?? const Uuid().v4();

  CannedResponse copyWith({
    String? id,
    String? text,
    int? sortOrder,
    bool? isDefault,
  }) {
    return CannedResponse(
      id: id ?? this.id,
      text: text ?? this.text,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'sortOrder': sortOrder,
      'isDefault': isDefault,
    };
  }

  factory CannedResponse.fromJson(Map<String, dynamic> json) {
    return CannedResponse(
      id: json['id'] as String,
      text: json['text'] as String,
      sortOrder: json['sortOrder'] as int? ?? 0,
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  @override
  String toString() => 'CannedResponse(text: $text)';
}

/// Default canned responses
class DefaultCannedResponses {
  static List<CannedResponse> get all => [
    CannedResponse(id: 'default_ok', text: 'OK', sortOrder: 0, isDefault: true),
    CannedResponse(
      id: 'default_yes',
      text: 'Yes',
      sortOrder: 1,
      isDefault: true,
    ),
    CannedResponse(id: 'default_no', text: 'No', sortOrder: 2, isDefault: true),
    CannedResponse(
      id: 'default_omw',
      text: 'On my way',
      sortOrder: 3,
      isDefault: true,
    ),
    CannedResponse(
      id: 'default_help',
      text: 'Need help',
      sortOrder: 4,
      isDefault: true,
    ),
    CannedResponse(
      id: 'default_safe',
      text: "I'm safe",
      sortOrder: 5,
      isDefault: true,
    ),
    CannedResponse(
      id: 'default_wait',
      text: 'Wait for me',
      sortOrder: 6,
      isDefault: true,
    ),
    CannedResponse(
      id: 'default_thanks',
      text: 'Thanks!',
      sortOrder: 7,
      isDefault: true,
    ),
  ];
}
