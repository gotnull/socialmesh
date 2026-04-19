// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Bottom sheet for starting a new mesh game.
///
/// Flow: pick a game type (RPS or TTT) + an opponent node number,
/// create the session locally, and dispatch an outbound `CREATE`
/// frame. Uses `AppBottomSheet.showScrollable` — no Material dialogs.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/haptic_service.dart';
import '../../mesh_services/models/mesh_service_template.dart';
import '../engine/game_engine_registry.dart';
import '../models/mesh_game_type.dart';
import '../providers/mesh_game_providers.dart';

/// Result of [NewGameSheet.show]. Null = dismissed.
class NewGameSheetResult {
  final String instanceId;
  final MeshGameType gameType;
  final int opponentNodeNum;

  const NewGameSheetResult({
    required this.instanceId,
    required this.gameType,
    required this.opponentNodeNum,
  });
}

class NewGameSheet {
  /// Display the new-game sheet and return the created session info,
  /// or null on cancel.
  static Future<NewGameSheetResult?> show({
    required BuildContext context,
    required int myNodeNum,
    required List<MeshGamePeer> availablePeers,
  }) {
    return AppBottomSheet.showScrollable<NewGameSheetResult>(
      context: context,
      title: AppLocalizations.of(context).meshGamesNewGameTitle,
      builder: (scrollController) => _NewGameSheetBody(
        scrollController: scrollController,
        myNodeNum: myNodeNum,
        peers: availablePeers,
      ),
    );
  }
}

/// Minimum identifying info about a candidate opponent.
class MeshGamePeer {
  final int nodeNum;
  final String displayName;

  const MeshGamePeer({required this.nodeNum, required this.displayName});
}

class _NewGameSheetBody extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final int myNodeNum;
  final List<MeshGamePeer> peers;

  const _NewGameSheetBody({
    required this.scrollController,
    required this.myNodeNum,
    required this.peers,
  });

  @override
  ConsumerState<_NewGameSheetBody> createState() => _NewGameSheetBodyState();
}

