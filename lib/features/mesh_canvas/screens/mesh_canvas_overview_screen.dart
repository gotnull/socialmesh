// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas entry screen — the drawer's destination.
//
// Information architecture (load-bearing — last reworked in S8 after
// the dev caught an IA drift where "Primary" was leaking onto the
// Local Device Canvas via shared cards + shared identity chip):
//
//   MeshCanvas
//   [ Local ] [ Mesh ]
//
//   LOCAL mode (chip = Local):
//     - Renders the Local Device Canvas viewport DIRECTLY under the
//       chip selector. No intermediary card, no list, no push step.
//     - The viewport body (CanvasViewportBody) shows the local
//       canvas + strip + identity chip ("Local Device Canvas /
//       Offline sandbox · paints remain local").
//     - No channel name appears anywhere. No "Primary".
//
//   MESH mode (chip = Mesh):
//     - Lists every configured Meshtastic channel as a latent
//       canvas. One row per channel, dormant or live.
//     - Tapping a channel pushes [MeshCanvasViewerScreen] with that
//       channel's canvas. The viewer's app bar shows the channel
//     name (Primary / LongFast / etc).
//     - No Local Device Canvas card lives here; Local belongs to
//       the Local chip, period.
//
// Hard IA rules (enforced by the canvas_overview_ia_test pin):
//   - "Local Device Canvas" framing NEVER appears around a mesh
//     canvas (no identity chip on mesh viewers).
//   - Channel names NEVER appear in Local mode.
//   - No card on the overview maps two scopes into one hierarchy.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/chip_selector.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/gradient_border_container.dart';
import '../../../core/widgets/metric_chip.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/staggered_list_tile.dart';
import '../../../services/canvas/canvas_models.dart';
import '../../../services/haptic_service.dart';
import '../providers/mesh_canvas_participation_providers.dart';
import '../providers/mesh_canvas_providers.dart';
import '../widgets/canvas_help_sheet.dart';
import '../widgets/canvas_overview_hero_card.dart';
import '../widgets/canvas_participation_disabled_card.dart';
import '../widgets/canvas_participation_onboarding_sheet.dart';
import '../widgets/canvas_participation_settings_sheet.dart';
import '../widgets/canvas_viewport_body.dart';
import '../widgets/channel_canvas_thumbnail.dart';
import 'mesh_canvas_viewer_screen.dart';

/// Local vs Mesh tab discriminator. Kept private to the overview
/// screen — it's a UI concern, not a canonical canvas property.
enum _OverviewTab { local, mesh }

final _overviewTabProvider =
    NotifierProvider<_OverviewTabNotifier, _OverviewTab>(
      _OverviewTabNotifier.new,
    );

class _OverviewTabNotifier extends Notifier<_OverviewTab> {
  @override
  _OverviewTab build() => _OverviewTab.local;

  void select(_OverviewTab tab) => state = tab;
}

class MeshCanvasOverviewScreen extends ConsumerStatefulWidget {
  const MeshCanvasOverviewScreen({super.key});

  @override
  ConsumerState<MeshCanvasOverviewScreen> createState() =>
      _MeshCanvasOverviewScreenState();
}

