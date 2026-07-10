// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'edge_fade.dart';

// One coloured-dot + label entry in a pinned chart legend.
class ChartLegendEntry {
  final Color color;
  final String label;

  const ChartLegendEntry({required this.color, required this.label});
}

// Pinned sliver header rendering a chart legend (coloured dots + labels +
// an optional trailing text such as a readings count) with the same
// frosted-glass + sticky-shadow treatment as SectionHeaderDelegate.
//
// The legend labels wrap onto additional lines when they do not fit one row,
// so the header's extent cannot be a fixed constant: it is measured up front
// by [ChartLegendHeaderDelegate.measure] with the current text scale and the
// available width, and the delegate then reports exactly that extent. A fixed
// extent used to clip the second wrapped line at the bottom.
class ChartLegendHeaderDelegate extends SliverPersistentHeaderDelegate {
  final List<ChartLegendEntry> entries;
  final String trailingText;
  final double extent;

  static const double _minExtent = 40.0;
  static const double _dotSize = 10.0;
  static const double _itemSpacing = 16.0;
  static const double _runSpacing = 4.0;
  static const double _verticalPadding = 24.0;
  static const double _labelFontSize = 12.0;
  static const double _trailingFontSize = 11.0;

  ChartLegendHeaderDelegate._({
    required this.entries,
    required this.trailingText,
    required this.extent,
  });

  // Build a delegate whose extent fits every wrapped legend row at the
  // current text scale. Measures each label with TextPainter, simulates the
  // Wrap's run-breaking against the width left over after the trailing text,
  // and sizes the header to the resulting run count (never below the 40px
  // single-row baseline).
  factory ChartLegendHeaderDelegate.measure({
    required BuildContext context,
    required List<ChartLegendEntry> entries,
    required String trailingText,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final rowWidth = screenWidth - AppTheme.spacing16 * 2;

    double textWidth(String text, double fontSize) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: fontSize, fontFamily: AppTheme.fontFamily),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    double textHeight(double fontSize) {
      final painter = TextPainter(
        text: TextSpan(
          text: 'Ag', // lint-allow: hardcoded-string — glyph-height probe
          style: TextStyle(fontSize: fontSize, fontFamily: AppTheme.fontFamily),
        ),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
      final height = painter.height;
      painter.dispose();
      return height;
    }

    final trailingWidth = textWidth(trailingText, _trailingFontSize);
    final wrapWidth = (rowWidth - trailingWidth).clamp(0.0, rowWidth);

    // Simulate the Wrap's run-breaking to count rows.
    var runs = entries.isEmpty ? 0 : 1;
    var x = 0.0;
    for (final entry in entries) {
      final itemWidth =
          _dotSize + AppTheme.spacing4 + textWidth(entry.label, _labelFontSize);
      if (x == 0.0) {
        x = itemWidth;
      } else if (x + _itemSpacing + itemWidth <= wrapWidth) {
        x += _itemSpacing + itemWidth;
      } else {
        runs++;
        x = itemWidth;
      }
    }

    final labelHeight = textHeight(_labelFontSize);
    final itemHeight = labelHeight < _dotSize ? _dotSize : labelHeight;
    final wrapHeight = runs == 0
        ? 0.0
        : runs * itemHeight + (runs - 1) * _runSpacing;
    final trailingHeight = textHeight(_trailingFontSize);
    final contentHeight = wrapHeight < trailingHeight
        ? trailingHeight
        : wrapHeight;
    final extent = contentHeight + _verticalPadding;

    return ChartLegendHeaderDelegate._(
      entries: entries,
      trailingText: trailingText,
      extent: extent < _minExtent ? _minExtent : extent,
    );
  }

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

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
          child: Container(
            height: extent,
            color: context.background.withValues(alpha: 0.8),
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            child: Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: _itemSpacing,
                    runSpacing: _runSpacing,
                    children: [
                      for (final entry in entries) _LegendItem(entry: entry),
                    ],
                  ),
                ),
                Text(
                  trailingText,
                  style: TextStyle(
                    fontSize: _trailingFontSize,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant ChartLegendHeaderDelegate oldDelegate) {
    if (trailingText != oldDelegate.trailingText) return true;
    if (extent != oldDelegate.extent) return true;
    if (entries.length != oldDelegate.entries.length) return true;
    for (var i = 0; i < entries.length; i++) {
      if (entries[i].label != oldDelegate.entries[i].label ||
          entries[i].color != oldDelegate.entries[i].color) {
        return true;
      }
    }
    return false;
  }
}

// Colour dot + label row for a single legend entry.
class _LegendItem extends StatelessWidget {
  final ChartLegendEntry entry;

  const _LegendItem({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: ChartLegendHeaderDelegate._dotSize,
          height: ChartLegendHeaderDelegate._dotSize,
          decoration: BoxDecoration(color: entry.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppTheme.spacing4),
        Text(
          entry.label,
          style: TextStyle(
            fontSize: ChartLegendHeaderDelegate._labelFontSize,
            color: context.textSecondary,
          ),
        ),
      ],
    );
  }
}