class _NewGameSheetBodyState extends ConsumerState<_NewGameSheetBody>
    with LifecycleSafeMixin {
  MeshGameType _gameType = MeshGameType.rpsV1;
  MeshGamePeer? _selectedPeer;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.peers.isNotEmpty) _selectedPeer = widget.peers.first;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canSubmit =
        !_isSubmitting && _selectedPeer != null && widget.peers.isNotEmpty;
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(AppTheme.spacing16),
      children: [
        _sectionHeader(context, l10n.meshGamesTitle),
        _gameTypeSelector(context, l10n),
        const SizedBox(height: AppTheme.spacing24),
        _sectionHeader(context, l10n.meshGamesOpponentPickerTitle),
        _opponentSelector(context, l10n),
        const SizedBox(height: AppTheme.spacing24),
        SizedBox(
          height: AppTheme.spacing48,
          child: FilledButton.icon(
            onPressed: canSubmit ? _submit : null,
            icon: const Icon(Icons.play_arrow),
            label: Text(l10n.meshGamesNewGame),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      child: Text(
        title.toUpperCase(),
        style: context.bodySmallStyle?.copyWith(
          color: context.textTertiary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }

  Widget _gameTypeSelector(BuildContext context, AppLocalizations l10n) {
    return Column(
      children: [
        _gameTypeTile(
          context: context,
          type: MeshGameType.rpsV1,
          label: l10n.meshGamesTypeRps,
          description: l10n.meshGamesTypeRpsDescription,
          icon: Icons.back_hand_outlined,
        ),
        const SizedBox(height: AppTheme.spacing8),
        _gameTypeTile(
          context: context,
          type: MeshGameType.ticTacToeV1,
          label: l10n.meshGamesTypeTicTacToe,
          description: l10n.meshGamesTypeTicTacToeDescription,
          icon: Icons.grid_3x3,
        ),
      ],
    );
  }

  Widget _gameTypeTile({
    required BuildContext context,
    required MeshGameType type,
    required String label,
    required String description,
    required IconData icon,
  }) {
    final selected = _gameType == type;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ref.haptics.itemSelect();
          safeSetState(() => _gameType = type);
        },
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(
              color: selected
                  ? context.accentColor.withValues(alpha: 0.4)
                  : context.border.withValues(alpha: 0.15),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected ? context.accentColor : context.textSecondary,
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: context.bodyStyle?.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      description,
                      style: context.bodySmallStyle?.copyWith(
                        color: context.textTertiary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: context.accentColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _opponentSelector(BuildContext context, AppLocalizations l10n) {
    if (widget.peers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
        ),
        child: Text(
          l10n.meshGamesOpponentMissing,
          style: context.bodySecondaryStyle?.copyWith(
            color: context.textSecondary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      );
    }

    return Column(
      children: [for (final peer in widget.peers) _peerTile(context, peer)],
    );
  }

  Widget _peerTile(BuildContext context, MeshGamePeer peer) {
    final selected = _selectedPeer?.nodeNum == peer.nodeNum;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.haptics.itemSelect();
            safeSetState(() => _selectedPeer = peer);
          },
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing12,
            ),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius12),
              border: Border.all(
                color: selected
                    ? context.accentColor.withValues(alpha: 0.4)
                    : context.border.withValues(alpha: 0.15),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    peer.displayName,
                    style: context.bodyStyle?.copyWith(
                      color: context.textPrimary,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle, color: context.accentColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final peer = _selectedPeer;
    if (peer == null) return;
    final repo = ref.read(meshGameRepositoryProvider);
    if (repo == null) return;
    final l10n = AppLocalizations.of(context);

    safeSetState(() => _isSubmitting = true);
    ref.haptics.buttonTap();
    try {
      await repo.open();
      final instanceId = _generateInstanceId();
      final participants = [widget.myNodeNum, peer.nodeNum];
      final initiatorIndex = 0;
      final initialBlob = switch (_gameType) {
        MeshGameType.rpsV1 => GameEngineRegistry.rps.encodeState(
          GameEngineRegistry.rps.initialState(initiatorIndex: initiatorIndex),
        ),
        MeshGameType.ticTacToeV1 => GameEngineRegistry.ticTacToe.encodeState(
          GameEngineRegistry.ticTacToe.initialState(
            initiatorIndex: initiatorIndex,
          ),
        ),
      };
      final presetId = _gameType == MeshGameType.rpsV1
          ? MeshServicePresetId.rpsV1
          : MeshServicePresetId.ticTacToeV1;
      final gameName = switch (_gameType) {
        MeshGameType.rpsV1 => l10n.meshGamesTypeRps,
        MeshGameType.ticTacToeV1 => l10n.meshGamesTypeTicTacToe,
      };
      final created = await repo.createLocalSession(
        instanceId: instanceId,
        gameType: _gameType,
        presetId: presetId,
        title: l10n.meshGamesSessionTitle(gameName, peer.displayName),
        participants: participants,
        initiatorNodeNum: widget.myNodeNum,
        turnIndex: initiatorIndex,
        initialStateBlob: initialBlob,
      );
      if (created == null) {
        AppLogging.meshGames('CREATE failed instance=$instanceId');
        return;
      }
      ref.read(meshGamesEpochProvider.notifier).bump();
      AppLogging.meshGames(
        'local CREATE instance=$instanceId type=${_gameType.identifier} '
        'opponent=${peer.nodeNum}',
      );
      if (!mounted) return;
      safeNavigatorPop(
        NewGameSheetResult(
          instanceId: instanceId,
          gameType: _gameType,
          opponentNodeNum: peer.nodeNum,
        ),
      );
    } finally {
      safeSetState(() => _isSubmitting = false);
    }
  }

  String _generateInstanceId() {
    final now = DateTime.now();
    final ts = now.millisecondsSinceEpoch.toRadixString(16);
    final hash = now.microsecondsSinceEpoch.hashCode
        .abs()
        .toRadixString(16)
        .padLeft(4, '0');
    return '$ts$hash'.substring(0, 16);
  }
}
