// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../theme.dart';
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
    required this.icon,
    required this.color,
  });

  final T value;
  final String label;
  final IconData icon;
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
  /// in the app currently wants.
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && onChanged != null;
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
          children: [
            for (final option in options)
              StatusFilterChip(
                label: option.label,
                icon: option.icon,
                color: option.color,
                isSelected: option.value == value,
                onTap: canTap ? () => onChanged!(option.value) : () {},
              ),
          ],
        ),
      ),
    );
  }
}
