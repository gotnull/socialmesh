// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// PetTimelineScreen — full-screen lifecycle "story" view.
//
// Structure (top → bottom):
//
//   Header
//     Stage • Branch chip · "N days old" · compact sigil preview
//
//   Origin block (hero)
//     DNA sigil glyph · seed hex · hatched date · dominant allele
//
//   Stage sections (one per stage the pet has entered)
//     Section header: STAGE NAME · relative date
//     Event cards attached to a continuous left spine
//
//   Upcoming block (ghost)
//     "Next: Adolescent in ~1d 4h"
//
// Visual hierarchy:
//
//   Major events     — hero-style card, 44px dot with glow, bold title,
//                      context pill (stage + branch captured at event)
//   Important events — medium card, 28px dot, title + timestamp
//   Minor single     — compact row, 14px dot, inline time
//   Minor grouped    — compact row with count pill ("Charged · 3×")
//                      and first→last range
//
// Responsive: left rail at x=32 on narrow phones; on wide layouts the
// whole column centers at max-width 560 so body text stays readable.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/haptic_service.dart';
import '../../../utils/time_format.dart';
import '../models/care_event.dart';
import '../models/pet_base_allele.dart';
import '../models/pet_enums.dart';
import '../models/pet_state.dart';
import '../models/pet_timeline_view.dart';
import '../providers/pet_providers.dart';
import '../widgets/pet_dna_viewer_sheet.dart';
import '../widgets/pet_sigil_painter.dart';

class PetTimelineScreen extends ConsumerStatefulWidget {
  const PetTimelineScreen({super.key});

  @override
  ConsumerState<PetTimelineScreen> createState() => _PetTimelineScreenState();
}

class _PetTimelineScreenState extends ConsumerState<PetTimelineScreen> {
  bool _openedLogged = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final asyncView = ref.watch(petTimelineViewProvider);
    final state = ref.watch(ownPetProvider).value;

    // One-shot open log. AppLogging.pet is env-gated so this is free
    // on users who haven't opted in to pet logs.
    if (!_openedLogged && !asyncView.isLoading && !asyncView.hasError) {
      _openedLogged = true;
      final view = asyncView.value;
      AppLogging.pet(
        'PetTimelineScreen: opened '
        'events=${view?.totalEvents ?? 0} '
        'sections=${view?.sections.length ?? 0}',
      );
    }

    return GlassScaffold.body(
      title: l10n.petTimelineScreenTitle,
      centerTitle: true,
      // The timeline body is Column > Expanded > CustomScrollView; the
      // inner scrollable must negotiate extent with the outer viewport.
      hasScrollBody: true,
      body: asyncView.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorState(message: e.toString()),
        data: (view) {
          if (view == null || state == null) {
            return _EmptyNoOwnerState(l10n: l10n);
          }
          return _TimelineBody(view: view, state: state, l10n: l10n);
        },
      ),
    );
  }
}

// ============================================================================
// Body — header + spine + sections + upcoming
// ============================================================================

class _TimelineBody extends StatelessWidget {
  final PetTimelineView view;
  final PetState state;
  final AppLocalizations l10n;

