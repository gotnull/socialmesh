// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Global in-app banner for active trusted Help Requests.
///
/// Watches [activeHelpRequestsProvider] (which is empty unless both Incident
/// Mode flags are on, and already excludes resolved/cancelled/expired and all
/// hazard_report workflows). Renders nothing when there are no active requests,
/// so it is safe to place unconditionally in the shell. Tapping opens the
/// responder inbox.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/status_banner.dart';
import '../../models/incident_mode_models.dart';
import '../../providers/mesh_incident_providers.dart';
import '../../screens/help_responder_inbox_screen.dart';

class IncidentHelpBanner extends ConsumerWidget {
  /// When true, the banner consumes the top safe-area inset (status bar /
  /// dynamic island) above itself. The shell sets this when the help banner is
  /// the topmost visible banner (i.e. the reconnection banner is not showing),
  /// so the banner sits below the status bar instead of underlapping it. When
  /// the reconnection banner is visible it already owns the inset, so this is
  /// false and the help banner stacks directly beneath it.
  final bool applyTopInset;

  const IncidentHelpBanner({super.key, this.applyTopInset = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref
        .watch(activeHelpRequestsProvider)
        .maybeWhen(
          data: (list) => list,
          orElse: () => const <IncidentProjection>[],
        );
    if (active.isEmpty) return const SizedBox.shrink();

    final banner = StatusBanner.warning(
      title: context.l10n.helpModeBannerActiveTitle,
      subtitle: context.l10n.helpModeActiveCount(active.length),
      icon: Icons.emergency_share,
      // Match the horizontal inset of the node cards so the banner does not
      // kiss the screen edges.
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const HelpResponderInboxScreen(),
        ),
      ),
    );

    if (!applyTopInset) return banner;
    // Fall back to viewPadding if padding.top was consumed to 0 by an ancestor,
    // plus a small breathing gap so the banner clears the dynamic island.
    final mq = MediaQuery.of(context);
    final safeTop = mq.padding.top > 0 ? mq.padding.top : mq.viewPadding.top;
    return Padding(
      padding: EdgeInsets.only(top: safeTop + AppTheme.spacing8),
      child: banner,
    );
  }
}
