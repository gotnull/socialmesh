// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Retro segmented pip bar used for visible pet stats. 10 segments.
/// Matches the Tamagotchi hardware metaphor — a small row of ticks that
/// fill as the stat rises.
class PetStatPipRow extends StatelessWidget {
  final String label;
  final int value;
  final int maxValue;
  final IconData icon;
  final Color color;

  const PetStatPipRow({
    super.key,
    required this.label,
    required this.value,
    required this.maxValue,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0, maxValue);
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: AppTheme.spacing10),
        SizedBox(
          width: 72,
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textTertiary,
              letterSpacing: 1.0,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ),
        const SizedBox(width: AppTheme.spacing8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const segments = 10;
              final gap = 3.0;
              final segmentWidth =
                  (constraints.maxWidth - gap * (segments - 1)) / segments;
              return Row(
                children: List.generate(segments, (i) {
                  final filled = i < clamped;
                  return Padding(
                    padding: EdgeInsets.only(
                      right: i == segments - 1 ? 0 : gap,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      width: segmentWidth,
                      height: 10,
                      decoration: BoxDecoration(
                        color: filled
                            ? color.withValues(alpha: 0.9)
                            : color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppTheme.radius4),
                        border: Border.all(
                          color: color.withValues(alpha: filled ? 0.4 : 0.2),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
        const SizedBox(width: AppTheme.spacing10),
        SizedBox(
          width: 28,
          child: Text(
            '$clamped',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
              fontFamily: AppTheme.fontFamily,
            ),
          ),
        ),
      ],
    );
  }
}
