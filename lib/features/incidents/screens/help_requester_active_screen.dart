// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Live requester-side Help Mode screen.
///
/// Watches the projected incident from the store and wires the
/// [HelpRequesterActiveView] actions to the outbound controller. "I'm safe"
/// and "Cancel request" route through distinct confirmation sheets. Reads
/// local persisted state only -- no notifications, no location escalation.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../providers/incident_help_providers.dart';
import '../models/incident_mode_models.dart';
import '../providers/mesh_incident_providers.dart';
import '../widgets/help_mode/help_confirm_sheets.dart';
import '../widgets/help_mode/help_requester_active_view.dart';
import '../widgets/help_mode/incident_messages_view.dart';

class HelpRequesterActiveScreen extends ConsumerStatefulWidget {
  final int incidentId;

  const HelpRequesterActiveScreen({super.key, required this.incidentId});

  @override
  ConsumerState<HelpRequesterActiveScreen> createState() =>
      _HelpRequesterActiveScreenState();
}

class _HelpRequesterActiveScreenState
    extends ConsumerState<HelpRequesterActiveScreen>
    with LifecycleSafeMixin<HelpRequesterActiveScreen> {
  void _refresh() =>
      ref.invalidate(incidentModeProjectionProvider(widget.incidentId));

  Future<void> _onUpdateStatus(IncidentQuickUpdate code) async {
    await ref
        .read(incidentHelpControllerProvider)
        .sendRequesterStatus(incidentId: widget.incidentId, code: code);
    if (!mounted) return;
    _refresh();
  }

  Future<void> _onImSafe() async {
    final confirmed = await showResolveConfirmSheet(context);
    if (!mounted || !confirmed) return;
    await ref
        .read(incidentHelpControllerProvider)
        .resolveSafe(incidentId: widget.incidentId);
    if (!mounted) return;
    _refresh();
  }

  Future<void> _onCancel() async {
    final confirmed = await showCancelConfirmSheet(context);
    if (!mounted || !confirmed) return;
    await ref
        .read(incidentHelpControllerProvider)
        .cancelRequest(incidentId: widget.incidentId);
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(incidentModeProjectionProvider(widget.incidentId));
    return GlassScaffold(
      title: context.l10n.helpModeActiveTitle,
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
              data: (projection) {
                if (projection == null) {
                  return Text(
                    context.l10n.helpModeTimelineEmpty,
                    style: context.hintStyle,
                  );
                }
                return HelpRequesterActiveView(
                  projection: projection,
                  onUpdateStatus: _onUpdateStatus,
                  onMessages: () => _onMessages(projection),
                  onImSafe: _onImSafe,
                  onCancel: _onCancel,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
