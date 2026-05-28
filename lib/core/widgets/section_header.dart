// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: haptic-feedback — onTap delegates to parent callback
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'app_bottom_sheet.dart';
import 'auto_scroll_text.dart';
import 'edge_fade.dart';

/// Canonical sub-section title used above cards, tables, and form groups
/// (the "CONNECTION DETAILS" / "QUICK ACTIONS" / "CURRENT VERSION" style).
///
/// When [helpSheetBuilder] is provided, a small (i) icon is rendered on
/// the same header line, immediately after the title — never inside the
/// card or table below. Tapping it opens an [AppBottomSheet] whose child
/// is the result of calling the builder. This mirrors NodeDex's
/// `_SectionInfoButton` pattern — the widget owns the sheet, callers just
/// declare what goes inside.
///
/// Do not use this for sticky sliver list headers — use [SectionHeader]
/// for those.
///
/// Usage:
/// ```dart
/// SectionTitle(
///   title: context.l10n.firmwareUpdateSectionDeviceInfo,
///   helpSheetBuilder: (ctx) => const _UpdateMethodInfoSheet(),
/// ),
/// const SizedBox(height: AppTheme.spacing12),
/// InfoTable(rows: [...]),
/// ```
class SectionTitle extends StatelessWidget {
  final String title;
  final IconData? leadingIcon;
  final WidgetBuilder? helpSheetBuilder;
  final Widget? trailing;

  /// When true, the title scrolls horizontally (marquee) if it
  /// overflows the available width. Use this for user-generated
  /// content (community names, channel names, node names) where
  /// truncating loses information. Defaults to false so existing
  /// fixed-copy call sites (`"CONNECTION DETAILS"`, etc.) keep
  /// their gentle fade-out behaviour.
  final bool marquee;

  const SectionTitle({
    super.key,
    required this.title,
    this.leadingIcon,
    this.helpSheetBuilder,
    this.trailing,
    this.marquee = false,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: context.textTertiary,
      letterSpacing: 1,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
      child: Row(
        children: [
          if (leadingIcon != null) ...[
            Icon(leadingIcon, size: 14, color: context.textTertiary),
            const SizedBox(width: AppTheme.spacing8),
          ],
          Flexible(
            child: marquee
                ? AutoScrollText(
                    title.toUpperCase(),
                    style: titleStyle,
                    // SectionTitle is a static header (not animated),
                    // so the natural-feeling scroll pacing here is
                    // slightly slower than the in-app-bar use to avoid
                    // grabbing attention away from the InfoTable below.
                    velocity: 28,
                    pauseBetween: const Duration(seconds: 3),
                  )
                : Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: titleStyle,
                  ),
          ),
          if (helpSheetBuilder != null) ...[
            const SizedBox(width: AppTheme.spacing4),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                AppBottomSheet.show<void>(
                  context: context,
                  child: Builder(builder: helpSheetBuilder!),
                );
              },
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing4),
                child: Icon(
                  Icons.info_outline,
                  size: 14,
                  color: context.textTertiary.withValues(alpha: 0.6),
                ),
              ),
            ),
          ],
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

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
            const SizedBox(width: AppTheme.spacing8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(AppTheme.radius8),
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
  final Widget? trailing;

  SectionHeaderDelegate({required this.title, this.count, this.trailing});

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
          child: _BlurredSectionHeader(
            title: title,
            count: count,
            trailing: trailing,
          ),
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
    return title != oldDelegate.title ||
        count != oldDelegate.count ||
        trailing != oldDelegate.trailing;
  }
}

/// Section header with semi-transparent background for blur effect
class _BlurredSectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final Widget? trailing;

  const _BlurredSectionHeader({required this.title, this.count, this.trailing});

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
            const SizedBox(width: AppTheme.spacing8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(AppTheme.radius8),
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
          if (trailing != null) ...[const Spacer(), trailing!],
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
        padding: const EdgeInsets.all(AppTheme.spacing6),
        decoration: BoxDecoration(
          color: enabled
              ? context.accentColor.withValues(alpha: 0.2)
              : context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius8),
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
  final int? count;
  final bool isSelected;
  final Color? color;
  final IconData? icon;
  final VoidCallback onTap;

  const SectionFilterChip({
    super.key,
    required this.label,
    this.count,
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
          borderRadius: BorderRadius.circular(AppTheme.radius20),
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
                  margin: const EdgeInsets.all(AppTheme.spacing2),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SizedBox(width: AppTheme.spacing6),
            ] else if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: isSelected ? chipColor : context.textTertiary,
              ),
              SizedBox(width: AppTheme.spacing4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? chipColor : context.textSecondary,
              ),
            ),
            if (count != null) ...[
              SizedBox(width: AppTheme.spacing6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? chipColor.withValues(alpha: 0.3)
                      : context.border.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
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
          ],
        ),
      ),
    );
  }
}
