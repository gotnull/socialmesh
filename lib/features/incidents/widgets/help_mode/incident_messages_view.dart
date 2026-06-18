// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Incident-scoped messages view (fixture / preview).
///
/// Renders messages bound to a single incident. The composer is a read-only
/// placeholder in this fixture surface -- no send path is wired (that is PR-7).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../models/incident_mode_models.dart';

class IncidentMessagesView extends StatelessWidget {
  final List<IncidentMessage> messages;
  final int requesterNodeId;

  const IncidentMessagesView({
    super.key,
    required this.messages,
    required this.requesterNodeId,
  });

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat.Hm();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (messages.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Text(
              context.l10n.helpModeMessagesEmpty,
              style: context.hintStyle,
            ),
          )
        else
          for (final m in messages)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
              child: Align(
                alignment: m.senderNodeId == requesterNodeId
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 280),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing12,
                    vertical: AppTheme.spacing8,
                  ),
                  decoration: BoxDecoration(
                    color: context.card,
                    borderRadius: BorderRadius.circular(AppTheme.radius12),
                    border: Border.all(color: context.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.text, style: context.bodySecondaryStyle),
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        timeFmt.format(m.timestamp.toLocal()),
                        style: context.captionMutedStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        const SizedBox(height: AppTheme.spacing12),
        // Fixture composer: read-only placeholder, no send path wired (PR-7).
        TextField(
          readOnly: true,
          maxLength: 160,
          decoration: InputDecoration(
            hintText: context.l10n.helpModeMessageHint,
            counterText: '',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius8),
            ),
            filled: true,
            fillColor: context.background,
            prefixIcon: Icon(
              Icons.chat_bubble_outline,
              color: context.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
