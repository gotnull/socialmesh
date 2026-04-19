// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

/// A card that presents a nearby person discovered over the mesh.
///
/// Leads with identity (name, avatar) rather than protocol details.
/// Designed to make discovery feel human: show who is nearby and what
/// you can do, not transport states.
class NearbyPersonCard extends StatelessWidget {
  /// Display name for the person (resolved from NodeDex or fallback).
  final String displayName;

  /// Avatar widget (typically a SigilAvatar or NodeAvatar).
  final Widget avatar;

  /// Human-readable status line (e.g., "Nearby", "Seen 2 min ago").
  final String statusLine;

  /// Color for the status indicator dot.
  final Color statusColor;

  /// Optional secondary info line (e.g., device type).
  final String? subtitle;

  /// Connection state description (e.g., "Ready to connect", "Connected").
  final String? connectionState;

  /// Color for the connection state badge.
  final Color? connectionStateColor;

  /// Whether this person has been verified / handshake completed.
  final bool isVerified;

  /// Called when the card is tapped.
  final VoidCallback? onTap;

  /// Called when the primary action button is tapped.
  final VoidCallback? onAction;

  /// Label for the action button (e.g., "Connect", "Message").
  final String? actionLabel;

  /// Icon for the action button.
  final IconData? actionIcon;

  const NearbyPersonCard({
    super.key,
    required this.displayName,
    required this.avatar,
    required this.statusLine,
    this.statusColor = SemanticColors.success,
    this.subtitle,
    this.connectionState,
    this.connectionStateColor,
    this.isVerified = false,
    this.onTap,
    this.onAction,
    this.actionLabel,
    this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap?.call();
            },
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            // Avatar with status dot
            Stack(
              children: [
                avatar,
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.card, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: AppTheme.spacing12),
            // Identity info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: AppTheme.spacing4),
                        Icon(
                          Icons.verified,
                          size: 14,
                          color: AppTheme.successGreen,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    statusLine,
                    style: TextStyle(fontSize: 12, color: context.textTertiary),
                  ),
                  if (connectionState != null) ...[
                    const SizedBox(height: AppTheme.spacing4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacing8,
                        vertical: AppTheme.spacing2,
                      ),
                      decoration: BoxDecoration(
                        color: (connectionStateColor ?? context.accentColor)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                      child: Text(
                        connectionState!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: connectionStateColor ?? context.accentColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Action button
            if (onAction != null && actionLabel != null)
              Padding(
                padding: const EdgeInsets.only(left: AppTheme.spacing8),
                child: FilledButton.icon(
                  onPressed: onAction,
                  icon: actionIcon != null ? Icon(actionIcon, size: 16) : null,
                  label: Text(
                    actionLabel!,
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing12,
                      vertical: AppTheme.spacing8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
