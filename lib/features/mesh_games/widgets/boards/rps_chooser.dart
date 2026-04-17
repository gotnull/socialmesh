// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// RPS board UI. Three large tappable throw cards; reveals when both
/// players have committed.
library;

import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../l10n/app_localizations.dart';
import '../../engine/rps_engine.dart';
import '../../models/mesh_game_session.dart';

typedef RpsOnCommit = void Function(RpsThrow throwValue);

class RpsChooser extends StatelessWidget {
  final MeshGameSession session;
  final RpsState state;
  final int myNodeNum;
  final RpsOnCommit onCommit;

  const RpsChooser({
    super.key,
    required this.session,
    required this.state,
    required this.myNodeNum,
    required this.onCommit,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final myIndex = session.participants.indexOf(myNodeNum);
    final iCommitted = myIndex >= 0 && state.hasCommitted(myIndex);
    final bothCommitted = state.bothCommitted;

    if (bothCommitted) {
      return _buildReveal(context, l10n);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          iCommitted
              ? l10n.meshGamesStatusWaiting
              : l10n.meshGamesRpsPickPrompt,
          style: context.titleStyle?.copyWith(
            color: context.textPrimary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: AppTheme.spacing20),
        Row(
          children: [
            _ThrowCard(
              label: l10n.meshGamesRpsRock,
              emoji: '🪨',
              enabled: !iCommitted,
              onTap: () => onCommit(RpsThrow.rock),
            ),
            const SizedBox(width: AppTheme.spacing12),
            _ThrowCard(
              label: l10n.meshGamesRpsPaper,
              emoji: '📄',
              enabled: !iCommitted,
              onTap: () => onCommit(RpsThrow.paper),
            ),
            const SizedBox(width: AppTheme.spacing12),
            _ThrowCard(
              label: l10n.meshGamesRpsScissors,
              emoji: '✂️',
              enabled: !iCommitted,
              onTap: () => onCommit(RpsThrow.scissors),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReveal(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.meshGamesRpsRevealTitle,
          style: context.titleStyle?.copyWith(
            color: context.textPrimary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _RevealTile(
              label: l10n.meshGamesOpponentLabel,
              throwValue: state.throws[_opponentIndex()],
            ),
            Text(
              'vs',
              style: context.titleStyle?.copyWith(
                color: context.textTertiary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            _RevealTile(label: 'You', throwValue: state.throws[_myIndex()]),
          ],
        ),
      ],
    );
  }

  int _myIndex() {
    final idx = session.participants.indexOf(myNodeNum);
    return idx < 0 ? 0 : idx;
  }

  int _opponentIndex() => _myIndex() == 0 ? 1 : 0;
}

class _ThrowCard extends StatelessWidget {
  final String label;
  final String emoji;
  final bool enabled;
  final VoidCallback onTap;

  const _ThrowCard({
    required this.label,
    required this.emoji,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing12,
              vertical: AppTheme.spacing20,
            ),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius16),
              border: Border.all(
                color: context.accentColor.withValues(alpha: 0.24),
              ),
            ),
            child: Column(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 40)),
                const SizedBox(height: AppTheme.spacing8),
                Text(
                  label,
                  style: context.bodyStyle?.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RevealTile extends StatelessWidget {
  final String label;
  final RpsThrow? throwValue;

  const _RevealTile({required this.label, required this.throwValue});

  @override
  Widget build(BuildContext context) {
    final emoji = switch (throwValue) {
      RpsThrow.rock => '🪨',
      RpsThrow.paper => '📄',
      RpsThrow.scissors => '✂️',
      null => '…',
    };
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 56)),
        const SizedBox(height: AppTheme.spacing6),
        Text(
          label,
          style: context.bodySmallStyle?.copyWith(
            color: context.textTertiary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ],
    );
  }
}
