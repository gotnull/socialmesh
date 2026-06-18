// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Responder inbox: lists active trusted help requests and opens the responder
/// screen for one. Reads [activeHelpRequestsProvider] (already gated by the
/// Incident Mode flags and filtered to non-terminal help_request workflows).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../models/incident_mode_models.dart';
import '../providers/mesh_incident_providers.dart';
import 'help_circle_screen.dart';
import 'help_responder_screen.dart';

class HelpResponderInboxScreen extends ConsumerWidget {
  const HelpResponderInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(activeHelpRequestsProvider);
    return GlassScaffold(
      title: context.l10n.helpModeInboxTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.health_and_safety_outlined),
          tooltip: context.l10n.helpModeCircleManage,
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const HelpCircleScreen()),
          ),
        ),
      ],
      slivers: [
        async.when(
          loading: () => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(
                context.l10n.helpModeInboxEmpty,
                style: context.hintStyle,
              ),
            ),
          ),
          data: (requests) {
            if (requests.isEmpty) {
              return SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    context.l10n.helpModeInboxEmpty,
                    style: context.hintStyle,
                  ),
                ),
              );
            }
            return SliverPadding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              sliver: SliverList.separated(
                itemCount: requests.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppTheme.spacing8),
                itemBuilder: (context, i) =>
                    _HelpRequestTile(projection: requests[i]),
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HelpRequestTile extends StatelessWidget {
  final IncidentProjection projection;

  const _HelpRequestTile({required this.projection});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(AppTheme.radius12),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) =>
                HelpResponderScreen(incidentId: projection.incidentId),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            children: [
              Icon(Icons.emergency_share, color: AppTheme.warningYellow),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.helpModeBannerActiveTitle,
                      style: context.titleSmallStyle,
                    ),
                    const SizedBox(height: AppTheme.spacing2),
                    Text(
                      projection.responderCount > 0
                          ? l10n.helpModeResponderCount(
                              projection.responderCount,
                            )
                          : l10n.helpModeNoResponders,
                      style: context.captionMutedStyle,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
