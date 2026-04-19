// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Animated empty state widget for NodeBoard views.

import 'package:flutter/material.dart';

import '../../../core/widgets/animated_empty_state.dart';

class NodeBoardEmptyState extends StatelessWidget {
  const NodeBoardEmptyState({
    super.key,
    required this.icons,
    required this.taglines,
    required this.titlePrefix,
    required this.titleKeyword,
    required this.titleSuffix,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  final List<IconData> icons;
  final List<String> taglines;
  final String titlePrefix;
  final String titleKeyword;
  final String titleSuffix;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: icons,
        taglines: taglines,
        titlePrefix: titlePrefix,
        titleKeyword: titleKeyword,
        titleSuffix: titleSuffix,
        actionLabel: actionLabel,
        actionIcon: actionIcon,
        onAction: onAction,
      ),
    );
  }
}