class _MeshCanvasOverviewScreenState
    extends ConsumerState<MeshCanvasOverviewScreen>
    with LifecycleSafeMixin<MeshCanvasOverviewScreen> {
  bool _onboardingShown = false;

  @override
  void initState() {
    super.initState();
    // First-run participation onboarding: post-frame so the screen's
    // GlassScaffold is mounted before the sheet pushes its route.
    // `meshCanvasParticipationProvider` resolves to AsyncLoading on
    // cold start; we re-check after the AsyncData lands via build().
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _maybeShowOnboarding();
    });
  }

  void _maybeShowOnboarding() {
    if (!mounted) return;
    if (_onboardingShown) return;
    final settings = ref.read(meshCanvasParticipationProvider).asData?.value;
    // Wait for the AsyncNotifier to resolve. The build() watches the
    // provider, so a future rebuild after AsyncData lands will call
    // this again via the post-frame callback re-scheduled there.
    if (settings == null) return;
    if (settings.onboardingSeen) {
      _onboardingShown = true;
      return;
    }
    _onboardingShown = true;
    AppLogging.meshCanvas('participation: showing first-run onboarding sheet');
    showCanvasParticipationOnboardingSheet(context: context);
  }

  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(_overviewTabProvider);
    // Materialise the canvas inbound attach exactly once, when the
    // user enters the feature.
    ref.watch(canvasProtocolWiringProvider);
    // Re-check onboarding after every settings rebuild so the first
    // AsyncData (post-cold-start) triggers the sheet exactly once.
    ref.listen(meshCanvasParticipationProvider, (_, _) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowOnboarding();
      });
    });
    final l = context.l10n;

    return GlassScaffold(
      title: l.meshCanvasPlaceholderTitle,
      physics: const NeverScrollableScrollPhysics(),
      actions: [
        IconButton(
          key: const ValueKey('mesh-canvas-overview-settings'),
          tooltip: l.meshCanvasParticipationSettingsTooltip,
          icon: const Icon(Icons.tune_rounded),
          onPressed: () {
            ref.haptics.buttonTap();
            showCanvasParticipationSettingsSheet(context: context);
          },
        ),
        IconButton(
          key: const ValueKey('mesh-canvas-overview-help'),
          tooltip: l.meshCanvasHelpTooltip,
          icon: const Icon(Icons.help_outline_rounded),
          onPressed: () {
            ref.haptics.buttonTap();
            showCanvasHelpSheet(context: context);
          },
        ),
      ],
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing12,
              AppTheme.spacing16,
              AppTheme.spacing8,
            ),
            child: ChipSelector<_OverviewTab>(
              value: activeTab,
              options: [
                ChipOption(
                  value: _OverviewTab.local,
                  label: l.meshCanvasOverviewTabLocal,
                  icon: Icons.smartphone_outlined,
                  color: context.accentColor,
                ),
                ChipOption(
                  value: _OverviewTab.mesh,
                  label: l.meshCanvasOverviewTabMesh,
                  icon: Icons.share_outlined,
                  color: context.accentColor,
                ),
              ],
              onChanged: (tab) {
                ref.haptics.tabChange();
                ref.read(_overviewTabProvider.notifier).select(tab);
              },
            ),
          ),
        ),
        SliverFillRemaining(
          hasScrollBody: true,
          child: activeTab == _OverviewTab.local
              ? const _LocalTabContent()
              : const _MeshTabContent(),
        ),
      ],
    );
  }
}

/// Local mode body — renders the Local Device Canvas viewport
/// DIRECTLY. No card, no list, no push. The Local sandbox is
/// singular, so the chip selector + viewport is the entire UX.
class _LocalTabContent extends ConsumerWidget {
  const _LocalTabContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localAsync = ref.watch(localDeviceCanvasProvider);
    return localAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Text(
          'Could not load local canvas: $e', // lint-allow: hardcoded-string
          style: TextStyle(color: context.textSecondary),
          textAlign: TextAlign.center,
        ),
      ),
      data: (canvas) => CanvasViewportBody(canvas: canvas),
    );
  }
}

