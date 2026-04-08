// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// Expandable section with a toggle for showing expert / diagnostic details.
///
/// Used across SIP and MRRP UX to implement progressive disclosure:
/// Level 1 (basic) is always visible; tapping reveals Level 3 (expert) content.
class ExpertDetailsExpander extends StatefulWidget {
  /// Label for the toggle row (e.g., "Technical details").
  final String label;

  /// Icon next to the toggle label.
  final IconData icon;

  /// Whether the section starts expanded.
  final bool initiallyExpanded;

  /// Expert-level content built when expanded.
  final WidgetBuilder expandedBuilder;

  const ExpertDetailsExpander({
    super.key,
    required this.label,
    this.icon = Icons.science_outlined,
    this.initiallyExpanded = false,
    required this.expandedBuilder,
  });

  @override
  State<ExpertDetailsExpander> createState() => _ExpertDetailsExpanderState();
}

class _ExpertDetailsExpanderState extends State<ExpertDetailsExpander> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _isExpanded = !_isExpanded);
          },
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing10,
            ),
            child: Row(
              children: [
                Icon(widget.icon, size: 14, color: context.textTertiary),
                const SizedBox(width: AppTheme.spacing6),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(fontSize: 12, color: context.textTertiary),
                  ),
                ),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: context.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _isExpanded
              ? widget.expandedBuilder(context)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
