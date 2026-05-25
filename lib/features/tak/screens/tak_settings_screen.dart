// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/theme.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../services/haptic_service.dart';
import '../../../services/tak/providers/tak_bridge_providers.dart';
import '../providers/tak_settings_provider.dart';
import '../utils/cot_affiliation.dart';
import '../widgets/tak_bridge_status_card.dart';
import '../widgets/tak_identity_list.dart';

/// Dedicated TAK settings form accessible from the TakScreen overflow menu
/// and from the main Settings screen.
///
/// Follows the same visual pattern as [SettingsScreen]: section headers,
/// icon+title+subtitle tiles with trailing widgets, [ThemedSwitch] toggles,
/// no visible borders, and slivers-based [GlassScaffold].
class TakSettingsScreen extends ConsumerStatefulWidget {
  const TakSettingsScreen({super.key});

  @override
  ConsumerState<TakSettingsScreen> createState() => _TakSettingsScreenState();
}

class _TakSettingsScreenState extends ConsumerState<TakSettingsScreen> {
  late TextEditingController _gatewayUrlController;
  late TextEditingController _callsignController;
  bool _controllersInitialized = false;

  @override
  void dispose() {
    if (_controllersInitialized) {
      _gatewayUrlController.dispose();
      _callsignController.dispose();
    }
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(takSettingsProvider);

    return settingsAsync.when(
      loading: () => GlassScaffold.body(
        title: context.l10n.takSettingsTitle,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => GlassScaffold.body(
        title: context.l10n.takSettingsTitle,
        body: Center(child: Text(context.l10n.takSettingsError('$error'))),
      ),
      data: (settings) {
        if (!_controllersInitialized) {
          _gatewayUrlController = TextEditingController(
            text: settings.gatewayUrl,
          );
          _callsignController = TextEditingController(text: settings.callsign);
          _controllersInitialized = true;
        }

        return GestureDetector(
          onTap: _dismissKeyboard,
          behavior: HitTestBehavior.opaque,
          child: GlassScaffold(
            title: context.l10n.takSettingsTitle,
            slivers: [
              // ---------------------------------------------------------------
              // CONNECTION (gateway only)
              // ---------------------------------------------------------------
              if (AppFeatureFlags.isTakGatewayEnabled) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: context.l10n.takSettingsSectionConnection,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _SettingsTile(
                    icon: Icons.link,
                    title: context.l10n.takSettingsGatewayUrlTitle,
                    subtitle: settings.gatewayUrl.isNotEmpty
                        ? settings.gatewayUrl
                        : context.l10n.takSettingsGatewayUrlDefault,
                    onTap: () => _showGatewayUrlEditor(context, settings),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _SettingsTile(
                    icon: Icons.flash_on,
                    title: context.l10n.takSettingsAutoConnectTitle,
                    subtitle: context.l10n.takSettingsAutoConnectSubtitle,
                    trailing: ThemedSwitch(
                      value: settings.autoConnect,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        ref
                            .read(takSettingsProvider.notifier)
                            .setAutoConnect(value);
                      },
                    ),
                  ),
                ),

                // ---------------------------------------------------------------
                // POSITION PUBLISHING (gateway only)
                // ---------------------------------------------------------------
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: context.l10n.takSettingsSectionPublishing,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _SettingsTile(
                    icon: Icons.my_location,
                    title: context.l10n.takSettingsPublishTitle,
                    subtitle: context.l10n.takSettingsPublishSubtitle,
                    trailing: ThemedSwitch(
                      value: settings.publishEnabled,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        ref
                            .read(takSettingsProvider.notifier)
                            .setPublishEnabled(value);
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _SettingsTile(
                    icon: Icons.timer_outlined,
                    title: context.l10n.takSettingsIntervalTitle,
                    subtitle: context.l10n.takSettingsIntervalSubtitle,
                    trailing: _IntervalSelector(
                      value: settings.publishInterval,
                      onChanged: (value) {
                        ref.haptics.buttonTap();
                        ref
                            .read(takSettingsProvider.notifier)
                            .setPublishInterval(value);
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _SettingsTile(
                    icon: Icons.badge_outlined,
                    title: context.l10n.takSettingsCallsignTitle,
                    subtitle: settings.callsign.isNotEmpty
                        ? settings.callsign
                        : context.l10n.takSettingsCallsignDefault,
                    onTap: () => _showCallsignEditor(context, settings),
                  ),
                ),
              ], // end gateway-only sections
              // ---------------------------------------------------------------
              // MAP
              // ---------------------------------------------------------------
              SliverToBoxAdapter(
                child: _SectionHeader(
                  title: context.l10n.takSettingsSectionMap,
                ),
              ),
              SliverToBoxAdapter(
                child: _SettingsTile(
                  icon: Icons.layers_outlined,
                  title: context.l10n.takSettingsMapLayerTitle,
                  subtitle: context.l10n.takSettingsMapLayerSubtitle,
                  trailing: ThemedSwitch(
                    value: settings.mapLayerVisible,
                    onChanged: (value) {
                      HapticFeedback.selectionClick();
                      ref
                          .read(takSettingsProvider.notifier)
                          .setMapLayerVisible(value);
                    },
                  ),
                ),
              ),

              // ---------------------------------------------------------------
              // PROXIMITY ALERTS (gateway only)
              // ---------------------------------------------------------------
              if (AppFeatureFlags.isTakGatewayEnabled) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: context.l10n.takSettingsSectionProximity,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _SettingsTile(
                    icon: Icons.radar,
                    title: context.l10n.takSettingsProximityTitle,
                    subtitle: context.l10n.takSettingsProximitySubtitle,
                    trailing: ThemedSwitch(
                      value: settings.proximityAlertEnabled,
                      onChanged: (value) {
                        HapticFeedback.selectionClick();
                        ref
                            .read(takSettingsProvider.notifier)
                            .setProximityAlertEnabled(value);
                      },
                    ),
                  ),
                ),
                if (settings.proximityAlertEnabled) ...[
                  SliverToBoxAdapter(
                    child: _SettingsTile(
                      icon: Icons.adjust,
                      title: context.l10n.takSettingsRadiusTitle,
                      subtitle: context.l10n.takSettingsRadiusSubtitle(
                        settings.proximityRadiusKm.roundToDouble(),
                      ),
                      trailing: SizedBox(
                        width: 160,
                        child: Slider(
                          value: settings.proximityRadiusKm,
                          min: 1,
                          max: 50,
                          divisions: 49,
                          label: context.l10n.takSettingsRadiusSubtitle(
                            settings.proximityRadiusKm.roundToDouble(),
                          ),
                          onChanged: (value) {
                            ref
                                .read(takSettingsProvider.notifier)
                                .setProximityRadiusKm(value.roundToDouble());
                          },
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _ProximityAffiliationCheckboxes(
                      selected: settings.proximityAffiliations,
                      onChanged: (value) {
                        ref
                            .read(takSettingsProvider.notifier)
                            .setProximityAffiliations(value);
                      },
                    ),
                  ),
                ],
              ], // end gateway-only proximity section
              // ---------------------------------------------------------------
              // MESH BRIDGE (bridge only)
              // ---------------------------------------------------------------
              if (AppFeatureFlags.isTakMeshBridgeEnabled) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: context.l10n.takBridgeSectionTitle,
                  ),
                ),
                SliverToBoxAdapter(
                  child: _SettingsTile(
                    icon: Icons.cell_tower,
                    title: context.l10n.takBridgeEnableToggle,
                    subtitle: context.l10n.takBridgeEnableSubtitle,
                    trailing: ThemedSwitch(
                      value: ref.watch(takBridgeStatusProvider).isRunning,
                      onChanged: (enabled) {
                        ref.haptics.buttonTap();
                        final bridge = ref.read(takMeshBridgeProvider);
                        if (enabled) {
                          bridge.start();
                        } else {
                          bridge.stop();
                        }
                        ref.read(takBridgeStatusProvider.notifier).refresh();
                      },
                    ),
                  ),
                ),
                if (ref.watch(takBridgeStatusProvider).isRunning) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing16,
                      ),
                      child: TakBridgeStatusCard(),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: _SettingsTile(
                      icon: Icons.devices,
                      title: context.l10n.takBridgeClientsTitle,
                      subtitle: context.l10n.takBridgeConnectedClients(
                        ref.watch(takBridgeStatusProvider).connectedClientCount,
                      ),
                    ),
                  ),
                ],
                SliverToBoxAdapter(
                  child: _SettingsTile(
                    icon: Icons.file_download_outlined,
                    title: context.l10n.takBridgeExportPackage,
                    subtitle: context.l10n.takBridgeExportPackageSubtitle,
                    onTap: () {
                      ref.haptics.buttonTap();
                    },
                  ),
                ),
              ],

              // ---------------------------------------------------------------
              // IDENTITY REGISTRY (bridge only)
              // ---------------------------------------------------------------
              if (AppFeatureFlags.isTakMeshBridgeEnabled) ...[
                SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: context.l10n.takIdentityRegistryTitle,
                  ),
                ),
                const TakIdentityList(),
              ], // end bridge-only identity section
              // Bottom padding
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Editors
  // ---------------------------------------------------------------------------

  void _showGatewayUrlEditor(BuildContext context, TakSettings settings) {
    _gatewayUrlController.text = settings.gatewayUrl;
    AppBottomSheet.show<void>(
      context: context,
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.takSettingsGatewayEditorTitle,
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              context.l10n.takSettingsGatewayEditorHint,
              style: Theme.of(
                sheetContext,
              ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
            ),
            const SizedBox(height: AppTheme.spacing16),
            TextField(
              controller: _gatewayUrlController,
              maxLength: 256,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: context.l10n.takSettingsGatewayEditorPlaceholder,
                hintStyle: TextStyle(color: context.textTertiary),
                filled: true,
                fillColor: context.card,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) {
                ref
                    .read(takSettingsProvider.notifier)
                    .setGatewayUrl(value.trim());
                Navigator.of(sheetContext).pop();
              },
            ),
            const SizedBox(height: AppTheme.spacing16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ref
                      .read(takSettingsProvider.notifier)
                      .setGatewayUrl(_gatewayUrlController.text.trim());
                  Navigator.of(sheetContext).pop();
                },
                child: Text(context.l10n.takSettingsSave),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCallsignEditor(BuildContext context, TakSettings settings) {
    _callsignController.text = settings.callsign;
    AppBottomSheet.show<void>(
      context: context,
      child: Builder(
        builder: (sheetContext) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.takSettingsCallsignEditorTitle,
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spacing4),
            Text(
              context.l10n.takSettingsCallsignEditorHint,
              style: Theme.of(
                sheetContext,
              ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
            ),
            const SizedBox(height: AppTheme.spacing16),
            TextField(
              controller: _callsignController,
              maxLength: 20,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: context.l10n.takSettingsCallsignEditorPlaceholder,
                hintStyle: TextStyle(color: context.textTertiary),
                filled: true,
                fillColor: context.card,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) {
                ref
                    .read(takSettingsProvider.notifier)
                    .setCallsign(value.trim());
                Navigator.of(sheetContext).pop();
              },
            ),
            const SizedBox(height: AppTheme.spacing16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ref
                      .read(takSettingsProvider.notifier)
                      .setCallsign(_callsignController.text.trim());
                  Navigator.of(sheetContext).pop();
                },
                child: Text(context.l10n.takSettingsSave),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Private widgets — mirroring the pattern from settings_screen.dart
// =============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: context.textTertiary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: context.textSecondary),
                const SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: AppTheme.spacing2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.textTertiary),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null)
                  trailing!
                else if (onTap != null)
                  Icon(Icons.chevron_right, color: context.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact interval selector that shows the current value and opens a menu.
class _IntervalSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _IntervalSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final label = value < 60 ? '${value}s' : '${value ~/ 60}m';
    return PopupMenuButton<int>(
      initialValue: value,
      onSelected: onChanged,
      offset: const Offset(0, 40),
      color: context.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: AppTheme.spacing4),
            Icon(Icons.arrow_drop_down, size: 18, color: context.textTertiary),
          ],
        ),
      ),
      itemBuilder: (context) => takPublishIntervalOptions.map((seconds) {
        final itemLabel = seconds < 60 ? '${seconds}s' : '${seconds ~/ 60}m';
        return PopupMenuItem(value: seconds, child: Text(itemLabel));
      }).toList(),
    );
  }
}