/// Mesh mode body — lists channel canvases (latent or live).
///
/// IA gate (CANVAS_PARTICIPATION_V0_1.md §5.2): when the user has not
/// opted into mesh participation, this widget renders ONLY the calm
/// "Join mesh canvases" CTA card. No hero, no PRIMARY COMMONS, no
/// OTHER CHANNELS — hiding the channel list entirely prevents any
/// tap that would surface a viewer (and therefore a presence /
/// attach / send) before consent.
class _MeshTabContent extends ConsumerWidget {
  const _MeshTabContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participationEnabled = ref.watch(
      meshCanvasParticipationEnabledProvider,
    );
    if (!participationEnabled) {
      return const SingleChildScrollView(
        child: CanvasParticipationDisabledCard(),
      );
    }
    final latentAsync = ref.watch(latentChannelCanvasesProvider);
    return latentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Text(
          'Could not list channel canvases: $e', // lint-allow: hardcoded-string
          style: TextStyle(color: context.textSecondary),
          textAlign: TextAlign.center,
        ),
      ),
      data: (rows) {
        if (rows.isEmpty) return const _OverviewEmptyState();
        // Aggregate stats for the hero card.
        var liveCount = 0;
        var totalPaintedCells = 0;
        for (final row in rows) {
          final m = row.materialised;
          if (m == null) continue;
          if (m.cellCount > 0) liveCount++;
          totalPaintedCells += m.cellCount;
        }
        // IA hierarchy (v0.1): Primary (channel 0) is treated as the
        // shared commons for this mesh — visually dominant, first
        // section, strongest CTA. All other configured channels are
        // surfaced as a secondary "OTHER CHANNELS" section so users
        // understand they're private / quieter boards, not equally
        // weighted alternatives to Primary. NO global / worldwide
        // canvas is implied; Primary is the commons for THIS mesh.
        LatentChannelCanvas? primary;
        final others = <LatentChannelCanvas>[];
        for (final row in rows) {
          if (row.channelIndex == 0 && primary == null) {
            primary = row;
          } else {
            others.add(row);
          }
        }
        final l = context.l10n;
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: CanvasOverviewHeroCard(
                channelCount: rows.length,
                liveCount: liveCount,
                totalPaintedCells: totalPaintedCells,
              ),
            ),
            if (primary != null) ...[
              SliverPersistentHeader(
                pinned: true,
                delegate: SectionHeaderDelegate(
                  title: l.meshCanvasOverviewPrimaryCommonsSectionHeader,
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing16,
                  AppTheme.spacing4,
                  AppTheme.spacing16,
                  AppTheme.spacing20,
                ),
                sliver: SliverToBoxAdapter(
                  child: StaggeredListTile(
                    index: 0,
                    child: _PrimaryCommonsCard(latent: primary),
                  ),
                ),
              ),
            ],
            if (others.isNotEmpty) ...[
              SliverPersistentHeader(
                pinned: true,
                delegate: SectionHeaderDelegate(
                  title: l.meshCanvasOverviewOtherChannelsSectionHeader,
                  count: others.length,
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTheme.spacing16,
                    AppTheme.spacing4,
                    AppTheme.spacing16,
                    AppTheme.spacing8,
                  ),
                  child: Text(
                    l.meshCanvasOverviewOtherChannelsSubtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textTertiary,
                      fontFamily: AppTheme.fontFamily,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing16,
                  AppTheme.spacing4,
                  AppTheme.spacing16,
                  AppTheme.spacing24,
                ),
                sliver: SliverList.separated(
                  itemCount: others.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppTheme.spacing12),
                  itemBuilder: (context, index) => StaggeredListTile(
                    // Offset by 1 so the Primary card animates first,
                    // then the secondary list cascades after.
                    index: index + 1,
                    child: _LatentChannelCard(latent: others[index]),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _OverviewEmptyState extends StatelessWidget {
  const _OverviewEmptyState();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    // Only reachable when (a) Local tab has zero canvases — defensive,
    // sandbox auto-creates in v0.1 — or (b) Mesh tab has zero
    // Meshtastic channels configured. Copy is channel-centric so the
    // user understands the source: channels, not discovery.
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [
          Icons.share_outlined,
          Icons.share_arrival_time_outlined,
          Icons.podcasts,
          Icons.hub_outlined,
        ],
        taglines: [
          l.meshCanvasOverviewEmptyTagline1,
          l.meshCanvasOverviewEmptyTagline2,
          l.meshCanvasOverviewEmptyTagline3,
        ],
        titlePrefix: l.meshCanvasOverviewEmptyTitlePrefix,
        titleKeyword: l.meshCanvasOverviewEmptyTitleKeyword,
        titleSuffix: l.meshCanvasOverviewEmptyTitleSuffix,
      ),
    );
  }
}

/// Pure helper for the relative-time fragment used in the card's
/// metadata cluster. Defaults to the canonical `nodedexRelativeXxx`
/// keys so the wording stays consistent with NodeDex / Constellation.
String _relativeActivityCluster(BuildContext context, int lastOpAtMs) {
  final l = context.l10n;
  if (lastOpAtMs <= 0) return l.meshCanvasOverviewNeverPainted;
  final delta = DateTime.now().difference(
    DateTime.fromMillisecondsSinceEpoch(lastOpAtMs),
  );
  if (delta.inMinutes < 1) return l.nodedexRelativeJustNow;
  if (delta.inMinutes < 60) return l.nodedexRelativeMinutesAgo(delta.inMinutes);
  if (delta.inHours < 24) return l.nodedexRelativeHoursAgo(delta.inHours);
  if (delta.inDays < 30) return l.nodedexRelativeDaysAgo(delta.inDays);
  return l.nodedexRelativeMonthsAgo(delta.inDays ~/ 30);
}

/// Dominant card for the Primary channel canvas — the "commons" for
/// this mesh in v0.1.
///
/// Visually dominant relative to [_LatentChannelCard]: larger
/// thumbnail (120 px), eyebrow `COMMONS` badge, dedicated subtitle,
/// stronger accent presence, and a CTA pill that frames the canvas
/// as the default place to start painting. Does NOT imply a global
/// canvas — copy is scoped to "this mesh".
class _PrimaryCommonsCard extends ConsumerWidget {
  final LatentChannelCanvas latent;

