// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Help Circle management screen: view and remove the peers you trust for Help
/// Mode. Adding is done from the node list / node detail long-press action
/// ("Add to Help Circle"). Local-only; no cloud.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/qr_share_sheet.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../providers/app_providers.dart';
import '../providers/incident_help_trust_provider.dart';

class HelpCircleScreen extends ConsumerWidget {
  const HelpCircleScreen({super.key});

  /// Shows the user's own Help Circle invite as a QR code, so a trusted peer
  /// can scan it to add the user to THEIR Help Circle (trust is directional).
  /// Encodes the same `socialmesh://help-circle/{base64}` payload the scanner
  /// and deep-link parser consume. No keys or sensitive data, just identity.
  void _shareMyCode(BuildContext context, WidgetRef ref, int myNodeNum) {
    final me = ref.read(nodesProvider)[myNodeNum];
    final longName = me?.displayName ?? '!${myNodeNum.toRadixString(16)}';
    final shortName = me?.avatarName ?? '';
    final payload = jsonEncode({
      'nodeNum': myNodeNum,
      'longName': longName,
      'shortName': shortName,
    });
    final uri =
        'socialmesh://help-circle/${base64Encode(utf8.encode(payload))}';
    QrShareSheet.show(
      context: context,
      title: context.l10n.helpModeCircleShareTitle,
      subtitle: context.l10n.helpModeCircleShareSubtitle,
      qrData: uri,
      infoText: context.l10n.helpModeCircleShareInfo(
        myNodeNum.toRadixString(16).toUpperCase(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final circle = ref.watch(incidentHelpTrustProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    return GlassScaffold(
      title: l10n.helpModeCircleTitle,
      actions: [
        if (myNodeNum != null)
          IconButton(
            icon: const Icon(Icons.qr_code),
            tooltip: l10n.helpModeCircleShareAction,
            onPressed: () => _shareMyCode(context, ref, myNodeNum),
          ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          sliver: SliverToBoxAdapter(
            child: StatusBanner.info(
              title: l10n.helpModeCircleTitle,
              subtitle:
                  '${l10n.helpModeCircleIntro}\n\n${l10n.helpModeCircleMutualNote}',
              icon: Icons.health_and_safety_outlined,
            ),
          ),
        ),
        if (circle.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Text(l10n.helpModeCircleEmpty, style: context.hintStyle),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              0,
              AppTheme.spacing16,
              AppTheme.spacing16,
            ),
            sliver: SliverList.separated(
              itemCount: circle.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTheme.spacing8),
              itemBuilder: (context, i) => _CircleTile(peer: circle[i]),
            ),
          ),
      ],
    );
  }
}

class _CircleTile extends ConsumerWidget {
  final HelpCirclePeer peer;

  const _CircleTile({required this.peer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final name = peer.displayName.isNotEmpty
        ? peer.displayName
        : '!${peer.nodeId.toRadixString(16)}';
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing16,
          AppTheme.spacing12,
          AppTheme.spacing8,
          AppTheme.spacing12,
        ),
        // Top-aligned so the leading icon and trailing remove button sit level
        // with the first text line even when the name/status wraps.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.health_and_safety, color: AppTheme.successGreen),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: context.titleSmallStyle),
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    l10n.helpModeCircleTrusted,
                    style: context.captionMutedStyle,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacing8),
            // Compact trailing action so the long label does not squeeze the
            // name column (the label lives on the tooltip).
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: AppTheme.errorRed,
              tooltip: l10n.helpModeCircleRemove,
              onPressed: () async {
                final notifier = ref.read(incidentHelpTrustProvider.notifier);
                final confirmed = await AppBottomSheet.showConfirm(
                  context: context,
                  title: l10n.helpModeCircleRemoveConfirmTitle,
                  message: l10n.helpModeCircleRemoveConfirmBody(name),
                  confirmLabel: l10n.commonRemove,
                  cancelLabel: l10n.commonCancel,
                  isDestructive: true,
                );
                if (confirmed == true) {
                  await notifier.untrust(peer.nodeId);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
