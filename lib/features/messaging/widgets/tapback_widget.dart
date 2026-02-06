// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../models/tapback.dart';
import '../../../providers/telemetry_providers.dart';

/// Widget for displaying tapback reactions on a message
class TapbackDisplay extends ConsumerWidget {
  final String messageId;

  const TapbackDisplay({super.key, required this.messageId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupedTapbacks = ref.watch(groupedTapbacksProvider(messageId));

    return groupedTapbacks.when(
      data: (grouped) {
        if (grouped.isEmpty) return const SizedBox.shrink();

        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: grouped.entries.map((entry) {
            return _TapbackBadge(type: entry.key, count: entry.value.length);
          }).toList(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}

class _TapbackBadge extends StatelessWidget {
  final TapbackType type;
  final int count;

  const _TapbackBadge({required this.type, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(type.emoji, style: context.bodySmallStyle),
          if (count > 1) ...[
            const SizedBox(width: 2),
            Text(
              '$count',
              style: context.captionStyle?.copyWith(
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Bottom sheet for selecting a tapback reaction
class TapbackPicker extends ConsumerWidget {
  final String messageId;
  final int fromNodeNum;
  final int? toNodeNum;
  final VoidCallback? onSelected;

  const TapbackPicker({
    super.key,
    required this.messageId,
    required this.fromNodeNum,
    this.toNodeNum,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'React',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: TapbackType.values.map((type) {
              return _TapbackButton(
                type: type,
                onTap: () async {
                  await ref
                      .read(tapbackActionsProvider.notifier)
                      .addTapback(
                        messageId: messageId,
                        fromNodeNum: fromNodeNum,
                        type: type,
                        toNodeNum: toNodeNum,
                      );
                  onSelected?.call();
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TapbackButton extends StatelessWidget {
  final TapbackType type;
  final VoidCallback onTap;

  const _TapbackButton({required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              type.emoji,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper function to show the tapback picker
void showTapbackPicker(
  BuildContext context, {
  required String messageId,
  required int fromNodeNum,
  int? toNodeNum,
  VoidCallback? onSelected,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => TapbackPicker(
      messageId: messageId,
      fromNodeNum: fromNodeNum,
      toNodeNum: toNodeNum,
      onSelected: onSelected,
    ),
  );
}
