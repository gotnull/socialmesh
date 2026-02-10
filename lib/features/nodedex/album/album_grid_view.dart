// SPDX-License-Identifier: GPL-3.0-or-later

// Album Grid View — the full album browsing experience.
//
// Renders the collector album as a vertically scrolling grid with:
//   - Album cover stats dashboard at the top
//   - Grouping selector (by trait / rarity / region)
//   - Sticky page headers for each group
//   - Card slot grids with filled slots for discovered nodes
//   - Mystery slots at the end of each group suggesting more to find
//   - Staggered entrance animations for slots
//
// The grid adapts its column count based on screen width (3 on phones,
// 4 on tablets). Each slot maintains a 5:7 portrait aspect ratio
// matching the SigilCard dimensions.
//
// This widget returns a List<Widget> of slivers via buildSlivers(),
// designed to be composed directly inside a parent CustomScrollView
// (e.g. GlassScaffold's sliver list). It does NOT create its own
// CustomScrollView, avoiding nested-scrollable issues.
//
// Layout structure (as slivers):
//   SliverToBoxAdapter  → AlbumCover
//   SliverToBoxAdapter  → Grouping selector chips
//   For each AlbumPage:
//     SliverPersistentHeader  → AlbumPageHeader (pinned)
//     SliverPadding > SliverGrid  → FilledSlot + MysterySlot items
//   SliverToBoxAdapter  → Bottom safe area padding
//
// Data flow:
//   albumPagesProvider → grouped, ordered list of AlbumPage objects
//   albumGroupingProvider → current grouping strategy
//   collectionProgressProvider → stats for the cover
//   Each FilledSlot reads its trait via nodeDexTraitProvider
//
// All rendering is purely presentational. No protocol logic, no
// side effects, no state mutations. Tap callbacks delegate to the
// parent screen for navigation (detail screen or gallery).
//
// Performance:
//   - SliverGrid uses lazy building (only visible slots are built)
//   - Stagger animation is capped at maxStaggerTime to avoid long waits
//   - Mystery slots are IgnorePointer with no interaction overhead
//   - Holographic effects on mini cards use simplified single-pass painter

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme.dart';
import '../models/nodedex_entry.dart';
import 'album_constants.dart';
import 'album_cover.dart';
import 'album_page_header.dart';
import 'album_providers.dart';
import 'collection_slot.dart';

// =============================================================================
// Album Sliver Builder
// =============================================================================

/// Builds the collector album as a list of slivers for composition
/// inside a parent CustomScrollView (e.g. GlassScaffold).
///
/// This is the primary entry point for the album UI. It returns slivers
/// rather than wrapping them in its own CustomScrollView, so the parent
/// screen can embed them alongside the glass app bar and other slivers
/// without nested-scrollable issues.
///
/// [onCardTap] is called when a filled slot is tapped (short press).
/// [onCardLongPress] is called when a filled slot is long-pressed,
/// passing the flat index for gallery navigation.
///
/// Usage:
/// ```dart
/// GlassScaffold(
///   title: 'NodeDex',
///   slivers: buildAlbumSlivers(
///     context: context,
///     ref: ref,
///     onCardTap: (entry, index) => openDetail(entry),
///     onCardLongPress: (entry, index) => openGallery(index),
///     animate: !reduceMotion,
///   ),
/// )
/// ```
List<Widget> buildAlbumSlivers({
  required BuildContext context,
  required WidgetRef ref,
  void Function(NodeDexEntry entry, int flatIndex)? onCardTap,
  void Function(NodeDexEntry entry, int flatIndex)? onCardLongPress,
  bool animate = true,
}) {
  final pages = ref.watch(albumPagesProvider);
  final grouping = ref.watch(albumGroupingProvider);
  final screenWidth = MediaQuery.sizeOf(context).width;
  final columns = AlbumConstants.columnsFor(screenWidth);

  final slivers = <Widget>[
    // Album cover dashboard
    SliverToBoxAdapter(child: AlbumCover(animate: animate)),

    // Grouping selector
    SliverToBoxAdapter(
      child: _GroupingSelector(
        current: grouping,
        onChanged: (g) {
          ref.read(albumGroupingProvider.notifier).setGrouping(g);
        },
      ),
    ),

    const SliverToBoxAdapter(child: SizedBox(height: 8)),
  ];

  if (pages.isEmpty) {
    // Empty state
    slivers.add(
      SliverFillRemaining(hasScrollBody: false, child: _EmptyAlbumState()),
    );
  } else {
    // Compute flat index offset for each page so gallery navigation
    // can map slot taps to the correct position in the flat list.
    int flatIndexOffset = 0;

    for (final page in pages) {
      final accentColor = accentColorForGroup(page.groupKey, context);

      // Sticky page header
      slivers.add(
        SliverPersistentHeader(
          pinned: true,
          delegate: AlbumPageHeaderDelegate(
            title: page.title,
            groupKey: page.groupKey,
            count: page.filledCount,
            accentColor: accentColor,
          ),
        ),
      );

      // Card grid for this page
      final totalSlots = page.filledCount + AlbumConstants.mysterySlotCount;
      final currentOffset = flatIndexOffset;

      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AlbumConstants.gridPaddingH,
            vertical: AlbumConstants.gridPaddingV,
          ),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: AlbumConstants.slotAspectRatio,
              crossAxisSpacing: AlbumConstants.gridSpacingH,
              mainAxisSpacing: AlbumConstants.gridSpacingV,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index < page.filledCount) {
                // Filled slot
                final entry = page.entries[index];
                final flatIndex = currentOffset + index;

                return _StaggeredSlot(
                  index: index,
                  animate: animate,
                  child: FilledSlot(
                    entry: entry,
                    animate: animate,
                    onTap: () {
                      onCardTap?.call(entry, flatIndex);
                    },
                    onLongPress: () {
                      onCardLongPress?.call(entry, flatIndex);
                    },
                  ),
                );
              } else {
                // Mystery slot
                return _StaggeredSlot(
                  index: index,
                  animate: animate,
                  child: MysterySlot(animate: animate),
                );
              }
            }, childCount: totalSlots),
          ),
        ),
      );

      // Subtle spacer between groups
      slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 4)));

      flatIndexOffset += page.filledCount;
    }
  }

  // Bottom safe area padding
  slivers.add(
    SliverToBoxAdapter(
      child: SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
    ),
  );

  return slivers;
}