  const _PrimaryCommonsCard({required this.latent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final accent = context.accentColor;
    final isLive =
        latent.materialised != null && latent.materialised!.cellCount > 0;

    final Widget thumbnail = latent.isDormant || latent.materialised == null
        ? const ChannelCanvasThumbnail(
            cells: <CanvasCell>[],
            isDormant: true,
            size: 120,
          )
        : _LiveThumbnail(
            canvasLocalId: latent.materialised!.localId,
            size: 120,
          );

    return GradientBorderContainer(
      borderRadius: AppTheme.radius20,
      borderWidth: 1.0,
      // Stronger accent presence than the secondary cards (0.05 /
      // 0.11) so Primary visually dominates as the commons.
      accentOpacity: isLive ? 0.22 : 0.14,
      enableDepthBlend: true,
      depthBlendOpacity: 0.04,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius20),
          onTap: () =>
              _openLatentCanvas(context: context, ref: ref, latent: latent),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                thumbnail,
                const SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Eyebrow badge — distinguishes the commons
                      // visually without claiming admin / ownership.
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(AppTheme.radius8),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.32),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          l.meshCanvasOverviewPrimaryCommonsBadge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: accent,
                            letterSpacing: 1.2,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing8),
                      Text(
                        latent.channelName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                          fontFamily: AppTheme.fontFamily,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        l.meshCanvasOverviewPrimaryCommonsSubtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textSecondary,
                          fontFamily: AppTheme.fontFamily,
                          letterSpacing: 0.2,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                      if (latent.isDormant ||
                          latent.materialised == null ||
                          latent.materialised!.cellCount == 0)
                        _PrimaryCommonsDormantCta(accent: accent)
                      else
                        _ActiveMetadata(latent: latent),
                    ],
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

/// Dormant-state CTA cluster on the Primary commons card. Pill-shaped
/// accent-filled "Seed the first pixel" button + a soft secondary
/// "First paint wakes the board" hint underneath.
class _PrimaryCommonsDormantCta extends StatelessWidget {
  final Color accent;

  const _PrimaryCommonsDormantCta({required this.accent});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: AppTheme.spacing6,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                accent.withValues(alpha: 0.22),
                accent.withValues(alpha: 0.12),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            border: Border.all(
              color: accent.withValues(alpha: 0.45),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.brush_outlined, size: 13, color: accent),
              const SizedBox(width: AppTheme.spacing6),
              Text(
                l.meshCanvasOverviewPrimaryCommonsDormantCta,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: accent,
                  letterSpacing: 0.4,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing6),
        Text(
          l.meshCanvasOverviewPrimaryCommonsDormantHint,
          style: TextStyle(
            fontSize: 11,
            color: context.textTertiary,
            fontFamily: AppTheme.fontFamily,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

/// Shared open-canvas flow used by both card variants. Pulled into a
/// free function so [_PrimaryCommonsCard] and [_LatentChannelCard] do
/// not drift apart on the tap path.
Future<void> _openLatentCanvas({
  required BuildContext context,
  required WidgetRef ref,
  required LatentChannelCanvas latent,
}) async {
  ref.haptics.itemSelect();
  final navigator = Navigator.of(context);
  final existing = latent.materialised;
  if (existing != null) {
    await navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => MeshCanvasViewerScreen(canvas: existing),
      ),
    );
    return;
  }
  final repoAsync = ref.read(canvasRepositoryProvider);
  final repo = repoAsync.asData?.value;
  if (repo == null) {
    AppLogging.meshCanvas(
      'latent channel tap skipped: repository not ready '
      '(channel=${latent.channelIndex})',
    );
    return;
  }
  final summary = await repo.getOrCreateMeshCanvas(
    canvasId: latent.canvasId,
    channelIndex: latent.channelIndex,
    name: latent.channelName,
  );
  ref.invalidate(canvasListProvider);
  if (!navigator.mounted) return;
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => MeshCanvasViewerScreen(canvas: summary),
    ),
  );
}

/// Channel canvas card — the Mesh tab's primary surface.
///
/// Replaces the prior settings-list row with a canvas-artifact card:
/// a square thumbnail of the actual board on the left, channel
/// identity + activity status on the right. Dormant channels render
/// with a faint seed marker in the thumbnail centre; live channels
/// render their painted cells at thumbnail scale.
///
/// Tap behaviour:
///   - Dormant: call `repo.getOrCreateMeshCanvas(...)` to persist
///     the row locally, then push [MeshCanvasViewerScreen]. No
///     broadcast happens until the first paint.
///   - Live: push the viewer with the materialised summary directly.
class _LatentChannelCard extends ConsumerWidget {
  final LatentChannelCanvas latent;

