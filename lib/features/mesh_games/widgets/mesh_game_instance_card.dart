// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

library;

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../../mesh_services/models/mesh_service_template.dart';
import '../models/mesh_game_session.dart';
import 'game_status_chip.dart';

/// Tappable card listing a mesh-game session inside the services list.
class MeshGameInstanceCard extends StatelessWidget {
  final MeshGameSession session;
  final int myNodeNum;
  final String opponentLabel;
  final bool isStale;
  final VoidCallback onTap;

  const MeshGameInstanceCard({
    super.key,
    required this.session,
    required this.myNodeNum,
    required this.opponentLabel,
    required this.onTap,
    this.isStale = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final resolved = MeshServiceCatalog.resolve(
      canonicalType: MeshServiceType.game,
      presetId: _presetFor(session),
    );
    final accent = resolved.accentColor;
    final gameName = _gameTypeLabel(l10n, session);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing14),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius16),
            border: Border.all(color: accent.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: AppTheme.spacing48,
                    height: AppTheme.spacing48,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.radius10),
                    ),
                    child: Icon(resolved.icon, color: accent, size: 22),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gameName,
                          style: context.bodyStyle?.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing4),
                        Text(
                          l10n.meshServicesEyebrowGame,
                          style: context.bodySmallStyle?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w600,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing2),
                        Text(
                          '${l10n.meshGamesOpponentLabel}: $opponentLabel',
                          style: context.captionStyle?.copyWith(
                            color: context.textTertiary,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: context.textTertiary.withValues(alpha: 0.6),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing10),
              Row(
                children: [
                  GameStatusChip(
                    session: session,
                    myNodeNum: myNodeNum,
                    isStale: isStale,
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Text(
                    l10n.meshGamesRevision(session.revision),
                    style: context.bodySmallStyle?.copyWith(
                      color: context.textTertiary,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  MeshServicePresetId? _presetFor(MeshGameSession session) {
    return switch (session.gameType.identifier) {
      'rps.v1' => MeshServicePresetId.rpsV1,
      'tic_tac_toe.v1' => MeshServicePresetId.ticTacToeV1,
      _ => null,
    };
  }

  String _gameTypeLabel(AppLocalizations l10n, MeshGameSession session) {
    return switch (session.gameType.identifier) {
      'rps.v1' => l10n.meshGamesTypeRps,
      'tic_tac_toe.v1' => l10n.meshGamesTypeTicTacToe,
      _ => l10n.meshGamesTypeUnknown,
    };
  }
}
