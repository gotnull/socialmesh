// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../models/mesh_game_session.dart';
import '../models/mesh_game_status.dart';

/// Compact status pill used in cards and headers.
class GameStatusChip extends StatelessWidget {
  final MeshGameSession session;
  final int myNodeNum;
  final bool isStale;

  const GameStatusChip({
    super.key,
    required this.session,
    required this.myNodeNum,
    this.isStale = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final style = _resolve(context, l10n);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing10,
        vertical: AppTheme.spacing6,
      ),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
      ),
      child: Text(
        style.label,
        style: context.bodySmallStyle?.copyWith(
          color: style.color,
          fontWeight: FontWeight.w700,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }

  _ChipStyle _resolve(BuildContext context, AppLocalizations l10n) {
    if (isStale) {
      return _ChipStyle(l10n.meshGamesStatusStale, SemanticColors.warning);
    }
    switch (session.status) {
      case MeshGameStatus.active:
        if (session.isLocalTurn(myNodeNum)) {
          return _ChipStyle(l10n.meshGamesStatusYourTurn, context.accentColor);
        }
        return _ChipStyle(l10n.meshGamesStatusWaiting, context.textTertiary);
      case MeshGameStatus.completed:
        if (session.winnerNodeNum == null) {
          return _ChipStyle(l10n.meshGamesStatusDraw, SemanticColors.info);
        }
        if (session.winnerNodeNum == myNodeNum) {
          return _ChipStyle(l10n.meshGamesStatusYouWon, SemanticColors.success);
        }
        return _ChipStyle(l10n.meshGamesStatusYouLost, SemanticColors.error);
      case MeshGameStatus.abandoned:
        return _ChipStyle(l10n.meshGamesStatusAbandoned, SemanticColors.error);
      case MeshGameStatus.stale:
        return _ChipStyle(l10n.meshGamesStatusStale, SemanticColors.warning);
    }
  }
}

class _ChipStyle {
  final String label;
  final Color color;
  const _ChipStyle(this.label, this.color);
}
