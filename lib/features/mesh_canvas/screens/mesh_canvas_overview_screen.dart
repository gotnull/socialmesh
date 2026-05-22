// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCanvas overview / list screen — the drawer's entry point as of
// S7.C. Replaces the prior pattern where the drawer dumped the user
// straight into the Local Device Canvas viewer.
//
// Two segmented sections via [ChipSelector]:
//   - Local: the single Local Device Canvas card (always present;
//     `canvasListProvider` auto-creates the sandbox on first read).
//   - Mesh: per-channel mesh canvases. v0.1 will usually be empty
//     because the broadcast path lands in S7-final; the empty-state
//     uses the mandatory `AnimatedEmptyState` primitive.
//
// Tapping a canvas card pushes [MeshCanvasViewerScreen] with the
// chosen canvas. The viewer no longer self-loads; it takes the
// canvas in via constructor.
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
    final canvasesAsync = ref.watch(canvasListProvider);
    final activeTab = ref.watch(_overviewTabProvider);
    // Materialise the canvas inbound attach exactly once, when the
    // user enters the feature. Pre-app-boot wiring would be wasted
    // for users who never paint; this lazy pattern keeps the
    // ProtocolService hook unset until first opening of the canvas.
    // The provider stays alive for the app's lifetime after this
    // first read because the wiring's ref.onDispose only fires if
    // the container itself tears down.
    ref.watch(canvasProtocolWiringProvider);
    final l = context.l10n;

    return GlassScaffold(
      title: l.meshCanvasPlaceholderTitle,
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
        if (activeTab == _OverviewTab.local)
          canvasesAsync.when(
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacing24),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (e, st) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                child: Text(
                  'Could not load canvases: $e', // lint-allow: hardcoded-string
                  style: TextStyle(color: context.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            data: (canvases) => _LocalTabBody(canvases: canvases),
          )
        else
          const _MeshTabBody(),
      ],
    );
  }
}

class _LocalTabBody extends StatelessWidget {
  final List<CanvasSummary> canvases;

  const _LocalTabBody({required this.canvases});

  @override
  Widget build(BuildContext context) {
    final localCanvases = canvases
        .where((c) => c.scope == CanvasScope.local)
        .toList(growable: false);

    if (localCanvases.isEmpty) {
      // Defensive: the Local Device Canvas auto-creates on first
      // `canvasListProvider` read, so this branch is effectively
      // unreachable in v0.1.
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: _OverviewEmptyState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing4,
        AppTheme.spacing16,
        AppTheme.spacing24,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
            child: _CanvasCard(canvas: localCanvases[index]),
          ),
          childCount: localCanvases.length,
        ),
      ),
    );
  }
}

/// Mesh tab: one row per configured Meshtastic channel, each backed
/// by the deterministic `(channel_psk, channel_name) -> canvas_id`
/// derivation in [deriveCanvasIdFromChannel]. The channel IS the
/// canvas — rows appear immediately regardless of peer activity, with
/// dormant copy when no paint has landed.
///
/// The "no channels at all" branch falls back to AnimatedEmptyState
/// with channel-centric copy. The "channels exist but no paints yet"
/// branch DOES NOT show that empty state — every channel still gets
/// its own row inviting the user to seed the first pixel.
class _MeshTabBody extends ConsumerWidget {
  const _MeshTabBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final latentAsync = ref.watch(latentChannelCanvasesProvider);
    return latentAsync.when(
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacing24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (e, st) => SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Text(
            'Could not list channel canvases: $e', // lint-allow: hardcoded-string
            style: TextStyle(color: context.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          // No Meshtastic channels configured at all (e.g., device
          // not yet provisioned). Show the empty-state explaining
          // that channels are the source — NOT "waiting for mesh
          // canvases" which implies discovery.
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: _OverviewEmptyState(),
          );
        }
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing4,
            AppTheme.spacing16,
            AppTheme.spacing24,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
                child: _LatentChannelCard(latent: rows[index]),
              ),
              childCount: rows.length,
            ),
          ),
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

class _CanvasCard extends ConsumerWidget {
  final CanvasSummary canvas;

  const _CanvasCard({required this.canvas});

  String _scopeLabel(BuildContext context) {
    final l = context.l10n;
    return canvas.scope == CanvasScope.local
        ? l.meshCanvasOverviewTabLocal
        : l.meshCanvasOverviewChannelLabel(canvas.channelIndex ?? 0);
  }

  IconData _scopeIcon() => canvas.scope == CanvasScope.local
      ? Icons.smartphone_outlined
      : Icons.share_outlined;

