// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Horizontally scrollable bar of context-aware terminal action chips.
// Each chip maps 1:1 to a typed command — tapping a chip executes the
// exact same pipeline as typing the command.
//
// Styled in Socialmesh's canonical chip pattern: accent @ 12% fill,
// accent @ 50% border, icon + text in accent colour. Matches the
// chip/filter style used across Signals, NodeDex, and Aether.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../providers/nodeboard_providers.dart';

class TerminalChipBar extends StatelessWidget {
  final List<TerminalChipAction> chips;
  final ValueChanged<String> onTapCommand;

  const TerminalChipBar({
    super.key,
    required this.chips,
    required this.onTapCommand,
  });

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing8,
      ),
      decoration: BoxDecoration(
        color: context.background,
        border: Border(
          top: BorderSide(color: context.border.withValues(alpha: 0.4)),
        ),
      ),
      child: SizedBox(
        height: AppTheme.spacing40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          itemCount: chips.length,
          separatorBuilder: (_, _) => const SizedBox(width: AppTheme.spacing8),
          itemBuilder: (context, i) => _TerminalChip(
            action: chips[i],
            onTap: () {
              AppLogging.nodeBoard(
                'Terminal: chip tapped label=${chips[i].label} cmd=${chips[i].command}',
              );
              HapticFeedback.lightImpact();
              onTapCommand(chips[i].command);
            },
          ),
        ),
      ),
    );
  }
}

class _TerminalChip extends StatelessWidget {
  final TerminalChipAction action;
  final VoidCallback onTap;

  const _TerminalChip({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    return Center(
      child: Material(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radius20),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing14,
              vertical: AppTheme.spacing6,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.radius20),
              border: Border.all(
                color: accent.withValues(alpha: 0.5),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (action.icon != null) ...[
                  Icon(action.icon, size: AppTheme.spacing14, color: accent),
                  const SizedBox(width: AppTheme.spacing6),
                ],
                Text(
                  action.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: accent,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
