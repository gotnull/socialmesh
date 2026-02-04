// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:ui';

import 'package:flutter/material.dart';
import '../theme.dart';
import 'edge_fade.dart';

/// Shared section header widget used in list views with grouping
class SectionHeader extends StatelessWidget {
  final String title;
  final int? count;

  const SectionHeader({super.key, required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: context.background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Sticky header delegate for section headers in sliver lists
/// Now includes backdrop blur effect for glass morphism
class SectionHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final int? count;

  SectionHeaderDelegate({required this.title, this.count});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final showShadow = shrinkOffset > 0 || overlapsContent;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: StickyHeaderShadow(
          blurRadius: showShadow ? 8 : 0,
          offsetY: showShadow ? 2 : 0,
          child: _BlurredSectionHeader(title: title, count: count),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 40;

  @override
  double get minExtent => 40;

  @override
  bool shouldRebuild(covariant SectionHeaderDelegate oldDelegate) {
    return title != oldDelegate.title || count != oldDelegate.count;
  }
}

/// Section header with semi-transparent background for blur effect
class _BlurredSectionHeader extends StatelessWidget {
  final String title;
  final int? count;

  const _BlurredSectionHeader({required this.title, this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      color: context.background.withValues(alpha: 0.8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: context.textTertiary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Toggle button for showing/hiding section headers
class SectionHeadersToggle extends StatelessWidget {
  final bool enabled;
  final VoidCallback onToggle;

  const SectionHeadersToggle({
    super.key,
    required this.enabled,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: enabled
              ? context.accentColor.withValues(alpha: 0.2)
              : context.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? context.accentColor.withValues(alpha: 0.5)
                : context.border.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(
          Icons.view_agenda_outlined,
          size: 16,
          color: enabled ? context.accentColor : context.textTertiary,
        ),
      ),
    );
  }
}

/// Filter chip widget for list filtering
class SectionFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool isSelected;
  final Color? color;
  final IconData? icon;
  final VoidCallback onTap;

  const SectionFilterChip({
    super.key,
    required this.label,
    required this.count,
    required this.isSelected,
    required this.onTap,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final chipColor = color ?? AppTheme.primaryBlue;
    final showStatusIndicator = label == 'Active';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? chipColor.withValues(alpha: 0.2) : context.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? chipColor.withValues(alpha: 0.5)
                : context.border.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Status indicator for Active chip
            if (showStatusIndicator && label == 'Active') ...[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [chipColor, chipColor.withValues(alpha: 0.6)],
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: chipColor.withValues(alpha: 0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SizedBox(width: 6),
            ] else if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? chipColor : context.textTertiary,
              ),
              SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? chipColor : context.textSecondary,
              ),
            ),
            SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? chipColor.withValues(alpha: 0.3)
                    : context.border.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? chipColor : context.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
