// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Board identity card shown above the terminal output. Replaces the
// older ASCII box-drawing header with a premium glass card that
// matches NodeDex / Aether / Signals styling.

import 'package:flutter/material.dart';

import '../../../core/theme.dart';

class TerminalBoardHeader extends StatelessWidget {
  const TerminalBoardHeader({
    super.key,
    required this.boardTitle,
    required this.sysopName,
    this.tagline,
  });

  final String boardTitle;
  final String sysopName;
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    final accent = context.accentColor;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing12,
        AppTheme.spacing16,
        AppTheme.spacing12,
      ),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacing8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
                ),
                child: Icon(
                  Icons.terminal,
                  size: AppTheme.spacing20,
                  color: accent,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      boardTitle,
                      style: context.titleStyle?.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.person_outline,
                            size: AppTheme.spacing12,
                            color: context.textTertiary,
                          ),
                        ),
                        const SizedBox(width: AppTheme.spacing4),
                        Expanded(
                          child: Text(
                            sysopName,
                            style: context.bodySmallStyle?.copyWith(
                              color: context.textTertiary,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tagline != null && tagline!.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacing12),
            Text(
              tagline!,
              style: context.bodyStyle?.copyWith(
                color: context.textSecondary,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
