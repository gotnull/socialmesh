// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../services/tak_gateway_client.dart';

/// Status card showing TAK Gateway connection state and counters.
class TakStatusCard extends StatelessWidget {
  final TakConnectionState connectionState;
  final int totalReceived;
  final int activeEntities;
  final String gatewayUrl;
  final DateTime? connectedSince;
  final String? lastError;

  const TakStatusCard({
    super.key,
    required this.connectionState,
    required this.totalReceived,
    required this.activeEntities,
    required this.gatewayUrl,
    this.connectedSince,
    this.lastError,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stateColor = _stateColor;
    final stateLabel = _stateLabel;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
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
              const SizedBox(width: 8),
              Text(
                stateLabel,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: stateColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                'TAK Gateway',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.orange.shade400,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _counter(theme, 'Events', '$totalReceived'),
              _counter(theme, 'Entities', '$activeEntities'),
              if (connectedSince != null)
                _counter(theme, 'Uptime', _formatUptime(connectedSince!)),
            ],
          ),
          if (lastError != null &&
              connectionState != TakConnectionState.connected) ...[
            const SizedBox(height: 8),
            Text(
              lastError!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.red.shade300,
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
        return Colors.green;
      case TakConnectionState.connecting:
      case TakConnectionState.reconnecting:
        return Colors.orange;
      case TakConnectionState.disconnected:
        return Colors.grey;
    }
  }

  String get _stateLabel {
    switch (connectionState) {
      case TakConnectionState.connected:
        return 'Connected';
      case TakConnectionState.connecting:
        return 'Connecting...';
      case TakConnectionState.reconnecting:
        return 'Reconnecting...';
      case TakConnectionState.disconnected:
        return 'Disconnected';
    }
  }

  static String _formatUptime(DateTime since) {
    final diff = DateTime.now().difference(since);
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return '${diff.inSeconds}s';
  }
}
