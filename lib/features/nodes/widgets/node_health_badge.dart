// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../../../core/health/node_health.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';

/// Small, visually-secondary operational health badge for SiteOps node
/// visibility (fresh / stale / offline / unknown). Coexists with — and does
/// not replace — the social presence label.
class NodeHealthBadge extends StatelessWidget {
  const NodeHealthBadge({super.key, required this.state});

  final NodeHealthState state;

  @override
  Widget build(BuildContext context) {
    final color = colorFor(state);
    final foreground = context.readableAccent(color);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        labelFor(context, state),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  /// Canonical state -> color mapping, shared with other health surfaces
  /// (e.g. the node-detail badges row) so the mapping has one home.
  static Color colorFor(NodeHealthState state) {
    switch (state) {
      case NodeHealthState.fresh:
        return SemanticColors.success;
      case NodeHealthState.stale:
        return SemanticColors.warning;
      case NodeHealthState.offline:
        return SemanticColors.error;
      case NodeHealthState.unknown:
        return SemanticColors.muted;
    }
  }

  /// Canonical state -> operational label mapping (localized).
  static String labelFor(BuildContext context, NodeHealthState state) {
    switch (state) {
      case NodeHealthState.fresh:
        return context.l10n.nodeHealthFresh;
      case NodeHealthState.stale:
        return context.l10n.nodeHealthStale;
      case NodeHealthState.offline:
        return context.l10n.nodeHealthOffline;
      case NodeHealthState.unknown:
        return context.l10n.nodeHealthUnknown;
    }
  }
}
