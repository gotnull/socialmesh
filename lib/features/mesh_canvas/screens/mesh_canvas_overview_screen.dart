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
import '../../../core/theme.dart';
import '../../../core/widgets/animated_empty_state.dart';
import '../../../core/widgets/chip_selector.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../services/canvas/canvas_models.dart';
import '../../../services/haptic_service.dart';
import '../providers/mesh_canvas_providers.dart';
import '../widgets/canvas_help_sheet.dart';
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

class MeshCanvasOverviewScreen extends ConsumerWidget {
  const MeshCanvasOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(_overviewTabProvider);
    // Materialise the canvas inbound attach exactly once, when the
    // user enters the feature.
    ref.watch(canvasProtocolWiringProvider);
    final l = context.l10n;

    return GlassScaffold(
      title: l.meshCanvasPlaceholderTitle,
      physics: const NeverScrollableScrollPhysics(),
      actions: [
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
class _MeshTabContent extends ConsumerWidget {
  const _MeshTabContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        // Section header + cards. Section header gives vertical
        // rhythm and signals "this is a typed surface, not a list
        // of canvases-in-general" — every row below is a channel
        // canvas.
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing16,
                  AppTheme.spacing8,
                  AppTheme.spacing16,
                  AppTheme.spacing8,
                ),
                child: Text(
                  context.l10n.meshCanvasOverviewMeshSectionHeader,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textTertiary,
                    fontFamily: AppTheme.fontFamily,
                    letterSpacing: 1.4,
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
                itemCount: rows.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppTheme.spacing12),
                itemBuilder: (context, index) =>
                    _LatentChannelCard(latent: rows[index]),
              ),
            ),
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

  Future<void> _open(BuildContext context, WidgetRef ref) async {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Live channels fetch their painted cells so the thumbnail can
    // render a real glimpse of the board. Dormant channels skip the
    // fetch — there is nothing to render.
    final List<CanvasCell> cells;
    if (latent.materialised != null && !latent.isDormant) {
      final cellsAsync = ref.watch(
        canvasCellsProvider(latent.materialised!.localId),
      );
      cells = cellsAsync.asData?.value ?? const <CanvasCell>[];
    } else {
      cells = const <CanvasCell>[];
    }

    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(AppTheme.radius12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        onTap: () => _open(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ChannelCanvasThumbnail(
                cells: cells,
                isDormant: latent.isDormant,
                size: 96,
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(child: _ChannelCardText(latent: latent)),
            ],
          ),
        ),
      ),
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
    final count = l.meshCanvasOverviewCellCount(m.cellCount);
    final when = _relativeActivityCluster(context, m.lastOpAtMs);
    return Text(
      '$count · $when', // lint-allow: hardcoded-string
      style: TextStyle(
        fontSize: 12,
        color: context.textSecondary,
        fontFamily: AppTheme.fontFamily,
        letterSpacing: 0.2,
      ),
    );
  }
}
