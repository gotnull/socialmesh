// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/routing/conversation_routes.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../providers/app_providers.dart';
import '../../providers/channels_display_order_provider.dart';
import '../../providers/help_providers.dart';
import '../../providers/messages_view_mode_provider.dart';
import '../../models/mesh_models.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bar_overflow_menu.dart';
import '../../core/widgets/animations.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/search_filter_header.dart';
import '../../core/widgets/status_filter_chip.dart';
import '../../core/widgets/ico_help_system.dart';
import '../messaging/messaging_screen.dart';
import '../navigation/main_shell.dart';
import 'channel_options_sheet.dart';
import 'channel_reorder_sheet.dart';
import 'channel_wizard_screen.dart';
import 'widgets/mesh_beacon_notice.dart';

class ChannelsScreen extends ConsumerStatefulWidget {
  /// When true, shows only the body content without AppBar/Scaffold
  /// Used when embedded in tabs
  final bool embedded;

  const ChannelsScreen({super.key, this.embedded = false});

  @override
  ConsumerState<ChannelsScreen> createState() => _ChannelsScreenState();
}

enum ChannelFilter { all, unread, primary, encrypted, position, mqtt }

// Resolves a persisted filter name back to the enum. Unknown or null
// names (fresh installs, values written by a newer app version) fall
// back to the all-channels view instead of throwing.
ChannelFilter channelFilterFromName(String? raw) => ChannelFilter.values
    .firstWhere((f) => f.name == raw, orElse: () => ChannelFilter.all);