  const _TimelineBody({
    required this.view,
    required this.state,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _branchAccent(state.branch);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive: narrow phones stretch to full width; wide
        // tablets center content at a readable max-width so cards
        // don't span half the screen.
        final maxWidth = constraints.maxWidth;
        final contentWidth = maxWidth < 560.0 ? maxWidth : 560.0;
        return Center(
          child: SizedBox(
            width: contentWidth,
            child: Column(
              children: [
                // Pinned header — stage chip + event-count pill stay
                // visible while the spine scrolls.
                _Header(view: view, state: state, accent: accent),
                // Pinned origin (DNA Forged) card — the seed/identity
                // anchor stays visible at the top alongside the header.
                ColoredBox(
                  color: context.background,
                  child: _OriginNode(
                    origin: view.origin,
                    accent: accent,
                    l10n: l10n,
                  ),
                ),
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      for (final section in view.sections)
                        SliverToBoxAdapter(
                          child: _StageSection(
                            section: section,
                            accent: accent,
                            l10n: l10n,
                          ),
                        ),
                      // "Next: …" flows directly after the last entry —
                      // a short spine stub keeps the rail continuous
                      // into the ghost node, and the timeline stays
                      // compact when there are few events instead of
                      // stranding the upcoming node at the bottom of
                      // the viewport behind a screen of empty rail.
                      if (view.upcoming != null) ...[
                        SliverToBoxAdapter(child: _SpineSpacer(accent: accent)),
                        SliverToBoxAdapter(
                          child: _UpcomingNode(
                            upcoming: view.upcoming!,
                            accent: accent,
                            l10n: l10n,
                          ),
                        ),
                      ],
                      // Bottom breathing room + home-indicator safe area.
                      SliverToBoxAdapter(
                        child: SizedBox(
                          height:
                              MediaQuery.paddingOf(context).bottom +
                              AppTheme.spacing16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ============================================================================
// Header — stage/branch/age quick chip row
// ============================================================================

class _Header extends StatelessWidget {
  final PetTimelineView view;
  final PetState state;
  final Color accent;

  const _Header({
    required this.view,
    required this.state,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final ageDays = state.ageInDaysAt(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing24,
        AppTheme.spacing16,
        AppTheme.spacing24,
        AppTheme.spacing12,
      ),
      child: Row(
        children: [
          // Compact pet preview — procedural painter (never Rive here;
          // the timeline is a secondary surface).
          SizedBox(
            width: 52,
            height: 52,
            child: PetCreature(
              dnaSeed: state.dnaSeed,
              stage: state.stage,
              branch: state.branch,
              mood: PetMood.content,
              isAsleep: state.isAsleep,
              isSick: state.isSick,
              isCalling: state.activeCall != null,
              hygieneArtefactCount: state.hygieneArtefacts.length,
              size: 52,
              mode: PetRenderMode.tiny,
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_stageLabel(state.stage, context.l10n)} · '
                  '${_branchLabel(state.branch, context.l10n)}',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                    letterSpacing: 0.4,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  context.l10n.petAgeDaysLabel(ageDays),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textTertiary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),
          _EventCountPill(count: view.totalEvents, accent: accent),
        ],
      ),
    );
  }
}

class _EventCountPill extends StatelessWidget {
  final int count;
  final Color accent;
  const _EventCountPill({required this.count, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        context.l10n.petTimelineEventCountPill(count),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: accent,
          letterSpacing: 0.5,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}

// ============================================================================
// Origin node — DNA/hatch hero at the top of the spine
// ============================================================================

class _OriginNode extends ConsumerWidget {
  final PetTimelineOrigin origin;
  final Color accent;
  final AppLocalizations l10n;

  const _OriginNode({
    required this.origin,
    required this.accent,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seedHex =
        '0x${origin.dnaSeed.toRadixString(16).padLeft(8, '0').toUpperCase()}';
    final hatchedText = _formatAbsolute(context, origin.hatchedAt);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rail + hero dot. No top connector — this is the start.
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  _HeroDot(accent: accent, icon: Icons.auto_awesome_outlined),
                  Expanded(
                    child: _DotsConnector(
                      color: accent.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing24),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    unawaited(
                      ref
                          .read(hapticServiceProvider)
                          .trigger(HapticType.selection),
                    );
                    AppBottomSheet.showScrollable<void>(
                      context: context,
                      initialChildSize: 0.9,
                      minChildSize: 0.5,
                      maxChildSize: 0.95,
                      builder: (controller) =>
                          PetDnaViewerSheet(scrollController: controller),
                    );
                  },
                  child: _OriginCard(
                    title: l10n.petTimelineOriginTitle,
                    seedHex: seedHex,
                    hatchedText: hatchedText,
                    dominantLabel: _alleleDominantLabel(
                      origin.dominantAllele,
                      l10n,
                    ),
                    accent: accent,
                    dominantColor: origin.dominantAllele.archetypeColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OriginCard extends StatelessWidget {
  final String title;
  final String seedHex;
  final String hatchedText;
  final String dominantLabel;
  final Color accent;
  final Color dominantColor;

  const _OriginCard({
    required this.title,
    required this.seedHex,
    required this.hatchedText,
    required this.dominantLabel,
    required this.accent,
    required this.dominantColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
              color: accent,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: AppTheme.spacing6),
          Text(
            seedHex,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: context.textPrimary,
              letterSpacing: 1.0,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dominantColor,
                ),
              ),
              const SizedBox(width: AppTheme.spacing6),
              Text(
                dominantLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            hatchedText,
            style: TextStyle(
              fontSize: 11,
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroDot extends StatelessWidget {
  final Color accent;
  final IconData icon;
  const _HeroDot({required this.accent, required this.icon});

  @override
  Widget build(BuildContext context) {
    // Same flat circle styling as every entry dot. No glow — it bled
    // into the pet sigil above and looked off vs. the row icons.
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: accent.withValues(alpha: 0.25),
        border: Border.all(color: accent.withValues(alpha: 0.85), width: 2.0),
      ),
      child: Icon(icon, size: 18, color: accent),
    );
  }
}

// ============================================================================
// Stage section — header + list of entries attached to the spine
// ============================================================================

class _StageSection extends StatelessWidget {
  final PetTimelineSection section;
  final Color accent;
  final AppLocalizations l10n;

  const _StageSection({
    required this.section,
    required this.accent,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          stage: section.stage,
          startedAt: section.startedAt,
          isCurrent: section.isCurrent,
          accent: accent,
          l10n: l10n,
        ),
        for (var i = 0; i < section.entries.length; i++)
          _EntryRow(
            entry: section.entries[i],
            accent: accent,
            l10n: l10n,
            isLastInSection:
                i == section.entries.length - 1 && !section.isCurrent,
          ),
        if (section.entries.isEmpty)
          _EmptySectionFiller(accent: accent, isCurrent: section.isCurrent),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final PetStage stage;
  final DateTime startedAt;
  final bool isCurrent;
  final Color accent;
  final AppLocalizations l10n;

  const _SectionHeader({
    required this.stage,
    required this.startedAt,
    required this.isCurrent,
    required this.accent,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing24,
        AppTheme.spacing4,
        AppTheme.spacing24,
        AppTheme.spacing8,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  _DotsConnector(
                    color: accent.withValues(alpha: 0.55),
                    height: AppTheme.spacing8,
                  ),
                  // Section marker — circle dot, same vocabulary as
                  // every entry dot. Filled for the current stage,
                  // hollow for past stages.
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: isCurrent ? 0.25 : 0.10),
                      border: Border.all(
                        color: accent.withValues(
                          alpha: isCurrent ? 0.85 : 0.45,
                        ),
                        width: isCurrent ? 2.0 : 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.trending_up,
                      size: 13,
                      color: accent.withValues(alpha: isCurrent ? 1.0 : 0.65),
                    ),
                  ),
                  Expanded(
                    child: _DotsConnector(
                      color: accent.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _stageLabel(stage, l10n).toUpperCase(),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.6,
                          color: isCurrent ? accent : context.textSecondary,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: AppTheme.spacing8),
                        _NowPill(
                          accent: accent,
                          label: l10n.petTimelineNowPill,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    _formatAbsolute(context, startedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textTertiary,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NowPill extends StatelessWidget {
  final Color accent;
  final String label;
  const _NowPill({required this.accent, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: accent,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}

class _EmptySectionFiller extends StatelessWidget {
  final Color accent;
  final bool isCurrent;
  const _EmptySectionFiller({required this.accent, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    // Quietly acknowledge an empty section with a short spine
    // segment so the visual flow isn't broken.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Center(
              child: _DotsConnector(
                color: accent.withValues(alpha: 0.55),
                height: AppTheme.spacing24,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: isCurrent
                ? Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
                    child: Text(
                      context.l10n.petTimelineQuietCurrent,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: context.textTertiary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Entry row — dispatches to major / important / minor / grouped
// ============================================================================

class _EntryRow extends ConsumerStatefulWidget {
  final PetTimelineEntry entry;
  final Color accent;
  final AppLocalizations l10n;

  /// True when this entry is the LAST in a non-current section, so we
  /// hide the bottom connector to visually close that stage-bucket.
  final bool isLastInSection;

  const _EntryRow({
    required this.entry,
    required this.accent,
    required this.l10n,
    required this.isLastInSection,
  });

  @override
  ConsumerState<_EntryRow> createState() => _EntryRowState();
}

class _EntryRowState extends ConsumerState<_EntryRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final visual = _entryVisual(entry, widget.accent);
    final isMajor = entry.importance == PetTimelineImportance.major;
    final isImportant = entry.importance == PetTimelineImportance.important;
    // Larger, more legible dots — minor was 14/8 which read as a bullet
    // rather than an icon. Spine stub bumped to give breathing room
    // between consecutive rows.
    final dotSize = isMajor ? 36.0 : (isImportant ? 28.0 : 24.0);
    final iconSize = isMajor ? 18.0 : (isImportant ? 14.0 : 13.0);
    final stubHeight = isMajor ? AppTheme.spacing14 : AppTheme.spacing12;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left rail: spine + dot
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  _DotsConnector(
                    color: widget.accent.withValues(alpha: 0.55),
                    height: stubHeight,
                  ),
                  _EntryDot(
                    color: visual.color,
                    icon: visual.icon,
                    size: dotSize,
                    iconSize: iconSize,
                    isMajor: isMajor,
                  ),
                  Expanded(
                    child: widget.isLastInSection
                        ? const SizedBox.shrink()
                        : _DotsConnector(
                            color: widget.accent.withValues(alpha: 0.55),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            // Right column: card content
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: isMajor || isImportant
                    ? () {
                        unawaited(
                          ref
                              .read(hapticServiceProvider)
                              .trigger(HapticType.selection),
                        );
                        setState(() => _expanded = !_expanded);
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacing14),
                  child: _EntryContent(
                    entry: entry,
                    visual: visual,
                    accent: widget.accent,
                    l10n: widget.l10n,
                    expanded: _expanded,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryDot extends StatelessWidget {
  final Color color;
  final IconData icon;
  final double size;
  final double iconSize;
  final bool isMajor;
  const _EntryDot({
    required this.color,
    required this.icon,
    required this.size,
    required this.iconSize,
    required this.isMajor,
  });

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: isMajor ? 0.25 : 0.15),
        border: Border.all(
          color: color.withValues(alpha: isMajor ? 0.85 : 0.55),
          width: isMajor ? 2.0 : 1.5,
        ),
      ),
      child: Icon(icon, size: iconSize, color: color),
    );
    if (!isMajor) return dot;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: dot,
    );
  }
}

class _EntryContent extends StatelessWidget {
  final PetTimelineEntry entry;
  final _EntryVisual visual;
  final Color accent;
  final AppLocalizations l10n;
  final bool expanded;

  const _EntryContent({
    required this.entry,
    required this.visual,
    required this.accent,
    required this.l10n,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    switch (entry) {
      case PetTimelineSingleEntry e:
        return _SingleContent(
          event: e.event,
          visual: visual,
          importance: e.importance,
          stage: e.stageAtEvent,
          branch: e.branchAtEvent,
          accent: accent,
          l10n: l10n,
          expanded: expanded,
        );
      case PetTimelineGroupedEntry g:
        return _GroupedContent(
          entry: g,
          visual: visual,
          accent: accent,
          l10n: l10n,
        );
    }
  }
}

class _SingleContent extends StatelessWidget {
  final CareEvent event;
  final _EntryVisual visual;
  final PetTimelineImportance importance;
  final PetStage stage;
  final PetBranch branch;
  final Color accent;
  final AppLocalizations l10n;
  final bool expanded;

  const _SingleContent({
    required this.event,
    required this.visual,
    required this.importance,
    required this.stage,
    required this.branch,
    required this.accent,
    required this.l10n,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final isMajor = importance == PetTimelineImportance.major;
    final isImportant = importance == PetTimelineImportance.important;
    final titleSize = isMajor ? 16.0 : (isImportant ? 14.0 : 13.0);
    final weight = isMajor ? FontWeight.w700 : FontWeight.w600;
    final label = _eventLabel(event.kind, l10n);
    final description = expanded
        ? _eventDescription(event.kind, l10n, stage, branch)
        : null;

    if (!isMajor && !isImportant) {
      // Minor singles render as a compact row with no card chrome.
      // Top padding aligns the text's vertical center with the dot's
      // vertical center (dot center y ≈ stub(12) + dot/2(12) = 24).
      return Padding(
        padding: const EdgeInsets.only(top: AppTheme.spacing16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: titleSize,
                  fontWeight: weight,
                  color: context.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacing8),
            Text(
              _formatRelative(event.at, l10n),
              style: TextStyle(
                fontSize: 11,
                color: context.textTertiary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ),
      );
    }

    // Major + important: real card.
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(
          color: (isMajor ? visual.color : context.border).withValues(
            alpha: isMajor ? 0.40 : 0.30,
          ),
          width: isMajor ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: weight,
              color: context.textPrimary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          const SizedBox(height: AppTheme.spacing2),
          Text(
            '${_formatRelative(event.at, l10n)}  ·  ${_formatAbsolute(context, event.at)}',
            style: TextStyle(
              fontSize: 11,
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          if (isImportant || isMajor) ...[
            const SizedBox(height: AppTheme.spacing6),
            Row(
              children: [
                _ContextChip(
                  label: _stageLabel(stage, l10n),
                  color: context.textSecondary,
                ),
                const SizedBox(width: AppTheme.spacing6),
                _ContextChip(
                  label: _branchLabel(branch, l10n),
                  color: visual.color,
                ),
              ],
            ),
          ],
          if (description != null) ...[
            const SizedBox(height: AppTheme.spacing8),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupedContent extends StatelessWidget {
  final PetTimelineGroupedEntry entry;
  final _EntryVisual visual;
  final Color accent;
  final AppLocalizations l10n;

  const _GroupedContent({
    required this.entry,
    required this.visual,
    required this.accent,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final label = _eventLabel(entry.kind, l10n);
    // Match the minor-single top padding so the row's text aligns with
    // the dot's vertical center on the left rail.
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacing16),
      child: Row(
        children: [
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                ),
                children: [
                  TextSpan(text: label),
                  const TextSpan(text: '  '),
                  TextSpan(
                    text: l10n.petTimelineGroupedCount(entry.count),
                    style: TextStyle(
                      color: visual.color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Text(
            _formatRelative(entry.lastAt, l10n),
            style: TextStyle(
              fontSize: 11,
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  final String label;
  final Color color;
  const _ContextChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: color.withValues(alpha: 0.30)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.4,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}

// ============================================================================
// Upcoming — ghost "next stage in ~Xd" at the tail
// ============================================================================

class _UpcomingNode extends StatelessWidget {
  final PetTimelineUpcoming upcoming;
  final Color accent;
  final AppLocalizations l10n;

  const _UpcomingNode({
    required this.upcoming,
    required this.accent,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  // Dashed-look connector to the ghost marker.
                  _DashedVertical(
                    color: accent.withValues(alpha: 0.45),
                    height: 24,
                  ),
                  // Ghost (hollow) dot.
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.transparent,
                      border: Border.all(
                        color: accent.withValues(alpha: 0.65),
                        width: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.petTimelineUpcomingLabel(
                        _stageLabel(upcoming.nextStage, l10n),
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.textSecondary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      upcoming.remaining == Duration.zero
                          ? l10n.petTimelineUpcomingImminent
                          : l10n.petTimelineUpcomingIn(
                              _formatDuration(upcoming.remaining, l10n),
                            ),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Short spine stub between the last entry and the upcoming ghost
/// node, keeping the rail visually continuous into "Next: …".
class _SpineSpacer extends StatelessWidget {
  final Color accent;

  const _SpineSpacer({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing24),
      child: Row(
        children: [
          SizedBox(
            width: AppTheme.spacing40,
            child: Center(
              child: _DotsConnector(
                color: accent.withValues(alpha: 0.55),
                height: AppTheme.spacing16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical column of evenly-spaced dots used in place of a solid
/// line as the spine connector between rail icons. Pass [height] for
/// fixed-height stubs; omit it (place inside an Expanded) to fill
/// available vertical space.
class _DotsConnector extends StatelessWidget {
  final Color color;
  final double? height;

  const _DotsConnector({required this.color, this.height});

  @override
  Widget build(BuildContext context) {
    final painter = _DotsPainter(color: color);
    if (height != null) {
      return SizedBox(
        width: 4,
        height: height,
        child: CustomPaint(painter: painter),
      );
    }
    // Inside Expanded — let CustomPaint fill the parent constraints.
    return SizedBox(
      width: 4,
      child: CustomPaint(painter: painter, size: Size.infinite),
    );
  }
}

class _DotsPainter extends CustomPainter {
  final Color color;
  const _DotsPainter({required this.color});

  static const double _dotRadius = 1.5;
  static const double _gap = 5.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cx = size.width / 2;
    var cy = _dotRadius;
    while (cy <= size.height - _dotRadius) {
      canvas.drawCircle(Offset(cx, cy), _dotRadius, paint);
      cy += _dotRadius * 2 + _gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DotsPainter old) => old.color != color;
}

class _DashedVertical extends StatelessWidget {
  final Color color;
  final double height;
  const _DashedVertical({required this.color, required this.height});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 2,
      height: height,
      child: CustomPaint(painter: _DashedPainter(color: color)),
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Color color;
  const _DashedPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0;
    const dashLen = 4.0;
    const gapLen = 3.0;
    var y = 0.0;
    while (y < size.height) {
      final end = (y + dashLen).clamp(0.0, size.height);
      canvas.drawLine(
        Offset(size.width / 2, y),
        Offset(size.width / 2, end),
        paint,
      );
      y += dashLen + gapLen;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter old) => old.color != color;
}

// ============================================================================
// Empty + error states
// ============================================================================

class _EmptyNoOwnerState extends StatelessWidget {
  final AppLocalizations l10n;
  const _EmptyNoOwnerState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timeline_outlined,
              size: 56,
              color: context.textTertiary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              l10n.petTimelineEmptyTitle,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: context.textSecondary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            const SizedBox(height: AppTheme.spacing6),
            Text(
              l10n.petTimelineEmptySubtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.textTertiary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: context.textTertiary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// Icon / label dispatch — shared with pet_recent_timeline semantically
// but kept local so we can tune timeline-specific visuals independently.
// ============================================================================

class _EntryVisual {
  final IconData icon;
  final Color color;
  const _EntryVisual(this.icon, this.color);
}

_EntryVisual _entryVisual(PetTimelineEntry entry, Color accent) {
  final kind = switch (entry) {
    PetTimelineSingleEntry e => e.event.kind,
    PetTimelineGroupedEntry g => g.kind,
  };
  return _visualForKind(kind, accent);
}

_EntryVisual _visualForKind(CareEventKind kind, Color accent) {
  switch (kind) {
    case CareEventKind.hatched:
      return _EntryVisual(Icons.egg_outlined, AppTheme.primaryPurple);
    case CareEventKind.stageAdvanced:
      return _EntryVisual(Icons.trending_up, accent);
    case CareEventKind.branchResolved:
      return _EntryVisual(Icons.account_tree_outlined, AccentColors.yellow);
    case CareEventKind.dormantEntered:
      return _EntryVisual(Icons.hourglass_empty, AccentColors.slate);
    case CareEventKind.reSigilled:
      return _EntryVisual(Icons.auto_awesome_outlined, AccentColors.yellow);
    case CareEventKind.charged:
      return _EntryVisual(Icons.bolt_outlined, AccentColors.yellow);
    case CareEventKind.surged:
      return _EntryVisual(Icons.flash_on, AccentColors.orange);
    case CareEventKind.resonated:
      return _EntryVisual(Icons.favorite_border, AccentColors.pink);
    case CareEventKind.stabilised:
      return _EntryVisual(Icons.cleaning_services_outlined, AccentColors.teal);
    case CareEventKind.synced:
      return _EntryVisual(Icons.sync, AccentColors.lavender);
    case CareEventKind.purged:
    case CareEventKind.sicknessRecovered:
      return _EntryVisual(Icons.healing_outlined, AccentColors.emerald);
    case CareEventKind.dimmed:
    case CareEventKind.sleepEntered:
      return _EntryVisual(Icons.nightlight_round, AccentColors.indigo);
    case CareEventKind.sleepExited:
      return _EntryVisual(Icons.wb_sunny_outlined, AccentColors.yellow);
    case CareEventKind.inspected:
      return _EntryVisual(Icons.visibility_outlined, AccentColors.sky);
    case CareEventKind.hygieneArtefactAppeared:
      return _EntryVisual(
        Icons.cleaning_services_outlined,
        AccentColors.orange,
      );
    case CareEventKind.sicknessOnset:
      return _EntryVisual(Icons.medical_services_outlined, AccentColors.red);
    case CareEventKind.callStarted:
      return _EntryVisual(
        Icons.notifications_active_outlined,
        AccentColors.pink,
      );
    case CareEventKind.callAnswered:
      return _EntryVisual(Icons.check_circle_outline, AccentColors.emerald);
    case CareEventKind.callMissed:
      return _EntryVisual(
        Icons.notifications_off_outlined,
        AccentColors.orange,
      );
    case CareEventKind.mistakeRecorded:
      return _EntryVisual(Icons.error_outline, AccentColors.red);
  }
}

String _eventLabel(CareEventKind kind, AppLocalizations l10n) {
  switch (kind) {
    case CareEventKind.hatched:
      return l10n.petEventHatched;
    case CareEventKind.stageAdvanced:
      return l10n.petEventStageAdvanced;
    case CareEventKind.branchResolved:
      return l10n.petEventBranchResolved;
    case CareEventKind.dormantEntered:
      return l10n.petEventDormantEntered;
    case CareEventKind.reSigilled:
      return l10n.petEventReSigilled;
    case CareEventKind.charged:
      return l10n.petEventCharged;
    case CareEventKind.surged:
      return l10n.petEventSurged;
    case CareEventKind.resonated:
      return l10n.petEventResonated;
    case CareEventKind.stabilised:
      return l10n.petEventStabilised;
    case CareEventKind.synced:
      return l10n.petEventSynced;
    case CareEventKind.purged:
      return l10n.petEventPurged;
    case CareEventKind.dimmed:
      return l10n.petEventDimmed;
    case CareEventKind.inspected:
      return l10n.petEventInspected;
    case CareEventKind.hygieneArtefactAppeared:
      return l10n.petEventHygieneArtefactAppeared;
    case CareEventKind.sicknessOnset:
      return l10n.petEventSicknessOnset;
    case CareEventKind.sicknessRecovered:
      return l10n.petEventSicknessRecovered;
    case CareEventKind.sleepEntered:
      return l10n.petEventSleepEntered;
    case CareEventKind.sleepExited:
      return l10n.petEventSleepExited;
    case CareEventKind.callStarted:
      return l10n.petEventCallStarted;
    case CareEventKind.callAnswered:
      return l10n.petEventCallAnswered;
    case CareEventKind.callMissed:
      return l10n.petEventCallMissed;
    case CareEventKind.mistakeRecorded:
      return l10n.petEventMistakeRecorded;
  }
}

/// Richer description shown when a major/important card is expanded.
/// Falls back to an empty string when we don't have meaningful detail
/// to add — the UI suppresses the line in that case.
String? _eventDescription(
  CareEventKind kind,
  AppLocalizations l10n,
  PetStage stage,
  PetBranch branch,
) {
  switch (kind) {
    case CareEventKind.hatched:
      return l10n.petTimelineDetailHatched;
    case CareEventKind.stageAdvanced:
      return l10n.petTimelineDetailStageAdvanced(_stageLabel(stage, l10n));
    case CareEventKind.branchResolved:
      return l10n.petTimelineDetailBranchResolved(_branchLabel(branch, l10n));
    case CareEventKind.dormantEntered:
      return l10n.petTimelineDetailDormantEntered;
    case CareEventKind.reSigilled:
      return l10n.petTimelineDetailReSigilled;
    case CareEventKind.sicknessOnset:
      return l10n.petTimelineDetailSicknessOnset;
    case CareEventKind.sicknessRecovered:
      return l10n.petTimelineDetailSicknessRecovered;
    case CareEventKind.purged:
      return l10n.petTimelineDetailPurged;
    case CareEventKind.callMissed:
      return l10n.petTimelineDetailCallMissed;
    case CareEventKind.mistakeRecorded:
      return l10n.petTimelineDetailMistakeRecorded;
    default:
      return null;
  }
}

// ============================================================================
// Label + time helpers
// ============================================================================

String _stageLabel(PetStage stage, AppLocalizations l10n) {
  switch (stage) {
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

String _branchLabel(PetBranch branch, AppLocalizations l10n) {
  switch (branch) {
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

String _alleleDominantLabel(PetBaseAllele allele, AppLocalizations l10n) {
  final name = switch (allele) {
    PetBaseAllele.aurora => l10n.petAlleleAurora,
    PetBaseAllele.tether => l10n.petAlleleTether,
    PetBaseAllele.gale => l10n.petAlleleGale,
    PetBaseAllele.calm => l10n.petAlleleCalm,
  };
  return l10n.petTimelineOriginDominant(name);
}

String _formatRelative(DateTime at, AppLocalizations l10n) {
  final diff = DateTime.now().difference(at);
  if (diff.isNegative || diff.inMinutes < 1) return l10n.commonJustNow;
  if (diff.inHours < 1) return l10n.commonMinutesAgo(diff.inMinutes);
  if (diff.inDays < 1) return l10n.commonHoursAgo(diff.inHours);
  return l10n.commonDaysAgo(diff.inDays);
}

String _formatAbsolute(BuildContext context, DateTime at) {
  // Short absolute label that reads OK inline with the relative time.
  // Time portion respects the user's 12/24h preference via AppTimeFormat.
  // Timeline records are stored UTC-flagged; render in the local zone.
  final local = at.toLocal();
  final now = DateTime.now();
  final sameYear = local.year == now.year;
  const months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final date = sameYear
      ? '${local.day} ${months[local.month]}'
      : '${local.day} ${months[local.month]} ${local.year}';
  final timeStr = AppTimeFormat.timeOnly(context).format(local);
  return '$date · $timeStr';
}

String _formatDuration(Duration d, AppLocalizations l10n) {
  if (d.inDays >= 1) {
    final days = d.inDays;
    final hours = d.inHours - days * 24;
    return hours > 0
        ? l10n.petTimelineDurationDaysHours(days, hours)
        : l10n.petTimelineDurationDays(days);
  }
  if (d.inHours >= 1) {
    final hours = d.inHours;
    final minutes = d.inMinutes - hours * 60;
    return minutes > 0
        ? l10n.petTimelineDurationHoursMinutes(hours, minutes)
        : l10n.petTimelineDurationHours(hours);
  }
  if (d.inMinutes >= 1) return l10n.petTimelineDurationMinutes(d.inMinutes);
  return l10n.petTimelineDurationImminent;
}

Color _branchAccent(PetBranch branch) {
  switch (branch) {
    case PetBranch.luminous:
      return AccentColors.yellow;
    case PetBranch.steady:
      return AccentColors.emerald;
    case PetBranch.volatile:
      return AccentColors.orange;
    case PetBranch.dimmed:
      return AccentColors.lavender;
    case PetBranch.unborn:
      return AppTheme.primaryPurple;
  }
}
