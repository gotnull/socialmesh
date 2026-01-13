import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../navigation/main_shell.dart';
import '../channels/channels_screen.dart';
import 'messaging_screen.dart';

/// Container screen that holds both Contacts and Channels in tabs
/// Provides a unified "Messages" experience
class MessagesContainerScreen extends ConsumerStatefulWidget {
  const MessagesContainerScreen({super.key});

  @override
  ConsumerState<MessagesContainerScreen> createState() =>
      _MessagesContainerScreenState();
}

class _MessagesContainerScreenState
    extends ConsumerState<MessagesContainerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channels = ref.watch(channelsProvider);
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final hasUnread = ref.watch(hasUnreadMessagesProvider);

    // Count contacts (nodes minus self)
    final contactsCount = nodes.values
        .where((n) => n.nodeNum != myNodeNum)
        .length;

    return Scaffold(
      backgroundColor: context.background,
      appBar: AppBar(
        backgroundColor: context.background,
        leading: const HamburgerMenuButton(),
        centerTitle: true,
        title: Text(
          'Messages',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        actions: const [DeviceStatusButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: context.border.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: context.accentColor,
              indicatorWeight: 3,
              labelColor: context.accentColor,
              unselectedLabelColor: context.textSecondary,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Contacts'),
                      const SizedBox(width: 6),
                      _TabBadge(count: contactsCount, showDot: hasUnread),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Channels'),
                      const SizedBox(width: 6),
                      _TabBadge(count: channels.length),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          MessagingScreen(embedded: true),
          ChannelsScreen(embedded: true),
        ],
      ),
    );
  }
}

/// Tab badge showing count and optional unread dot
class _TabBadge extends StatelessWidget {
  final int count;
  final bool showDot;

  const _TabBadge({required this.count, this.showDot = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: context.border.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AccentColors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
