// SPDX-License-Identifier: GPL-3.0-or-later

// Album Constants — layout grid, animation durations, and slot dimensions.
//
// Centralizes all magic numbers for the Collector Album system.
// Every spacing value, duration, and dimension used by album
// widgets is defined here so the visual language stays consistent
// and tuning requires changes in exactly one place.
//
// Layout philosophy:
//   - 8dp spacing grid (inherited from AppTheme)
//   - Portrait card slots at 5:7 aspect ratio (matching SigilCard)
//   - 3 columns on phones, 4 on tablets (breakpoint at 600dp)
//   - Album pages scroll vertically with sticky group headers
//   - Gallery uses horizontal PageView with peek at adjacent cards

import 'package:flutter/material.dart';

/// Layout, timing, and visual constants for the Collector Album.
///
/// All values are static constants — no state, no computation.
/// Widgets read these directly; providers do not depend on them.
class AlbumConstants {
  AlbumConstants._();

  // ---------------------------------------------------------------------------
  // Grid layout
  // ---------------------------------------------------------------------------

  /// Number of card columns on compact screens (< 600dp width).
  static const int columnsCompact = 3;

  /// Number of card columns on expanded screens (>= 600dp width).
  static const int columnsExpanded = 4;

  /// Breakpoint width (dp) for switching between compact and expanded.
  static const double expandedBreakpoint = 600.0;

  /// Horizontal spacing between card slots in the grid.
  static const double gridSpacingH = 8.0;

  /// Vertical spacing between card slots in the grid.
  static const double gridSpacingV = 12.0;

  /// Horizontal padding around the entire grid.
  static const double gridPaddingH = 16.0;

  /// Vertical padding above and below the grid content.
  static const double gridPaddingV = 8.0;

  /// Card slot aspect ratio (width:height). Matches SigilCard 5:7.
  static const double slotAspectRatio = 5.0 / 7.0;

  /// Returns the appropriate column count for the given screen width.
  static int columnsFor(double screenWidth) {
    return screenWidth >= expandedBreakpoint ? columnsExpanded : columnsCompact;
  }

  // ---------------------------------------------------------------------------
  // Slot dimensions
  // ---------------------------------------------------------------------------

  /// Minimum slot width before the grid switches to fewer columns.
  static const double minSlotWidth = 90.0;

  /// Border radius for card slots.
  static const double slotBorderRadius = 10.0;

  /// Border width for empty (mystery) slots.
  static const double emptySlotBorderWidth = 1.0;

  /// Dash length for empty slot dashed border.
  static const double emptySlotDashLength = 6.0;

  /// Dash gap for empty slot dashed border.
  static const double emptySlotDashGap = 4.0;

  /// Size of the mystery "?" icon inside empty slots.
  static const double mysteryIconSize = 28.0;

  /// Opacity of the mystery slot content.
  static const double mysterySlotOpacity = 0.25;

  /// Number of mystery (empty) slots appended per group.
  /// Suggests more nodes to discover without implying a fixed total.
  static const int mysterySlotCount = 2;

  // ---------------------------------------------------------------------------
  // Mini card (filled slot)
  // ---------------------------------------------------------------------------

  /// Padding inside a filled card slot.
  static const double miniCardPadding = 4.0;

  /// Sigil size as a fraction of slot width.
  static const double miniSigilFraction = 0.55;

  /// Font size for the node name on mini cards.
  static const double miniNameFontSize = 9.0;

  /// Font size for the hex ID on mini cards.
  static const double miniHexFontSize = 7.0;

  /// Maximum lines for the node name on mini cards.
  static const int miniNameMaxLines = 1;

  /// Rarity border width on mini cards.
  static const double miniRarityBorderWidth = 1.5;

  /// Glow blur radius for rare+ mini cards.
  static const double miniGlowBlur = 6.0;

  /// Glow spread radius for rare+ mini cards.
  static const double miniGlowSpread = 1.0;

  // ---------------------------------------------------------------------------
  // Album page headers
  // ---------------------------------------------------------------------------

  /// Height of sticky page headers.
  static const double pageHeaderHeight = 48.0;

  /// Font size for page header title text.
  static const double pageHeaderTitleSize = 13.0;

  /// Font size for page header count badge.
  static const double pageHeaderCountSize = 11.0;

  /// Horizontal padding inside page headers.
  static const double pageHeaderPaddingH = 16.0;

  /// Icon size in page headers.
  static const double pageHeaderIconSize = 18.0;

  // ---------------------------------------------------------------------------
  // Album cover / stats dashboard
  // ---------------------------------------------------------------------------

  /// Height of the album cover section.
  static const double coverHeight = 260.0;

  /// Border radius for the album cover card.
  static const double coverBorderRadius = 16.0;

  /// Horizontal margin around the album cover.
  static const double coverMarginH = 16.0;

  /// Vertical margin above and below the album cover.
  static const double coverMarginV = 8.0;

  /// Size of the explorer title emblem on the cover.
  static const double coverEmblemSize = 56.0;

  /// Font size for the explorer title on the cover.
  static const double coverTitleSize = 20.0;

  /// Font size for the explorer subtitle on the cover.
  static const double coverSubtitleSize = 12.0;

