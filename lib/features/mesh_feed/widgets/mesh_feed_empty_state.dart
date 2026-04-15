// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/widgets/animated_empty_state.dart';

/// Animated empty state for the mesh feed screen.
/// Uses the reusable AnimatedEmptyState widget for consistency across Social screens.
class MeshFeedEmptyState extends StatelessWidget {
  const MeshFeedEmptyState({super.key, required this.onCompose});

  final VoidCallback onCompose;

  static const _icons = [
    Icons.dynamic_feed_outlined,
    Icons.cell_tower,
    Icons.hub_outlined,
    Icons.sync_alt,
    Icons.broadcast_on_personal_outlined,
    Icons.share_outlined,
    Icons.schedule_outlined,
    Icons.people_outline,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final taglines = [
      l10n.meshFeedEmptyTagline1,
      l10n.meshFeedEmptyTagline2,
      l10n.meshFeedEmptyTagline3,
      l10n.meshFeedEmptyTagline4,
    ];

    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: _icons,
        taglines: taglines,
        titlePrefix: l10n.meshFeedEmptyTitlePrefix,
        titleKeyword: l10n.meshFeedEmptyTitleKeyword,
        titleSuffix: l10n.meshFeedEmptyTitleSuffix,
        actionLabel: l10n.meshFeedEmptyAction,
        actionIcon: Icons.add,
        onAction: onCompose,
        actionEnabled: true,
      ),
    );
  }
}
