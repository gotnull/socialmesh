// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../models/mesh_models.dart';
import '../../providers/app_providers.dart';
import '../../providers/channels_display_order_provider.dart';

/// Opens the drag-to-reorder sheet for the Channels list display order.
///
/// Reordering is presentational only: the radio's channel slots (and
/// therefore message routing) never change. Each drop persists
/// immediately, so the order survives app relaunches.
Future<void> showChannelReorderSheet(BuildContext context) {
  return AppBottomSheet.showScrollable<void>(
    context: context,
    initialChildSize: 0.6,
    minChildSize: 0.4,
    maxChildSize: 0.9,
    builder: (controller) => _ChannelReorderSheet(scrollController: controller),
  );
}

class _ChannelReorderSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;

  const _ChannelReorderSheet({required this.scrollController});

  @override
  ConsumerState<_ChannelReorderSheet> createState() =>
      _ChannelReorderSheetState();
}

class _ChannelReorderSheetState extends ConsumerState<_ChannelReorderSheet> {
  late List<ChannelConfig> _channels;

  @override
  void initState() {
    super.initState();
    _channels = applyChannelDisplayOrder(
      ref.read(channelsProvider),
      ref.read(channelsDisplayOrderProvider),
    );
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      final target = newIndex > oldIndex ? newIndex - 1 : newIndex;
      final moved = _channels.removeAt(oldIndex);
      _channels.insert(target, moved);
    });
    ref
        .read(channelsDisplayOrderProvider.notifier)
        .setOrder(_channels.map((c) => c.index).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing20,
            0,
            AppTheme.spacing20,
            AppTheme.spacing12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.channelsReorderSheetTitle,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: AppTheme.spacing4),
              Text(
                context.l10n.channelsReorderSheetHint,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: context.textTertiary),
              ),
            ],
          ),
        ),
        Divider(color: context.border, height: 1),
        Expanded(
          child: ReorderableListView.builder(
            scrollController: widget.scrollController,
            buildDefaultDragHandles: false,
            padding: EdgeInsets.only(
              top: AppTheme.spacing8,
              bottom: MediaQuery.of(context).padding.bottom + 8,
            ),
            itemCount: _channels.length,
            onReorder: _onReorder,
            itemBuilder: (context, index) {
              final channel = _channels[index];
              final isPrimary = channel.index == 0;
              return Padding(
                key: ValueKey(channel.index),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing20,
                  vertical: AppTheme.spacing8,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isPrimary
                            ? context.accentColor
                            : context.background,
                        borderRadius: BorderRadius.circular(AppTheme.radius8),
                      ),
                      child: Center(
                        child: Text(
                          '${channel.index}',
                          style: TextStyle(
                            color: isPrimary
                                ? Colors.white
                                : context.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      child: Text(
                        channel.name.isEmpty
                            ? (isPrimary
                                  ? context.l10n.channelsPrimaryChannelName
                                  : context.l10n.channelsDefaultChannelName(
                                      channel.index,
                                    ))
                            : channel.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    ReorderableDragStartListener(
                      index: index,
                      child: Icon(
                        Icons.drag_handle,
                        color: context.textTertiary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
