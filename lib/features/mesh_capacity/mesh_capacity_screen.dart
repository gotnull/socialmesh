// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Mesh Capacity Advisor — dedicated screen.
//
// Drawer-level surface that explains how the local mesh's density relates
// to the active modem preset. Visual language mirrors Signals (gradient
// hero card, accent border, compact stat chips) and NodeDex (stats card
// pattern, educational tiles, sticky-style header rhythm). Never mutates
// radio state.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/meshtastic/modem_preset_metadata.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animated_empty_state.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/search_filter_header.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/status_filter_chip.dart';
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../l10n/app_localizations.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/mesh_capacity_provider.dart';
import '../../providers/connection_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/mesh_capacity/mesh_capacity_models.dart';
import '../nodedex/screens/nodedex_detail_screen.dart';
import '../nodedex/widgets/sigil_painter.dart';
import '../settings/radio_config_screen.dart';
import 'mesh_capacity_explanation_sheet.dart';

/// Time-window filter for the RF-active node list. Mirrors the bucket
/// boundaries used by [_ActivitySection] so the histogram and the list
/// share the same mental model.
enum _NodeWindow { all, fiveMin, fifteenMin, sixtyMin }

class MeshCapacityScreen extends ConsumerStatefulWidget {
  const MeshCapacityScreen({super.key});

  @override
  ConsumerState<MeshCapacityScreen> createState() => _MeshCapacityScreenState();
}

