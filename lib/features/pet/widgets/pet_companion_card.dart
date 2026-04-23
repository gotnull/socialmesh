// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetCompanionCard — NodeDex detail integration point.
//
// Renders a peer's cached pet (if any) as a compact tile: animated
// preview, stage • branch label, freshness line. Returns a small empty
// state if no cache is present for [nodeNum].
//
// On first mount (and whenever the cached observation for this nodeNum
// is stale or missing) the widget broadcasts a pet.v1/get_summary
// REQUEST via [petRemoteClientProvider]. The response observer wired in
// mrrp_providers.dart ingests the sender's public state into the cache,
// which then triggers this widget to refresh. See pet_remote_client.dart
// for why this is broadcast-style rather than targeted.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../l10n/app_localizations.dart';
import '../models/peer_pet_live_state.dart';
import '../models/pet_enums.dart';
import '../providers/pet_providers.dart';
import 'pet_mini_preview.dart';

/// How old a cached observation may be before the Companion card
/// re-triggers a broadcast fetch on mount. Shorter than the stale-dim
/// threshold (12h) so the UI refreshes proactively.
const _refreshAfter = Duration(minutes: 30);

class PetCompanionContent extends ConsumerStatefulWidget {
  final int nodeNum;
  const PetCompanionContent({super.key, required this.nodeNum});

  @override
  ConsumerState<PetCompanionContent> createState() =>
      _PetCompanionContentState();
}

class _PetCompanionContentState extends ConsumerState<PetCompanionContent>
    with LifecycleSafeMixin<PetCompanionContent> {
  bool _fetchScheduled = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final async = ref.watch(remotePetProvider(widget.nodeNum));
    final observation = async.value;
    _maybeTriggerFetch(observation);
    if (observation == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
        child: Text(
          l10n.petCompanionUnknown,
          style: TextStyle(
            fontSize: 13,
            color: context.textTertiary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      );
    }

    final state = observation.state;
    final isStale =
        observation.ageFrom(DateTime.now()) > const Duration(hours: 12);
    // Smoothed live-band — the display layer for peer presence derived
    // from last-seen + wire flags with hysteresis. `unknown` renders
    // nothing (by design — no "Unknown" label leaks into the UI).
    final liveState = ref.watch(peerPetLiveStateProvider(widget.nodeNum));
    final bandLine = _liveBandLine(context, liveState, l10n);

    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacing8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PetPreviewFromState(state: state, size: 72, isStale: isStale),
          const SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_stageLabel(state.stage, l10n)} • '
                  '${_branchLabel(state.branch, l10n)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                    letterSpacing: 0.5,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  l10n.petAgeDaysLabel(state.ageInDays),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textSecondary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  l10n.petCompanionObservedRelative(
                    _shortAge(observation.ageFrom(DateTime.now())),
                  ),
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textTertiary,
                    fontStyle: FontStyle.italic,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                if (bandLine != null) ...[
                  const SizedBox(height: AppTheme.spacing4),
                  bandLine,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Schedules a one-shot broadcast fetch when the cached observation
  /// for this peer is missing or older than [_refreshAfter]. The actual
  /// fetch runs in a microtask so we never touch providers during a
  /// build, and it's guarded by [_fetchScheduled] so remounts within
  /// the same widget life don't re-trigger.
  void _maybeTriggerFetch(dynamic observation) {
    if (_fetchScheduled) return;
    final needsRefresh =
        observation == null ||
        (observation.observedAt as DateTime).isBefore(
          DateTime.now().subtract(_refreshAfter),
        );
    if (!needsRefresh) return;
    _fetchScheduled = true;
    Future.microtask(() async {
      final client = ref.read(petRemoteClientProvider);
      if (client == null) return;
      final outcome = await client.fetchSummary();
      AppLogging.pet(
        'PetCompanionContent: fetch outcome=${outcome.runtimeType}',
      );
    });
  }
}

String _stageLabel(PetStage s, AppLocalizations l10n) {
  switch (s) {
    case PetStage.egg:
      return l10n.petStageEgg;
    case PetStage.juvenile:
      return l10n.petStageJuvenile;
    case PetStage.adolescent:
      return l10n.petStageAdolescent;
    case PetStage.adult:
      return l10n.petStageAdult;
    case PetStage.elder:
      return l10n.petStageElder;
    case PetStage.dormant:
      return l10n.petStageDormant;
  }
}

String _branchLabel(PetBranch b, AppLocalizations l10n) {
  switch (b) {
    case PetBranch.unborn:
      return l10n.petBranchUnborn;
    case PetBranch.luminous:
      return l10n.petBranchLuminous;
    case PetBranch.steady:
      return l10n.petBranchSteady;
    case PetBranch.volatile:
      return l10n.petBranchVolatile;
    case PetBranch.dimmed:
      return l10n.petBranchDimmed;
  }
}

/// Render the smoothed live-band pip, or null when the band is
/// [PeerPetLiveBand.unknown] (we render nothing — the absence of the
/// line IS the "no recent activity" signal).
Widget? _liveBandLine(
  BuildContext context,
  PeerPetLiveState liveState,
  AppLocalizations l10n,
) {
  final label = switch (liveState.band) {
    PeerPetLiveBand.active => l10n.petLiveStateActive,
    PeerPetLiveBand.calm => l10n.petLiveStateCalm,
    PeerPetLiveBand.idle => l10n.petLiveStateIdle,
    PeerPetLiveBand.sleepy => l10n.petLiveStateSleepy,
    PeerPetLiveBand.dormant => l10n.petLiveStateDormant,
    PeerPetLiveBand.unknown => null,
  };
  if (label == null) return null;
  final color = switch (liveState.band) {
    PeerPetLiveBand.active => context.accentColor,
    PeerPetLiveBand.calm => context.textSecondary,
    PeerPetLiveBand.idle => context.textSecondary,
    PeerPetLiveBand.sleepy => context.textTertiary,
    PeerPetLiveBand.dormant => context.textTertiary,
    // Unreachable — handled above.
    PeerPetLiveBand.unknown => context.textTertiary,
  };
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: AppTheme.spacing6),
      Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.4,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    ],
  );
}

String _shortAge(Duration d) {
  if (d.inMinutes < 1) return '${d.inSeconds}s';
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  return '${d.inDays}d';
}
