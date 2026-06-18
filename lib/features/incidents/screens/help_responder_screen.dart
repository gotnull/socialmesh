// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Live responder-side screen for a single trusted help request.
///
/// Before responding it shows the inbound alert (Acknowledge / Respond);
/// once responding it shows the full responder view (status / messages /
/// leave). Reads local persisted, trusted state only. No notifications, no
/// location escalation. "Open Map" is intentionally deferred (the map has no
/// incident deep-link yet) -- documented follow-up.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/section_header.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/incident_help_providers.dart';
import '../models/incident_mode_models.dart';
import '../providers/mesh_incident_providers.dart';
import '../widgets/help_mode/help_inbound_alert_card.dart';
import '../widgets/help_mode/help_responder_view.dart';
import '../widgets/help_mode/incident_messages_view.dart';
import '../widgets/help_mode/incident_timeline_view.dart';

class HelpResponderScreen extends ConsumerStatefulWidget {
  final int incidentId;

  const HelpResponderScreen({super.key, required this.incidentId});

  @override
  ConsumerState<HelpResponderScreen> createState() =>
      _HelpResponderScreenState();
}

class _HelpResponderScreenState extends ConsumerState<HelpResponderScreen>
    with LifecycleSafeMixin<HelpResponderScreen> {
  void _refresh() =>
      ref.invalidate(incidentModeProjectionProvider(widget.incidentId));

  Future<void> _onRespond() async {
    await ref
        .read(incidentHelpControllerProvider)
        .acceptHelpRequest(incidentId: widget.incidentId);
    if (!mounted) return;
    _refresh();
  }

  Future<void> _onAcknowledge() async {
    await ref
        .read(incidentHelpControllerProvider)
        .acknowledge(incidentId: widget.incidentId);
    if (!mounted) return;
    _refresh();
  }

  Future<void> _onUpdateStatus(IncidentQuickUpdate code) async {
    await ref
        .read(incidentHelpControllerProvider)
        .sendResponderStatus(incidentId: widget.incidentId, code: code);
    if (!mounted) return;
    _refresh();
  }

  Future<void> _onLeave() async {
    await ref
        .read(incidentHelpControllerProvider)
        .leaveResponse(incidentId: widget.incidentId);
    if (!mounted) return;
    _refresh();
  }

  void _onMessages(IncidentProjection projection) {
    final messages = [
      for (final e in projection.timeline)
        if (e.message != null) e.message!,
    ];
    AppBottomSheet.showScrollable<void>(
      context: context,
      title: context.l10n.helpModeMessages,
      builder: (controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: IncidentMessagesView(
          messages: messages,
          requesterNodeId: projection.originNodeId,
        ),
      ),
    );
  }

  String _requesterName(int nodeId) {
    final node = ref.read(nodesProvider)[nodeId];
    final longName = node?.longName ?? '';
    if (longName.isNotEmpty) return longName;
    final shortName = node?.shortName ?? '';
    if (shortName.isNotEmpty) return shortName;
    return '!${nodeId.toRadixString(16)}';
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(incidentModeProjectionProvider(widget.incidentId));
    return GlassScaffold(
      title: context.l10n.helpModeRespondingTitle,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          sliver: SliverToBoxAdapter(
            child: async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppTheme.spacing32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                context.l10n.helpModeTimelineEmpty,
                style: context.hintStyle,
              ),
              data: (projection) => _body(context, projection),
            ),
          ),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, IncidentProjection? projection) {
    final l10n = context.l10n;
    if (projection == null) {
      return Text(l10n.helpModeTimelineEmpty, style: context.hintStyle);
    }
    final localNode = ref.read(myNodeNumProvider) ?? 0;
    final isResponder = projection.responders.any((p) => p.nodeId == localNode);

    if (isResponder) {
      return HelpResponderView(
        projection: projection,
        onUpdateStatus: _onUpdateStatus,
        onMessages: () => _onMessages(projection),
        onLeave: _onLeave,
        now: DateTime.now(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HelpInboundAlertCard(
          requesterName: _requesterName(projection.originNodeId),
          onAcknowledge: _onAcknowledge,
          onRespond: _onRespond,
          // Open Map deep-link to the requester is a documented follow-up
          // (the map has no incident context yet); disabled for now.
          onOpenMap: null,
          onDismiss: () => safeNavigatorPop(),
        ),
        const SizedBox(height: AppTheme.spacing20),
        SectionTitle(title: l10n.helpModeActivityTitle),
        const SizedBox(height: AppTheme.spacing8),
        IncidentTimelineView(events: projection.timeline),
      ],
    );
  }
}
