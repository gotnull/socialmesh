import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../../providers/app_providers.dart';
import '../../models/mesh_models.dart';
import 'animations.dart';
import 'app_bottom_sheet.dart';

/// Result from channel selector
class ChannelSelection {
  final int index;
  final String name;

  const ChannelSelection({required this.index, required this.name});
}

/// Generic reusable channel selector bottom sheet
class ChannelSelectorSheet extends ConsumerWidget {
  final String title;
  final int? initialSelection;

  const ChannelSelectorSheet({
    super.key,
    this.title = 'Select Channel',
    this.initialSelection,
  });

  /// Show the channel selector and return the selection
  static Future<ChannelSelection?> show(
    BuildContext context, {
    String title = 'Select Channel',
    int? initialSelection,
  }) {
    return AppBottomSheet.show<ChannelSelection>(
      context: context,
      padding: EdgeInsets.zero,
      child: ChannelSelectorSheet(
        title: title,
        initialSelection: initialSelection,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(channelsProvider);
    final selectedIndex = initialSelection ?? 0;

    // Filter to only active channels
    final activeChannels = <MapEntry<int, ChannelConfig>>[];
    for (var i = 0; i < channels.length; i++) {
      final channel = channels[i];
      if (channel.role != 'DISABLED') {
        activeChannels.add(MapEntry(i, channel));
      }
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 0),
            child: Row(
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppTheme.textTertiary),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.darkBorder),

          // Channel list
          Flexible(
            child: activeChannels.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: activeChannels.length,
                    itemBuilder: (context, index) {
                      final entry = activeChannels[index];
                      final channelIndex = entry.key;
                      final channel = entry.value;
                      final name = channel.name.isEmpty
                          ? (channelIndex == 0
                                ? 'Primary'
                                : 'Channel $channelIndex')
                          : channel.name;
                      final isSelected = channelIndex == selectedIndex;
                      final isPrimary = channel.role == 'PRIMARY';
                      final animationsEnabled = ref.watch(
                        animationsEnabledProvider,
                      );

                      return Perspective3DSlide(
                        index: index,
                        direction: SlideDirection.left,
                        enabled: animationsEnabled,
                        child: _ChannelTile(
                          name: name,
                          index: channelIndex,
                          isPrimary: isPrimary,
                          isSelected: isSelected,
                          onTap: () {
                            Navigator.pop(
                              context,
                              ChannelSelection(index: channelIndex, name: name),
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_tethering_off,
            size: 48,
            color: AppTheme.textTertiary,
          ),
          SizedBox(height: 12),
          Text(
            'No channels configured',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final String name;
  final int index;
  final bool isPrimary;
  final bool isSelected;
  final VoidCallback onTap;

  const _ChannelTile({
    required this.name,
    required this.index,
    required this.isPrimary,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          color: isSelected
              ? context.accentColor.withValues(alpha: 0.08)
              : Colors.transparent,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: TextStyle(
                      color: context.accentColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: isSelected
                                  ? context.accentColor
                                  : Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isPrimary) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(
                                alpha: 0.15,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'PRIMARY',
                              style: TextStyle(
                                color: context.accentColor,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'Channel $index',
                      style: TextStyle(
                        color: AppTheme.textTertiary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.check_circle, color: context.accentColor, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
