// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Section Info Button — inline contextual help for NodeDex cards.
//
// Opens a bottom sheet with the section-specific help text from
// HelpContent.nodeDexSectionHelp. Shared across detail-screen cards
// so every card can surface consistent inline help.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/help/help_content.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';

class SectionInfoButton extends StatelessWidget {
  final String helpKey;

  const SectionInfoButton({super.key, required this.helpKey});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showHelp(context),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing4),
        child: Icon(
          Icons.info_outline,
          size: 14,
          color: context.textTertiary.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    final rawText = HelpContent.nodeDexSectionHelp[helpKey];
    if (rawText == null) return;

    final helpText = HelpContent.localizedNodeDexSectionHelp(
      helpKey,
      context.l10n,
    );

    HapticFeedback.selectionClick();
    AppBottomSheet.show<void>(
      context: context,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppTheme.spacing24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: context.accentColor,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    _titleForKey(helpKey, context),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              helpText,
              style: TextStyle(
                fontSize: 14,
                color: context.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _titleForKey(String key, BuildContext context) {
    final l10n = context.l10n;
    switch (key) {
      case 'sigil':
        return l10n.nodedexHelpSigil;
      case 'trait':
        return l10n.nodedexHelpPersonalityTrait;
      case 'discovery':
        return l10n.nodedexHelpDiscoveryStats;
      case 'signal':
        return l10n.nodedexHelpSignalRecords;
      case 'social_tag':
        return l10n.nodedexHelpClassification;
      case 'note':
        return l10n.nodedexHelpNote;
      case 'regions':
        return l10n.nodedexHelpRegionHistory;
      case 'encounters':
        return l10n.nodedexHelpRecentEncounters;
      case 'activity_timeline':
        return l10n.nodedexHelpActivityTimeline;
      case 'constellation':
        return l10n.nodedexHelpConstellationLinks;
      case 'device':
        return l10n.nodedexHelpDeviceInfo;
      default:
        return l10n.nodedexHelpInfoDefault;
    }
  }
}
