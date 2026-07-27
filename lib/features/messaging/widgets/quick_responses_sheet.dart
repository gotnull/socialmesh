// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../models/canned_response.dart';
import '../../settings/canned_responses_screen.dart';

/// Quick Responses bottom sheet: the alert-bell action plus the user's
/// canned replies.
///
/// Replies render as full-width list rows so every reply is a distinct,
/// clearly tappable control and long labels wrap instead of truncating.
/// A fixed multi-column grid is deliberately avoided here: it forces
/// unrelated replies side by side and ellipsizes anything longer than
/// half the sheet width.
class QuickResponsesSheet extends StatelessWidget {
  final List<CannedResponse> responses;
  final void Function(String text) onSelect;

  /// Sends the alert-bell quick message: a bell-emoji text whose wire
  /// payload carries ASCII BEL (0x07) so buzzer-equipped radios ring.
  final VoidCallback onSendAlertBell;

  const QuickResponsesSheet({
    super.key,
    required this.responses,
    required this.onSelect,
    required this.onSendAlertBell,
  });

  @override
  Widget build(BuildContext context) {
    // A single shrink-wrapped scrollable holds every row: with large text
    // scales even the fixed header + alert-bell rows can exceed the height
    // budget, and pinning them beside a Flexible list overflows the column.
    // One scrollable keeps the sheet compact when content fits and scrolls
    // when it does not.
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      child: ListView(
        shrinkWrap: true,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing20,
              0,
              AppTheme.spacing20,
              AppTheme.spacing8,
            ),
            child: Row(
              children: [
                Container(
                  width: AppTheme.spacing32,
                  height: AppTheme.spacing32,
                  decoration: BoxDecoration(
                    color: context.accentColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppTheme.radius8),
                  ),
                  child: Icon(Icons.bolt, color: context.accentColor, size: 18),
                ),
                SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Text(
                    context.l10n.messagingQuickResponses,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(color: context.border, height: 1),
          // Alert bell: one tap sends a ring, like the official app's
          // quick-message bell.
          Semantics(
            button: true,
            label: context.l10n.messagingAlertBellTooltip,
            hint: context.l10n.messagingAlertBellSubtitle,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: onSendAlertBell,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing20,
                  vertical: AppTheme.spacing12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.messagingAlertBellTooltip,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: context.textPrimary,
                            ),
                          ),
                          Text(
                            context.l10n.messagingAlertBellSubtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: AppTheme.spacing12),
                    Container(
                      width: AppTheme.spacing32,
                      height: AppTheme.spacing32,
                      decoration: BoxDecoration(
                        color: context.accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                      child: Icon(
                        Icons.notifications_active,
                        color: context.accentColor,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Divider(color: context.border, height: 1),
          // Responses: full-width rows, one per reply.
          if (responses.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing32),
              child: Text(
                context.l10n.messagingNoQuickResponsesConfigured,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.textSecondary),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < responses.length; i++) ...[
                    if (i > 0) SizedBox(height: AppTheme.spacing8),
                    _QuickResponseTile(
                      response: responses[i],
                      onTap: () => onSelect(responses[i].text),
                    ),
                  ],
                ],
              ),
            ),
          // Footer with settings link
          Divider(color: context.border, height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing12,
            ),
            child: Semantics(
              button: true,
              child: GestureDetector(
                onTap: () {
                  // Capture navigator before pop since context becomes
                  // invalid after
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  navigator.push(
                    MaterialPageRoute(
                      builder: (context) => const CannedResponsesScreen(),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.settings,
                      size: 16,
                      color: context.textSecondary.withValues(alpha: 0.8),
                    ),
                    SizedBox(width: AppTheme.spacing8),
                    Flexible(
                      child: Text(
                        context.l10n.messagingConfigureQuickResponses,
                        style: TextStyle(
                          color: context.textSecondary.withValues(alpha: 0.8),
                          fontSize: 13,
                        ),
                      ),
                    ),
                    SizedBox(width: AppTheme.spacing4),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: context.textSecondary.withValues(alpha: 0.6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _QuickResponseTile extends StatelessWidget {
  final CannedResponse response;
  final VoidCallback onTap;

  const _QuickResponseTile({required this.response, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.messagingQuickResponseSemantics(response.text),
      excludeSemantics: true,
      child: Material(
        color: context.background,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing12,
              vertical: AppTheme.spacing12,
            ),
            // Reply text wraps freely - quick replies must never be
            // silently truncated with an ellipsis.
            child: Text(
              response.text,
              style: TextStyle(
                color: context.textPrimary,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