class _ChannelsScreenState extends ConsumerState<ChannelsScreen>
    with LifecycleSafeMixin {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  ChannelFilter _activeFilter = ChannelFilter.all;

  @override
  void initState() {
    super.initState();
    // Restore the last chosen filter chip. Read synchronously off the
    // already-loaded settings service when present; before it loads the
    // default all-channels view applies, matching first launches.
    _activeFilter = channelFilterFromName(
      ref.read(settingsServiceProvider).value?.channelsListFilter,
    );
  }

  void _selectFilter(ChannelFilter filter) {
    HapticFeedback.lightImpact();
    setState(() => _activeFilter = filter);
    final settings = ref.read(settingsServiceProvider).value;
    if (settings == null || settings.channelsListFilter == filter.name) return;
    unawaited(settings.setChannelsListFilter(filter.name));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  List<ChannelConfig> _applyFilter(
    List<ChannelConfig> channels,
    Map<int, int> unreadCounts,
  ) {
    switch (_activeFilter) {
      case ChannelFilter.all:
        return channels;
      case ChannelFilter.unread:
        return channels.where((c) => (unreadCounts[c.index] ?? 0) > 0).toList();
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
    // The saved display order applies before filtering so the user's
    // arrangement holds in every filtered subset. Slot assignment on the
    // radio is untouched.
    final channels = applyChannelDisplayOrder(
      ref.watch(channelsProvider),
      ref.watch(channelsDisplayOrderProvider),
    );
    final channelUnreads = ref.watch(channelUnreadCountsProvider);

    // Count channels by filter for badges
    final unreadChannelCount = channels
        .where((c) => (channelUnreads[c.index] ?? 0) > 0)
        .length;
    final primaryCount = channels.where((c) => c.role == 'PRIMARY').length;
    final encryptedCount = channels.where((c) => c.hasSecureKey).length;
    final positionCount = channels.where((c) => c.positionEnabled).length;
    final mqttCount = channels.where((c) => c.uplink || c.downlink).length;

    // Apply filter first
    var filteredChannels = _applyFilter(channels, channelUnreads);

    // Then filter by search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredChannels = filteredChannels.where((channel) {
        return channel.name.toLowerCase().contains(query) ||
            channel.index.toString().contains(query);
      }).toList();
    }

    // Build the body content — use CustomScrollView with a pinned sliver
    // header so the search bar + filter chips never overflow on compact
    // screens (previously caused a 22px bottom overflow in the Column).
    final textScaler = MediaQuery.textScalerOf(context);

    final bodyContent = CustomScrollView(
      // Inner scrollable owns the bounce. The outer GlassScaffold
      // (messages container) is pinned with ClampingScrollPhysics so
      // the pinned search/filter chips never slide out from under the
      // tabs. `primary: false` keeps the inner from competing for the
      // PrimaryScrollController.
      physics: widget.embedded
          ? const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics())
          : null,
      primary: !widget.embedded,
      slivers: [
        const SliverToBoxAdapter(child: MeshBeaconNotice()),
        SliverPersistentHeader(
          pinned: true,
          delegate: SearchFilterHeaderDelegate(
            searchController: _searchController,
            searchQuery: _searchQuery,
            onSearchChanged: (value) => setState(() => _searchQuery = value),
            hintText: context.l10n.channelsSearchHint,
            textScaler: textScaler,
            rebuildKey: Object.hashAll([
              _activeFilter,
              channels.length,
              unreadChannelCount,
              primaryCount,
              encryptedCount,
              positionCount,
              mqttCount,
            ]),
            filterChips: [
              StatusFilterChip(
                label: context.l10n.channelsFilterAll,
                count: channels.length,
                isSelected: _activeFilter == ChannelFilter.all,
                onTap: () => _selectFilter(ChannelFilter.all),
              ),
              StatusFilterChip(
                label: context.l10n.channelsFilterUnread,
                count: unreadChannelCount,
                isSelected: _activeFilter == ChannelFilter.unread,
                icon: Icons.mark_email_unread_outlined,
                color: AccentColors.red,
                onTap: () => _selectFilter(ChannelFilter.unread),
              ),
              StatusFilterChip(
                label: context.l10n.channelsFilterPrimary,
                count: primaryCount,
                isSelected: _activeFilter == ChannelFilter.primary,
                color: AccentColors.blue,
                icon: Icons.star,
                onTap: () => _selectFilter(ChannelFilter.primary),
              ),
              StatusFilterChip(
                label: context.l10n.channelsFilterEncrypted,
                count: encryptedCount,
                isSelected: _activeFilter == ChannelFilter.encrypted,
                color: AccentColors.green,
                icon: Icons.lock,
                onTap: () => _selectFilter(ChannelFilter.encrypted),
              ),
              StatusFilterChip(
                label: context.l10n.channelsFilterPosition,
                count: positionCount,
                isSelected: _activeFilter == ChannelFilter.position,
                color: AccentColors.orange,
                icon: Icons.location_on,
                onTap: () => _selectFilter(ChannelFilter.position),
              ),
              StatusFilterChip(
                label: context.l10n.channelsFilterMqtt,
                count: mqttCount,
                isSelected: _activeFilter == ChannelFilter.mqtt,
                color: AccentColors.purple,
                icon: Icons.cloud,
                onTap: () => _selectFilter(ChannelFilter.mqtt),
              ),
            ],
          ),
        ),
        // Channels list (or empty state)
        if (filteredChannels.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: context.card,
                      borderRadius: BorderRadius.circular(AppTheme.radius16),
                    ),
                    child: Icon(
                      Icons.wifi_tethering,
                      size: 40,
                      color: context.textTertiary,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacing24),
                  Text(
                    _searchQuery.isNotEmpty
                        ? context.l10n.channelsNoMatch(_searchQuery)
                        : context.l10n.channelsEmpty,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: context.textSecondary,
                    ),
                  ),
                  if (_searchQuery.isEmpty) ...[
                    SizedBox(height: AppTheme.spacing8),
                    Text(
                      context.l10n.channelsEmptySubtitle,
                      style: TextStyle(
                        fontSize: 14,
                        color: context.textTertiary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (_searchQuery.isNotEmpty) ...[
                    const SizedBox(height: AppTheme.spacing12),
                    TextButton(
                      onPressed: () => setState(() => _searchQuery = ''),
                      child: Text(context.l10n.channelsClearSearch),
                    ),
                  ],
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 16,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final channel = filteredChannels[index];
                final animationsEnabled = ref.watch(animationsEnabledProvider);
                final compactView = ref.watch(channelsCompactViewProvider);
                return Perspective3DSlide(
                  index: index,
                  direction: SlideDirection.left,
                  enabled: animationsEnabled,
                  child: compactView
                      ? _CompactChannelTile(channel: channel)
                      : _ChannelTile(
                          channel: channel,
                          animationsEnabled: animationsEnabled,
                        ),
                );
              }, childCount: filteredChannels.length),
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
        child: GlassScaffold(
          resizeToAvoidBottomInset: false,
          leading: const HamburgerMenuButton(),
          centerTitle: true,
          title: context.l10n.channelsScreenTitle(channels.length),
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
                  case 'reorder':
                    showChannelReorderSheet(context);
                  case 'settings':
                    Navigator.pushNamed(context, '/settings');
                  case 'help':
                    ref
                        .read(helpProvider.notifier)
                        .startTour('channels_overview');
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'add',
                  child: ListTile(
                    leading: Icon(Icons.add),
                    title: Text(context.l10n.channelsMenuAddChannel),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                PopupMenuItem(
                  value: 'scan',
                  child: ListTile(
                    leading: Icon(Icons.qr_code_scanner),
                    title: Text(context.l10n.channelsMenuScanQrCode),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                if (channels.length > 1)
                  PopupMenuItem(
                    value: 'reorder',
                    child: ListTile(
                      leading: Icon(Icons.swap_vert),
                      title: Text(context.l10n.channelsMenuReorder),
                      contentPadding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'settings',
                  child: ListTile(
                    leading: Icon(Icons.settings_outlined),
                    title: Text(context.l10n.channelsMenuSettings),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
                PopupMenuItem(
                  value: 'help',
                  child: ListTile(
                    leading: Icon(Icons.help_outline),
                    title: Text(context.l10n.channelsMenuHelp),
                    contentPadding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ],
          // Use hasScrollBody: true because bodyContent is a CustomScrollView.
          // hasScrollBody: false would force intrinsic dimension computation
          // which CustomScrollView cannot provide, causing a null check crash
          // in RenderViewportBase.layoutChildSequence.
          slivers: [
            SliverFillRemaining(hasScrollBody: true, child: bodyContent),
          ],
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
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isPrimary ? context.accentColor : context.background,
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
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
              SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name.isEmpty
                          ? (isPrimary
                                ? context.l10n.channelsPrimaryChannelName
                                : context.l10n.channelsDefaultChannelName(
                                    channel.index,
                                  ))
                          : channel.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacing6),
                    Row(
                      children: [
                        Icon(
                          hasKey ? Icons.lock : Icons.lock_open,
                          size: 14,
                          color: hasKey
                              ? context.accentColor
                              : context.textTertiary,
                        ),
                        SizedBox(width: AppTheme.spacing6),
                        Text(
                          hasKey
                              ? context.l10n.channelsTileEncrypted
                              : context.l10n.channelsTileNoEncryption,
                          style: TextStyle(
                            fontSize: 13,
                            color: context.textSecondary,
                          ),
                        ),
                        if (isPrimary) ...[
                          SizedBox(width: AppTheme.spacing12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: context.accentColor.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(
                                AppTheme.radius4,
                              ),
                            ),
                            child: Text(
                              context.l10n.channelsTilePrimaryBadge,
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
                    borderRadius: BorderRadius.circular(AppTheme.radius11),
                  ),
                  child: Center(
                    child: Text(
                      unreadCount > 99
                          ? context.l10n.channelsUnreadOverflow
                          : '$unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppTheme.spacing8),
              ],
              Icon(Icons.chevron_right, color: context.textTertiary),
            ],
          ),
        ),
      ),
    );
  }

  void _openChannelChat(BuildContext context) =>
      _openChannelChatFor(context, channel);
}

// Resolves the display name and opens the channel chat. Shared by the
// card and compact tiles.
String _channelDisplayName(BuildContext context, ChannelConfig channel) =>
    channel.name.isEmpty
    ? (channel.index == 0
          ? context.l10n.channelsPrimaryChannelName
          : context.l10n.channelsDefaultChannelName(channel.index))
    : channel.name;

void _openChannelChatFor(BuildContext context, ChannelConfig channel) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ChatScreen(
        type: ConversationType.channel,
        channelIndex: channel.index,
        title: _channelDisplayName(context, channel),
      ),
      settings: RouteSettings(name: meshtasticChannelRouteName(channel.index)),
    ),
  );
}

/// Dense channel row for the compact view mode: flat surface, smaller
/// index badge, single row. Mirrors the compact tiles on the Nodes and
/// Contacts lists so the densified surfaces read consistently.
class _CompactChannelTile extends ConsumerWidget {
  final ChannelConfig channel;

  const _CompactChannelTile({required this.channel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPrimary = channel.index == 0;
    final hasKey = channel.hasSecureKey;
    final unreadCount =
        ref.watch(channelUnreadCountsProvider)[channel.index] ?? 0;

    return InkWell(
      onTap: () => _openChannelChatFor(context, channel),
      onLongPress: () => showChannelOptionsSheet(context, channel, ref: ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isPrimary ? context.accentColor : context.background,
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              child: Center(
                child: Text(
                  '${channel.index}',
                  style: TextStyle(
                    color: isPrimary ? Colors.white : context.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Text(
                _channelDisplayName(context, channel),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppTheme.spacing8),
            Icon(
              hasKey ? Icons.lock : Icons.lock_open,
              size: 14,
              color: hasKey ? context.accentColor : context.textTertiary,
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: AppTheme.spacing8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: context.accentColor,
                  borderRadius: BorderRadius.circular(AppTheme.radius10),
                ),
                child: Text(
                  unreadCount > 99
                      ? context.l10n.channelsUnreadOverflow
                      : '$unreadCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(width: AppTheme.spacing8),
            Icon(Icons.chevron_right, color: context.textTertiary, size: 16),
          ],
        ),
      ),
    );
  }
}
