// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Calendar-day separator for the Meshtastic chat screen. Message bubbles
// show time-of-day only, so without a separator two messages from
// different days read as minutes apart. The chat screen decides which
// rows start a new day and wraps this widget into the same list slot as
// the bubble (index parity with the scroll/restore helpers is
// load-bearing there).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../utils/time_format.dart';

/// Whether a date separator belongs above the row carrying [current],
/// given the [previous] row's timestamp (`null` for the first loaded row,
/// which always gets a separator so the window's earliest day is named).
///
/// Days are compared on the phone's local calendar, so a conversation
/// spanning midnight splits exactly at the local day boundary.
bool showsMessageDateSeparator(DateTime? previous, DateTime current) {
  if (previous == null) return true;
  final a = previous.toLocal();
  final b = current.toLocal();
  return a.year != b.year || a.month != b.month || a.day != b.day;
}

/// Calendar-relative label for a day separator: "Today", "Yesterday", the
/// weekday name inside the trailing week, then a full date honouring the
/// user's date-order preference. [now] is injectable for deterministic
/// tests; it defaults to the current wall clock.
String messageDateSeparatorLabel(
  BuildContext context,
  DateTime timestamp, {
  DateTime? now,
}) {
  final local = timestamp.toLocal();
  final reference = (now ?? DateTime.now()).toLocal();
  final today = DateTime(reference.year, reference.month, reference.day);
  final messageDay = DateTime(local.year, local.month, local.day);
  final dayDelta = today.difference(messageDay).inDays;

  if (dayDelta == 0) return context.l10n.timelineToday;
  if (dayDelta == 1) return context.l10n.timelineYesterday;
  if (dayDelta > 1 && dayDelta < 7) {
    return DateFormat(
      'EEEE',
      Localizations.localeOf(context).toString(),
    ).format(local);
  }
  return AppTimeFormat.fullDate(context).format(local);
}

class MessageDateSeparator extends StatelessWidget {
  final DateTime timestamp;

  const MessageDateSeparator({super.key, required this.timestamp});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: AppTheme.spacing4,
          ),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
          ),
          child: Text(
            messageDateSeparatorLabel(context, timestamp),
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
