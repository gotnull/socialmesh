// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// lint-allow: haptic-feedback — swatch taps return a palette index to
// the host screen via Navigator.pop; the host fires `ref.haptics.
// itemSelect()` (respecting user settings) immediately after pop. An
// inline HapticFeedback call here would bypass that preference and
// produce a double-pulse.

// Full 64-colour palette sheet for the MeshCanvas viewer.
//
// Spec anchor: docs/canvas/CANVAS_V0_1.md §S0.ux.15 ("active palette
// swatch is one tap away (bottom strip or quick-access)") and §11
// (the canonical palette is `paletteId = 1`, 64 entries).
//
// S7.B scope: opens from the bottom strip's "more" button. Renders
//   - an optional pinned "Recent" rail at the top showing the user's
//     most-recently-used colours (LRU, newest first). Hidden when
//     empty so a fresh install doesn't show an awkward placeholder.
//   - the 64-colour grid as an 8 x 8 layout in palette-index order
//     so users can build a mental map of where colours live.
// Tapping any swatch pops the sheet returning the selected palette
// index; the host updates `selectedColorProvider` (which transitively
// pushes to `recentColorsProvider`) and fires the haptic.
//
// Sizing: starts at 60% screen height (full grid + drag pill fit
// comfortably above the keyboard / home indicator), drag-up to 90%,
// drag-down to dismiss. The grid is finger-sized: 8 columns at the
// typical 360-440pt screen width gives ~40-50pt-square swatches,
// well above the 44pt accessible-target floor.
library;

import 'package:flutter/material.dart';

import '../../../core/canvas/canvas_palette.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';

/// Open the palette sheet. Returns the selected palette index, or
/// null if the user dismissed via drag-down / tap-outside.
///
/// [recentIndices] drives the pinned "Recent" rail at the top of the
/// sheet — pass an empty list (or omit) to hide the rail entirely.
/// Order is "newest first"; the caller is responsible for de-duping.
Future<int?> showCanvasPaletteSheet({
  required BuildContext context,
  required int selectedIndex,
  List<int> recentIndices = const <int>[],
  String recentLabel = 'Recent', // lint-allow: hardcoded-string
}) {
  return AppBottomSheet.showScrollable<int>(
    context: context,
    builder: (controller) => _CanvasPaletteSheet(
      selectedIndex: selectedIndex,
      recentIndices: recentIndices,
      recentLabel: recentLabel,
      scrollController: controller,
    ),
  );
}

class _CanvasPaletteSheet extends StatelessWidget {
  final int selectedIndex;
  final List<int> recentIndices;
  final String recentLabel;
  final ScrollController scrollController;

  const _CanvasPaletteSheet({
    required this.selectedIndex,
    required this.recentIndices,
    required this.recentLabel,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final hasRecents = recentIndices.isNotEmpty;
    // SingleChildScrollView + GridView(shrinkWrap) so every swatch
    // is materialised eagerly — a lazy SliverGrid would chop off
    // the bottom rows in widget tests where the initial sheet
    // height is smaller than the full 8 x 8 grid. The grid does
    // not need lazy rendering (only 64 entries) so we pay nothing.
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasRecents) ...[
            _RecentRail(
              indices: recentIndices,
              selectedIndex: selectedIndex,
              label: recentLabel,
              onTap: (i) => Navigator.of(context).pop(i),
            ),
            const SizedBox(height: AppTheme.spacing8),
            const Divider(height: 1),
            const SizedBox(height: AppTheme.spacing16),
          ],
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1,
            ),
            itemCount: SocialMeshPalette.colors.length,
            itemBuilder: (context, paletteIndex) {
              return _GridSwatch(
                paletteIndex: paletteIndex,
                isSelected: paletteIndex == selectedIndex,
                onTap: () => Navigator.of(context).pop(paletteIndex),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RecentRail extends StatelessWidget {
  final List<int> indices;
  final int selectedIndex;
  final String label;
  final void Function(int paletteIndex) onTap;

  const _RecentRail({
    required this.indices,
    required this.selectedIndex,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textTertiary,
              letterSpacing: 1.1,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: indices.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppTheme.spacing12),
            itemBuilder: (context, position) {
              final paletteIndex = indices[position];
              return _RecentSwatch(
                paletteIndex: paletteIndex,
                isSelected: paletteIndex == selectedIndex,
                onTap: () => onTap(paletteIndex),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _RecentSwatch extends StatelessWidget {
  final int paletteIndex;
  final bool isSelected;
  final VoidCallback onTap;

  const _RecentSwatch({
    required this.paletteIndex,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = SocialMeshPalette.colorOf(paletteIndex);
    final isTransparent = paletteIndex == SocialMeshPalette.defaultIndex;
    // Suffix the semantic label so the recents-rail entry is
    // distinguishable from the main-grid entry of the same colour
    // when widget tests look up by Semantics label.
    final name =
        '${SocialMeshPalette.nameOf(paletteIndex)} (recent)'; // lint-allow: hardcoded-string

    return Semantics(
      label: name,
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colour,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withValues(alpha: 0.6),
              width: isSelected ? 3 : 1,
            ),
          ),
          child: isTransparent
              ? Center(
                  child: Icon(
                    Icons.format_color_reset,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}

class _GridSwatch extends StatelessWidget {
  final int paletteIndex;
  final bool isSelected;
  final VoidCallback onTap;

  const _GridSwatch({
    required this.paletteIndex,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = SocialMeshPalette.colorOf(paletteIndex);
    final isTransparent = paletteIndex == SocialMeshPalette.defaultIndex;

    return Semantics(
      label: SocialMeshPalette.nameOf(paletteIndex),
      selected: isSelected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: colour,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.dividerColor.withValues(alpha: 0.6),
              width: isSelected ? 3 : 1,
            ),
          ),
          child: isTransparent
              ? Center(
                  child: Icon(
                    Icons.format_color_reset,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
