// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: haptic-feedback - onTap delegates to parent callback
import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../services/tak_gateway_client.dart';

import 'package:socialmesh/core/theme.dart';

/// Status card showing TAK Gateway connection state and counters.
class TakStatusCard extends StatelessWidget {
  final TakConnectionState connectionState;
  final int totalReceived;
  final int activeEntities;
  final String gatewayUrl;
  final DateTime? connectedSince;
  final String? lastError;
  final VoidCallback? onInfoTap;

  const TakStatusCard({
    super.key,
    required this.connectionState,
    required this.totalReceived,
    required this.activeEntities,
    required this.gatewayUrl,
    this.connectedSince,
    this.lastError,
    this.onInfoTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stateColor = _stateColor;
    final stateLabel = _localizedStateLabel(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(AppTheme.spacing16, 8, 16, 0),
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: stateColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: stateColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                stateLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: stateColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                context.l10n.takStatusCardLabel,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AccentColors.orange,
                  letterSpacing: 1.0,
                ),
              ),
              if (onInfoTap != null) ...[
                const SizedBox(width: AppTheme.spacing4),
                GestureDetector(
                  onTap: onInfoTap,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing4),
                    child: Icon(
                      Icons.info_outline,
                      size: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _counter(
                theme,
                context.l10n.takStatusCardCounterEvents,
                '$totalReceived',
              ),
              _counter(
                theme,
                context.l10n.takStatusCardCounterEntities,
                '$activeEntities',
              ),
              if (connectedSince != null)
                _counter(
                  theme,
                  context.l10n.takStatusCardCounterUptime,
                  _localizedFormatUptime(connectedSince!, context),
                ),
            ],
          ),
          if (lastError != null &&
              connectionState != TakConnectionState.connected) ...[
            const SizedBox(height: AppTheme.spacing8),
            Text(
              lastError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppTheme.errorRed,
                fontSize: 11,
              ),
              maxLines: 2,
            ),
          ],
        ],
      ),
    );
  }

  Widget _counter(ThemeData theme, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }

  Color get _stateColor {
    switch (connectionState) {
      case TakConnectionState.connected:
        return AppTheme.successGreen;
      case TakConnectionState.connecting:
      case TakConnectionState.reconnecting:
        return AccentColors.orange;
      case TakConnectionState.disconnected:
        return SemanticColors.disabled;
    }
  }

  String _localizedStateLabel(BuildContext context) {
    switch (connectionState) {
      case TakConnectionState.connected:
        return context.l10n.takStatusCardConnected;
      case TakConnectionState.connecting:
        return context.l10n.takStatusCardConnecting;
      case TakConnectionState.reconnecting:
        return context.l10n.takStatusCardReconnecting;
      case TakConnectionState.disconnected:
        return context.l10n.takStatusCardDisconnected;
    }
  }

  static String _localizedFormatUptime(DateTime since, BuildContext context) {
    final l10n = context.l10n;
    final diff = DateTime.now().difference(since);
    if (diff.inHours > 0) {
      return l10n.takStatusCardUptimeHoursMinutes(
        diff.inHours,
        diff.inMinutes % 60,
      );
    }
    if (diff.inMinutes > 0) {
      return l10n.takStatusCardUptimeMinutes(diff.inMinutes);
    }
    return l10n.takStatusCardUptimeSeconds(diff.inSeconds);
  }
}
