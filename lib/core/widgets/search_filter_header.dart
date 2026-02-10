// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'edge_fade.dart';

// ---------------------------------------------------------------------------
// Layout constants — single source of truth for search + filter headers.
// All values follow the 8dp grid from the design system.
// ---------------------------------------------------------------------------

/// Layout constants for [SearchFilterHeader] and its sliver delegate.
///
/// Every screen that uses a search bar + filter chips pattern MUST use these
/// constants instead of hardcoding values.
class SearchFilterLayout {
  SearchFilterLayout._();

  /// Horizontal padding around the search field and chip row.
  static const double horizontalPadding = 16.0;

  /// Vertical padding above the search field.
  static const double searchTopPadding = 8.0;

  /// Vertical gap between the search field and the filter-chip row.
  static const double searchToChipsGap = 8.0;

  /// Height of the horizontally-scrollable filter-chip row.
  static const double chipRowHeight = 44.0;

  /// Vertical gap between the chip row and the bottom divider.
  static const double chipsToBottomGap = 8.0;

  /// Height of the bottom divider.
  static const double dividerHeight = 1.0;

  /// Border radius for the search field container.
  static const double searchFieldRadius = 12.0;

  /// Horizontal gap between consecutive filter chips.
  static const double chipSpacing = 8.0;

  /// Edge-fade gradient size on the trailing edge of the chip row.
  static const double edgeFadeSize = 32.0;

  /// Backdrop blur sigma for the frosted-glass effect.
  static const double blurSigma = 20.0;

  /// Background opacity for the frosted-glass container.
  static const double backgroundAlpha = 0.8;

  /// Computes the minimum search-field height respecting text scale and
  /// minimum interactive dimension.
  static double searchFieldHeight(TextScaler textScaler) =>
      math.max(kMinInteractiveDimension, textScaler.scale(48));

  /// Total extent for a header containing both a search field and a chip row.
  static double fullExtent(TextScaler textScaler) =>
      searchTopPadding +
      searchFieldHeight(textScaler) +
      searchToChipsGap +
      chipRowHeight +
      chipsToBottomGap +
      dividerHeight;

  /// Total extent for a search-only header (no filter chips).
  static double searchOnlyExtent(TextScaler textScaler) =>
      searchTopPadding +
      searchFieldHeight(textScaler) +
      chipsToBottomGap; // reuse as bottom pad
}

// ---------------------------------------------------------------------------
// SearchFilterHeader — composable, non-sliver widget.
// ---------------------------------------------------------------------------

/// A search bar + horizontally-scrollable filter-chip row with consistent
/// spacing, backdrop blur, and an optional bottom divider.
///
/// Use this widget directly inside [Column] / [Expanded] layouts (e.g. the
/// Channels screen). For sliver-based screens, use [SearchFilterHeaderDelegate]
/// instead.
///
/// ```dart
/// SearchFilterHeader(
///   searchController: _searchController,
///   searchQuery: _searchQuery,
///   onSearchChanged: (v) => setState(() => _searchQuery = v),
///   hintText: 'Search channels',
///   filterChips: [
///     SectionFilterChip(label: 'All', count: 5, isSelected: true, onTap: () {}),
///   ],
/// )
/// ```
class SearchFilterHeader extends StatelessWidget {
  /// Controller for the search [TextField].
  final TextEditingController searchController;

  /// Current search query string (used to show/hide the clear button).
  final String searchQuery;

  /// Called when the search text changes.
  final ValueChanged<String> onSearchChanged;

  /// Placeholder text for the search field.
  final String hintText;

  /// Optional [FocusNode] for the search field.
  final FocusNode? focusNode;

  /// Filter-chip widgets displayed in the horizontally-scrollable row.
  ///
  /// Pass an empty list to hide the chip row entirely.
  final List<Widget> filterChips;

  /// Optional trailing controls pinned to the end of the chip row (e.g. a
  /// sort button or section-headers toggle). These sit outside the scrollable
  /// area.
  final List<Widget> trailingControls;

