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

    return Container(
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(
          color: context.border.withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: event.toClipboardText()));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: direction + type + time
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: dirColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                      child: Text(
                        l10n.mrrpHarnessTrafficDirection(event.direction),
                        style: TextStyle(
                          color: dirColor,
                          fontWeight: FontWeight.w700,
                          fontFamily: AppTheme.fontFamily,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Text(
                      event.msgType.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: context.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTime(event.timestamp),
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: context.textTertiary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing6),

                // Details: service, action, request_id, peer, size
                Wrap(
                  spacing: AppTheme.spacing6,
                  runSpacing: AppTheme.spacing4,
                  children: [
                    if (event.serviceId != null)
                      _DetailChip(
                        label: MrrpServiceId.nameOf(event.serviceId!),
                      ),
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
    final chipColor = color ?? context.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: chipColor,
          fontFamily: AppTheme.fontFamily,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
