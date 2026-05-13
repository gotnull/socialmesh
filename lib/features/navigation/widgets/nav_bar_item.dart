// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';

/// Data class for bottom navigation items.
class NavItem {
  /// Stable string identifier for customization (user-chosen
  /// ordering). Persisted via SharedPreferences in
  /// `bottomTabOrder` — once shipped, the id is a release contract
  /// and must never be renamed. See
  /// `bottom_tab_providers.dart` for the canonical id list.
  final String id;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const NavItem({
    required this.id,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// A single bottom navigation bar item with badge support, animations,
/// and accent-gradient highlighting when selected.
class NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final int badgeCount;
  final bool showWarningBadge;
  final bool showReconnectingBadge;
  final VoidCallback onTap;

  const NavBarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    this.badgeCount = 0,
    this.showWarningBadge = false,
    this.showReconnectingBadge = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine icon color
    final accentColor = theme.colorScheme.primary;
    Color iconColor;
    if (isSelected) {
      iconColor = accentColor;
    } else if (showReconnectingBadge) {
      iconColor = AppTheme.warningYellow;
    } else if (showWarningBadge) {
      iconColor = AppTheme.accentOrange;
    } else {
      iconColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }

    // Determine label color
    Color labelColor;
    if (isSelected) {
      labelColor = accentColor;
    } else if (showReconnectingBadge) {
      labelColor = AppTheme.warningYellow;
    } else if (showWarningBadge) {
      labelColor = AppTheme.accentOrange;
    } else {
      labelColor = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    }

    return BouncyTap(
      onTap: onTap,
      scaleFactor: 0.9,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: AppCurves.overshoot,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
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
                              colors: [
                                gradientColors.first,
                                gradientColors.last,
                              ],
                            ).createShader(bounds);
                          },
                          child: AnimatedMorphIcon(
                            icon: icon,
                            size: 24,
                            color: SemanticColors.onAccent,
                          ),
                        )
                      : AnimatedMorphIcon(
                          icon: icon,
                          size: 24,
                          color: iconColor,
                        ),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: badgeCount > 9 ? 4 : 0,
                        vertical: 0,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AccentColors.red,
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          badgeCount > 99 ? '99+' : '$badgeCount',
                          style: const TextStyle(
                            color: SemanticColors.onAccent,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showReconnectingBadge)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: PulsingDot(color: AppTheme.warningYellow),
                  )
                else if (showWarningBadge)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppTheme.accentOrange,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing4),
            isSelected
                ? ShaderMask(
                    shaderCallback: (bounds) {
                      final gradientColors = AccentColors.gradientFor(
                        accentColor,
                      );
                      return LinearGradient(
                        colors: [gradientColors.first, gradientColors.last],
                      ).createShader(bounds);
                    },
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: SemanticColors.onAccent,
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

/// A small dot that pulses between transparent and opaque.
/// Used for reconnecting indicators on nav bar items and drawer nodes.
class PulsingDot extends StatefulWidget {
  final Color color;

  const PulsingDot({super.key, required this.color});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _animation.value),
            shape: BoxShape.circle,
            border: Border.all(
              color: Theme.of(context).scaffoldBackgroundColor,
              width: 2,
            ),
          ),
        );
      },
    );
  }
}
