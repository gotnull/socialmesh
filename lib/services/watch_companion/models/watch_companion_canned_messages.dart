// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Canonical canned-message keys. These are wire-format identifiers and are
/// frozen for v1; the Watch sends a key and the phone resolves it to a
/// localized body before dispatching down the normal send path.
class WatchCompanionCannedMessageKeys {
  WatchCompanionCannedMessageKeys._();

  static const String onMyWay = 'on_my_way';
  static const String imOk = 'im_ok';
  static const String needHelp = 'need_help';
  static const String atCamp = 'at_camp';
  static const String batteryLow = 'battery_low';
  static const String messageReceived = 'message_received';

  /// Iteration order matches the order rendered on the Watch.
  static const List<String> all = <String>[
    onMyWay,
    imOk,
    needHelp,
    atCamp,
    batteryLow,
    messageReceived,
  ];

  static bool isKnown(String key) => all.contains(key);
}

/// One canned-message row in a watch snapshot. The phone resolves [label]
/// from the active locale before pushing; the Watch renders [label] verbatim.
class WatchCompanionCannedMessage {
  const WatchCompanionCannedMessage({required this.key, required this.label});

  final String key;
  final String label;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'key': key,
    'label': label,
  };

  factory WatchCompanionCannedMessage.fromJson(Map<String, dynamic> json) {
    return WatchCompanionCannedMessage(
      key: json['key'] as String,
      label: json['label'] as String,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchCompanionCannedMessage &&
          other.key == key &&
          other.label == label;

  @override
  int get hashCode => Object.hash(key, label);

  @override
  String toString() => 'WatchCompanionCannedMessage(key: $key, label: $label)';
}