  const _LatentChannelCard({required this.latent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The thumbnail subtree differs by state:
    //   - Live channel  → _LiveThumbnail watches canvasCellsProvider.
    //   - Dormant       → static ChannelCanvasThumbnail with no cells.
    // This split avoids a conditional ref.watch inside a single
    // ConsumerWidget — that pattern produces stale Riverpod
    // dependency tracking and the "_dependents.isEmpty: is not true"
    // framework assertion when the conditional flips between builds.
    final Widget thumbnail = latent.isDormant || latent.materialised == null
        ? const ChannelCanvasThumbnail(
            cells: <CanvasCell>[],
            isDormant: true,
            size: 96,
          )
        : _LiveThumbnail(canvasLocalId: latent.materialised!.localId);

    // Live channels render with a stronger accent border to draw the
    // eye toward channels that already have activity. Dormant
    // channels use a quieter accentOpacity so they recede.
    final isLive =
        latent.materialised != null && latent.materialised!.cellCount > 0;
    return GradientBorderContainer(
      borderRadius: AppTheme.radius16,
      borderWidth: 1.0,
      accentOpacity: isLive ? 0.11 : 0.05,
      enableDepthBlend: isLive,
      depthBlendOpacity: 0.02,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          onTap: () =>
              _openLatentCanvas(context: context, ref: ref, latent: latent),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                thumbnail,
                const SizedBox(width: AppTheme.spacing16),
                Expanded(child: _ChannelCardText(latent: latent)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Watches the per-canvas cells provider and feeds them into a
/// [ChannelCanvasThumbnail]. Always materialised for a known
/// `canvasLocalId`, so its `ref.watch` is consistent across rebuilds
/// — avoids the conditional-watch bug that crashed the sim with
/// `_dependents.isEmpty: is not true`.
class _LiveThumbnail extends ConsumerWidget {
  final int canvasLocalId;
  final double size;

  const _LiveThumbnail({required this.canvasLocalId, this.size = 96});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cellsAsync = ref.watch(canvasCellsProvider(canvasLocalId));
    final cells = cellsAsync.asData?.value ?? const <CanvasCell>[];
    return ChannelCanvasThumbnail(
      cells: cells,
      isDormant: cells.isEmpty,
      size: size,
    );
  }
}

/// Title + metadata + dormant-affordance text for a channel canvas
/// card. Pulled out so the layout reads card-row → text-column at
/// a glance, and so the test can target a single subtree by type.
class _ChannelCardText extends StatelessWidget {
  final LatentChannelCanvas latent;

  const _ChannelCardText({required this.latent});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final scope = l.meshCanvasOverviewChannelLabel(latent.channelIndex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          latent.channelName,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
            fontFamily: AppTheme.fontFamily,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: AppTheme.spacing2),
        Text(
          scope,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.textTertiary,
            fontFamily: AppTheme.fontFamily,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        if (latent.isDormant)
          _DormantAffordance(scope: scope)
        else
          _ActiveMetadata(latent: latent),
      ],
    );
  }
}

/// Dormant channel sub-row — small filled-circle bullet + the
/// "Dormant · Seed first pixel" hint. The bullet is the only
/// visible affordance, kept subtle so the user reads it as
/// atmospheric rather than alarming.
class _DormantAffordance extends StatelessWidget {
  final String scope;

  const _DormantAffordance({required this.scope});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: context.textTertiary.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppTheme.spacing8),
        Flexible(
          child: Text(
            l.meshCanvasOverviewChannelDormantHint,
            style: TextStyle(
              fontSize: 12,
              color: context.textSecondary,
              fontFamily: AppTheme.fontFamily,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Live channel sub-row — painted-cell count + relative last-active.
/// Renders as a middle-dot metadata cluster ("17 painted · 2h ago").
class _ActiveMetadata extends StatelessWidget {
  final LatentChannelCanvas latent;

  const _ActiveMetadata({required this.latent});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final m = latent.materialised!;
    return Wrap(
      spacing: AppTheme.spacing6,
      runSpacing: AppTheme.spacing6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // `Icons.grain` reads as scattered pixels — packet-radio /
        // graffiti-wall register, not enterprise stat-block.
        MetricChip(
          icon: Icons.grain,
          value: l.meshCanvasOverviewCellCount(m.cellCount),
        ),
        // `Icons.history` reads as "last seen on the mesh" rather
        // than a calendar/schedule.
        MetricChip(
          icon: Icons.history,
          value: _relativeActivityCluster(context, m.lastOpAtMs),
        ),
      ],
    );
  }
}