  String _relativeActivity(BuildContext context) {
    final l = context.l10n;
    if (canvas.lastOpAtMs <= 0) return l.meshCanvasOverviewNeverPainted;
    final delta = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(canvas.lastOpAtMs),
    );
    if (delta.inMinutes < 1) return l.nodedexRelativeJustNow;
    if (delta.inMinutes < 60) {
      return l.nodedexRelativeMinutesAgo(delta.inMinutes);
    }
    if (delta.inHours < 24) {
      return l.nodedexRelativeHoursAgo(delta.inHours);
    }
    if (delta.inDays < 30) {
      return l.nodedexRelativeDaysAgo(delta.inDays);
    }
    return l.nodedexRelativeMonthsAgo(delta.inDays ~/ 30);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(AppTheme.radius12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        onTap: () {
          ref.haptics.itemSelect();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => MeshCanvasViewerScreen(canvas: canvas),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Icon(_scopeIcon(), size: 22, color: context.accentColor),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      canvas.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      _scopeLabel(context),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                        fontFamily: AppTheme.fontFamily,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_outlined,
                          size: 13,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          _relativeActivity(context),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing12),
                        Icon(
                          Icons.grid_4x4,
                          size: 13,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: AppTheme.spacing4),
                        Text(
                          l.meshCanvasOverviewCellCount(canvas.cellCount),
                          style: TextStyle(
                            fontSize: 12,
                            color: context.textSecondary,
                            fontFamily: AppTheme.fontFamily,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Latent (channel-bound) canvas row used in the Mesh tab. Mirrors the
/// shape of [_CanvasCard] so the two tabs look visually consistent,
/// but pulls its data from a [LatentChannelCanvas] (which may have a
/// null `materialised`).
///
/// Tap behaviour:
///   - Dormant (no canvas row yet): call
///     `repo.getOrCreateMeshCanvas(canvasId, channelIndex, name)` to
///     persist the row, then push [MeshCanvasViewerScreen] with the
///     freshly-created `CanvasSummary`. No broadcast happens until
///     the first paint — the row is local until then.
///   - Live (canvas row already exists): push the viewer with the
///     materialised summary directly.
class _LatentChannelCard extends ConsumerWidget {
  final LatentChannelCanvas latent;

  const _LatentChannelCard({required this.latent});

  String _scopeLabel(BuildContext context) {
    final l = context.l10n;
    return l.meshCanvasOverviewChannelLabel(latent.channelIndex);
  }

  /// Activity hint. Dormant channels read "No paints yet - seed the
  /// first pixel"; active channels render a relative timestamp.
  String _activityHint(BuildContext context) {
    final l = context.l10n;
    if (latent.isDormant) {
      return l.meshCanvasOverviewChannelDormantHint;
    }
    final lastOp = latent.materialised!.lastOpAtMs;
    if (lastOp <= 0) return l.meshCanvasOverviewNeverPainted;
    final delta = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(lastOp),
    );
    if (delta.inMinutes < 1) return l.nodedexRelativeJustNow;
    if (delta.inMinutes < 60) {
      return l.nodedexRelativeMinutesAgo(delta.inMinutes);
    }
    if (delta.inHours < 24) {
      return l.nodedexRelativeHoursAgo(delta.inHours);
    }
    if (delta.inDays < 30) {
      return l.nodedexRelativeDaysAgo(delta.inDays);
    }
    return l.nodedexRelativeMonthsAgo(delta.inDays ~/ 30);
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    ref.haptics.itemSelect();
    final navigator = Navigator.of(context);
    // If the canvas row already exists, just push. Otherwise create
    // it locally — first paint will broadcast through the same path
    // as any other mesh-canvas tap.
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
    // Refresh the list so the row flips from dormant -> live on
    // return-pop. Without this the user's first-paint round-trip
    // would leave the overview stale until the next provider
    // invalidation.
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
    final l = context.l10n;
    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(AppTheme.radius12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        onTap: () => _open(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                ),
                child: Icon(
                  Icons.share_outlined,
                  size: 22,
                  color: context.accentColor,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latent.channelName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      _scopeLabel(context),
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textTertiary,
                        fontFamily: AppTheme.fontFamily,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing8),
                    Row(
                      children: [
                        Icon(
                          latent.isDormant
                              ? Icons.fiber_manual_record
                              : Icons.schedule_outlined,
                          size: 13,
                          color: context.textTertiary,
                        ),
                        const SizedBox(width: AppTheme.spacing4),
                        Expanded(
                          child: Text(
                            _activityHint(context),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                              fontFamily: AppTheme.fontFamily,
                            ),
                          ),
                        ),
                        if (!latent.isDormant) ...[
                          const SizedBox(width: AppTheme.spacing8),
                          Icon(
                            Icons.grid_4x4,
                            size: 13,
                            color: context.textTertiary,
                          ),
                          const SizedBox(width: AppTheme.spacing4),
                          Text(
                            l.meshCanvasOverviewCellCount(
                              latent.materialised!.cellCount,
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textSecondary,
                              fontFamily: AppTheme.fontFamily,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
