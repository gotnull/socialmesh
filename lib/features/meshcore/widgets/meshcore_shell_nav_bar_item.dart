// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';

class MeshCoreNavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const MeshCoreNavBarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.primary;

    final iconColor = isSelected
        ? accentColor
        : theme.colorScheme.onSurface.withValues(alpha: 0.6);

    final labelColor = isSelected
        ? accentColor
        : theme.colorScheme.onSurface.withValues(alpha: 0.6);

    return BouncyTap(
      onTap: onTap,
      scaleFactor: 0.9,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: AppCurves.overshoot,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.15 : 1.0,
              duration: const Duration(milliseconds: 350),
              curve: AppCurves.overshoot,
              child: isSelected
                  ? ShaderMask(
                      shaderCallback: (bounds) {
                        final gradientColors = AccentColors.gradientFor(
                          accentColor,
                        );
                        return LinearGradient(
                          colors: [gradientColors[0], gradientColors[1]],
                        ).createShader(bounds);
                      },
                      child: AnimatedMorphIcon(
                        icon: icon,
                        size: 24,
                        color: Colors.white,
                      ),
                    )
                  : AnimatedMorphIcon(icon: icon, size: 24, color: iconColor),
            ),
            const SizedBox(height: AppTheme.spacing4),
            isSelected
                ? ShaderMask(
                    shaderCallback: (bounds) {
                      final gradientColors = AccentColors.gradientFor(
                        accentColor,
                      );
                      return LinearGradient(
                        colors: [gradientColors[0], gradientColors[1]],
                      ).createShader(bounds);
                    },
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  )
                : AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    curve: AppCurves.overshoot,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.normal,
                      color: labelColor,
                      fontFamily: AppTheme.fontFamily,
                    ),
                    child: Text(label),
                  ),
          ],
        ),
      ),
    );
  }
}
