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
import '../../core/widgets/section_header.dart';
import '../../generated/meshtastic/config.pbenum.dart' as config_pbenum;
import '../../l10n/app_localizations.dart';
import '../../providers/app_providers.dart';
import '../../providers/mesh_capacity_provider.dart';
import '../../providers/connection_providers.dart';
import '../../services/haptic_service.dart';
import '../../services/mesh_capacity/mesh_capacity_models.dart';
import '../settings/radio_config_screen.dart';
import 'mesh_capacity_explanation_sheet.dart';

class MeshCapacityScreen extends ConsumerStatefulWidget {
  const MeshCapacityScreen({super.key});

  @override
  ConsumerState<MeshCapacityScreen> createState() => _MeshCapacityScreenState();
}

class _MeshCapacityScreenState extends ConsumerState<MeshCapacityScreen>
    with LifecycleSafeMixin<MeshCapacityScreen> {
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
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final snapshot = ref.watch(meshCapacitySnapshotProvider);
    final isConnected = ref.watch(isDeviceConnectedProvider);
    final pressureColor = _pressureColor(context, snapshot.pressureLevel);

    return GlassScaffold(
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing10,
                    vertical: AppTheme.spacing4,
                  ),
                  decoration: BoxDecoration(
                    color: pressureColor.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(AppTheme.radius20),
                    border: Border.all(
                      color: pressureColor.withValues(alpha: 0.4),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _pressureIcon(snapshot.pressureLevel),
                        size: 12,
                        color: pressureColor,
                      ),
                      const SizedBox(width: AppTheme.spacing6),
                      Text(
                        _pressureLabel(
                          l10n,
                          snapshot.pressureLevel,
                        ).toUpperCase(),
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w700,
                          color: pressureColor,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (presetMetadata != null)
                  Flexible(
                    child: Text(
                      presetMetadata.label(l10n).toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.6,
                        fontWeight: FontWeight.w600,
                        color: context.textSecondary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  )
                else
                  Text(
                    l10n.meshCapacitySheetPresetUnknownValue.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w600,
                      color: context.textTertiary,
                      fontFamily: AppTheme.fontFamily,
                    ),
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
              height: 80,
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
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeOut,
                            height: h,
                            decoration: BoxDecoration(
                              color: c > 0
                                  ? color
                                  : color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius4,
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
                label: l10n.meshCapacitySheetActiveNodes5mLabel,
                value: '${snapshot.activeRfNodes5m}',
              ),
              InfoTableRow(
                label: l10n.meshCapacitySheetActiveNodes15mLabel,
                value: '${snapshot.activeRfNodes15m}',
              ),
              InfoTableRow(
                label: l10n.meshCapacitySheetActiveNodes60mLabel,
                value: '${snapshot.activeRfNodes60m}',
              ),
              InfoTableRow(
                label: l10n.meshCapacitySheetTotalKnownLabel,
                value: '${snapshot.totalKnownNodes}',
              ),
              InfoTableRow(
                label: l10n.meshCapacitySheetPressureLabel,
                value: _pressureLabel(l10n, snapshot.pressureLevel),
              ),
              InfoTableRow(
                label: l10n.meshCapacityReasonLabel,
                value: _reasonLabel(l10n, snapshot.recommendation.reasonCode),
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
