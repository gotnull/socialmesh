// SPDX-License-Identifier: GPL-3.0-or-later

// Album Page Header — sticky section header for album grid pages.
//
// Each album page (a group of nodes by trait, rarity, or region) gets
// a sticky header that pins at the top of the scroll view as the user
// browses through the grid. The header communicates:
//
//   - Group identity via icon + title (e.g. "Relay Nodes", "LEGENDARY Cards")
//   - Collection count via a compact badge (e.g. "12 collected")
//   - Visual hierarchy via an ornamental separator line
//
// Design constraints:
//   - Must work as a SliverPersistentHeaderDelegate child
//   - Uses theme-aware colors from context extensions
//   - Spacing follows the 8dp grid
//   - Ornamental details are subtle (thin lines, small icons)
//   - No protocol-specific logic — purely presentational
//
// The header adapts its icon based on the groupKey provided by the
// album providers. Trait groups get the trait's conceptual icon;
// rarity groups get a gem/star icon; region groups get a map icon.

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../models/nodedex_entry.dart';
import '../widgets/sigil_card.dart';
import 'album_constants.dart';

// =============================================================================
// Album Page Header Widget
// =============================================================================

/// A decorated section header for an album page in the collector grid.
///
/// Displays the group title, an icon representing the group type, and
/// a count badge showing how many cards are in this section.
///
/// Usage:
/// ```dart
/// AlbumPageHeader(
///   title: 'Relay Nodes',
///   groupKey: 'relay',
///   count: 7,
///   accentColor: NodeTrait.relay.color,
/// )
/// ```
class AlbumPageHeader extends StatelessWidget {
  /// The display title for this page (e.g. "Relay Nodes", "EPIC Cards").
  final String title;

  /// The group key used to select the appropriate icon.
  /// Trait names, rarity names, or 'region' for geographic groups.
  final String groupKey;

  /// Number of collected cards in this group.
  final int count;

  /// Accent color for the header ornaments and count badge.
  /// Typically derived from the trait color or rarity border color.
  final Color accentColor;

  const AlbumPageHeader({
    super.key,
    required this.title,
    required this.groupKey,
    required this.count,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AlbumConstants.pageHeaderHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: AlbumConstants.pageHeaderPaddingH,
      ),
      decoration: BoxDecoration(
        color: context.isDarkMode
            ? context.background.withValues(alpha: 0.92)
            : context.background.withValues(alpha: 0.95),
      ),
      child: Row(
        children: [
          // Leading ornament line
          _LeadingOrnament(color: accentColor),
          const SizedBox(width: 8),

          // Group icon
          _GroupIcon(groupKey: groupKey, color: accentColor),
          const SizedBox(width: 8),

          // Title
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: AlbumConstants.pageHeaderTitleSize,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          const SizedBox(width: 8),

          // Count badge
          _CountBadge(count: count, color: accentColor),

          const SizedBox(width: 8),

          // Trailing ornament line
          _TrailingOrnament(color: accentColor),
        ],
      ),
    );
  }
}

// =============================================================================
// Album Page Header Delegate (for SliverPersistentHeader)
// =============================================================================

/// A [SliverPersistentHeaderDelegate] that renders an [AlbumPageHeader].
///
/// Use this with [SliverPersistentHeader] to create sticky group
/// headers in the album grid view.
///
/// Usage:
/// ```dart
/// SliverPersistentHeader(
///   pinned: true,
///   delegate: AlbumPageHeaderDelegate(
///     title: 'Relay Nodes',
///     groupKey: 'relay',
///     count: 7,
///     accentColor: NodeTrait.relay.color,
///   ),
/// )
/// ```
class AlbumPageHeaderDelegate extends SliverPersistentHeaderDelegate {
  /// The display title for this album page.
  final String title;

  /// The group key for icon selection.
  final String groupKey;

  /// Number of collected cards in this group.
  final int count;

  /// Accent color for header decoration.
  final Color accentColor;

  const AlbumPageHeaderDelegate({
    required this.title,
    required this.groupKey,
    required this.count,
    required this.accentColor,
  });

  @override
  double get minExtent => AlbumConstants.pageHeaderHeight;

  @override
  double get maxExtent => AlbumConstants.pageHeaderHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return AlbumPageHeader(
      title: title,
      groupKey: groupKey,
      count: count,
      accentColor: accentColor,
    );
  }

  @override
  bool shouldRebuild(AlbumPageHeaderDelegate oldDelegate) {
    return title != oldDelegate.title ||
        groupKey != oldDelegate.groupKey ||
        count != oldDelegate.count ||
        accentColor != oldDelegate.accentColor;
  }
}

// =============================================================================
// Group icon
// =============================================================================

/// Renders the appropriate icon for a group based on its key.
///
/// Trait groups get a conceptual icon (e.g. relay → router, ghost → visibility_off).
/// Rarity groups get tier-specific icons (legendary → star, epic → diamond).
/// Region groups get a map pin icon.
class _GroupIcon extends StatelessWidget {
  final String groupKey;
  final Color color;

