// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme.dart';
import '../../../models/tapback.dart';
import '../../../providers/app_providers.dart';

/// Widget for displaying tapback reactions on a message.
/// Shows individual tapbacks with emoji + sender shortName (matches iOS).
class TapbackDisplay extends ConsumerWidget {
  final List<MessageTapback> tapbacks;

  const TapbackDisplay({super.key, required this.tapbacks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);

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
