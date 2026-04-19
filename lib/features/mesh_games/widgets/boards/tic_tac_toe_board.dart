// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Tic-Tac-Toe 3×3 board UI.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../engine/tic_tac_toe_engine.dart';
import '../../models/mesh_game_session.dart';

typedef TicTacToeOnTap = void Function(int cellIndex);

class TicTacToeBoard extends StatelessWidget {
  final MeshGameSession session;
  final TicTacToeState state;
  final int myNodeNum;
  final TicTacToeOnTap onTap;

  const TicTacToeBoard({
    super.key,
    required this.session,
    required this.state,
    required this.myNodeNum,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isMyTurn = session.isLocalTurn(myNodeNum) && !state.isTerminal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isMyTurn)
          Text(
            l10n.meshGamesTttTapPrompt,
            style: context.bodySecondaryStyle?.copyWith(
              color: context.textSecondary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        const SizedBox(height: AppTheme.spacing16),
        AspectRatio(
          aspectRatio: 1,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: 9,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: AppTheme.spacing8,
              crossAxisSpacing: AppTheme.spacing8,
            ),
            itemBuilder: (context, index) {
              final mark = state.cells[index];
              final isEmpty = mark == TicTacToeMark.empty;
              final canTap = isMyTurn && isEmpty;
              return _Cell(
                mark: mark,
                xLabel: l10n.meshGamesTttMarkX,
                oLabel: l10n.meshGamesTttMarkO,
                enabled: canTap,
                onTap: canTap ? () => onTap(index) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  final TicTacToeMark mark;
  final String xLabel;
  final String oLabel;
  final bool enabled;
  final VoidCallback? onTap;

  const _Cell({
    required this.mark,
    required this.xLabel,
    required this.oLabel,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = mark == TicTacToeMark.empty;
    final label = switch (mark) {
      TicTacToeMark.x => xLabel,
      TicTacToeMark.o => oLabel,
      TicTacToeMark.empty => '',
    };
    final color = switch (mark) {
      TicTacToeMark.x => context.accentColor,
      TicTacToeMark.o => SemanticColors.info,
      TicTacToeMark.empty => context.textTertiary,
    };
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Container(
          decoration: BoxDecoration(
            color: isEmpty
                ? context.card.withValues(alpha: enabled ? 1 : 0.6)
                : context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(color: context.border.withValues(alpha: 0.2)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ),
      ),
    );
  }
}