// =============================================================================
// Grouping selector
// =============================================================================

/// A row of choice chips for selecting the album grouping strategy.
///
/// The chips are styled to match the sci-fi aesthetic with subtle
/// borders and accent coloring on the selected chip.
class _GroupingSelector extends StatelessWidget {
  final AlbumGrouping current;
  final ValueChanged<AlbumGrouping> onChanged;

  const _GroupingSelector({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AlbumConstants.gridPaddingH,
        vertical: 4,
      ),
      child: Row(
        children: [
          // Label
          Text(
            'GROUP BY',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
              color: context.textTertiary.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(width: 12),

          // Chips
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: AlbumGrouping.values.map((grouping) {
                  final isSelected = grouping == current;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _GroupingChip(
                      grouping: grouping,
                      isSelected: isSelected,
                      onTap: () => onChanged(grouping),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single grouping option chip.
class _GroupingChip extends StatelessWidget {
  final AlbumGrouping grouping;
  final bool isSelected;
  final VoidCallback onTap;

  const _GroupingChip({
    required this.grouping,
    required this.isSelected,
    required this.onTap,
  });

  String get _label {
    return switch (grouping) {
      AlbumGrouping.byTrait => 'Trait',
      AlbumGrouping.byRarity => 'Rarity',
      AlbumGrouping.byRegion => 'Region',
    };
  }

  IconData get _icon {
    return switch (grouping) {
      AlbumGrouping.byTrait => Icons.psychology_outlined,
      AlbumGrouping.byRarity => Icons.diamond_outlined,
      AlbumGrouping.byRegion => Icons.map_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final accentColor = context.accentColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? accentColor.withValues(alpha: 0.4)
                : context.border.withValues(alpha: 0.3),
            width: isSelected ? 1.0 : 0.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              size: 14,
              color: isSelected
                  ? accentColor
                  : context.textTertiary.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 5),
            Text(
              _label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? accentColor : context.textSecondary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Staggered slot animation
// =============================================================================

/// Wraps a slot widget with a staggered entrance animation that combines:
///
///   1. **Fade in** — opacity ramps from 0 to 1 over the first 60%.
///   2. **Scale settle** — card scales from 0.88 to 1.0 with easeOutCubic.
///      No overshoot, no bounce — the card has weight and settles into place.
///   3. **Slide up** — 20px vertical travel with decelerate curve.
///
/// The stagger delay between cards creates a wave that cascades diagonally
/// across the grid (since SliverGrid fills left-to-right, top-to-bottom).
/// The maximum total stagger time is capped so large collections don't
/// wait forever.
///
/// When [animate] is false (reduce-motion), the child is shown immediately
/// with no animation.
class _StaggeredSlot extends StatefulWidget {
  final int index;
  final bool animate;
  final Widget child;

  const _StaggeredSlot({
    required this.index,
    required this.animate,
    required this.child,
  });

  @override
  State<_StaggeredSlot> createState() => _StaggeredSlotState();
}

class _StaggeredSlotState extends State<_StaggeredSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Fade: ramp up in the first 60% of the animation.
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    // Scale: 0.88 → 1.0 with deceleration. No overshoot — the card
    // has mass and settles cleanly.
    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
      ),
    );

    // Slide: 20px upward with decelerate. Enough to be visible,
    // not enough to feel bouncy.
    _slideAnimation = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    if (widget.animate) {
      // Compute stagger delay, capped at max.
      final rawDelay =
          widget.index * AlbumConstants.slotStaggerDelay.inMilliseconds;
      final cappedDelay = math.min(
        rawDelay,
        AlbumConstants.maxStaggerTime.inMilliseconds,
      );

      Future.delayed(Duration(milliseconds: cappedDelay), () {
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.animate) return widget.child;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = _fadeAnimation.value.clamp(0.0, 1.0);
        final scale = _scaleAnimation.value;
        final slideY = _slideAnimation.value;

        return Opacity(
          opacity: opacity,
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..translate(0.0, slideY)
              ..scale(scale),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// =============================================================================
// Empty state
// =============================================================================

class _EmptyAlbumState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.collections_bookmark_outlined,
              size: 64,
              color: context.textTertiary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No cards yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to a mesh device and discover nodes\nto start building your collection',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: context.textTertiary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _HintChip(
                  icon: Icons.bluetooth_searching,
                  label: 'Scan for devices',
                ),
                const SizedBox(width: 12),
                _HintChip(icon: Icons.explore_outlined, label: 'Move around'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HintChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: context.border.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: context.textTertiary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: context.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
