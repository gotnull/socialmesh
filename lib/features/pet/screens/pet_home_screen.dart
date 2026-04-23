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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/haptic_service.dart';
import '../models/care_event.dart';
import '../models/pet_action_result.dart';
import '../models/pet_advisory.dart';
import '../models/pet_enums.dart';
import '../models/pet_state.dart';
import '../providers/pet_providers.dart';
import '../services/pet_animation_tracker.dart';
import '../widgets/pet_action_button.dart';
import '../widgets/pet_actions_guide_sheet.dart';
import '../widgets/pet_dna_viewer_sheet.dart';
import '../widgets/pet_hatch_overlay.dart';
import '../widgets/pet_inspect_sheet.dart';
import '../widgets/pet_need_indicator.dart';
import '../widgets/pet_onboarding_sheet.dart';
import '../widgets/pet_sigil_painter.dart';
import '../widgets/pet_stat_pip_row.dart';
import '../widgets/pet_status_line.dart';

class PetHomeScreen extends ConsumerWidget {
  const PetHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    // Activate the notification bridge — idempotent; the provider
    // installs a single ref.listen that survives rebuilds.
    ref.watch(petNotificationBridgeProvider);
    final async = ref.watch(ownPetProvider);

    // _PetBody owns its own GlassScaffold so it can pin the stats +
    // action buttons into Scaffold.bottomNavigationBar — the only
    // Flutter slot that's guaranteed fixed to the bottom regardless of
    // scroll, slivers, or viewport insets. The loading / error / empty
    // states wrap their own GlassScaffold to keep the app-bar styling
    // consistent.
    return async.when(
      loading: () => GlassScaffold.body(
        title: l10n.petScreenTitle,
        centerTitle: true,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => GlassScaffold.body(
        title: l10n.petScreenTitle,
        centerTitle: true,
        body: Center(
          child: Text(
            err.toString(),
            style: TextStyle(
              color: context.textSecondary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ),
      ),
      data: (state) => state == null
          ? GlassScaffold.body(
              title: l10n.petScreenTitle,
              centerTitle: true,
              body: _PetEmptyState(l10n: l10n),
            )
          : _PetBody(state: state),
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

class _PetBody extends ConsumerStatefulWidget {
  final PetState state;
  const _PetBody({required this.state});

  @override
  ConsumerState<_PetBody> createState() => _PetBodyState();
}

class _PetBodyState extends ConsumerState<_PetBody>
    with TickerProviderStateMixin, LifecycleSafeMixin {
  /// Only fire one-shot effects for stage transitions that happened
  /// within this window. Older unacknowledged transitions are silently
  /// acknowledged so we never replay ancient history on first mount.
  static const _freshnessWindow = Duration(minutes: 5);

  /// How long the "no-op reaction" toast lingers before fading.
  static const _noOpToastDuration = Duration(milliseconds: 1500);

  bool _hatchOverlayActive = false;
  _BannerSpec? _banner;
  int? _syncSessionNodeNum;

  /// In-memory watermark of the most recent transition we've already
  /// played an effect for, set synchronously in [_evaluateNewTransition]
  /// before we kick the async `tracker.acknowledge` write. Guards
  /// against SharedPreferences write latency: if the provider re-emits
  /// before the disk write flushes, `latestUnacknowledged` would
  /// otherwise return the same event and we'd replay the hatch overlay
  /// + banner. Keyed to the current owner so a pet rekey resets it.
  int? _playedOwnerNodeNum;
  DateTime? _lastPlayedEventAt;

  // No-op reaction feedback — transient toast + creature bounce shown
  // when a tapped action resolved to capped / notNeeded / invalidInState.
  late final AnimationController _bounceController;
  late final Animation<double> _bounceScale;
  String? _noOpToastMessage;
  Timer? _noOpToastTimer;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _bounceScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.92), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.04), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 30),
    ]).animate(_bounceController);
    // Post-frame so the tracker future has a chance to resolve and we
    // don't touch providers during the first build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncTrackerForCurrentOwner();
      _maybeShowOnboarding();
    });
  }

  /// Show the three-card welcome sheet once, on the very first visit
  /// to the pet home screen. The completion flag persists in
  /// SharedPreferences; dismissing the sheet (by drag or Skip) also
  /// counts as completion so we never re-nag the user.
  Future<void> _maybeShowOnboarding() async {
    final completedAsync = await ref.read(
      petOnboardingCompletedProvider.future,
    );
    if (!mounted || completedAsync) return;
    await AppBottomSheet.showScrollable<void>(
      context: context,
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (controller) => PetOnboardingSheet(scrollController: controller),
    );
    // Whether the user tapped "Got it" (sets the flag inside the
    // sheet) or swiped away, mark it completed so they're never
    // shown this sheet again.
    if (mounted) await markPetOnboardingCompleted(ref);
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _noOpToastTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PetBody old) {
    super.didUpdateWidget(old);
    if (old.state.ownerNodeNum != widget.state.ownerNodeNum) {
      // Owner changed (rare — device swap, or reSigil) — reset local
      // effect state so the new owner's transitions fire cleanly.
      _hatchOverlayActive = false;
      _banner = null;
      _syncSessionNodeNum = null;
      _playedOwnerNodeNum = null;
      _lastPlayedEventAt = null;
    }
    _syncTrackerForCurrentOwner();
  }

  /// Check the tracker and kick any pending effect. First-mount only —
  /// future transitions are detected by the [ref.listen] on
  /// [ownPetProvider] inside [build], which fires on actual stage
  /// changes. Calling this again on every [didUpdateWidget] was
  /// replaying the hatch overlay whenever the provider re-emitted for
  /// any reason (e.g. per-animation-tick state churn).
  void _syncTrackerForCurrentOwner() {
    final state = widget.state;
    if (_syncSessionNodeNum == state.ownerNodeNum) {
      // Already synced this mount — nothing to do. The in-build
      // ref.listen handles new transitions from here.
      return;
    }
    final trackerAsync = ref.read(petAnimationTrackerProvider);
    final tracker = trackerAsync.asData?.value;
    if (tracker == null) return;

    _syncSessionNodeNum = state.ownerNodeNum;

    final unack = tracker.latestUnacknowledged(state);
    if (unack == null) return;

    final age = DateTime.now().difference(unack.at);
    if (age > _freshnessWindow) {
      // Ancient history — silently swallow all unacknowledged events.
      unawaited(tracker.acknowledgeAll(state));
      AppLogging.pet(
        '_PetBody: swallowed stale transition (age=${age.inMinutes}min)',
      );
      return;
    }

    // Fresh event — acknowledge synchronously in-memory AND kick the
    // async disk write, then fire the effect.
    _markPlayed(state.ownerNodeNum, unack.at);
    unawaited(tracker.acknowledge(state.ownerNodeNum, unack.at));
    _playTransitionEffect(state, unack);
  }

  /// Called when a stage transition happens during the current mount
  /// (via the ref.listen watch in build). No freshness window needed —
  /// we know the transition just fired.
  void _evaluateNewTransition() {
    final state = widget.state;
    final trackerAsync = ref.read(petAnimationTrackerProvider);
    final tracker = trackerAsync.asData?.value;
    if (tracker == null) return;
    final unack = tracker.latestUnacknowledged(state);
    if (unack == null) return;
    // In-memory guard: if we've already played this exact event (or a
    // newer one) this session, don't replay. Beats the shared_prefs
    // write race.
    if (_playedOwnerNodeNum == state.ownerNodeNum &&
        _lastPlayedEventAt != null &&
        !unack.at.isAfter(_lastPlayedEventAt!)) {
      return;
    }
    _markPlayed(state.ownerNodeNum, unack.at);
    unawaited(tracker.acknowledge(state.ownerNodeNum, unack.at));
    _playTransitionEffect(state, unack);
  }

  void _markPlayed(int ownerNodeNum, DateTime at) {
    _playedOwnerNodeNum = ownerNodeNum;
    _lastPlayedEventAt = at;
  }

  void _playTransitionEffect(PetState state, CareEvent event) {
    final kind = classifyTransitionByResultingStage(state.stage);
    final haptic = ref.read(hapticServiceProvider);

    // Haptic first — it confirms the transition moment for the player
    // even if they look away from the screen during the overlay.
    switch (kind) {
      case PetTransitionKind.hatch:
        unawaited(haptic.trigger(HapticType.heavy));
      case PetTransitionKind.branchResolution:
        unawaited(haptic.trigger(HapticType.heavy));
      case PetTransitionKind.adolescence:
      case PetTransitionKind.maturation:
        unawaited(haptic.trigger(HapticType.medium));
      case PetTransitionKind.dormancy:
        unawaited(haptic.trigger(HapticType.warning));
      case PetTransitionKind.unknown:
        return;
    }

    // Hatch gets the overlay. Other transitions get haptic + banner only.
    if (kind == PetTransitionKind.hatch) {
      setState(() {
        _hatchOverlayActive = true;
      });
    }

    setState(() {
      _banner = _BannerSpec.forKind(kind, state.branch);
    });

    AppLogging.pet(
      '_PetBody: played ${kind.name} effect at ${event.at.toIso8601String()}',
    );
  }

  void _onOverlayComplete() {
    if (!mounted) return;
    setState(() => _hatchOverlayActive = false);
  }

  void _dismissBanner() {
    setState(() => _banner = null);
  }

  /// Called by the action bar after every tap. Fires the appropriate
  /// haptic based on the outcome, and when the outcome is non-applied
  /// plays the no-op reaction (creature bounce + transient toast) so
  /// the owner immediately sees that their tap registered but didn't
  /// change anything.
  Future<void> _onActionResult(
    PetActionResult result,
    HapticType appliedHaptic,
  ) async {
    final haptic = ref.read(hapticServiceProvider);
    switch (result.outcome) {
      case PetActionOutcome.applied:
        unawaited(haptic.trigger(appliedHaptic));
      case PetActionOutcome.capped:
      case PetActionOutcome.notNeeded:
        unawaited(haptic.trigger(HapticType.light));
        _showNoOpReaction(_reasonMessage(result.reason, context.l10n));
      case PetActionOutcome.invalidInState:
        unawaited(haptic.trigger(HapticType.warning));
        _showNoOpReaction(_reasonMessage(result.reason, context.l10n));
    }
  }

  void _showNoOpReaction(String? message) {
    if (!mounted) return;
    _noOpToastTimer?.cancel();
    // Kick the creature bounce — always restart from 0 so rapid taps
    // don't stack into a larger-than-intended scale swing.
    _bounceController
      ..stop()
      ..forward(from: 0.0);
    if (message != null) {
      setState(() => _noOpToastMessage = message);
      _noOpToastTimer = Timer(_noOpToastDuration, () {
        if (!mounted) return;
        setState(() => _noOpToastMessage = null);
      });
    }
  }

  static String? _reasonMessage(
    PetActionReason? reason,
    AppLocalizations l10n,
  ) {
    if (reason == null) return null;
    switch (reason) {
      case PetActionReason.fullyCharged:
        return l10n.petReasonFullyCharged;
      case PetActionReason.moodAlreadyFull:
        return l10n.petReasonMoodAlreadyFull;
      case PetActionReason.stabilityAlreadyFull:
        return l10n.petReasonStabilityAlreadyFull;
      case PetActionReason.nothingToClean:
        return l10n.petReasonNothingToClean;
      case PetActionReason.nothingToSync:
        return l10n.petReasonNothingToSync;
      case PetActionReason.alreadyAsleep:
        return l10n.petReasonAlreadyAsleep;
      case PetActionReason.asleep:
        return l10n.petReasonAsleep;
      case PetActionReason.egg:
        return l10n.petReasonEgg;
      case PetActionReason.dormant:
        return l10n.petReasonDormant;
      case PetActionReason.notSick:
        return l10n.petReasonNotSick;
      case PetActionReason.notBedtime:
        return l10n.petReasonNotBedtime;
      case PetActionReason.notDormant:
        return l10n.petReasonNotDormant;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for NEW stage transitions that arrive while the screen is
    // mounted (e.g. care engine advances into a new stage during a
    // foreground animation tick).
    ref.listen<AsyncValue<PetState?>>(ownPetProvider, (prev, next) {
      final previousState = prev?.value;
      final nextState = next.value;
      if (nextState == null) return;
      if (previousState == null) return;
      if (previousState.stage == nextState.stage) return;
      // State transitioned in real time. Evaluate via the tracker so
      // we respect the watermark + freshness rules consistently.
      _evaluateNewTransition();
    });

    final state = widget.state;
    final l10n = context.l10n;
    final engine = ref.watch(petCareEngineProvider);
    final config = ref.watch(petConfigProvider);
    final statMax = config.statMax;
    final mood = engine.deriveMood(state);
    final now = DateTime.now();
    final ageDays = state.ageInDaysAt(now);
    final inSleepWindow = engine.isInSleepWindow(now);
    // The primary "what should I tap right now?" advisory. Derived
    // purely from state + config; drives the PetStatusLine above the
    // creature AND the pulsing-button semantics in _ActionBar.
    final advisory = computePrimaryAdvisory(
      state: state,
      config: config,
      inSleepWindow: inSleepWindow,
    );

    // Bottom cluster — goes into Scaffold.bottomNavigationBar via the
    // GlassScaffold passthrough. This is the one Flutter slot that is
    // structurally outside the scrolling body area; it cannot move,
    // scroll, or be pushed by content.
    final bottomCluster = Material(
      color: context.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing24,
              AppTheme.spacing12,
              AppTheme.spacing24,
              AppTheme.spacing8,
            ),
            child: Column(
              children: [
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
          ),
          _ActionBar(
            state: state,
            inSleepWindow: inSleepWindow,
            advisory: advisory,
            onResult: _onActionResult,
          ),
        ],
      ),
    );

    final scrollBody = LayoutBuilder(
      builder: (context, constraints) {
        final maxCreature = constraints.maxWidth.clamp(200.0, 320.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing24,
            vertical: AppTheme.spacing16,
          ),
          child: Column(
            children: [
              if (_banner != null) ...[
                StatusBanner.accent(
                  title: _banner!.title(l10n),
                  subtitle: _banner!.subtitle(l10n),
                  icon: _banner!.icon,
                  onDismiss: _dismissBanner,
                ),
                const SizedBox(height: AppTheme.spacing16),
              ],
              if (state.activeCall != null) ...[
                _CallBanner(reason: state.activeCall!.reason, l10n: l10n),
                const SizedBox(height: AppTheme.spacing16),
              ],
              if (state.stage == PetStage.dormant) ...[
                _DormantBanner(l10n: l10n),
                const SizedBox(height: AppTheme.spacing16),
              ],
              // Plain-language advisory — the single highest-priority
              // "what to tap right now" for a first-time user. Always
              // visible; reads "Thriving" when nothing's needed so the
              // position itself is a stable signal to rest the eye on.
              PetStatusLine(advisory: advisory),
              const SizedBox(height: AppTheme.spacing16),
              Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _bounceScale,
                      builder: (context, child) => Transform.scale(
                        scale: _bounceScale.value,
                        child: child,
                      ),
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
                        energy: state.energy,
                        moodStat: state.mood,
                        stability: state.stability,
                        statMax: statMax,
                      ),
                    ),
                    // Floating thought-bubble indicator showing what the
                    // pet wants. Hygiene is excluded because dirt marks
                    // on the field already signal that channel.
                    if (state.activeCall != null &&
                        state.activeCall!.reason != CallReason.hygiene)
                      PetNeedIndicator(
                        reason: state.activeCall!.reason,
                        creatureSize: maxCreature.toDouble(),
                      ),
                    if (_hatchOverlayActive)
                      PetHatchOverlay(
                        dnaSeed: state.dnaSeed,
                        size: maxCreature.toDouble(),
                        onComplete: _onOverlayComplete,
                      ),
                  ],
                ),
              ),
              _NoOpToastSlot(message: _noOpToastMessage),
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
            ],
          ),
        );
      },
    );

    // Pass NeverScrollableScrollPhysics so GlassScaffold routes through
    // _buildNonScrollableBody — a plain Scaffold whose `body:` is our
    // scrollBody directly (no outer CustomScrollView + SliverFillRemaining
    // wrapping). In that path the Scaffold's own `bottomNavigationBar`
    // slot is used, which is the ONLY Flutter layout contract that
    // guarantees the cluster can never scroll, flex, or follow content.
    return GlassScaffold.body(
      title: l10n.petScreenTitle,
      centerTitle: true,
      physics: const NeverScrollableScrollPhysics(),
      actions: [
        IconButton(
          tooltip: l10n.petGuideSheetTitle,
          icon: const Icon(Icons.help_outline),
          onPressed: () {
            ref.read(hapticServiceProvider).buttonTap();
            AppBottomSheet.showScrollable<void>(
              context: context,
              initialChildSize: 0.8,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (controller) =>
                  PetActionsGuideSheet(scrollController: controller),
            );
          },
        ),
        IconButton(
          tooltip: l10n.petDnaViewerOpenAction,
          icon: const Icon(Icons.fingerprint),
          onPressed: () {
            ref.read(hapticServiceProvider).buttonTap();
            AppBottomSheet.showScrollable<void>(
              context: context,
              initialChildSize: 0.9,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              builder: (controller) =>
                  PetDnaViewerSheet(scrollController: controller),
            );
          },
        ),
      ],
      body: scrollBody,
      bottomNavigationBar: bottomCluster,
    );
  }
}