/// Checkbox list for selecting which affiliations trigger proximity alerts.
class _ProximityAffiliationCheckboxes extends StatelessWidget {
  const _ProximityAffiliationCheckboxes({
    required this.selected,
    required this.onChanged,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  static const _options = [
    (key: 'hostile', color: CotAffiliationColors.hostile),
    (key: 'unknown', color: CotAffiliationColors.unknown),
    (key: 'suspect', color: CotAffiliationColors.suspect),
  ];

  static String _label(BuildContext context, String key) => switch (key) {
    'hostile' => context.l10n.takSettingsAlertHostile,
    'unknown' => context.l10n.takSettingsAlertUnknown,
    'suspect' => context.l10n.takSettingsAlertSuspect,
    _ => key,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.takSettingsAlertOn,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
          ),
          for (final option in _options)
            Row(
              children: [
                Checkbox(
                  value: selected.contains(option.key),
                  activeColor: option.color,
                  onChanged: (checked) {
                    HapticFeedback.selectionClick();
                    final updated = Set<String>.of(selected);
                    if (checked ?? false) {
                      updated.add(option.key);
                    } else {
                      updated.remove(option.key);
                    }
                    onChanged(updated);
                  },
                ),
                Text(
                  _label(context, option.key),
                  style: TextStyle(fontSize: 14, color: context.textPrimary),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
