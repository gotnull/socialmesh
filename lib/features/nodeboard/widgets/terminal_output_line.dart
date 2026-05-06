// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Terminal output line rendered in the standard SocialMesh theme.
// Monospace preserves the BBS feel; colours come from context.*.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/logging.dart';
import '../../../core/theme.dart';
import '../providers/nodeboard_providers.dart';

// lint-allow: hardcoded-string
const _kTerminalFontFamily = 'JetBrainsMono';

class TerminalOutputLineWidget extends StatelessWidget {
  const TerminalOutputLineWidget({
    super.key,
    required this.line,
    this.onTapCommand,
  });

  final TerminalOutputLine line;
  final ValueChanged<String>? onTapCommand;

  @override
  Widget build(BuildContext context) {
    final baseStyle = _styleFor(context, line.style);
    final isTappable = line.tapCommand != null && onTapCommand != null;

    final content = RichText(
      text: TextSpan(
        style: baseStyle,
        children: [
          if (line.index != null)
            TextSpan(
              text: '[${line.index}] ',
              style: baseStyle.copyWith(
                color: context.accentColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          TextSpan(text: line.text),
        ],
      ),
    );

    if (!isTappable) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing2,
        ),
        child: content,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          AppLogging.nodeBoard(
            'Terminal: tapped output line cmd=${line.tapCommand}',
          );
          HapticFeedback.lightImpact();
          onTapCommand!(line.tapCommand!);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing10,
          ),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: context.accentColor.withValues(alpha: 0.35),
                width: 2,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(child: content),
              Icon(
                Icons.chevron_right,
                size: AppTheme.spacing16,
                color: context.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  TextStyle _styleFor(BuildContext context, TerminalLineStyle s) {
    const fs = 14.0;
    const lh = 1.45;
    return switch (s) {
      TerminalLineStyle.normal => TextStyle(
        fontFamily: _kTerminalFontFamily,
        fontSize: fs,
        height: lh,
        color: context.textPrimary,
      ),
      TerminalLineStyle.header => TextStyle(
        fontFamily: _kTerminalFontFamily,
        fontSize: fs,
        height: lh,
        color: context.accentColor,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
      TerminalLineStyle.accent => TextStyle(
        fontFamily: _kTerminalFontFamily,
        fontSize: fs,
        height: lh,
        color: context.accentColor,
      ),
      TerminalLineStyle.dim => TextStyle(
        fontFamily: _kTerminalFontFamily,
        fontSize: fs,
        height: lh,
        color: context.textTertiary,
      ),
      TerminalLineStyle.error => TextStyle(
        fontFamily: _kTerminalFontFamily,
        fontSize: fs,
        height: lh,
        color: SemanticColors.error,
      ),
      TerminalLineStyle.system => TextStyle(
        fontFamily: _kTerminalFontFamily,
        fontSize: fs,
        height: lh,
        color: context.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    };
  }
}
