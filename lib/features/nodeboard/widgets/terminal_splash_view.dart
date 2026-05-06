// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Renders a board's ANSI/ASCII splash as monospace text inside a
// SocialMesh-themed card. Input is sanitized by AnsiSanitizer so
// escape sequences and control bytes cannot reach Flutter rendering.

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../services/ansi_sanitizer.dart';

class TerminalSplashView extends StatelessWidget {
  final String splash;

  const TerminalSplashView({super.key, required this.splash});

  @override
  Widget build(BuildContext context) {
    final lines = AnsiSanitizer.sanitizeLines(splash);
    if (lines.isEmpty || (lines.length == 1 && lines.first.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        0,
        AppTheme.spacing16,
        AppTheme.spacing12,
      ),
      padding: const EdgeInsets.all(AppTheme.spacing14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Text(
              line.isEmpty ? ' ' : line,
              style: TextStyle(
                fontFamily: 'JetBrainsMono', // lint-allow: hardcoded-string
                fontSize: 12,
                height: 1.3,
                color: context.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
