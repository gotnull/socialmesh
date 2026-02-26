// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../theme.dart';

/// Categories for knowledge-base articles.
///
/// Each category has a display name, icon, and accent color for the UI.
enum HelpArticleCategory {
  gettingStarted(
    'Getting Started',
    Icons.rocket_launch_outlined,
    AccentColors.green,
  ),
  meshBasics('Mesh Basics', Icons.hub_outlined, AccentColors.cyan),
  channels('Channels & Encryption', Icons.forum_outlined, AccentColors.blue),
  messaging('Messaging', Icons.chat_outlined, AccentColors.green),
  nodes('Nodes & Roles', Icons.hexagon_outlined, AccentColors.yellow),
  device('Device & Radio', Icons.developer_board_outlined, AccentColors.orange),
  network('Network & Maps', Icons.cell_tower, AccentColors.cyan),
  safety('Safety & Rules', Icons.gavel_outlined, AccentColors.red);

  const HelpArticleCategory(this.displayName, this.icon, this.color);

  final String displayName;
  final IconData icon;
  final Color color;

  /// Parse a category from its JSON key (e.g. 'getting-started').
  static HelpArticleCategory fromKey(String key) {
    return switch (key) {
      'getting-started' => HelpArticleCategory.gettingStarted,
      'mesh-basics' => HelpArticleCategory.meshBasics,
      'channels' => HelpArticleCategory.channels,
      'messaging' => HelpArticleCategory.messaging,
      'nodes' => HelpArticleCategory.nodes,
      'device' => HelpArticleCategory.device,
      'network' => HelpArticleCategory.network,
      'safety' => HelpArticleCategory.safety,
      _ => HelpArticleCategory.gettingStarted,
    };
  }

  /// Category key used in manifest.json filenames.
  String get key {
    return switch (this) {
      HelpArticleCategory.gettingStarted => 'getting-started',
      HelpArticleCategory.meshBasics => 'mesh-basics',
      HelpArticleCategory.channels => 'channels',
      HelpArticleCategory.messaging => 'messaging',
      HelpArticleCategory.nodes => 'nodes',
      HelpArticleCategory.device => 'device',
      HelpArticleCategory.network => 'network',
      HelpArticleCategory.safety => 'safety',
    };
  }
}

/// A knowledge-base article entry (loaded from manifest.json).
class HelpArticle {
  final String id;
  final String title;
  final String description;
  final HelpArticleCategory category;
  final String iconName;
  final int order;
  final String filePath;
  final int readingTimeMinutes;

  const HelpArticle({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.iconName,
    required this.order,
    required this.filePath,
    required this.readingTimeMinutes,
  });

  factory HelpArticle.fromJson(Map<String, dynamic> json) {
    return HelpArticle(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: HelpArticleCategory.fromKey(json['category'] as String),
      iconName: json['icon'] as String,
      order: json['order'] as int,
      filePath: json['file'] as String,
      readingTimeMinutes: json['readingTime'] as int? ?? 2,
    );
  }

  /// Material icon from the icon name string in manifest.json.
  IconData get icon {
    return switch (iconName) {
      'radio' => Icons.radio,
      'cell_tower' => Icons.cell_tower,
      'route' => Icons.route,
      'wifi_tethering' => Icons.wifi_tethering,
      'hub' => Icons.hub_outlined,
      'swap_horiz' => Icons.swap_horiz,
      'terrain' => Icons.terrain,
      'compare_arrows' => Icons.compare_arrows,
      'forum' => Icons.forum_outlined,
      'lock' => Icons.lock_outlined,
      'key' => Icons.key_outlined,
      'share' => Icons.share_outlined,
      'chat' => Icons.chat_outlined,
      'near_me' => Icons.near_me_outlined,
      'store_forward' => Icons.move_to_inbox_outlined,
      'check_circle' => Icons.check_circle_outline,
      'hexagon' => Icons.hexagon_outlined,
      'account_tree' => Icons.account_tree_outlined,
      'info' => Icons.info_outlined,
      'developer_board' => Icons.developer_board_outlined,
      'bluetooth' => Icons.bluetooth,
      'public' => Icons.public,
      'settings_input' => Icons.settings_input_antenna,
      'memory' => Icons.memory,
      'signal_cellular' => Icons.signal_cellular_alt,
      'network_check' => Icons.network_check,
      'timeline' => Icons.timeline,
      'radar' => Icons.radar,
      'gavel' => Icons.gavel_outlined,
      'timer' => Icons.timer_outlined,
      'security' => Icons.security_outlined,
      _ => Icons.article_outlined,
    };
  }
}
