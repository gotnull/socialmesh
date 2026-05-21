// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Capability flags consumed by the Watch UI to decide which surfaces to
/// render and which controls to gate. The phone derives every flag from the
/// active protocol + readiness state; the Watch never inspects protocol kind
/// directly.
class WatchCompanionCapabilities {
  const WatchCompanionCapabilities({
    required this.canQuickReply,
    required this.canSendImOk,
    required this.canSendLocationIntent,
    required this.canShowNodes,
    required this.canShowInbox,
  });

  final bool canQuickReply;
  final bool canSendImOk;

  /// Always false in v1: MESH_SIGNALS_V0_1 explicitly bars a GPS payload.
  /// Reserved for a future signal extension; documented as v2 in the plan.
  final bool canSendLocationIntent;

  final bool canShowNodes;
  final bool canShowInbox;

  /// All capabilities off. Used when no protocol is active or the bridge is
  /// disabled by feature flag.
  static const WatchCompanionCapabilities none = WatchCompanionCapabilities(
    canQuickReply: false,
    canSendImOk: false,
    canSendLocationIntent: false,
    canShowNodes: false,
    canShowInbox: false,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'canQuickReply': canQuickReply,
    'canSendImOk': canSendImOk,
    'canSendLocationIntent': canSendLocationIntent,
    'canShowNodes': canShowNodes,
    'canShowInbox': canShowInbox,
  };

  factory WatchCompanionCapabilities.fromJson(Map<String, dynamic> json) {
    return WatchCompanionCapabilities(
      canQuickReply: json['canQuickReply'] as bool,
      canSendImOk: json['canSendImOk'] as bool,
      canSendLocationIntent: json['canSendLocationIntent'] as bool,
      canShowNodes: json['canShowNodes'] as bool,
      canShowInbox: json['canShowInbox'] as bool,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WatchCompanionCapabilities &&
          other.canQuickReply == canQuickReply &&
          other.canSendImOk == canSendImOk &&
          other.canSendLocationIntent == canSendLocationIntent &&
          other.canShowNodes == canShowNodes &&
          other.canShowInbox == canShowInbox;

  @override
  int get hashCode => Object.hash(
    canQuickReply,
    canSendImOk,
    canSendLocationIntent,
    canShowNodes,
    canShowInbox,
  );

  @override
  String toString() =>
      'WatchCompanionCapabilities('
      'reply: $canQuickReply, ok: $canSendImOk, loc: $canSendLocationIntent, '
      'nodes: $canShowNodes, inbox: $canShowInbox)';
}
