import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../services/signal_service.dart';

/// TTL selector widget for signal creation.
///
/// Shows available TTL options as selectable chips.
class TTLSelector extends StatelessWidget {
  const TTLSelector({
    super.key,
    required this.selectedMinutes,
    required this.onChanged,
  });

  final int selectedMinutes;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: SignalTTL.options.map((minutes) {
        final isSelected = minutes == selectedMinutes;

        return BouncyTap(
          onTap: onChanged != null ? () => onChanged!(minutes) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? context.accentColor.withValues(alpha: 0.15)
                  : context.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? context.accentColor
                    : context.border.withValues(alpha: 0.5),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Text(
              SignalTTL.label(minutes),
              style: TextStyle(
                color: isSelected ? context.accentColor : context.textSecondary,
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
