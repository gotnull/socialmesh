import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../models/automation.dart';

/// Card displaying an automation with toggle and actions
class AutomationCard extends StatelessWidget {
  final Automation automation;
  final void Function(bool enabled) onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const AutomationCard({
    super.key,
    required this.automation,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final trigger = automation.trigger;
    final isEnabled = automation.enabled;

    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.darkCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEnabled
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)
                : AppTheme.darkBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Trigger icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isEnabled
                        ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2)
                        : AppTheme.darkBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    trigger.type.icon,
                    color: isEnabled
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),

                // Name and description
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        automation.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isEnabled ? null : Colors.grey,
                            ),
                      ),
                      if (automation.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          automation.description!,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),

                // Toggle switch
                ThemedSwitch(value: isEnabled, onChanged: onToggle),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Trigger and actions summary
            Row(
              children: [
                // Trigger info
                Expanded(
                  child: _buildInfoChip(
                    context,
                    icon: Icons.bolt,
                    label: trigger.type.displayName,
                    color: Colors.amber,
                  ),
                ),

                const SizedBox(width: 8),

                // Arrow
                const Icon(Icons.arrow_forward, size: 16, color: Colors.grey),

                const SizedBox(width: 8),

                // Actions count
                Expanded(
                  child: _buildInfoChip(
                    context,
                    icon: Icons.play_arrow,
                    label:
                        '${automation.actions.length} action${automation.actions.length == 1 ? '' : 's'}',
                    color: AppTheme.successGreen,
                  ),
                ),
              ],
            ),

            // Stats row
            const SizedBox(height: 12),
            Row(
              children: [
                if (automation.triggerCount > 0) ...[
                  Icon(Icons.trending_up, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${automation.triggerCount} runs',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
                if (automation.lastTriggered != null) ...[
                  if (automation.triggerCount > 0) const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    _formatLastTriggered(automation.lastTriggered!),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
                const Spacer(),
                // Delete button - always visible
                GestureDetector(
                  onTap: onDelete,
                  child: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastTriggered(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${diff.inDays ~/ 7}w ago';
  }
}
