// SPDX-License-Identifier: GPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../providers/app_providers.dart';
import '../../providers/help_providers.dart';
import '../../models/mesh_models.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/search_filter_header.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/ico_help_system.dart';
import '../messaging/messaging_screen.dart';
import '../navigation/main_shell.dart';
import 'channel_options_sheet.dart';
import 'channel_wizard_screen.dart';

class ChannelsScreen extends ConsumerStatefulWidget {
  /// When true, shows only the body content without AppBar/Scaffold
  /// Used when embedded in tabs
  final bool embedded;

  const ChannelsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<ChannelsScreen> createState() => _ChannelsScreenState();
}

enum ChannelFilter { all, primary, encrypted, position, mqtt }

class _ChannelsScreenState extends ConsumerState<ChannelsScreen>
    with LifecycleSafeMixin {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  ChannelFilter _activeFilter = ChannelFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  List<ChannelConfig> _applyFilter(List<ChannelConfig> channels) {
    switch (_activeFilter) {
      case ChannelFilter.all:
        return channels;
      case ChannelFilter.primary:
        return channels.where((c) => c.role == 'PRIMARY').toList();
      case ChannelFilter.encrypted:
        return channels.where((c) => c.hasSecureKey).toList();
      case ChannelFilter.position:
        return channels.where((c) => c.positionEnabled).toList();
      case ChannelFilter.mqtt:
        return channels.where((c) => c.uplink || c.downlink).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(channelsProvider);

    // Count channels by filter for badges
    final primaryCount = channels.where((c) => c.role == 'PRIMARY').length;
    final encryptedCount = channels.where((c) => c.hasSecureKey).length;
    final positionCount = channels.where((c) => c.positionEnabled).length;
    final mqttCount = channels.where((c) => c.uplink || c.downlink).length;

    // Apply filter first
    var filteredChannels = _applyFilter(channels);

    // Then filter by search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredChannels = filteredChannels.where((channel) {
        return channel.name.toLowerCase().contains(query) ||
            channel.index.toString().contains(query);
      }).toList();
    }

    // Build the body content
    final bodyContent = Column(
      children: [
        // Search bar + filter chips
        SearchFilterHeader(
          searchController: _searchController,
          searchQuery: _searchQuery,
          onSearchChanged: (value) => setState(() => _searchQuery = value),
          hintText: 'Search channels',
          filterChips: [
            SectionFilterChip(
              label: 'All',
              count: channels.length,
              isSelected: _activeFilter == ChannelFilter.all,
              onTap: () => setState(() => _activeFilter = ChannelFilter.all),
            ),
            SectionFilterChip(
              label: 'Primary',
              count: primaryCount,
              isSelected: _activeFilter == ChannelFilter.primary,
              color: AccentColors.blue,
              icon: Icons.star,
              onTap: () =>
                  setState(() => _activeFilter = ChannelFilter.primary),
            ),
            SectionFilterChip(
              label: 'Encrypted',
              count: encryptedCount,
              isSelected: _activeFilter == ChannelFilter.encrypted,
              color: AccentColors.green,
              icon: Icons.lock,
              onTap: () =>
                  setState(() => _activeFilter = ChannelFilter.encrypted),
            ),
            SectionFilterChip(
              label: 'Position',
              count: positionCount,
              isSelected: _activeFilter == ChannelFilter.position,
              color: AccentColors.orange,
              icon: Icons.location_on,
              onTap: () =>
                  setState(() => _activeFilter = ChannelFilter.position),
            ),
            SectionFilterChip(
              label: 'MQTT',
              count: mqttCount,
              isSelected: _activeFilter == ChannelFilter.mqtt,
              color: AccentColors.purple,
              icon: Icons.cloud,
              onTap: () => setState(() => _activeFilter = ChannelFilter.mqtt),
            ),
          ],
        ),
        // Channels list
        Expanded(
          child: filteredChannels.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: context.card,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.wifi_tethering,
                          size: 40,
                          color: context.textTertiary,
                        ),
                      ),
                      SizedBox(height: 24),
                      Text(
                        _searchQuery.isNotEmpty
                            ? 'No channels match "$_searchQuery"'
                            : 'No channels configured',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: context.textSecondary,
                        ),
                      ),
                      if (_searchQuery.isEmpty) ...[
                        SizedBox(height: 8),
                        Text(
                          'Channels are still being loaded from device\nor use the icons above to add channels',
                          style: TextStyle(
                            fontSize: 14,
                            color: context.textTertiary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (_searchQuery.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: () => setState(() => _searchQuery = ''),
                          child: const Text('Clear search'),
                        ),
                      ],
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 8,
                    bottom: 16,
                  ),
                  itemCount: filteredChannels.length,
                  itemBuilder: (context, index) {
                    final channel = filteredChannels[index];
                    final animationsEnabled = ref.watch(
                      animationsEnabledProvider,
                    );
                    return Perspective3DSlide(
                      index: index,
                      direction: SlideDirection.left,
                      enabled: animationsEnabled,
                      child: _ChannelTile(
                        channel: channel,
                        animationsEnabled: animationsEnabled,
                      ),
                    );
                  },
                ),
        ),
      ],
    );

    // If embedded (in tabs), return just the body with gesture detector
    if (widget.embedded) {
      return GestureDetector(
        onTap: _dismissKeyboard,
        child: Container(color: context.background, child: bodyContent),
      );
    }

    // Full standalone screen with AppBar
    return GestureDetector(
      onTap: _dismissKeyboard,
      child: HelpTourController(
        topicId: 'channels_overview',
        stepKeys: const {},
        child: Scaffold(
          backgroundColor: context.background,
          appBar: AppBar(
            backgroundColor: context.background,
            leading: const HamburgerMenuButton(),
            centerTitle: true,
            title: Text(
              'Channels (${channels.length})',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
            actions: [
              const DeviceStatusButton(),
              AppBarOverflowMenu<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'add':
                      // Find next available channel index (1-7, 0 is Primary)
                      final usedIndices = channels.map((c) => c.index).toSet();
                      int nextIndex = 1;
                      for (int i = 1; i <= 7; i++) {
                        if (!usedIndices.contains(i)) {
                          nextIndex = i;
                          break;
                        }
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              ChannelWizardScreen(channelIndex: nextIndex),
                        ),
                      );
                    case 'scan':
                      Navigator.of(context).pushNamed('/qr-scanner');
                    case 'settings':
                      Navigator.pushNamed(context, '/settings');
                    case 'help':
                      ref
                          .read(helpProvider.notifier)
                          .startTour('channels_overview');
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'add',
                    child: ListTile(
                      leading: Icon(Icons.add),
                      title: Text('Add Channel'),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'scan',
                    child: ListTile(
                      leading: Icon(Icons.qr_code_scanner),
                      title: Text('Scan QR Code'),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings_outlined),
                      title: Text('Settings'),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'help',
                    child: ListTile(
                      leading: Icon(Icons.help_outline),
                      title: Text('Help'),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: bodyContent,
        ),
      ),
    );
  }
}

class _ChannelTile extends ConsumerWidget {
  final ChannelConfig channel;
  final bool animationsEnabled;

  const _ChannelTile({required this.channel, this.animationsEnabled = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrimary = channel.index == 0;
    final hasKey = channel.hasSecureKey;
    final channelUnreads = ref.watch(channelUnreadCountsProvider);
    final unreadCount = channelUnreads[channel.index] ?? 0;

    return BouncyTap(
      onTap: () => _openChannelChat(context),
      onLongPress: () => showChannelOptionsSheet(context, channel, ref: ref),
      scaleFactor: animationsEnabled ? 0.98 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isPrimary ? context.accentColor : context.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${channel.index}',
                    style: TextStyle(
                      color: isPrimary ? Colors.white : context.textSecondary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name.isEmpty
                          ? (isPrimary
                                ? 'Primary Channel'
                                : 'Channel ${channel.index}')
                          : channel.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          hasKey ? Icons.lock : Icons.lock_open,
                          size: 14,
                          color: hasKey
                              ? context.accentColor
                              : context.textTertiary,
                        ),
                        SizedBox(width: 6),
                        Text(
                          hasKey ? 'Encrypted' : 'No encryption',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                        if (isPrimary) ...[
                          SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'PRIMARY',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: context.accentColor,

                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (unreadCount > 0) ...[
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: unreadCount > 9 ? 6 : 0,
                    vertical: 2,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 22,
                    minHeight: 22,
                  ),
                  decoration: BoxDecoration(
                    color: context.accentColor,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
              ],
              Icon(Icons.chevron_right, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  void _openChannelChat(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          type: ConversationType.channel,
          channelIndex: channel.index,
          title: channel.name.isEmpty
              ? (channel.index == 0
                    ? 'Primary Channel'
                    : 'Channel ${channel.index}')
              : channel.name,
        ),
      ),
    );
  }
}