/// Reserved-height strip between the creature and the stage labels.
/// When [message] is null the strip is invisible but still takes the
/// same space, so showing/hiding the toast doesn't shift the layout.
/// A non-null message fades in + slides up via AnimatedSwitcher.
class _NoOpToastSlot extends StatelessWidget {
  final String? message;
  const _NoOpToastSlot({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing12),
      child: SizedBox(
        height: 32,
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: message == null
                ? const SizedBox.shrink(key: ValueKey('_noop_empty'))
                : Container(
                    key: ValueKey('_noop_$message'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing14,
                      vertical: AppTheme.spacing6,
                    ),
                    decoration: BoxDecoration(
                      color: context.card.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(AppTheme.radius16),
                      border: Border.all(
                        color: context.border.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      message!,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                        letterSpacing: 0.3,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Banner copy + iconography for each transition kind. Branch-specific
/// text for the adolescent→adult case.
class _BannerSpec {
  final IconData icon;
  final String Function(AppLocalizations l10n) title;
  final String Function(AppLocalizations l10n) subtitle;

  _BannerSpec({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  static _BannerSpec? forKind(PetTransitionKind kind, PetBranch branch) {
    switch (kind) {
      case PetTransitionKind.hatch:
        return _BannerSpec(
          icon: Icons.auto_awesome,
          title: (l10n) => l10n.petHatchBannerTitle,
          subtitle: (l10n) => l10n.petHatchBannerSubtitle,
        );
      case PetTransitionKind.branchResolution:
        switch (branch) {
          case PetBranch.luminous:
            return _BannerSpec(
              icon: Icons.wb_sunny_outlined,
              title: (l10n) => l10n.petBranchBannerTitleLuminous,
              subtitle: (l10n) => l10n.petBranchBannerSubtitleLuminous,
            );
          case PetBranch.steady:
            return _BannerSpec(
              icon: Icons.shield_outlined,
              title: (l10n) => l10n.petBranchBannerTitleSteady,
              subtitle: (l10n) => l10n.petBranchBannerSubtitleSteady,
            );
          case PetBranch.volatile:
            return _BannerSpec(
              icon: Icons.flash_on_outlined,
              title: (l10n) => l10n.petBranchBannerTitleVolatile,
              subtitle: (l10n) => l10n.petBranchBannerSubtitleVolatile,
            );
          case PetBranch.dimmed:
            return _BannerSpec(
              icon: Icons.cloud_outlined,
              title: (l10n) => l10n.petBranchBannerTitleDimmed,
              subtitle: (l10n) => l10n.petBranchBannerSubtitleDimmed,
            );
          case PetBranch.unborn:
            return null;
        }
      case PetTransitionKind.maturation:
        return _BannerSpec(
          icon: Icons.star_border,
          title: (l10n) => l10n.petElderBannerTitle,
          subtitle: (l10n) => l10n.petElderBannerSubtitle,
        );
      case PetTransitionKind.dormancy:
        return _BannerSpec(
          icon: Icons.bedtime_outlined,
          title: (l10n) => l10n.petDormantBannerTitle,
          subtitle: (l10n) => l10n.petDormantBannerSubtitle,
        );
      case PetTransitionKind.adolescence:
      case PetTransitionKind.unknown:
        return null;
    }
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

/// Visibility/interactivity rules baked into this widget:
///
///   * Charge  — always visible; long-press = Surge. Disabled when
///     asleep. Dimmed when energy is at max with no hungry call.
///   * Resonate — always visible. Disabled when asleep. Dimmed when
///     mood is at max with no lonely call.
///   * Stabilise — conditionally visible (only when a hygiene artefact
///     exists). Otherwise hidden.
///   * Sync    — always visible. Dimmed when there's no active call
///     AND stability is at max.
///   * Purge   — conditionally visible (only when sick), pulsing.
///   * Dim     — conditionally visible during the sleep window or when
///     asleep. Dimmed when already asleep.
///   * Inspect — always visible.
///   * Re-sigil — only visible when dormant (replaces the live action
///     set entirely).
class _ActionBar extends ConsumerWidget {
  final PetState state;
  final bool inSleepWindow;

  /// Advisory computed once at the parent level. Used to pulse the
  /// button that matches `advisory.action` so the status line's
  /// inline action name and the bottom-bar pulse reinforce each
  /// other — user's eye follows the cue from sentence to button.
  final PetAdvisory advisory;

  final Future<void> Function(PetActionResult result, HapticType applied)
  onResult;

  const _ActionBar({
    required this.state,
    required this.inSleepWindow,
    required this.advisory,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(ownPetProvider.notifier);

    final dormant = state.stage == PetStage.dormant;
    final egg = state.stage == PetStage.egg;
    final asleep = state.isAsleep;
    final statMax = ref.read(petConfigProvider).statMax;

    // Wrap: call the controller action and forward the outcome to the
    // parent _PetBodyState. The parent decides haptic + no-op reaction.
    VoidCallback run(
      Future<PetActionResult> Function() action,
      HapticType appliedHaptic,
    ) {
      return () async {
        final result = await action();
        await onResult(result, appliedHaptic);
      };
    }

    final buttons = <Widget>[];

    if (dormant) {
      buttons.add(
        PetActionButton(
          icon: Icons.auto_awesome_outlined,
          label: l10n.petActionReSigil,
          accent: AccentColors.yellow,
          pulsing: advisory.action == PetAdvisoryAction.reSigil,
          onTap: run(controller.reSigil, HapticType.heavy),
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
      final hasHungryCall = state.activeCall?.reason == CallReason.hungry;
      final hasLonelyCall = state.activeCall?.reason == CallReason.lonely;
      final chargeUsable = !asleep && !egg;
      final chargeDimmed =
          chargeUsable && state.energy >= statMax && !hasHungryCall;

      buttons.add(
        PetActionButton(
          icon: Icons.bolt_outlined,
          label: l10n.petActionCharge,
          accent: AccentColors.yellow,
          dimmed: chargeDimmed,
          pulsing: advisory.action == PetAdvisoryAction.charge,
          onTap: chargeUsable
              ? run(controller.charge, HapticType.medium)
              : null,
          onLongPress: chargeUsable
              ? run(controller.surge, HapticType.heavy)
              : null,
        ),
      );

      final resonateUsable = !asleep && !egg;
      final resonateDimmed =
          resonateUsable && state.mood >= statMax && !hasLonelyCall;
      buttons.add(
        PetActionButton(
          icon: Icons.graphic_eq,
          label: l10n.petActionResonate,
          accent: AccentColors.pink,
          dimmed: resonateDimmed,
          pulsing: advisory.action == PetAdvisoryAction.resonate,
          onTap: resonateUsable
              ? run(controller.resonate, HapticType.medium)
              : null,
        ),
      );

      if (state.hygieneArtefacts.isNotEmpty) {
        buttons.add(
          PetActionButton(
            icon: Icons.cleaning_services_outlined,
            label: l10n.petActionStabilise,
            accent: AccentColors.teal,
            pulsing: advisory.action == PetAdvisoryAction.stabilise,
            onTap: run(controller.stabilise, HapticType.medium),
          ),
        );
      }

      if (state.isSick) {
        buttons.add(
          PetActionButton(
            icon: Icons.healing_outlined,
            label: l10n.petActionPurge,
            accent: AccentColors.red,
            pulsing: advisory.action == PetAdvisoryAction.purge,
            onTap: run(controller.purge, HapticType.heavy),
          ),
        );
      }

      if (!egg) {
        // Sync is now purely the "answer the call" tap — dim it when
        // there's no call, since stability no longer motivates it.
        final syncDimmed = state.activeCall == null;
        buttons.add(
          PetActionButton(
            icon: Icons.sync,
            label: l10n.petActionSync,
            accent: AccentColors.lavender,
            dimmed: syncDimmed,
            pulsing: advisory.action == PetAdvisoryAction.sync,
            onTap: run(controller.sync, HapticType.light),
          ),
        );
      }

      if ((inSleepWindow || asleep) && !egg) {
        buttons.add(
          PetActionButton(
            icon: Icons.nightlight_round,
            label: l10n.petActionDim,
            accent: AccentColors.indigo,
            dimmed: asleep,
            pulsing: advisory.action == PetAdvisoryAction.dim && !asleep,
            // We still wire onTap while asleep so the user gets the
            // "Already resting" toast rather than a silent no-op.
            onTap: run(controller.dim, HapticType.light),
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
    AppBottomSheet.showScrollable<void>(
      context: context,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (controller) => PetInspectSheet(scrollController: controller),
    );
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
