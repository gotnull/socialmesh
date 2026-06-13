// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:socialmesh/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/units/distance_format.dart';

import '../ar_state.dart';

/// Settings panel for AR configuration
class ARSettingsPanel extends StatelessWidget {
  final ARState state;
  final ValueChanged<ARViewMode> onViewModeChanged;
  final ValueChanged<double> onMaxDistanceChanged;
  final ValueChanged<String> onToggleElement;
  final VoidCallback onToggleOfflineNodes;
  final VoidCallback onToggleFavoritesOnly;
  final MeasurementUnits units;

  const ARSettingsPanel({
    super.key,
    required this.state,
    required this.onViewModeChanged,
    required this.onMaxDistanceChanged,
    required this.onToggleElement,
    required this.onToggleOfflineNodes,
    required this.onToggleFavoritesOnly,
    required this.units,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(context.l10n.arSettingsViewMode),
          const SizedBox(height: AppTheme.spacing12),
          _buildViewModeSelector(context),

          const SizedBox(height: AppTheme.spacing24),
          _buildSectionHeader(context.l10n.arSettingsDistanceFilter),
          const SizedBox(height: AppTheme.spacing12),
          _buildDistanceSlider(context),

          const SizedBox(height: AppTheme.spacing24),
          _buildSectionHeader(context.l10n.arSettingsNodeFilters),
          const SizedBox(height: AppTheme.spacing12),
          _buildFilterToggles(context),

          const SizedBox(height: AppTheme.spacing24),
          _buildSectionHeader(context.l10n.arSettingsHudElements),
          const SizedBox(height: AppTheme.spacing12),
          _buildHudToggles(context),

          const SizedBox(height: AppTheme.spacing24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        color: const Color(0xFF00E5FF).withValues(alpha: 0.7),
        fontSize: 11,
        fontWeight: FontWeight.bold,
        fontFamily: AppTheme.fontFamily,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildViewModeSelector(BuildContext context) {
    return Row(
      children: [
        _buildModeChip(
          label: context.l10n.arSettingsTactical,
          icon: Icons.grid_view,
          mode: ARViewMode.advanced,
        ),
        const SizedBox(width: AppTheme.spacing8),
        _buildModeChip(
          label: context.l10n.arSettingsExplorer,
          icon: Icons.explore,
          mode: ARViewMode.explorer,
        ),
        const SizedBox(width: AppTheme.spacing8),
        _buildModeChip(
          label: context.l10n.arSettingsMinimal,
          icon: Icons.radio_button_unchecked,
          mode: ARViewMode.minimal,
        ),
      ],
    );
  }

  Widget _buildModeChip({
    required String label,
    required IconData icon,
    required ARViewMode mode,
  }) {
    final isSelected = state.viewMode == mode;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onViewModeChanged(mode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF00E5FF)
                  : Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? const Color(0xFF00E5FF)
                    : Colors.white.withValues(alpha: 0.5),
                size: 24,
              ),
              const SizedBox(height: AppTheme.spacing4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF00E5FF)
                      : Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDistanceSlider(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.arSettingsMaxDistance,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            Text(
              _formatDistance(state.maxDistance),
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: const Color(0xFF00E5FF),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            thumbColor: const Color(0xFF00E5FF),
            overlayColor: const Color(0xFF00E5FF).withValues(alpha: 0.2),
            trackHeight: 4,
          ),
          child: Slider(
            value: state.maxDistance,
            min: 100,
            max: 100000,
            divisions: 100,
            onChanged: onMaxDistanceChanged,
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.l10n.arSettingsMinDistanceLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
            Text(
              context.l10n.arSettingsMaxDistanceLabel,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterToggles(BuildContext context) {
    return Column(
      children: [
        _buildToggleRow(
          icon: Icons.wifi_off,
          label: context.l10n.arSettingsShowOfflineNodes,
          value: state.showOfflineNodes,
          onTap: onToggleOfflineNodes,
        ),
        const SizedBox(height: AppTheme.spacing8),
        _buildToggleRow(
          icon: Icons.star,
          label: context.l10n.arSettingsFavoritesOnly,
          value: state.showOnlyFavorites,
          onTap: onToggleFavoritesOnly,
        ),
      ],
    );
  }

  Widget _buildHudToggles(BuildContext context) {
    final config = state.hudConfig;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildHudChip(
          context.l10n.arSettingsHorizon,
          config.showHorizon,
          'horizon',
        ),
        _buildHudChip(
          context.l10n.arSettingsCompass,
          config.showCompass,
          'compass',
        ),
        _buildHudChip(
          context.l10n.arSettingsAltimeter,
          config.showAltimeter,
          'altimeter',
        ),
        _buildHudChip(
          context.l10n.arSettingsAlerts,
          config.showAlerts,
          'alerts',
        ),
      ],
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: value
              ? const Color(0xFF00E5FF).withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppTheme.radius8),
          border: Border.all(
            color: value
                ? const Color(0xFF00E5FF).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: value
                  ? const Color(0xFF00E5FF)
                  : Colors.white.withValues(alpha: 0.5),
              size: 20,
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: value
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              width: 44,
              height: 24,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
                color: value
                    ? const Color(0xFF00E5FF)
                    : Colors.white.withValues(alpha: 0.1),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: value
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHudChip(String label, bool isEnabled, String element) {
    return GestureDetector(
      onTap: () => onToggleElement(element),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isEnabled
              ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          border: Border.all(
            color: isEnabled
                ? const Color(0xFF00E5FF)
                : Colors.white.withValues(alpha: 0.1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isEnabled
                ? const Color(0xFF00E5FF)
                : Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: isEnabled ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  String _formatDistance(double meters) =>
      formatDistanceMetersAscii(meters, units);
}
