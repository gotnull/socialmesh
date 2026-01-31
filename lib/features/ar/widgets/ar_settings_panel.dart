// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:socialmesh/core/theme.dart';
import 'package:flutter/material.dart';

import '../ar_state.dart';

/// Settings panel for AR configuration
class ARSettingsPanel extends StatelessWidget {
  final ARState state;
  final ValueChanged<ARViewMode> onViewModeChanged;
  final ValueChanged<double> onMaxDistanceChanged;
  final ValueChanged<String> onToggleElement;
  final VoidCallback onToggleOfflineNodes;
  final VoidCallback onToggleFavoritesOnly;

  const ARSettingsPanel({
    super.key,
    required this.state,
    required this.onViewModeChanged,
    required this.onMaxDistanceChanged,
    required this.onToggleElement,
    required this.onToggleOfflineNodes,
    required this.onToggleFavoritesOnly,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('VIEW MODE'),
          const SizedBox(height: 12),
          _buildViewModeSelector(),

          const SizedBox(height: 24),
          _buildSectionHeader('DISTANCE FILTER'),
          const SizedBox(height: 12),
          _buildDistanceSlider(),

          const SizedBox(height: 24),
          _buildSectionHeader('NODE FILTERS'),
          const SizedBox(height: 12),
          _buildFilterToggles(),

          const SizedBox(height: 24),
          _buildSectionHeader('HUD ELEMENTS'),
          const SizedBox(height: 12),
          _buildHudToggles(),

          const SizedBox(height: 24),
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

  Widget _buildViewModeSelector() {
    return Row(
      children: [
        _buildModeChip(
          label: 'Tactical',
          icon: Icons.grid_view,
          mode: ARViewMode.tactical,
        ),
        const SizedBox(width: 8),
        _buildModeChip(
          label: 'Explorer',
          icon: Icons.explore,
          mode: ARViewMode.explorer,
        ),
        const SizedBox(width: 8),
        _buildModeChip(
          label: 'Minimal',
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
        onTap: () => onViewModeChanged(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? const Color(0xFF00E5FF).withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
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
              const SizedBox(height: 4),
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

  Widget _buildDistanceSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Max Distance',
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
        const SizedBox(height: 8),
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
              '100m',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 10,
              ),
            ),
            Text(
              '100km',
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

  Widget _buildFilterToggles() {
    return Column(
      children: [
        _buildToggleRow(
          icon: Icons.wifi_off,
          label: 'Show Offline Nodes',
          value: state.showOfflineNodes,
          onTap: onToggleOfflineNodes,
        ),
        const SizedBox(height: 8),
        _buildToggleRow(
          icon: Icons.star,
          label: 'Favorites Only',
          value: state.showOnlyFavorites,
          onTap: onToggleFavoritesOnly,
        ),
      ],
    );
  }

  Widget _buildHudToggles() {
    final config = state.hudConfig;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildHudChip('Horizon', config.showHorizon, 'horizon'),
        _buildHudChip('Compass', config.showCompass, 'compass'),
        _buildHudChip('Altimeter', config.showAltimeter, 'altimeter'),
        _buildHudChip('Alerts', config.showAlerts, 'alerts'),
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
          borderRadius: BorderRadius.circular(8),
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
            const SizedBox(width: 12),
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
                borderRadius: BorderRadius.circular(12),
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
          borderRadius: BorderRadius.circular(16),
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

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
  }
}
