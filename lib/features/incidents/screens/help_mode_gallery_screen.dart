// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Help Mode fixture gallery: a review surface that renders every Incident
/// Mode UI state from fixture projections. NOT connected to the mesh, the
/// store, or notifications. For UX review and widget testing only.
///
/// Plan: docs/engineering/INCIDENT_MODE_SIP_MRRP_PLAN.md (PR-6 fixture UI)
library;

import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../utils/snackbar.dart';
import '../fixtures/incident_mode_fixtures.dart';
import '../widgets/help_mode/help_inbound_alert_card.dart';
import '../widgets/help_mode/help_request_affordance.dart';
import '../widgets/help_mode/help_request_create_sheet.dart';
import '../widgets/help_mode/help_requester_active_view.dart';
import '../widgets/help_mode/help_responder_view.dart';
import '../widgets/help_mode/incident_global_banner.dart';
import '../widgets/help_mode/incident_messages_view.dart';

class HelpModeGalleryScreen extends StatelessWidget {
  const HelpModeGalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GlassScaffold(
      title: l10n.helpModeGalleryTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              StatusBanner.info(
                title: l10n.helpModeGalleryTitle,
                subtitle: l10n.helpModeGallerySubtitle,
                icon: Icons.science_outlined,
              ),

              _section(
                context,
                'Map affordance', // lint-allow: hardcoded-string
                SizedBox(
                  height: 140,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.background,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius12,
                            ),
                            border: Border.all(color: context.border),
                          ),
                        ),
                      ),
                      const HelpRequestAffordance(enabledOverride: true),
                    ],
                  ),
                ),
              ),

              _section(
                context,
                'Create', // lint-allow: hardcoded-string
                OutlinedButton.icon(
                  onPressed: () => showHelpRequestCreateSheet(
                    context,
                    onSubmit: (_) =>
                        showInfoSnackBar(context, l10n.helpModeGallerySubtitle),
                  ),
                  icon: const Icon(Icons.emergency_share),
                  label: Text(l10n.helpModeNeedHelp),
                ),
              ),

              _section(
                context,
                'Broadcasting', // lint-allow: hardcoded-string
                HelpRequesterActiveView(
                  projection: IncidentModeFixtures.broadcasting(),
                ),
              ),
              _section(
                context,
                'Active - no responder', // lint-allow: hardcoded-string
                HelpRequesterActiveView(
                  projection: IncidentModeFixtures.activeNoResponder(),
                ),
              ),
              _section(
                context,
                'Active - with responder', // lint-allow: hardcoded-string
                HelpRequesterActiveView(
                  projection: IncidentModeFixtures.activeWithResponder(),
                ),
              ),
              _section(
                context,
                'Responder en route', // lint-allow: hardcoded-string
                HelpRequesterActiveView(
                  projection: IncidentModeFixtures.responderEnRoute(),
                ),
              ),
              _section(
                context,
                'Responder arrived', // lint-allow: hardcoded-string
                HelpRequesterActiveView(
                  projection: IncidentModeFixtures.responderArrived(),
                ),
              ),

              _section(
                context,
                'Inbound alert', // lint-allow: hardcoded-string
                HelpInboundAlertCard(
                  requesterName: IncidentModeFixtures.requesterName,
                  onAcknowledge: () => _demo(context),
                  onRespond: () => _demo(context),
                  onOpenMap: () => _demo(context),
                  onDismiss: () => _demo(context),
                ),
              ),

              _section(
                context,
                'Responder view', // lint-allow: hardcoded-string
                HelpResponderView(
                  projection: IncidentModeFixtures.responderArrived(),
                ),
              ),

              _section(
                context,
                'Messages', // lint-allow: hardcoded-string
                IncidentMessagesView(
                  messages: IncidentModeFixtures.messages(),
                  requesterNodeId: IncidentModeFixtures.requesterNode,
                ),
              ),

              _section(
                context,
                'Global banner', // lint-allow: hardcoded-string
                IncidentGlobalBanner(
                  projection: IncidentModeFixtures.activeWithResponder(),
                  onView: () => _demo(context),
                ),
              ),

              _section(
                context,
                'Resolved', // lint-allow: hardcoded-string
                HelpRequesterActiveView(
                  projection: IncidentModeFixtures.resolvedSafe(),
                ),
              ),
              _section(
                context,
                'Cancelled', // lint-allow: hardcoded-string
                HelpRequesterActiveView(
                  projection: IncidentModeFixtures.cancelled(),
                ),
              ),
              _section(
                context,
                'Expired', // lint-allow: hardcoded-string
                HelpRequesterActiveView(
                  projection: IncidentModeFixtures.expired(),
                ),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  void _demo(BuildContext context) =>
      showInfoSnackBar(context, context.l10n.helpModeGallerySubtitle);

  Widget _section(BuildContext context, String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.spacing24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Internal preview label (dev gallery only; not user-facing copy).
          SectionTitle(title: label), // lint-allow: hardcoded-string
          const SizedBox(height: AppTheme.spacing8),
          child,
        ],
      ),
    );
  }
}