  /// Whether to show the bottom divider. Defaults to `true`.
  final bool showDivider;

  /// Whether to apply backdrop blur. Defaults to `false` for non-sliver usage
  /// (the blur is typically only needed when pinned over scrolling content).
  final bool applyBlur;

  const SearchFilterHeader({
    super.key,
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    this.hintText = 'Search',
    this.focusNode,
    this.filterChips = const [],
    this.trailingControls = const [],
    this.showDivider = true,
    this.applyBlur = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = _SearchFilterContent(
      searchController: searchController,
      searchQuery: searchQuery,
      onSearchChanged: onSearchChanged,
      hintText: hintText,
      focusNode: focusNode,
      filterChips: filterChips,
      trailingControls: trailingControls,
      showDivider: showDivider,
    );

    if (applyBlur) {
      content = ClipRect(
        clipBehavior: Clip.hardEdge,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: SearchFilterLayout.blurSigma,
            sigmaY: SearchFilterLayout.blurSigma,
          ),
          child: Container(
            color: context.background.withValues(
              alpha: SearchFilterLayout.backgroundAlpha,
            ),
            child: content,
          ),
        ),
      );
    }

    return content;
  }
}

// ---------------------------------------------------------------------------
// SearchFilterHeaderDelegate — sliver persistent header delegate.
// ---------------------------------------------------------------------------

/// A [SliverPersistentHeaderDelegate] that renders a pinned search bar +
/// filter-chip row with consistent layout, backdrop blur, and a bottom
/// divider.
///
/// Use inside a [SliverPersistentHeader] with `pinned: true`.
///
/// ```dart
/// SliverPersistentHeader(
///   pinned: true,
///   delegate: SearchFilterHeaderDelegate(
///     searchController: _searchController,
///     searchQuery: _searchQuery,
///     onSearchChanged: (v) => setState(() => _searchQuery = v),
///     hintText: 'Find a node',
///     filterChips: [ ... ],
///     textScaler: MediaQuery.textScalerOf(context),
///   ),
/// )
/// ```
class SearchFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  /// Controller for the search [TextField].
  final TextEditingController searchController;

  /// Current search query string.
  final String searchQuery;

  /// Called when the search text changes.
  final ValueChanged<String> onSearchChanged;

  /// Placeholder text for the search field.
  final String hintText;

  /// Optional [FocusNode] for the search field.
  final FocusNode? focusNode;

  /// Filter-chip widgets. Pass an empty list for a search-only header.
  final List<Widget> filterChips;

  /// Optional trailing controls outside the scrollable chip area.
  final List<Widget> trailingControls;

  /// The current [TextScaler] — pass `MediaQuery.textScalerOf(context)`.
  final TextScaler textScaler;

  /// An opaque key used by [shouldRebuild] to detect content changes.
  ///
  /// Callers should pass a value that changes whenever any chip label, count,
  /// or selection state changes. A simple approach is to use
  /// `Object.hashAll([filter, count1, count2, ...])`.
  final Object? rebuildKey;

  SearchFilterHeaderDelegate({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.textScaler,
    this.hintText = 'Search',
    this.focusNode,
    this.filterChips = const [],
    this.trailingControls = const [],
    this.rebuildKey,
  });

  bool get _hasChips => filterChips.isNotEmpty;

  double get _computedExtent => _hasChips
      ? SearchFilterLayout.fullExtent(textScaler)
      : SearchFilterLayout.searchOnlyExtent(textScaler);

  @override
  double get minExtent => _computedExtent;

  @override
  double get maxExtent => _computedExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ClipRect(
      clipBehavior: Clip.hardEdge,
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: SearchFilterLayout.blurSigma,
          sigmaY: SearchFilterLayout.blurSigma,
        ),
        child: Container(
          color: context.background.withValues(
            alpha: SearchFilterLayout.backgroundAlpha,
          ),
          child: _SearchFilterContent(
            searchController: searchController,
            searchQuery: searchQuery,
            onSearchChanged: onSearchChanged,
            hintText: hintText,
            focusNode: focusNode,
            filterChips: filterChips,
            trailingControls: trailingControls,
            showDivider: _hasChips,
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant SearchFilterHeaderDelegate oldDelegate) {
    return searchQuery != oldDelegate.searchQuery ||
        hintText != oldDelegate.hintText ||
        rebuildKey != oldDelegate.rebuildKey ||
        filterChips.length != oldDelegate.filterChips.length ||
        trailingControls.length != oldDelegate.trailingControls.length;
  }
}

