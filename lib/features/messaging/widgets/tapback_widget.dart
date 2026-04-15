// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/node_avatar.dart';
import '../../../models/tapback.dart';
import '../../../providers/app_providers.dart';

/// A group of tapbacks sharing the same emoji.
class _TapbackGroup {
  final String emoji;
  final List<MessageTapback> tapbacks;
  final List<String> shortNames;

  _TapbackGroup({
    required this.emoji,
    required this.tapbacks,
    required this.shortNames,
  });
}

/// Widget for displaying tapback reactions on a message.
/// Groups identical emoji reactions together and uses Wrap for overflow.
/// Long-press a group to see all senders in a detail sheet.
class TapbackDisplay extends ConsumerWidget {
  final List<MessageTapback> tapbacks;

  const TapbackDisplay({super.key, required this.tapbacks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);

    if (tapbacks.isEmpty) return const SizedBox.shrink();

    // Group tapbacks by emoji
    final groups = _buildGroups(nodes);

    return Wrap(
      spacing: AppTheme.spacing4,
      runSpacing: AppTheme.spacing4,
      children: groups.map((group) {
        return GestureDetector(
          onLongPress: () {
            HapticFeedback.lightImpact();
            _showDetailSheet(context, group);
          },
          child: _GroupedTapbackChip(group: group),
        );
      }).toList(),
    );
  }

  List<_TapbackGroup> _buildGroups(Map<int, dynamic> nodes) {
    final groupMap = <String, List<MessageTapback>>{};
    final groupOrder = <String>[];
    for (final tapback in tapbacks) {
      groupMap.putIfAbsent(tapback.emoji, () {
        groupOrder.add(tapback.emoji);
        return [];
      });
      groupMap[tapback.emoji]!.add(tapback);
    }

    return groupOrder.map((emoji) {
      final items = groupMap[emoji]!;
      final shortNames = items
          .map((t) => _resolveShortName(t.fromNodeNum, nodes))
          .toList();
      return _TapbackGroup(
        emoji: emoji,
        tapbacks: items,
        shortNames: shortNames,
      );
    }).toList();
  }

  String _resolveShortName(int nodeNum, Map<int, dynamic> nodes) {
    final node = nodes[nodeNum];
    if (node != null) {
      final shortName = node.shortName as String?;
      if (shortName != null && shortName.isNotEmpty) return shortName;
    }
    return '?';
  }

  void _showDetailSheet(BuildContext context, _TapbackGroup group) {
    final l10n = context.l10n;
    AppBottomSheet.show(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with emoji and title
          Row(
            children: [
              Text(group.emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: AppTheme.spacing10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.tapbackDetailSheetTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: context.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      l10n.tapbackDetailSenderCount(group.tapbacks.length),
                      style: TextStyle(
                        fontSize: 13,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),
          // List of senders
          ...group.tapbacks.asMap().entries.map((entry) {
            final index = entry.key;
            final shortName = group.shortNames[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
              child: Row(
                children: [
                  NodeAvatar(
                    text: shortName,
                    color: context.accentColor,
                    size: 28,
                  ),
                  const SizedBox(width: AppTheme.spacing10),
                  Expanded(
                    child: Text(
                      shortName,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// A compact chip showing a grouped emoji reaction.
/// Shows: emoji + count (if > 1) + first sender name(s).
class _GroupedTapbackChip extends StatelessWidget {
  final _TapbackGroup group;

  const _GroupedTapbackChip({required this.group});

  @override
  Widget build(BuildContext context) {
    final count = group.tapbacks.length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        color: Colors.white.withValues(alpha: 0.05),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(group.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: AppTheme.spacing3),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
