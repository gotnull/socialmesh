// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// GlassScaffold-hosted detail screen for a mesh-game session.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/haptic_service.dart';
import '../models/mesh_game_session.dart';
import '../models/mesh_game_status.dart';
import '../providers/mesh_game_providers.dart';
import '../widgets/game_body_registry.dart';
import '../widgets/game_status_chip.dart';

/// Detail screen showing the board + status for a single game session.
class GameDetailScreen extends ConsumerStatefulWidget {
  final String instanceId;
  final int myNodeNum;
  final String opponentLabel;

  const GameDetailScreen({
    super.key,
    required this.instanceId,
    required this.myNodeNum,
    required this.opponentLabel,
  });

  @override
  ConsumerState<GameDetailScreen> createState() => _GameDetailScreenState();
}

/// How long after [lastMoveAt] before the UI surfaces a stale chip.
const Duration _staleThreshold = Duration(seconds: 120);

class _GameDetailScreenState extends ConsumerState<GameDetailScreen>
    with LifecycleSafeMixin {
  bool _isResyncing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sessionAsync = ref.watch(meshGameSessionProvider(widget.instanceId));

    return GlassScaffold.body(
      title: _title(l10n, sessionAsync.asData?.value),
      actions: [
        IconButton(
          tooltip: l10n.meshGamesActionResync,
          onPressed: _isResyncing ? null : () => _handleResync(context),
          icon: _isResyncing
              ? const SizedBox(
                  width: AppTheme.spacing16,
                  height: AppTheme.spacing16,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : const Icon(Icons.sync),
        ),
      ],
      body: sessionAsync.when(
        data: (session) => session == null
            ? _buildMissing(context, l10n)
            : _buildLoaded(context, l10n, session),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _buildMissing(context, l10n),
      ),
    );
  }

  String _title(AppLocalizations l10n, MeshGameSession? session) {
    if (session == null) return l10n.meshGamesTitle;
    return switch (session.gameType.identifier) {
      'rps.v1' => l10n.meshGamesTypeRps,
      'tic_tac_toe.v1' => l10n.meshGamesTypeTicTacToe,
      _ => l10n.meshGamesTypeUnknown,
    };
  }

  Widget _buildMissing(BuildContext context, AppLocalizations l10n) {
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [Icons.extension_outlined],
        taglines: [l10n.meshGamesEmptyTagline],
        titlePrefix: '',
        titleKeyword: l10n.meshGamesEmptyTitle,
        titleSuffix: '',
      ),
    );
  }

  Widget _buildLoaded(
    BuildContext context,
    AppLocalizations l10n,
    MeshGameSession session,
  ) {
    final isStale = _isStale(session);
    return RefreshIndicator(
      onRefresh: () => _handleResync(context),
      child: ListView(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Row(
            children: [
              GameStatusChip(
                session: session,
                myNodeNum: widget.myNodeNum,
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
              const Spacer(),
              Text(
                '${l10n.meshGamesOpponentLabel}: ${widget.opponentLabel}',
                style: context.bodySmallStyle?.copyWith(
                  color: context.textSecondary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),
          _tryBuildBoard(context, session),
          const SizedBox(height: AppTheme.spacing24),
          if (session.status == MeshGameStatus.active && isStale)
            _buildStaleBanner(context, l10n),
        ],
      ),
    );
  }

  Widget _tryBuildBoard(BuildContext context, MeshGameSession session) {
    try {
      return GameBodyRegistry.buildFor(
        session: session,
        myNodeNum: widget.myNodeNum,
        onMove: _handleMove,
      );
    } catch (e, st) {
      AppLogging.meshGameUi('board build failed: $e\n$st');
      return GameBodyRegistry.fallback(
        context,
        AppLocalizations.of(context).meshGamesSendFailed,
      );
    }
  }

  Widget _buildStaleBanner(BuildContext context, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: SemanticColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(
          color: SemanticColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync_problem, color: SemanticColors.warning),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              l10n.meshGamesStatusStale,
              style: context.bodySecondaryStyle?.copyWith(
                color: SemanticColors.warning,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
          TextButton(
            onPressed: _isResyncing ? null : () => _handleResync(context),
            child: Text(l10n.meshGamesActionResync),
          ),
        ],
      ),
    );
  }

  bool _isStale(MeshGameSession session) {
    if (session.status.isTerminal) return false;
    return DateTime.now().difference(session.lastMoveAt) > _staleThreshold;
  }

  Future<void> _handleMove(Object move) async {
    ref.haptics.buttonTap();
    final result = await applyLocalMeshGameMove(
      ref: ref,
      instanceId: widget.instanceId,
      myNodeNum: widget.myNodeNum,
      move: move,
    );
    if (!mounted) return;
    switch (result.outcome) {
      case MeshGameLocalMoveOutcome.accepted:
        final session = result.session;
        if (session?.status == MeshGameStatus.completed) {
          if (session?.winnerNodeNum == widget.myNodeNum) {
            ref.haptics.success();
          } else if (session?.winnerNodeNum != null) {
            ref.haptics.error();
          }
        }
        break;
      case MeshGameLocalMoveOutcome.rejectedByEngine:
        ref.haptics.error();
        break;
      case MeshGameLocalMoveOutcome.transportFailed:
        ref.haptics.warning();
        break;
      case MeshGameLocalMoveOutcome.notReady:
        ref.haptics.warning();
        break;
    }
  }

  Future<void> _handleResync(BuildContext context) async {
    final transport = ref.read(meshGameTransportProvider);
    final session = ref.read(meshGameSessionProvider(widget.instanceId));
    final current = session.asData?.value;
    if (transport == null || current == null) return;
    safeSetState(() => _isResyncing = true);
    try {
      AppLogging.meshGameUi('resync requested instance=${widget.instanceId}');
      await transport.requestStatus(session: current);
    } finally {
      safeSetState(() => _isResyncing = false);
    }
  }
}
