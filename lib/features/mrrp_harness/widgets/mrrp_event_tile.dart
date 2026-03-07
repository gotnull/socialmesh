// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../services/protocol/sip/mrrp_traffic_event.dart';
import '../../../services/protocol/sip/mrrp_types.dart';

/// Tile widget showing a single traffic event in the console.
class MrrpEventTile extends StatelessWidget {
  final MrrpTrafficEvent event;

  const MrrpEventTile({required this.event, super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isTx = event.direction == 'TX'; // lint-allow: hardcoded-string
    final dirColor = isTx ? AccentColors.teal : AccentColors.indigo;

    return Material(
      color: context.card,
      borderRadius: BorderRadius.circular(AppTheme.radius8),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: event.toClipboardText()));
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: AppTheme.spacing8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: direction + type + time
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: dirColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(AppTheme.radius4),
                    ),
                    child: Text(
                      l10n.mrrpHarnessTrafficDirection(event.direction),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: dirColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing6),
                  Text(
                    event.msgType.name,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _formatTime(event.timestamp),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: context.textTertiary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing4),

              // Details: service, action, request_id, peer, size
              Wrap(
                spacing: AppTheme.spacing8,
                runSpacing: AppTheme.spacing2,
                children: [
                  if (event.serviceId != null)
                    _DetailChip(label: MrrpServiceId.nameOf(event.serviceId!)),
                  if (event.requestId != null)
                    _DetailChip(
                      label:
                          'req=0x${event.requestId!.toRadixString(16)}', // lint-allow: hardcoded-string
                    ),
                  if (event.peerNodeId != null)
                    _DetailChip(
                      label:
                          '0x${event.peerNodeId!.toRadixString(16).padLeft(8, '0').toUpperCase()}',
                    ),
                  _DetailChip(
                    label:
                        '${event.sizeBytes}B', // lint-allow: hardcoded-string
                  ),
                  if (event.status != null)
                    _DetailChip(
                      label: event.status!.name,
                      color: event.status == MrrpStatusCode.ok
                          ? SemanticColors.success
                          : SemanticColors.error,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:'
        '${time.second.toString().padLeft(2, '0')}.'
        '${time.millisecond.toString().padLeft(3, '0')}';
  }
}

class _DetailChip extends StatelessWidget {
  final String label;
  final Color? color;

  const _DetailChip({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color ?? context.textSecondary,
        fontFamily: 'monospace', // lint-allow: hardcoded-string
        fontSize: 10,
      ),
    );
  }
}
