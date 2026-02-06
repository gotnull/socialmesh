// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../core/transport.dart';
import '../../../providers/app_providers.dart';
import '../../../models/presence_confidence.dart';
import '../../../providers/presence_providers.dart';

/// Network Overview Widget - Shows mesh network status at a glance
class NetworkOverviewContent extends ConsumerWidget {
  const NetworkOverviewContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);
    final presenceMap = ref.watch(presenceMapProvider);
    final messages = ref.watch(messagesProvider);
    final connectionState = ref.watch(connectionStateProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);

    final isConnected =
        connectionState.whenOrNull(
          data: (state) => state == DeviceConnectionState.connected,
        ) ??
        false;

    // Calculate stats
    final activeNodes = nodes.values
        .where((n) => presenceConfidenceFor(presenceMap, n).isActive)
        .length;
    final totalNodes = nodes.length;
    final recentMessages = messages.where((m) {
      final age = DateTime.now().difference(m.timestamp);
      return age.inHours < 1;
    }).length;
    final unreadMessages = messages
        .where((m) => !m.received && m.to == myNodeNum)
        .length;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Connection status
          Expanded(
            child: _StatItem(
              icon: isConnected ? Icons.check_circle : Icons.error_outline,
              iconColor: isConnected ? context.accentColor : AppTheme.errorRed,
              value: isConnected ? 'Online' : 'Offline',
              label: 'Status',
            ),
          ),
          _VerticalDivider(),
          // Nodes
          Expanded(
            child: _StatItem(
              icon: Icons.people_outline,
              iconColor: context.accentColor,
              value: '$activeNodes/$totalNodes',
              label: 'Nodes',
            ),
          ),
          _VerticalDivider(),
          // Messages
          Expanded(
            child: _StatItem(
              icon: Icons.chat_bubble_outline,
              iconColor: context.accentColor,
              value: recentMessages.toString(),
              label: 'Last Hour',
              badge: unreadMessages > 0 ? unreadMessages : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final int? badge;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            if (badge != null)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  child: Text(
                    badge! > 9 ? '9+' : badge.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: context.textTertiary),
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: context.border.withValues(alpha: 0.5),
    );
  }
}