class _MeshCapacityScreenState extends ConsumerState<MeshCapacityScreen>
    with LifecycleSafeMixin<MeshCapacityScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  _NodeWindow _window = _NodeWindow.all;

  @override
  void initState() {
    super.initState();
    // One-shot "screen opened" telemetry. The advisor's actual state
    // transitions are logged inside [MeshCapacitySnapshotNotifier] using
    // a stable dedupe key — logging from build() here would spam every
    // time the activity histogram rebuilt.
    AppLogging.meshCapacity('screen opened sourceSurface=mesh_capacity_screen');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  /// All nodes considered RF-active for the screen — direct radio
  /// observations (not MQTT-bridged), excluding self, heard within the
  /// last 60 minutes (the broadest window the advisor reasons about).
  /// This is the candidate set; window/search filters are applied on
  /// top of it.
  List<MeshNode> _rfActiveCandidates(
    Map<int, MeshNode> nodes,
    int? myNodeNum,
    DateTime now,
  ) {
    final out = <MeshNode>[];
    for (final node in nodes.values) {
      if (node.viaMqtt) continue;
      if (myNodeNum != null && node.nodeNum == myNodeNum) continue;
      final last = node.lastHeard;
      if (last == null) continue;
      final age = now.difference(last);
      if (age.isNegative) continue;
      if (age > const Duration(minutes: 60)) continue;
      out.add(node);
    }
    out.sort((a, b) => b.lastHeard!.compareTo(a.lastHeard!));
    return out;
  }

  bool _matchesWindow(MeshNode node, DateTime now, _NodeWindow window) {
    if (window == _NodeWindow.all) return true;
    final age = now.difference(node.lastHeard!);
    switch (window) {
      case _NodeWindow.fiveMin:
        return age <= const Duration(minutes: 5);
      case _NodeWindow.fifteenMin:
        return age <= const Duration(minutes: 15);
      case _NodeWindow.sixtyMin:
        return age <= const Duration(minutes: 60);
      case _NodeWindow.all:
        return true;
    }
  }

  bool _matchesSearch(MeshNode node, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return node.displayName.toLowerCase().contains(q) ||
        node.nodeNum.toString().contains(q) ||
        (node.userId?.toLowerCase().contains(q) ?? false);
  }

  int _countForWindow(
    List<MeshNode> candidates,
    DateTime now,
    _NodeWindow window,
  ) {
    if (window == _NodeWindow.all) return candidates.length;
    return candidates.where((n) => _matchesWindow(n, now, window)).length;
  }

  String _windowLabel(AppLocalizations l10n, _NodeWindow w) {
    switch (w) {
      case _NodeWindow.all:
        return l10n.meshCapacityNodeFilterAll;
      case _NodeWindow.fiveMin:
        return l10n.meshCapacityNodeFilter5m;
      case _NodeWindow.fifteenMin:
        return l10n.meshCapacityNodeFilter15m;
      case _NodeWindow.sixtyMin:
        return l10n.meshCapacityNodeFilter60m;
    }
  }

  Color _windowColor(BuildContext context, _NodeWindow w) {
    switch (w) {
      case _NodeWindow.all:
        return AppTheme.primaryBlue;
      case _NodeWindow.fiveMin:
        return AccentColors.green;
      case _NodeWindow.fifteenMin:
        return AccentColors.cyan;
      case _NodeWindow.sixtyMin:
        return AccentColors.lavender;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final snapshot = ref.watch(meshCapacitySnapshotProvider);
    final isConnected = ref.watch(isDeviceConnectedProvider);
    final pressureColor = _pressureColor(context, snapshot.pressureLevel);

    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final now = DateTime.now();
    final candidates = _rfActiveCandidates(nodes, myNodeNum, now);
    final filtered = candidates
        .where(
          (n) =>
              _matchesWindow(n, now, _window) &&
              _matchesSearch(n, _searchQuery),
        )
        .toList(growable: false);

    return GestureDetector(
      onTap: _dismissKeyboard,
      child: GlassScaffold(
        resizeToAvoidBottomInset: false,
        title: l10n.meshCapacityScreenTitle,
        actions: [
          IconButton(
            tooltip: l10n.meshCapacitySheetOpenSettings,
            icon: const Icon(Icons.settings_input_antenna, size: 22),
            onPressed: isConnected ? () => _openRadioSettings(snapshot) : null,
          ),
          AppBarOverflowMenu<String>(
            onSelected: (value) {
              switch (value) {
                case 'explain':
                  _openExplanation(snapshot);
                case 'settings':
                  _openRadioSettings(snapshot);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'explain',
                child: ListTile(
                  leading: const Icon(Icons.menu_book_outlined),
                  title: Text(l10n.meshCapacitySheetTitle),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              PopupMenuItem(
                value: 'settings',
                enabled: isConnected,
                child: ListTile(
                  leading: const Icon(Icons.settings_input_antenna),
                  title: Text(l10n.meshCapacitySheetOpenSettings),
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing8)),

          if (!isConnected)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildNotConnectedState(l10n),
            )
          else if (!snapshot.hasSufficientSignalData) ...[
            SliverToBoxAdapter(
              child: _PressureHeroCard(
                snapshot: snapshot,
                pressureColor: pressureColor,
              ),
            ),
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildQuietMeshState(l10n),
            ),
          ] else ...[
            SliverToBoxAdapter(
              child: _PressureHeroCard(
                snapshot: snapshot,
                pressureColor: pressureColor,
              ),
            ),
            SliverToBoxAdapter(child: _StatRow(snapshot: snapshot)),

            if (snapshot.recommendation.shouldShowCard)
              SliverToBoxAdapter(
                child: _RecommendationCard(
                  snapshot: snapshot,
                  pressureColor: pressureColor,
                  onOpenSettings: () => _openRadioSettings(snapshot),
                  onLearnMore: () => _openExplanation(snapshot),
                ),
              ),

            const SliverToBoxAdapter(child: _ActivitySection()),

            // Pinned search + window filter chips for the RF-active
            // node list — same primitive as Presence/NodeDex/Signals.
            SliverPersistentHeader(
              pinned: true,
              delegate: SearchFilterHeaderDelegate(
                searchController: _searchController,
                searchQuery: _searchQuery,
                onSearchChanged: (value) =>
                    setState(() => _searchQuery = value),
                hintText: l10n.meshCapacityNodesSearchHint,
                textScaler: MediaQuery.textScalerOf(context),
                rebuildKey: Object.hashAll([
                  _window,
                  candidates.length,
                  _countForWindow(candidates, now, _NodeWindow.fiveMin),
                  _countForWindow(candidates, now, _NodeWindow.fifteenMin),
                  _countForWindow(candidates, now, _NodeWindow.sixtyMin),
                ]),
                filterChips: [
                  for (final w in _NodeWindow.values)
                    StatusFilterChip(
                      label: _windowLabel(l10n, w),
                      count: _countForWindow(candidates, now, w),
                      isSelected: _window == w,
                      color: _windowColor(context, w),
                      onTap: () => setState(() => _window = w),
                    ),
                ],
              ),
            ),

            SliverPersistentHeader(
              pinned: true,
              delegate: SectionHeaderDelegate(
                title: l10n.meshCapacityNodeListHeader,
                count: filtered.length,
              ),
            ),

            if (filtered.isEmpty)
              SliverToBoxAdapter(
                child: _NoMatchState(
                  hasSearch: _searchQuery.isNotEmpty,
                  hasFilter: _window != _NodeWindow.all,
                  onClearFilter: () =>
                      setState(() => _window = _NodeWindow.all),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) =>
                      _NodeRow(node: filtered[i], now: now, l10n: l10n),
                  childCount: filtered.length,
                ),
              ),

            const SliverToBoxAdapter(child: _EducationSection()),

            SliverToBoxAdapter(
              child: _SnapshotDetailsSection(snapshot: snapshot),
            ),

            SliverToBoxAdapter(
              child: SizedBox(
                height:
                    MediaQuery.of(context).padding.bottom + AppTheme.spacing24,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNotConnectedState(AppLocalizations l10n) {
    return AnimatedEmptyState(
      config: AnimatedEmptyStateConfig(
        icons: const [
          Icons.cell_tower_outlined,
          Icons.network_check,
          Icons.bluetooth_disabled,
          Icons.signal_cellular_off,
        ],
        taglines: [
          l10n.meshCapacityNotConnectedTagline1,
          l10n.meshCapacityNotConnectedTagline2,
          l10n.meshCapacityNotConnectedTagline3,
        ],
        titlePrefix: l10n.meshCapacityNotConnectedTitlePrefix,
        titleKeyword: l10n.meshCapacityNotConnectedTitleKeyword,
        titleSuffix: l10n.meshCapacityNotConnectedTitleSuffix,
      ),
    );
  }

  Widget _buildQuietMeshState(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing24,
        AppTheme.spacing32,
        AppTheme.spacing24,
        AppTheme.spacing32,
      ),
      child: AnimatedEmptyState(
        config: AnimatedEmptyStateConfig(
          icons: const [
            Icons.network_check,
            Icons.signal_cellular_alt,
            Icons.sensors,
            Icons.spa_outlined,
          ],
          taglines: [
            l10n.meshCapacityQuietMeshTagline1,
            l10n.meshCapacityQuietMeshTagline2,
            l10n.meshCapacityQuietMeshTagline3,
          ],
          titlePrefix: l10n.meshCapacityQuietMeshTitlePrefix,
          titleKeyword: l10n.meshCapacityQuietMeshTitleKeyword,
          titleSuffix: l10n.meshCapacityQuietMeshTitleSuffix,
        ),
      ),
    );
  }

  Future<void> _openExplanation(MeshCapacitySnapshot snapshot) async {
    await ref.read(hapticServiceProvider).trigger(HapticType.light);
    if (!mounted) return;
    AppLogging.meshCapacity(
      'explanation opened reasonCode=${snapshot.recommendation.reasonCode.name} '
      'sourceSurface=mesh_capacity_screen',
    );
    await MeshCapacityExplanationSheet.show(
      context: context,
      snapshot: snapshot,
      sourceSurface: 'mesh_capacity_screen',
    );
  }

  Future<void> _openRadioSettings(MeshCapacitySnapshot snapshot) async {
    await ref.read(hapticServiceProvider).trigger(HapticType.medium);
    if (!mounted) return;
    AppLogging.meshCapacity(
      'radio settings opened from advisor '
      'reasonCode=${snapshot.recommendation.reasonCode.name} '
      'sourceSurface=mesh_capacity_screen',
    );
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const RadioConfigScreen()));
  }
}

Color _pressureColor(BuildContext context, MeshCapacityPressureLevel level) {
  switch (level) {
    case MeshCapacityPressureLevel.healthy:
      return AccentColors.green;
    case MeshCapacityPressureLevel.busy:
      return AccentColors.cyan;
    case MeshCapacityPressureLevel.congested:
      return AccentColors.orange;
    case MeshCapacityPressureLevel.capacityLimited:
      return AccentColors.coral;
    case MeshCapacityPressureLevel.unknown:
      return context.textTertiary;
  }
}

String _pressureLabel(AppLocalizations l10n, MeshCapacityPressureLevel level) {
  switch (level) {
    case MeshCapacityPressureLevel.healthy:
      return l10n.meshCapacityPressureHealthy;
    case MeshCapacityPressureLevel.busy:
      return l10n.meshCapacityPressureBusy;
    case MeshCapacityPressureLevel.congested:
      return l10n.meshCapacityPressureCongested;
    case MeshCapacityPressureLevel.capacityLimited:
      return l10n.meshCapacityPressureCapacityLimited;
    case MeshCapacityPressureLevel.unknown:
      return l10n.meshCapacityPressureUnknown;
  }
}

// ---------------------------------------------------------------------------
// Hero card with animated pressure gauge.
// ---------------------------------------------------------------------------

class _PressureHeroCard extends StatelessWidget {
  const _PressureHeroCard({
    required this.snapshot,
    required this.pressureColor,
  });

  final MeshCapacitySnapshot snapshot;
  final Color pressureColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preset = snapshot.currentModemPreset;
    final presetMetadata = preset == null
        ? null
        : modemPresetMetadataFor(preset);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing4,
        AppTheme.spacing16,
        AppTheme.spacing4,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing20,
          AppTheme.spacing20,
          AppTheme.spacing20,
          AppTheme.spacing20,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              pressureColor.withValues(alpha: 0.16),
              pressureColor.withValues(alpha: 0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radius20),
          border: Border.all(
            color: pressureColor.withValues(alpha: 0.30),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppTheme.spacing8,
              runSpacing: AppTheme.spacing8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _HeroChip(
                  icon: _pressureIcon(snapshot.pressureLevel),
                  label: _pressureLabel(
                    l10n,
                    snapshot.pressureLevel,
                  ).toUpperCase(),
                  color: pressureColor,
                  filled: true,
                ),
                _HeroChip(
                  icon: Icons.settings_input_antenna,
                  label: presetMetadata != null
                      ? presetMetadata.label(l10n).toUpperCase()
                      : l10n.meshCapacitySheetPresetUnknownValue.toUpperCase(),
                  color: presetMetadata != null
                      ? context.textSecondary
                      : context.textTertiary,
                  filled: false,
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${snapshot.activeRfNodes15m}',
                  style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w700,
                    color: pressureColor,
                    height: 1,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
                  child: Text(
                    l10n.meshCapacityHeroNodesUnit,
                    style: TextStyle(
                      fontSize: 13,
                      color: context.textSecondary,
                      fontWeight: FontWeight.w500,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              l10n.meshCapacityHeroSubtitle,
              style: TextStyle(
                fontSize: 13,
                color: context.textSecondary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            _PressureGauge(snapshot: snapshot, pressureColor: pressureColor),
          ],
        ),
      ),
    );
  }

  IconData _pressureIcon(MeshCapacityPressureLevel level) {
    switch (level) {
      case MeshCapacityPressureLevel.healthy:
        return Icons.check_circle_outline;
      case MeshCapacityPressureLevel.busy:
        return Icons.network_check;
      case MeshCapacityPressureLevel.congested:
        return Icons.warning_amber_rounded;
      case MeshCapacityPressureLevel.capacityLimited:
        return Icons.error_outline;
      case MeshCapacityPressureLevel.unknown:
        return Icons.help_outline;
    }
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing10,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: filled ? color.withValues(alpha: 0.18) : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        border: Border.all(
          color: filled
              ? color.withValues(alpha: 0.4)
              : color.withValues(alpha: 0.35),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppTheme.spacing6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 0.6,
              fontWeight: filled ? FontWeight.w700 : FontWeight.w600,
              color: color,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _PressureGauge extends StatelessWidget {
  const _PressureGauge({required this.snapshot, required this.pressureColor});

  final MeshCapacitySnapshot snapshot;
  final Color pressureColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final thresholds = _thresholdsFor(snapshot.currentModemPreset);
    final maxScale = thresholds == null
        ? (snapshot.activeRfNodes15m + 5).clamp(10, 1000).toDouble()
        : (thresholds.$3 * 1.25).clamp(10, 100000).toDouble();
    final progress = thresholds == null
        ? 0.0
        : (snapshot.activeRfNodes15m / maxScale).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          child: Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: context.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  border: Border.all(
                    color: context.border.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
              ),
              if (thresholds != null)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    return Stack(
                      children: [
                        // Filled bar.
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          width: width * progress,
                          height: 12,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                pressureColor.withValues(alpha: 0.7),
                                pressureColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius8,
                            ),
                          ),
                        ),
                        // Threshold ticks.
                        _gaugeTick(width, thresholds.$1 / maxScale),
                        _gaugeTick(width, thresholds.$2 / maxScale),
                        _gaugeTick(width, thresholds.$3 / maxScale),
                      ],
                    );
                  },
                ),
            ],
          ),
        ),
        if (thresholds != null) ...[
          const SizedBox(height: AppTheme.spacing8),
          Row(
            children: [
              _GaugeLegend(
                color: AccentColors.cyan,
                label: l10n.meshCapacityGaugeBusy,
                value: thresholds.$1,
              ),
              const SizedBox(width: AppTheme.spacing12),
              _GaugeLegend(
                color: AccentColors.orange,
                label: l10n.meshCapacityGaugeCongested,
                value: thresholds.$2,
              ),
              const SizedBox(width: AppTheme.spacing12),
              _GaugeLegend(
                color: AccentColors.coral,
                label: l10n.meshCapacityGaugeCapacityLimited,
                value: thresholds.$3,
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.meshCapacityGaugePresetUnknown,
            style: TextStyle(
              fontSize: 11,
              color: context.textTertiary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ],
    );
  }

  Widget _gaugeTick(double parentWidth, double fraction) {
    final pos = (parentWidth * fraction.clamp(0.0, 1.0)) - 1;
    return Positioned(
      left: pos,
      child: Container(
        width: 2,
        height: 12,
        color: Colors.black.withValues(alpha: 0.45),
      ),
    );
  }
}

class _GaugeLegend extends StatelessWidget {
  const _GaugeLegend({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppTheme.spacing4),
        Text(
          '$label · $value',
          style: TextStyle(
            fontSize: 10,
            color: context.textTertiary,
            fontWeight: FontWeight.w500,
            fontFamily: AppTheme.fontFamily,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

(int, int, int)? _thresholdsFor(
  config_pbenum.Config_LoRaConfig_ModemPreset? preset,
) {
  if (preset == null) return null;
  switch (preset) {
    case config_pbenum.Config_LoRaConfig_ModemPreset.LONG_SLOW:
    case config_pbenum.Config_LoRaConfig_ModemPreset.VERY_LONG_SLOW:
      return (10, 20, 40);
    case config_pbenum.Config_LoRaConfig_ModemPreset.LONG_MODERATE:
      return (15, 30, 55);
    case config_pbenum.Config_LoRaConfig_ModemPreset.LONG_FAST:
    case config_pbenum.Config_LoRaConfig_ModemPreset.LONG_TURBO:
      return (25, 40, 70);
    case config_pbenum.Config_LoRaConfig_ModemPreset.MEDIUM_SLOW:
    case config_pbenum.Config_LoRaConfig_ModemPreset.MEDIUM_FAST:
      return (60, 100, 200);
    case config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_SLOW:
    case config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_FAST:
      return (150, 250, 500);
    case config_pbenum.Config_LoRaConfig_ModemPreset.SHORT_TURBO:
      return (300, 500, 1000);
    default:
      return null;
  }
}

// ---------------------------------------------------------------------------
// Stat row.
// ---------------------------------------------------------------------------

class _StatRow extends StatelessWidget {
  const _StatRow({required this.snapshot});

  final MeshCapacitySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing12,
        AppTheme.spacing16,
        AppTheme.spacing4,
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: Icons.flash_on,
              label: l10n.meshCapacityStat5m,
              value: '${snapshot.activeRfNodes5m}',
              accent: AccentColors.green,
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: _StatTile(
              icon: Icons.network_check,
              label: l10n.meshCapacityStat15m,
              value: '${snapshot.activeRfNodes15m}',
              accent: AccentColors.cyan,
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: _StatTile(
              icon: Icons.history,
              label: l10n.meshCapacityStat60m,
              value: '${snapshot.activeRfNodes60m}',
              accent: AccentColors.lavender,
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: _StatTile(
              icon: Icons.hexagon_outlined,
              label: l10n.meshCapacityStatTotal,
              value: '${snapshot.totalKnownNodes}',
              accent: AccentColors.slate,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing12,
      ),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(
          color: context.border.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(height: AppTheme.spacing6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: context.textTertiary,
              letterSpacing: 0.3,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Recommendation card.
// ---------------------------------------------------------------------------

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.snapshot,
    required this.pressureColor,
    required this.onOpenSettings,
    required this.onLearnMore,
  });

  final MeshCapacitySnapshot snapshot;
  final Color pressureColor;
  final VoidCallback onOpenSettings;
  final VoidCallback onLearnMore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final reason = snapshot.recommendation.reasonCode;
    final suggested = snapshot.recommendation.suggestedPreset;
    final suggestedMetadata = suggested == null
        ? null
        : modemPresetMetadataFor(suggested);
    final title = _titleFor(l10n, snapshot);
    final body = _bodyFor(l10n, reason);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing4,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          border: Border.all(
            color: pressureColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.tips_and_updates_outlined,
                  size: 18,
                  color: pressureColor,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                      fontFamily: AppTheme.fontFamily,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              body,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: context.textSecondary,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
            if (suggestedMetadata != null) ...[
              const SizedBox(height: AppTheme.spacing12),
              _SuggestedPresetTile(
                metadataLabel: suggestedMetadata.label(l10n),
                metadataDescription: suggestedMetadata.description(l10n),
                accent: pressureColor,
              ),
            ],
            const SizedBox(height: AppTheme.spacing16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onLearnMore,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacing12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                      side: BorderSide(color: context.border, width: 0.5),
                    ),
                    icon: const Icon(Icons.menu_book_outlined, size: 16),
                    label: Text(l10n.meshCapacityLearnMore),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onOpenSettings,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spacing12,
                      ),
                      backgroundColor: pressureColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radius12),
                      ),
                    ),
                    icon: const Icon(Icons.settings_input_antenna, size: 16),
                    label: Text(l10n.meshCapacitySheetOpenSettings),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _titleFor(AppLocalizations l10n, MeshCapacitySnapshot s) {
    if (s.recommendation.reasonCode == MeshCapacityReasonCode.presetUnknown) {
      return l10n.meshCapacityCardTitlePresetUnknown;
    }
    switch (s.pressureLevel) {
      case MeshCapacityPressureLevel.capacityLimited:
        return l10n.meshCapacityCardTitleCapacityLimited;
      case MeshCapacityPressureLevel.congested:
        return l10n.meshCapacityCardTitleCongested;
      case MeshCapacityPressureLevel.busy:
      case MeshCapacityPressureLevel.healthy:
      case MeshCapacityPressureLevel.unknown:
        return l10n.meshCapacityCardTitleBusy;
    }
  }

  String _bodyFor(AppLocalizations l10n, MeshCapacityReasonCode reason) {
    switch (reason) {
      case MeshCapacityReasonCode.busyButAcceptable:
        return l10n.meshCapacityRecommendationBodyBusy;
      case MeshCapacityReasonCode.longPresetDenseMesh:
        return l10n.meshCapacityRecommendationBodyLongPresetDense;
      case MeshCapacityReasonCode.slowPresetDenseMesh:
        return l10n.meshCapacityRecommendationBodyMediumPresetDense;
      case MeshCapacityReasonCode.veryDenseEventLikeMesh:
        return l10n.meshCapacityRecommendationBodyEventLike;
      case MeshCapacityReasonCode.presetUnknown:
        return l10n.meshCapacityCardSubtitlePresetUnknown;
      case MeshCapacityReasonCode.healthyForPreset:
      case MeshCapacityReasonCode.insufficientData:
        return l10n.meshCapacityRecommendationBodyBusy;
    }
  }
}

class _SuggestedPresetTile extends StatelessWidget {
  const _SuggestedPresetTile({
    required this.metadataLabel,
    required this.metadataDescription,
    required this.accent,
  });

  final String metadataLabel;
  final String metadataDescription;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.swap_horiz, size: 16, color: accent),
          const SizedBox(width: AppTheme.spacing10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.meshCapacitySheetSuggestedPresetLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: accent,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  metadataLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  metadataDescription,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: context.textSecondary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Activity timeline (last-heard histogram) — Presence-style 5 buckets.
// ---------------------------------------------------------------------------

class _ActivitySection extends ConsumerWidget {
  const _ActivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final now = DateTime.now();
    final buckets = List<int>.filled(5, 0);
    for (final node in nodes.values) {
      if (node.viaMqtt) continue;
      if (myNodeNum != null && node.nodeNum == myNodeNum) continue;
      final last = node.lastHeard;
      if (last == null) continue;
      final age = now.difference(last);
      if (age.isNegative) continue;
      if (age.inMinutes < 1) {
        buckets[0]++;
      } else if (age.inMinutes < 5) {
        buckets[1]++;
      } else if (age.inMinutes < 15) {
        buckets[2]++;
      } else if (age.inMinutes < 60) {
        buckets[3]++;
      } else if (age.inHours < 6) {
        buckets[4]++;
      }
    }
    final maxCount = buckets.reduce((a, b) => a > b ? a : b).clamp(1, 999);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing24,
        AppTheme.spacing16,
        AppTheme.spacing4,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, size: 16, color: context.textSecondary),
                const SizedBox(width: AppTheme.spacing8),
                Text(
                  l10n.meshCapacityActivityTitle,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textSecondary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing16),
            SizedBox(
              height: 96,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(5, (i) {
                  final c = buckets[i];
                  final h = c == 0 ? 4.0 : (c / maxCount * 64).clamp(8.0, 64.0);
                  final color = _bucketColor(context, i);
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing3,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (c > 0)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppTheme.spacing4,
                              ),
                              child: Text(
                                '$c',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                  fontFamily: AppTheme.fontFamily,
                                ),
                              ),
                            ),
                          Flexible(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 500),
                              curve: Curves.easeOut,
                              constraints: BoxConstraints(maxHeight: h),
                              decoration: BoxDecoration(
                                color: c > 0
                                    ? color
                                    : color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  AppTheme.radius4,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Row(
              children: [
                _bucketLabel(context, l10n.meshCapacityBucket1m),
                _bucketLabel(context, l10n.meshCapacityBucket5m),
                _bucketLabel(context, l10n.meshCapacityBucket15m),
                _bucketLabel(context, l10n.meshCapacityBucket60m),
                _bucketLabel(context, l10n.meshCapacityBucket6h),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _bucketColor(BuildContext context, int i) {
    switch (i) {
      case 0:
        return AccentColors.green;
      case 1:
        return AccentColors.emerald;
      case 2:
        return AccentColors.cyan;
      case 3:
        return AccentColors.lavender;
      default:
        return context.textTertiary;
    }
  }

  Widget _bucketLabel(BuildContext context, String label) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          color: context.textTertiary,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Educational section.
// ---------------------------------------------------------------------------

class _EducationSection extends StatelessWidget {
  const _EducationSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing24,
        AppTheme.spacing16,
        AppTheme.spacing4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: l10n.meshCapacityEducationHeader),
          const SizedBox(height: AppTheme.spacing12),
          _EducationTile(
            icon: Icons.height,
            accent: AccentColors.green,
            title: l10n.meshCapacityEducationRangeTitle,
            body: l10n.meshCapacityEducationRangeBody,
          ),
          const SizedBox(height: AppTheme.spacing8),
          _EducationTile(
            icon: Icons.bolt,
            accent: AccentColors.orange,
            title: l10n.meshCapacityEducationCapacityTitle,
            body: l10n.meshCapacityEducationCapacityBody,
          ),
          const SizedBox(height: AppTheme.spacing8),
          _EducationTile(
            icon: Icons.handshake_outlined,
            accent: AccentColors.lavender,
            title: l10n.meshCapacityEducationCompatTitle,
            body: l10n.meshCapacityEducationCompatBody,
          ),
        ],
      ),
    );
  }
}

class _EducationTile extends StatelessWidget {
  const _EducationTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppTheme.radius8),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: context.textSecondary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Snapshot details (read-only InfoTable).
// ---------------------------------------------------------------------------

class _SnapshotDetailsSection extends StatelessWidget {
  const _SnapshotDetailsSection({required this.snapshot});

  final MeshCapacitySnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final preset = snapshot.currentModemPreset;
    final presetMetadata = preset == null
        ? null
        : modemPresetMetadataFor(preset);
    final suggested = snapshot.recommendation.suggestedPreset;
    final suggestedMetadata = suggested == null
        ? null
        : modemPresetMetadataFor(suggested);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing24,
        AppTheme.spacing16,
        AppTheme.spacing4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: l10n.meshCapacitySheetSnapshotHeader),
          const SizedBox(height: AppTheme.spacing8),
          InfoTable(
            rows: [
              InfoTableRow(
                label: l10n.meshCapacitySheetCurrentPresetLabel,
                value: presetMetadata != null
                    ? presetMetadata.label(l10n)
                    : l10n.meshCapacitySheetPresetUnknownValue,
              ),
              InfoTableRow(
                label: l10n.meshCapacitySheetPressureLabel,
                value: _pressureLabel(l10n, snapshot.pressureLevel),
              ),
              InfoTableRow(
                label: l10n.meshCapacityReasonLabel,
                value: _reasonLabel(l10n, snapshot.recommendation.reasonCode),
              ),
              InfoTableRow(
                label: l10n.meshCapacitySheetTotalKnownLabel,
                value: '${snapshot.totalKnownNodes}',
              ),
              if (suggestedMetadata != null)
                InfoTableRow(
                  label: l10n.meshCapacitySheetSuggestedPresetLabel,
                  value: suggestedMetadata.label(l10n),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _reasonLabel(AppLocalizations l10n, MeshCapacityReasonCode reason) {
    switch (reason) {
      case MeshCapacityReasonCode.healthyForPreset:
        return l10n.meshCapacityReasonHealthy;
      case MeshCapacityReasonCode.busyButAcceptable:
        return l10n.meshCapacityReasonBusy;
      case MeshCapacityReasonCode.longPresetDenseMesh:
        return l10n.meshCapacityReasonLongDense;
      case MeshCapacityReasonCode.slowPresetDenseMesh:
        return l10n.meshCapacityReasonMediumDense;
      case MeshCapacityReasonCode.veryDenseEventLikeMesh:
        return l10n.meshCapacityReasonEventLike;
      case MeshCapacityReasonCode.presetUnknown:
        return l10n.meshCapacityReasonPresetUnknown;
      case MeshCapacityReasonCode.insufficientData:
        return l10n.meshCapacityReasonInsufficientData;
    }
  }
}

// ---------------------------------------------------------------------------
// RF-active node row + no-match state.
// ---------------------------------------------------------------------------

class _NodeRow extends StatelessWidget {
  const _NodeRow({required this.node, required this.now, required this.l10n});

  final MeshNode node;
  final DateTime now;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final age = now.difference(node.lastHeard!);
    final hop = node.hopCount;
    final ageColor = _ageColor(context, age);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing8,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => NodeDexDetailScreen(nodeNum: node.nodeNum),
          ),
        ),
        leading: SigilAvatar(nodeNum: node.nodeNum, size: 40),
        title: Text(
          node.displayName,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: context.textPrimary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppTheme.spacing4),
          child: Wrap(
            spacing: AppTheme.spacing6,
            runSpacing: AppTheme.spacing4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _RowChip(
                icon: Icons.schedule,
                label: _ageLabel(l10n, age),
                color: ageColor,
              ),
              if (hop != null)
                _RowChip(
                  icon: hop == 0 ? Icons.radio_button_checked : Icons.route,
                  label: hop == 0
                      ? l10n.meshCapacityNodeHopDirect
                      : l10n.meshCapacityNodeHopCount(hop),
                  color: hop == 0 ? AccentColors.green : context.textTertiary,
                ),
              if (node.snr != null)
                _RowChip(
                  icon: Icons.signal_cellular_alt,
                  label: l10n.meshCapacityNodeSnr(node.snr!),
                  color: context.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _ageColor(BuildContext context, Duration age) {
    if (age <= const Duration(minutes: 5)) return AccentColors.green;
    if (age <= const Duration(minutes: 15)) return AccentColors.cyan;
    if (age <= const Duration(minutes: 60)) return AccentColors.lavender;
    return context.textTertiary;
  }

  String _ageLabel(AppLocalizations l10n, Duration age) {
    if (age.inSeconds < 60) return l10n.meshCapacityNodeAgeJustNow;
    final minutes = age.inMinutes;
    if (minutes < 60) return l10n.meshCapacityNodeAgeMinutes(minutes);
    final hours = age.inHours;
    return l10n.meshCapacityNodeAgeHours(hours);
  }
}

class _RowChip extends StatelessWidget {
  const _RowChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}

class _NoMatchState extends StatelessWidget {
  const _NoMatchState({
    required this.hasSearch,
    required this.hasFilter,
    required this.onClearFilter,
  });

  final bool hasSearch;
  final bool hasFilter;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing24,
        AppTheme.spacing24,
        AppTheme.spacing24,
        AppTheme.spacing16,
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: BorderRadius.circular(AppTheme.radius16),
            ),
            child: Icon(
              hasSearch ? Icons.search_off : Icons.filter_list_off,
              size: 28,
              color: context.textTertiary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            hasSearch
                ? l10n.meshCapacityNodeListNoMatchSearch
                : l10n.meshCapacityNodeListNoMatchFilter,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.textSecondary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
          if (hasFilter && !hasSearch) ...[
            const SizedBox(height: AppTheme.spacing8),
            TextButton(
              onPressed: onClearFilter,
              child: Text(l10n.meshCapacityNodeListShowAll),
            ),
          ],
        ],
      ),
    );
  }
}