  const _GroupIcon({required this.groupKey, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AlbumConstants.pageHeaderIconSize + 8,
      height: AlbumConstants.pageHeaderIconSize + 8,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        _iconFor(groupKey),
        size: AlbumConstants.pageHeaderIconSize,
        color: color.withValues(alpha: 0.8),
      ),
    );
  }

  IconData _iconFor(String key) {
    return switch (key) {
      // Trait icons
      'relay' => Icons.router_outlined,
      'sentinel' => Icons.shield_outlined,
      'beacon' => Icons.cell_tower_outlined,
      'wanderer' => Icons.explore_outlined,
      'anchor' => Icons.anchor_outlined,
      'courier' => Icons.mail_outlined,
      'drifter' => Icons.air_outlined,
      'ghost' => Icons.visibility_off_outlined,
      'unknown' => Icons.help_outline_rounded,
      // Rarity icons
      'legendary' => Icons.star_rounded,
      'epic' => Icons.diamond_outlined,
      'rare' => Icons.auto_awesome_outlined,
      'uncommon' => Icons.hexagon_outlined,
      'common' => Icons.circle_outlined,
      // Region
      'region' => Icons.map_outlined,
      // Fallback
      _ => Icons.folder_outlined,
    };
  }
}

// =============================================================================
// Count badge
// =============================================================================

/// A compact pill badge showing the number of collected cards in a group.
class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;

  const _CountBadge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Text(
        '$count collected',
        style: TextStyle(
          fontSize: AlbumConstants.pageHeaderCountSize,
          fontWeight: FontWeight.w600,
          fontFamily: AppTheme.fontFamily,
          color: color.withValues(alpha: 0.8),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// =============================================================================
// Ornamental elements
// =============================================================================

/// A short decorative line at the leading edge of the header.
///
/// Renders a thin horizontal line with a small diamond terminus,
/// matching the field-journal ornamental style used in patina stamps
/// and sigil card dividers.
class _LeadingOrnament extends StatelessWidget {
  final Color color;

  const _LeadingOrnament({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: AlbumConstants.pageHeaderHeight,
      child: CustomPaint(
        painter: _LeadingOrnamentPainter(color: color.withValues(alpha: 0.3)),
      ),
    );
  }
}

/// A short decorative line at the trailing edge of the header.
class _TrailingOrnament extends StatelessWidget {
  final Color color;

  const _TrailingOrnament({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 16,
      height: AlbumConstants.pageHeaderHeight,
      child: CustomPaint(
        painter: _TrailingOrnamentPainter(color: color.withValues(alpha: 0.3)),
      ),
    );
  }
}

class _LeadingOrnamentPainter extends CustomPainter {
  final Color color;

  _LeadingOrnamentPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cy = size.height / 2;

    // Horizontal line
    canvas.drawLine(Offset(0, cy), Offset(size.width - 3, cy), paint);

    // Small diamond at the end
    final dx = size.width - 1;
    final diamondSize = 2.0;
    final diamond = Path()
      ..moveTo(dx - diamondSize, cy)
      ..lineTo(dx, cy - diamondSize)
      ..lineTo(dx + diamondSize, cy)
      ..lineTo(dx, cy + diamondSize)
      ..close();

    canvas.drawPath(diamond, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_LeadingOrnamentPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

class _TrailingOrnamentPainter extends CustomPainter {
  final Color color;

  _TrailingOrnamentPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cy = size.height / 2;

    // Small diamond at the start
    final diamondSize = 2.0;
    final diamond = Path()
      ..moveTo(0 - diamondSize, cy)
      ..lineTo(0, cy - diamondSize)
      ..lineTo(0 + diamondSize, cy)
      ..lineTo(0, cy + diamondSize)
      ..close();

    canvas.drawPath(diamond, paint..style = PaintingStyle.fill);

    // Horizontal line
    paint.style = PaintingStyle.stroke;
    canvas.drawLine(Offset(3, cy), Offset(size.width, cy), paint);
  }

  @override
  bool shouldRepaint(_TrailingOrnamentPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}

// =============================================================================
// Utility: accent color resolution for groups
// =============================================================================

/// Resolves the appropriate accent color for a group key.
///
/// Trait keys map to the trait's color. Rarity keys map to the rarity's
/// border color. Region keys use the app's accent color. Unknown keys
/// fall back to textTertiary.
///
/// This is a pure function — no side effects, no state.
Color accentColorForGroup(String groupKey, BuildContext context) {
  // Check trait names first.
  for (final trait in NodeTrait.values) {
    if (trait.name == groupKey) return trait.color;
  }

  // Check rarity names.
  for (final rarity in CardRarity.values) {
    if (rarity.name == groupKey) return rarity.borderColor;
  }

  // Region or unknown — use app accent.
  if (groupKey == 'region') return context.accentColor;

  return context.textTertiary;
}
