// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/settings_primitives.dart';
import '../../providers/auth_providers.dart';
import 'bug_report_repository.dart';

/// Settings row that opens the user's bug report threads.
///
/// Signed in: shows the unread-response count (hidden at zero) and pushes
/// the `/my-bug-reports` route. Signed out: dimmed, explains that sign-in
/// is needed, and pushes `/account`. Both settings screens (Meshtastic and
/// MeshCore) render this same row so the support path does not depend on
/// which radio is connected.
class MyBugReportsTile extends ConsumerWidget {
  const MyBugReportsTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final signedIn = ref.watch(currentUserProvider) != null;
    final chevron = Icon(Icons.chevron_right, color: context.textTertiary);

    if (!signedIn) {
      return Opacity(
        opacity: 0.5,
        child: SettingsTile(
          icon: Icons.forum_outlined,
          title: l10n.settingsTileMyBugReportsTitle,
          subtitle: l10n.settingsTileMyBugReportsNotSignedIn,
          trailing: chevron,
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.pushNamed(context, '/account');
          },
        ),
      );
    }

    final unread = ref
        .watch(bugReportUnreadCountProvider)
        .maybeWhen(data: (count) => count, orElse: () => 0);

    return SettingsTile(
      icon: Icons.forum_outlined,
      title: l10n.settingsTileMyBugReportsTitle,
      subtitle: l10n.settingsTileMyBugReportsSubtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (unread > 0)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing8,
                vertical: AppTheme.spacing3,
              ),
              margin: const EdgeInsets.only(right: AppTheme.spacing8),
              decoration: BoxDecoration(
                color: context.accentColor,
                borderRadius: BorderRadius.circular(AppTheme.radius10),
              ),
              child: Text(
                '$unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          chevron,
        ],
      ),
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.pushNamed(context, '/my-bug-reports');
      },
    );
  }
}
