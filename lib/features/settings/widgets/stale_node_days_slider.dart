// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../services/nodes/stale_node_cleanup.dart';

/// The stale-node age picker: a [label] above a one-day-step slider from
/// [kStaleNodeMinDays] to [kStaleNodeMaxDays], with the range ends shown
/// either side.
class StaleNodeDaysSlider extends StatelessWidget {
  final String label;
  final int days;
  final ValueChanged<int> onChanged;

  const StaleNodeDaysSlider({
    super.key,
    required this.label,
    required this.days,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final rangeStyle = textTheme.bodySmall?.copyWith(
      color: context.textSecondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodyMedium?.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            Text(kStaleNodeMinDays.toString(), style: rangeStyle),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: context.accentColor,
                  inactiveTrackColor: context.accentColor.withValues(
                    alpha: 0.2,
                  ),
                  thumbColor: context.accentColor,
                  overlayColor: context.accentColor.withValues(alpha: 0.2),
                ),
                child: Semantics(
                  label: context.l10n.staleNodesDaysSliderLabel,
                  child: Slider(
                    value: days
                        .clamp(kStaleNodeMinDays, kStaleNodeMaxDays)
                        .toDouble(),
                    min: kStaleNodeMinDays.toDouble(),
                    max: kStaleNodeMaxDays.toDouble(),
                    divisions: kStaleNodeMaxDays - kStaleNodeMinDays,
                    semanticFormatterCallback: (value) =>
                        context.l10n.staleNodesDaysValue(value.round()),
                    onChanged: (value) {
                      final next = value.round();
                      if (next == days) return;
                      HapticFeedback.selectionClick();
                      onChanged(next);
                    },
                  ),
                ),
              ),
            ),
            Text(kStaleNodeMaxDays.toString(), style: rangeStyle),
          ],
        ),
      ],
    );
  }
}
