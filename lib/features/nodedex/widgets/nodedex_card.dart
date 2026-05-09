// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Canonical NodeDex card container. Every NodeDex detail-screen card
// (Signal Records, Classification, Note, Discovery, Device Info, MRRP
// Services, Region History, Field Note, Radio Compatibility, etc.)
// MUST render through this widget so heading style, padding, and
// decoration stay identical across the screen.
//
// Heading row contains only the leading icon, title, and optional (i)
// help icon — never trailing actions. Action buttons or count chips go
// into [trailing], which renders below the heading right-aligned.

import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/section_header.dart';
import 'section_info_button.dart';

class NodeDexCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? helpKey;
  final Widget? trailing;
  final Widget child;

  const NodeDexCard({
    super.key,
    required this.title,
    required this.icon,
    this.helpKey,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(
          color: context.border.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(
            title: title,
            leadingIcon: icon,
            helpSheetBuilder: helpKey == null
                ? null
                : (ctx) => NodeDexHelpSheetBody(helpKey: helpKey!),
          ),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
              child: Align(alignment: Alignment.centerRight, child: trailing),
            ),
          child,
        ],
      ),
    );
  }
}
