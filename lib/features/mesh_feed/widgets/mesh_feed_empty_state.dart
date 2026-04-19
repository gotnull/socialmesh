// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/widgets/animated_empty_state.dart';

enum _MeshFeedEmptyStateMode { feed, filtered }

/// Animated empty state for the mesh feed screen.
/// Uses the reusable AnimatedEmptyState widget for consistency across Social screens.
class MeshFeedEmptyState extends StatelessWidget {
  const MeshFeedEmptyState({super.key, required this.onCompose})
    : onShowAll = null,
      _mode = _MeshFeedEmptyStateMode.feed;

  const MeshFeedEmptyState.filtered({super.key, required this.onShowAll})
    : onCompose = null,
      _mode = _MeshFeedEmptyStateMode.filtered;

  final VoidCallback? onCompose;
  final VoidCallback? onShowAll;
  final _MeshFeedEmptyStateMode _mode;

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

  static const _filteredIcons = [
    Icons.filter_list_off_rounded,
    Icons.search_off_rounded,
    Icons.tune_rounded,
    Icons.dynamic_feed_outlined,
    Icons.hub_outlined,
    Icons.near_me,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isFiltered = _mode == _MeshFeedEmptyStateMode.filtered;
    final taglines = isFiltered
        ? List.filled(
            4,
            _balancedLineBreak(l10n.meshFeedEmptyFilterDescription),
          )
        : [
            _twoLineTagline(
              l10n.meshFeedEmptyTagline1,
              l10n.meshFeedEmptyTagline2,
            ),
            _twoLineTagline(
              l10n.meshFeedEmptyTagline3,
              l10n.meshFeedEmptyTagline4,
            ),
            _twoLineTagline(
              l10n.meshFeedEmptyTagline2,
              l10n.meshFeedEmptyTagline3,
            ),
            _twoLineTagline(
              l10n.meshFeedEmptyTagline4,
              l10n.meshFeedEmptyTagline1,
            ),
          ];

    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: isFiltered ? _filteredIcons : _icons,
        taglines: taglines,
        titlePrefix: isFiltered
            ? l10n.meshFeedEmptyFilterTitle
            : l10n.meshFeedEmptyTitlePrefix,
        titleKeyword: isFiltered ? '' : l10n.meshFeedEmptyTitleKeyword,
        titleSuffix: isFiltered ? '' : l10n.meshFeedEmptyTitleSuffix,
        actionLabel: isFiltered
            ? l10n.meshFeedFilterAll
            : l10n.meshFeedEmptyAction,
        actionIcon: isFiltered ? Icons.filter_list_off_rounded : Icons.add,
        onAction: isFiltered ? onShowAll : onCompose,
        actionEnabled: true,
      ),
    );
  }

  String _twoLineTagline(String first, String second) => '$first\n$second';

  String _balancedLineBreak(String value) {
    final words = value.split(' ');
    if (words.length < 5) return value;
    final midpoint = (words.length / 2).ceil();
    return '${words.take(midpoint).join(' ')}\n${words.skip(midpoint).join(' ')}';
  }
}
