// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:socialmesh/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ar_state.dart';

/// Visual view mode selector widget
class ARViewModeSelector extends StatelessWidget {
  final ARViewMode currentMode;
  final ValueChanged<ARViewMode> onModeChanged;

  const ARViewModeSelector({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF00E5FF).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildModeButton(
            mode: ARViewMode.tactical,
            icon: Icons.grid_view,
            label: 'TAC',
          ),
          const SizedBox(height: 4),
          _buildModeButton(
            mode: ARViewMode.explorer,
            icon: Icons.explore,
            label: 'EXP',
          ),
          const SizedBox(height: 4),
          _buildModeButton(
            mode: ARViewMode.minimal,
            icon: Icons.radio_button_unchecked,
            label: 'MIN',
          ),
        ],
      ),
    );
  }

  Widget _buildModeButton({
    required ARViewMode mode,
    required IconData icon,
    required String label,
  }) {
    final isSelected = currentMode == mode;

    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          HapticFeedback.selectionClick();
          onModeChanged(mode);
        }
      },
      child: Container(
        width: 50,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF00E5FF).withValues(alpha: 0.3)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isSelected
              ? Border.all(color: const Color(0xFF00E5FF))
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(0xFF00E5FF)
                  : Colors.white.withValues(alpha: 0.5),
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? const Color(0xFF00E5FF)
                    : Colors.white.withValues(alpha: 0.5),
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontFamily: AppTheme.fontFamily,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
