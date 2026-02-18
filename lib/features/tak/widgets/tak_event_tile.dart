// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';

import '../models/tak_event.dart';

/// List tile for a single TAK/CoT event in the event list.
///
/// Follows the vertical-stack layout pattern from CODING_PATTERNS:
/// title row, subtitle row, metadata chips row via Wrap.
class TakEventTile extends StatelessWidget {
  final TakEvent event;
  final VoidCallback? onTap;

  const TakEventTile({super.key, required this.event, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isStale = event.isStale;
    final age = _formatAge(event.receivedUtcMs);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                // Leading icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: (isStale ? Colors.grey : Colors.orange).withValues(
                      alpha: 0.15,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.gps_fixed,
                    size: 20,
                    color: isStale ? Colors.grey : Colors.orange.shade400,
                  ),
                ),
                const SizedBox(width: 12),
                // Content — vertical stack
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        event.displayName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isStale
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.5,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      // Subtitle
                      Text(
                        '${event.typeDescription}  \u2022  '
                        '${event.lat.toStringAsFixed(4)}, '
                        '${event.lon.toStringAsFixed(4)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Metadata chips
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _chip(context, Icons.access_time, age),
                          _chip(
                            context,
                            isStale ? Icons.timer_off : Icons.timer,
                            isStale ? 'Stale' : 'Active',
                          ),
                          if (event.callsign != null)
                            _chip(context, Icons.badge, event.callsign!),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, IconData icon, String label) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatAge(int receivedUtcMs) {
    final age = DateTime.now().millisecondsSinceEpoch - receivedUtcMs;
    if (age < 60000) return '${(age / 1000).round()}s ago';
    if (age < 3600000) return '${(age / 60000).round()}m ago';
    return '${(age / 3600000).round()}h ago';
  }
}
