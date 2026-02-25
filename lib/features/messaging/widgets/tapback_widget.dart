// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../models/tapback.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/telemetry_providers.dart';

/// Widget for displaying tapback reactions on a message.
/// Shows individual tapbacks with emoji + sender shortName (matches iOS).
class TapbackDisplay extends ConsumerWidget {
  final String messageId;

  const TapbackDisplay({super.key, required this.messageId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tapbacksAsync = ref.watch(messageTapbacksProvider(messageId));
    final nodes = ref.watch(nodesProvider);

    return tapbacksAsync.when(
      data: (tapbacks) {
        if (tapbacks.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radius18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            color: Colors.white.withValues(alpha: 0.05),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int i = 0; i < tapbacks.length; i++) ...[
                if (i > 0) const SizedBox(width: AppTheme.spacing10),
                _IndividualTapback(
                  tapback: tapbacks[i],
                  shortName: _resolveShortName(tapbacks[i].fromNodeNum, nodes),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, st) => const SizedBox.shrink(),
    );
  }

  String _resolveShortName(int nodeNum, Map<int, dynamic> nodes) {
    final node = nodes[nodeNum];
    if (node != null) {
      final shortName = node.shortName as String?;
      if (shortName != null && shortName.isNotEmpty) return shortName;
    }
    return '?';
  }
}

class _IndividualTapback extends StatelessWidget {
  final MessageTapback tapback;
  final String shortName;

  const _IndividualTapback({required this.tapback, required this.shortName});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(tapback.emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: AppTheme.spacing2),
        Text(
          shortName,
          style: context.captionStyle?.copyWith(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
          ),
        ),
      ],
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
              borderRadius: BorderRadius.circular(AppTheme.radius2),
            ),
          ),
          const SizedBox(height: AppTheme.spacing20),
          Text(
            'React',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing16),
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
          const SizedBox(height: AppTheme.spacing24),
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
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radius16),
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
