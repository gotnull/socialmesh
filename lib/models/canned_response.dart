// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:uuid/uuid.dart';
import 'package:socialmesh/l10n/l10n_utils.dart';

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
  static List<CannedResponse> get all {
    final l10n = safeL10n();
    return [
      CannedResponse(
        id: 'default_ok',
        text: l10n.cannedResponseOk,
        sortOrder: 0,
        isDefault: true,
      ),
      CannedResponse(
        id: 'default_yes',
        text: l10n.cannedResponseYes,
        sortOrder: 1,
        isDefault: true,
      ),
      CannedResponse(
        id: 'default_no',
        text: l10n.cannedResponseNo,
        sortOrder: 2,
        isDefault: true,
      ),
      CannedResponse(
        id: 'default_omw',
        text: l10n.cannedResponseOnMyWay,
        sortOrder: 3,
        isDefault: true,
      ),
      CannedResponse(
        id: 'default_help',
        text: l10n.cannedResponseNeedHelp,
        sortOrder: 4,
        isDefault: true,
      ),
      CannedResponse(
        id: 'default_safe',
        text: l10n.cannedResponseImSafe,
        sortOrder: 5,
        isDefault: true,
      ),
      CannedResponse(
        id: 'default_wait',
        text: l10n.cannedResponseWaitForMe,
        sortOrder: 6,
        isDefault: true,
      ),
      CannedResponse(
        id: 'default_thanks',
        text: l10n.cannedResponseThanks,
        sortOrder: 7,
        isDefault: true,
      ),
    ];
  }
}