  /// Font size for stat values on the cover.
  static const double coverStatValueSize = 18.0;

  /// Font size for stat labels on the cover.
  static const double coverStatLabelSize = 10.0;

  /// Size of rarity tier dots in the cover breakdown.
  static const double coverRarityDotSize = 10.0;

  /// Height of the rarity breakdown bar on the cover.
  static const double coverRarityBarHeight = 6.0;

  // ---------------------------------------------------------------------------
  // Card gallery
  // ---------------------------------------------------------------------------

  /// Fraction of screen width the focused card occupies in gallery.
  static const double galleryViewportFraction = 0.85;

  /// Scale factor for non-focused cards in the gallery.
  static const double galleryUnfocusedScale = 0.9;

  /// Opacity for non-focused cards in the gallery.
  static const double galleryUnfocusedOpacity = 0.6;

  /// Height of the gallery bottom info bar.
  static const double galleryBottomBarHeight = 72.0;

  /// Size of page indicator dots in gallery.
  static const double galleryDotSize = 6.0;

  /// Size of the active page indicator dot.
  static const double galleryActiveDotSize = 8.0;

  /// Maximum number of visible dots before switching to counter.
  static const int galleryMaxDots = 15;

  // ---------------------------------------------------------------------------
  // Card flip
  // ---------------------------------------------------------------------------

  /// Duration of the card flip animation.
  static const Duration flipDuration = Duration(milliseconds: 500);

  /// Curve for the card flip animation.
  static const Curve flipCurve = Curves.easeInOutCubic;

  /// Perspective value for the 3D flip transform.
  static const double flipPerspective = 0.002;

  // ---------------------------------------------------------------------------
  // Holographic effect
  // ---------------------------------------------------------------------------

  /// Duration of one full holographic shimmer cycle.
  static const Duration holoCycleDuration = Duration(milliseconds: 3000);

  /// Opacity of the holographic overlay on rare cards.
  static const double holoOpacityRare = 0.08;

  /// Opacity of the holographic overlay on epic cards.
  static const double holoOpacityEpic = 0.12;

  /// Opacity of the holographic overlay on legendary cards.
  static const double holoOpacityLegendary = 0.18;

  /// Width of individual holographic shimmer bands.
  static const double holoBandWidth = 0.15;

  /// Angle of the holographic gradient (radians).
  static const double holoAngle = 0.5;

  /// Returns the holographic opacity for a given rarity, or 0 if none.
  static double holoOpacityFor(int rarityIndex) {
    return switch (rarityIndex) {
      2 => holoOpacityRare,
      3 => holoOpacityEpic,
      4 => holoOpacityLegendary,
      _ => 0.0,
    };
  }

  /// The rainbow colors used in the holographic shimmer gradient.
  static const List<Color> holoColors = [
    Color(0xFFFF6B6B), // red
    Color(0xFFFFE66D), // yellow
    Color(0xFF4ECDC4), // teal
    Color(0xFF45B7D1), // sky
    Color(0xFFA06CD5), // purple
    Color(0xFFFF6B9D), // pink
    Color(0xFFFF6B6B), // red (wrap)
  ];

  // ---------------------------------------------------------------------------
  // Animation durations
  // ---------------------------------------------------------------------------

  /// Duration for slot appear animation (staggered in grid).
  static const Duration slotAppearDuration = Duration(milliseconds: 300);

  /// Stagger delay between consecutive slot animations.
  static const Duration slotStaggerDelay = Duration(milliseconds: 40);

  /// Maximum total stagger time (caps the delay for large collections).
  static const Duration maxStaggerTime = Duration(milliseconds: 800);

  /// Duration for the album cover entrance animation.
  static const Duration coverEntranceDuration = Duration(milliseconds: 600);

  /// Duration for the view mode toggle transition.
  static const Duration viewToggleDuration = Duration(milliseconds: 350);

  /// Curve for the view mode toggle transition.
  static const Curve viewToggleCurve = Curves.easeInOutCubic;

  /// Duration for the mini card press feedback scale animation.
  static const Duration pressScaleDuration = Duration(milliseconds: 120);

  /// Scale factor when a mini card is pressed.
  static const double pressScaleFactor = 0.95;

  // ---------------------------------------------------------------------------
  // Grouping
  // ---------------------------------------------------------------------------

  /// Display order for trait groups in the album.
  static const List<String> traitGroupOrder = [
    'relay',
    'sentinel',
    'beacon',
    'wanderer',
    'anchor',
    'courier',
    'drifter',
    'ghost',
    'unknown',
  ];

  /// Display order for rarity groups in the album.
  static const List<String> rarityGroupOrder = [
    'legendary',
    'epic',
    'rare',
    'uncommon',
    'common',
  ];

  // ---------------------------------------------------------------------------
  // Page texture
  // ---------------------------------------------------------------------------

  /// Opacity of the subtle linen/grain texture on album pages.
  static const double pageTextureOpacity = 0.02;

  /// Opacity of the page edge vignette gradient.
  static const double pageVignetteOpacity = 0.04;

  /// Blur radius for the page background ambient glow.
  static const double pageAmbientBlur = 40.0;

  /// Opacity of the page background ambient glow.
  static const double pageAmbientOpacity = 0.06;
}
