// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../services/haptic_service.dart';
import '../providers/tak_settings_provider.dart';
import '../utils/cot_affiliation.dart';

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
        title: 'TAK Settings',
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => GlassScaffold.body(
        title: 'TAK Settings',
        body: Center(child: Text('Error: $error')),
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
            title: 'TAK Settings',
            slivers: [
              // ---------------------------------------------------------------
              // CONNECTION
              // ---------------------------------------------------------------
              const SliverToBoxAdapter(
                child: _SectionHeader(title: 'CONNECTION'),
              ),
              SliverToBoxAdapter(
                child: _SettingsTile(
                  icon: Icons.link,
                  title: 'Gateway URL',
                  subtitle: settings.gatewayUrl.isNotEmpty
                      ? settings.gatewayUrl
                      : 'Default (tak.socialmesh.app)',
                  onTap: () => _showGatewayUrlEditor(context, settings),
                ),
              ),
              SliverToBoxAdapter(
                child: _SettingsTile(
                  icon: Icons.flash_on,
                  title: 'Auto-connect on open',
                  subtitle: 'Automatically connect when TAK screens open',
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
              // POSITION PUBLISHING
              // ---------------------------------------------------------------
              const SliverToBoxAdapter(
                child: _SectionHeader(title: 'POSITION PUBLISHING'),
              ),
              SliverToBoxAdapter(
                child: _SettingsTile(
                  icon: Icons.my_location,
                  title: 'Publish my position',
                  subtitle:
                      'Share your node position with ATAK/WinTAK operators',
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
                  title: 'Publish interval',
                  subtitle: 'How often to send your position',
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
                  title: 'Callsign override',
                  subtitle: settings.callsign.isNotEmpty
                      ? settings.callsign
                      : 'Using node name',
                  onTap: () => _showCallsignEditor(context, settings),
                ),
              ),

              // ---------------------------------------------------------------
              // MAP
              // ---------------------------------------------------------------
              const SliverToBoxAdapter(child: _SectionHeader(title: 'MAP')),
              SliverToBoxAdapter(
                child: _SettingsTile(
                  icon: Icons.layers_outlined,
                  title: 'Show TAK layer on map',
                  subtitle: 'Display TAK entity markers on the dedicated map',
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
              // PROXIMITY ALERTS
              // ---------------------------------------------------------------
              const SliverToBoxAdapter(
                child: _SectionHeader(title: 'PROXIMITY ALERTS'),
              ),
              SliverToBoxAdapter(
                child: _SettingsTile(
                  icon: Icons.radar,
                  title: 'Enable proximity alerts',
                  subtitle: 'Notify when hostile/unknown entities enter radius',
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
                    title: 'Alert radius',
                    subtitle: '${settings.proximityRadiusKm.round()} km',
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: settings.proximityRadiusKm,
                        min: 1,
                        max: 50,
                        divisions: 49,
                        label: '${settings.proximityRadiusKm.round()} km',
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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gateway URL',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Leave empty to use the default gateway',
              style: Theme.of(
                sheetContext,
              ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _gatewayUrlController,
              maxLength: 256,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                hintText: 'https://tak.socialmesh.app',
                hintStyle: TextStyle(color: context.textTertiary),
                filled: true,
                fillColor: context.card,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ref
                      .read(takSettingsProvider.notifier)
                      .setGatewayUrl(_gatewayUrlController.text.trim());
                  Navigator.of(sheetContext).pop();
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCallsignEditor(BuildContext context, TakSettings settings) {
    _callsignController.text = settings.callsign;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Callsign Override',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Leave empty to use your node name',
              style: Theme.of(
                sheetContext,
              ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _callsignController,
              maxLength: 20,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'e.g., ALPHA-1',
                hintStyle: TextStyle(color: context.textTertiary),
                filled: true,
                fillColor: context.card,
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
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
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  ref
                      .read(takSettingsProvider.notifier)
                      .setCallsign(_callsignController.text.trim());
                  Navigator.of(sheetContext).pop();
                },
                child: const Text('Save'),
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: context.textSecondary),
                const SizedBox(width: 16),
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
                        const SizedBox(height: 2),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(8),
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
            const SizedBox(width: 4),
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
    (key: 'hostile', label: 'Hostile', color: CotAffiliationColors.hostile),
    (key: 'unknown', label: 'Unknown', color: CotAffiliationColors.unknown),
    (key: 'suspect', label: 'Suspect', color: CotAffiliationColors.suspect),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alert on:',
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
                  option.label,
                  style: TextStyle(fontSize: 14, color: context.textPrimary),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