// ---------------------------------------------------------------------------
// Shared internal content widget.
// ---------------------------------------------------------------------------

class _SearchFilterContent extends StatelessWidget {
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final String hintText;
  final FocusNode? focusNode;
  final List<Widget> filterChips;
  final List<Widget> trailingControls;
  final bool showDivider;

  const _SearchFilterContent({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.hintText,
    required this.focusNode,
    required this.filterChips,
    required this.trailingControls,
    required this.showDivider,
  });

  bool get _hasChips => filterChips.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final fieldHeight = SearchFilterLayout.searchFieldHeight(textScaler);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // -- Search bar --
        Padding(
          padding: EdgeInsets.fromLTRB(
            SearchFilterLayout.horizontalPadding,
            SearchFilterLayout.searchTopPadding,
            SearchFilterLayout.horizontalPadding,
            0,
          ),
          child: SizedBox(
            height: fieldHeight,
            child: _SearchField(
              controller: searchController,
              query: searchQuery,
              onChanged: onSearchChanged,
              hintText: hintText,
              focusNode: focusNode,
              height: fieldHeight,
            ),
          ),
        ),

        // -- Gap between search and chips --
        if (_hasChips) SizedBox(height: SearchFilterLayout.searchToChipsGap),

        // -- Filter chips row --
        if (_hasChips)
          SizedBox(
            height: SearchFilterLayout.chipRowHeight,
            child: _buildChipRow(context),
          ),

        // -- Gap before divider --
        if (_hasChips) SizedBox(height: SearchFilterLayout.chipsToBottomGap),

        // -- Bottom divider --
        if (showDivider)
          Container(
            height: SearchFilterLayout.dividerHeight,
            color: context.border.withValues(alpha: 0.3),
          ),
      ],
    );
  }

  Widget _buildChipRow(BuildContext context) {
    final hasTrailing = trailingControls.isNotEmpty;

    // Build the scrollable chip list with consistent spacing
    final chipList = <Widget>[];
    for (int i = 0; i < filterChips.length; i++) {
      chipList.add(filterChips[i]);
      if (i < filterChips.length - 1) {
        chipList.add(SizedBox(width: SearchFilterLayout.chipSpacing));
      }
    }
    // Trailing padding inside the scrollable area
    chipList.add(SizedBox(width: SearchFilterLayout.horizontalPadding));

    Widget scrollableChips = EdgeFade.end(
      fadeSize: SearchFilterLayout.edgeFadeSize,
      fadeColor: context.background,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(left: SearchFilterLayout.horizontalPadding),
        children: chipList,
      ),
    );

    if (!hasTrailing) {
      return scrollableChips;
    }

    // When there are trailing controls, put the scrollable chips in an
    // Expanded and pin trailing controls to the right.
    return Row(
      children: [
        Expanded(child: scrollableChips),
        SizedBox(width: SearchFilterLayout.chipSpacing),
        ...trailingControls,
        SizedBox(width: SearchFilterLayout.horizontalPadding - 4),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared search field widget.
// ---------------------------------------------------------------------------

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final String hintText;
  final FocusNode? focusNode;
  final double height;

  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.hintText,
    required this.focusNode,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(
          SearchFilterLayout.searchFieldRadius,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        style: TextStyle(color: context.textPrimary),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: context.textTertiary),
          prefixIcon: Icon(Icons.search, color: context.textTertiary),
          suffixIcon: query.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: context.textTertiary),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          isDense: true,
          constraints: BoxConstraints.tightFor(height: height),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: SearchFilterLayout.horizontalPadding,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}
