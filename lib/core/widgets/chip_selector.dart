// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../theme.dart';
import 'edge_fade.dart';
import 'status_filter_chip.dart';

/// One option in a [ChipSelector] — the displayable face of a `T` value.
///
/// Each option carries its own accent [color] so a multi-option picker
/// can colour-code semantically (e.g. green for "detected", red for
/// "clear") rather than picking one tint for the whole row.
class ChipOption<T> {
  const ChipOption({
    required this.value,
    required this.label,
    this.icon,
    required this.color,
  });

  final T value;
  final String label;

  /// Leading glyph. When null, the chip renders a small filled circle
  /// in [color] instead — useful for severity/status pickers where the
  /// color itself carries the meaning.
  final IconData? icon;
  final Color color;
}

/// Centered, wrapping row of [StatusFilterChip]s used as a single-select
/// picker. Replaces Material's `SegmentedButton` for inner-settings,
/// config, and form screens — segments wrap and look broken when labels
/// are longer than ~5 characters or when more than 2 options are shown,
/// while the chip row degrades cleanly to multiple lines.
///
/// Example:
///
/// ```dart
/// ChipSelector<NotificationStyle>(
///   value: _notifStyle,
///   options: const [
///     ChipOption(value: NotificationStyle.minimal, ...),
///     ChipOption(value: NotificationStyle.detailed, ...),
///   ],
///   onChanged: _setNotifStyle,
/// )
/// ```
class ChipSelector<T> extends StatelessWidget {
  const ChipSelector({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
    this.alignment = WrapAlignment.center,
    this.scrollable = false,
  });

  /// Currently selected value. Pass `null` if your `T` is nullable and
  /// no option is selected.
  final T value;

  /// Available options, in display order. Order is the only ordering
  /// guarantee — the widget does not sort.
  final List<ChipOption<T>> options;

  /// Called when the user taps an option. `null` disables every chip
  /// (equivalent to setting [enabled] to false).
  final ValueChanged<T>? onChanged;

  /// When false, chips render but don't respond to taps. Defaults to
  /// true. Distinct from `onChanged: null` only in intent — both are
  /// rendered identically.
  final bool enabled;

  /// Wrap alignment. Defaults to centered, which is what every callsite
  /// in the app currently wants. Ignored when [scrollable] is true.
  final WrapAlignment alignment;

  /// When true, the chips render in a single horizontal scroll row with
  /// an [EdgeFade.end] indicator on the right edge, instead of wrapping
  /// onto multiple lines. Use this for pickers with many short options
  /// (e.g. duration intervals) where wrapping to 2-3 rows feels heavy.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && onChanged != null;
    final chips = <Widget>[
      for (final option in options)
        StatusFilterChip(
          label: option.label,
          icon: option.icon,
          color: option.color,
          isSelected: option.value == value,
          onTap: canTap ? () => onChanged!(option.value) : () {},
        ),
    ];

    if (scrollable) {
      // EdgeFade.end always renders a right-edge fade — visually
      // signals "more options exist off-screen" without depending on a
      // ScrollController to check overflow. Negligible visual cost when
      // the chips actually fit on one row.
      return EdgeFade.end(
        fadeColor: context.background,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.only(right: AppTheme.spacing16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < chips.length; i++) ...[
                if (i > 0) const SizedBox(width: AppTheme.spacing8),
                chips[i],
              ],
            ],
          ),
        ),
      );
    }

    // SizedBox + Center is the explicit recipe for centering: the
    // SizedBox claims full width from the parent (a Column with
    // CrossAxisAlignment.start otherwise leaves the Wrap with only its
    // content's intrinsic width), and Center positions the
    // intrinsic-sized Wrap in the middle. Wrap's own `alignment`
    // becomes a no-op once children fit on a single line, which is why
    // we wrap (no pun intended) the Wrap rather than relying on it.
    return SizedBox(
      width: double.infinity,
      child: Center(
        child: Wrap(
          alignment: alignment,
          spacing: AppTheme.spacing8,
          runSpacing: AppTheme.spacing8,
          children: chips,
        ),
      ),
    );
  }
}
