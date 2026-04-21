// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Pet Home Screen — the single-tap daily touchpoint.
//
// Layout (top → bottom):
//   • Glass app bar with feature title
//   • Optional attention-call banner (pulsing, themed by call reason)
//   • Centered pet creature (animated PetCreature painter)
//   • Stage • Branch • "N days old" header line
//   • Three stat pip rows (Energy, Mood, Stability)
//   • Bottom action bar — conditional buttons:
//       always:      Charge (tap) / Surge (long-press), Resonate, Sync, Inspect
//       contextual:  Stabilise (hygiene present), Purge (sick),
//                    Dim (in sleep window or asleep), Re-sigil (dormant)
//   • Empty state when no ownerNodeNum is bound yet

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/haptic_service.dart';
import '../models/pet_enums.dart';
import '../models/pet_state.dart';
import '../providers/pet_providers.dart';
import '../widgets/pet_action_button.dart';
import '../widgets/pet_inspect_sheet.dart';
import '../widgets/pet_sigil_painter.dart';
import '../widgets/pet_stat_pip_row.dart';

class PetHomeScreen extends ConsumerWidget {
  const PetHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(ownPetProvider);

    return GlassScaffold.body(
      title: l10n.petScreenTitle,
      centerTitle: true,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
            err.toString(),
            style: TextStyle(
              color: context.textSecondary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ),
        data: (state) =>
            state == null ? _PetEmptyState(l10n: l10n) : _PetBody(state: state),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state — shown when no ownerNodeNum is bound.
// ---------------------------------------------------------------------------

class _PetEmptyState extends StatelessWidget {
  final AppLocalizations l10n;
  const _PetEmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing32,
          vertical: AppTheme.spacing24,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.egg_outlined,
              size: 72,
              color: AppTheme.primaryPurple.withValues(alpha: 0.6),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              l10n.petNoOwnerTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            const SizedBox(height: AppTheme.spacing10),
            Text(
              l10n.petNoOwnerDescription,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Core body — renders the pet + stats + actions.
// ---------------------------------------------------------------------------

class _PetBody extends ConsumerWidget {
  final PetState state;
  const _PetBody({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final engine = ref.watch(petCareEngineProvider);
    final mood = engine.deriveMood(state);
    final now = DateTime.now();
    final ageDays = state.ageInDaysAt(now);
    final inSleepWindow = engine.isInSleepWindow(now);

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxCreature = constraints.maxWidth.clamp(200.0, 320.0);
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing24,
                  vertical: AppTheme.spacing16,
                ),
                child: Column(
                  children: [
                    if (state.activeCall != null) ...[
                      _CallBanner(reason: state.activeCall!.reason, l10n: l10n),
                      const SizedBox(height: AppTheme.spacing16),
                    ],
                    if (state.stage == PetStage.dormant) ...[
                      _DormantBanner(l10n: l10n),
                      const SizedBox(height: AppTheme.spacing16),
                    ],
                    Center(
                      child: PetCreature(
                        dnaSeed: state.dnaSeed,
                        stage: state.stage,
                        branch: state.branch,
                        mood: mood,
                        isAsleep: state.isAsleep,
                        isSick: state.isSick,
                        isCalling: state.activeCall != null,
                        hygieneArtefactCount: state.hygieneArtefacts.length,
                        size: maxCreature.toDouble(),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                    Text(
                      '${_stageLabel(state.stage, l10n)} • '
                      '${_branchLabel(state.branch, l10n)}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                        letterSpacing: 1.1,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      l10n.petAgeDaysLabel(ageDays),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing6),
                    Text(
                      _moodLabel(mood, l10n),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _moodColor(mood),
                        letterSpacing: 0.5,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing20),
                    PetStatPipRow(
                      label: l10n.petStatEnergy,
                      value: state.energy,
                      maxValue: 10,
                      icon: Icons.bolt_outlined,
                      color: AccentColors.yellow,
                    ),
                    const SizedBox(height: AppTheme.spacing10),
                    PetStatPipRow(
                      label: l10n.petStatMood,
                      value: state.mood,
                      maxValue: 10,
                      icon: Icons.favorite_border,
                      color: AccentColors.pink,
                    ),
                    const SizedBox(height: AppTheme.spacing10),
                    PetStatPipRow(
                      label: l10n.petStatStability,
                      value: state.stability,
                      maxValue: 10,
                      icon: Icons.blur_on_outlined,
                      color: AccentColors.teal,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        _ActionBar(state: state, inSleepWindow: inSleepWindow),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Call / dormant banners
// ---------------------------------------------------------------------------

class _CallBanner extends StatelessWidget {
  final CallReason reason;
  final AppLocalizations l10n;

  const _CallBanner({required this.reason, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final (color, text) = _copy(reason, l10n);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_active_outlined, size: 18, color: color),
          const SizedBox(width: AppTheme.spacing10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: context.textPrimary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static (Color, String) _copy(CallReason reason, AppLocalizations l10n) {
    switch (reason) {
      case CallReason.hungry:
        return (AccentColors.yellow, l10n.petCallBannerHungry);
      case CallReason.lonely:
        return (AccentColors.pink, l10n.petCallBannerLonely);
      case CallReason.sick:
        return (AccentColors.red, l10n.petCallBannerSick);
      case CallReason.hygiene:
        return (AccentColors.slate, l10n.petCallBannerHygiene);
      case CallReason.bedtime:
        return (AccentColors.indigo, l10n.petCallBannerBedtime);
      case CallReason.boredom:
        return (AccentColors.lavender, l10n.petCallBannerBoredom);
    }
  }
}

class _DormantBanner extends StatelessWidget {
  final AppLocalizations l10n;
  const _DormantBanner({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: AccentColors.slate.withValues(alpha: 0.12),
        border: Border.all(color: AccentColors.slate.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.petDormantTitle,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            l10n.petDormantDescription,
            style: TextStyle(
              fontSize: 13,
              color: context.textSecondary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action bar
// ---------------------------------------------------------------------------

class _ActionBar extends ConsumerWidget {
  final PetState state;
  final bool inSleepWindow;

  const _ActionBar({required this.state, required this.inSleepWindow});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(ownPetProvider.notifier);
    final haptic = ref.read(hapticServiceProvider);

    final dormant = state.stage == PetStage.dormant;
    final egg = state.stage == PetStage.egg;
    final asleep = state.isAsleep;

    // Interactivity map.
    VoidCallback wrap(HapticType hap, Future<void> Function() action) {
      return () async {
        await haptic.trigger(hap);
        await action();
      };
    }

    final buttons = <Widget>[];

    if (dormant) {
      buttons.add(
        PetActionButton(
          icon: Icons.auto_awesome_outlined,
          label: l10n.petActionReSigil,
          accent: AccentColors.yellow,
          onTap: wrap(HapticType.heavy, controller.reSigil),
        ),
      );
      buttons.add(
        PetActionButton(
          icon: Icons.visibility_outlined,
          label: l10n.petActionInspect,
          accent: AccentColors.sky,
          onTap: () => _openInspect(context),
        ),
      );
    } else {
      final chargeEnabled = !asleep && !egg;
      buttons.add(
        PetActionButton(
          icon: Icons.bolt_outlined,
          label: l10n.petActionCharge,
          accent: AccentColors.yellow,
          onTap: chargeEnabled
              ? wrap(HapticType.medium, controller.charge)
              : null,
          onLongPress: chargeEnabled
              ? wrap(HapticType.heavy, controller.surge)
              : null,
        ),
      );

      buttons.add(
        PetActionButton(
          icon: Icons.graphic_eq,
          label: l10n.petActionResonate,
          accent: AccentColors.pink,
          onTap: (!asleep && !egg)
              ? wrap(HapticType.medium, controller.resonate)
              : null,
        ),
      );

      if (state.hygieneArtefacts.isNotEmpty) {
        buttons.add(
          PetActionButton(
            icon: Icons.cleaning_services_outlined,
            label: l10n.petActionStabilise,
            accent: AccentColors.teal,
            onTap: wrap(HapticType.medium, controller.stabilise),
          ),
        );
      }

      if (state.isSick) {
        buttons.add(
          PetActionButton(
            icon: Icons.healing_outlined,
            label: l10n.petActionPurge,
            accent: AccentColors.red,
            pulsing: true,
            onTap: wrap(HapticType.heavy, controller.purge),
          ),
        );
      }

      if (!egg) {
        buttons.add(
          PetActionButton(
            icon: Icons.sync,
            label: l10n.petActionSync,
            accent: AccentColors.lavender,
            onTap: wrap(HapticType.light, controller.sync),
          ),
        );
      }

      if ((inSleepWindow || asleep) && !egg) {
        buttons.add(
          PetActionButton(
            icon: Icons.nightlight_round,
            label: l10n.petActionDim,
            accent: AccentColors.indigo,
            onTap: asleep ? null : wrap(HapticType.light, controller.dim),
          ),
        );
      }

      buttons.add(
        PetActionButton(
          icon: Icons.visibility_outlined,
          label: l10n.petActionInspect,
          accent: AccentColors.sky,
          onTap: () => _openInspect(context),
        ),
      );
    }

    return BottomActionBar(
      horizontalPadding: AppTheme.spacing12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: buttons,
      ),
    );
  }

  void _openInspect(BuildContext context) {
    AppBottomSheet.show<void>(context: context, child: const PetInspectSheet());
  }
}

// ---------------------------------------------------------------------------
// Label helpers
// ---------------------------------------------------------------------------

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

String _moodLabel(PetMood m, AppLocalizations l10n) {
  switch (m) {
    case PetMood.content:
      return l10n.petMoodContent;
    case PetMood.hungry:
      return l10n.petMoodHungry;
    case PetMood.sad:
      return l10n.petMoodSad;
    case PetMood.sick:
      return l10n.petMoodSick;
    case PetMood.sleeping:
      return l10n.petMoodSleeping;
    case PetMood.calling:
      return l10n.petMoodCalling;
  }
}

Color _moodColor(PetMood m) {
  switch (m) {
    case PetMood.content:
      return AccentColors.emerald;
    case PetMood.hungry:
      return AccentColors.yellow;
    case PetMood.sad:
      return AccentColors.pink;
    case PetMood.sick:
      return AccentColors.red;
    case PetMood.sleeping:
      return AccentColors.indigo;
    case PetMood.calling:
      return AccentColors.orange;
  }
}
