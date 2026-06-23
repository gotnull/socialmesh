// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:async';

import '../../core/l10n/l10n_extension.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socialmesh/core/transport.dart';
import '../../core/widgets/ico_help_system.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../utils/snackbar.dart';
import '../navigation/main_shell.dart';
import '../channels/channel_wizard_screen.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../channels/channels_screen.dart';
import 'messaging_screen.dart';

/// Requests the Messages container open a specific sub-tab
/// (0 = Contacts, 1 = Channels). Set by the bottom-nav Messages tap when
/// there is unread; consumed (cleared) by the container once applied.
class MessagesSubtabRequestNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void request(int index) => state = index;

  void clear() => state = null;
}

final messagesSubtabRequestProvider =
    NotifierProvider<MessagesSubtabRequestNotifier, int?>(
      MessagesSubtabRequestNotifier.new,
    );

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

  // Set true while we drive the TabController programmatically (an
  // auto-switch to the unread sub-tab). Guards `_persistTabIndexIfChanged`
  // so an auto-switch never overwrites the user's chosen default sub-tab —
  // only user-driven swipes persist a new default.
  bool _suppressDefaultPersist = false;

  void _showAddChannelScreen(bool isConnected) {
    if (!isConnected) {
      showErrorSnackBar(context, context.l10n.messagesAddChannelNotConnected);
      return;
    }

    final channels = ref.read(channelsProvider);
    final usedIndices = channels.map((c) => c.index).toSet();
    int nextIndex = 1;
    for (int i = 1; i <= 7; i++) {
      if (!usedIndices.contains(i)) {
        nextIndex = i;
        break;
      }
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChannelWizardScreen(channelIndex: nextIndex),
      ),
    );
  }

  void _openChannelScanner(bool isConnected) {
    if (!isConnected) {
      showErrorSnackBar(context, context.l10n.messagesScanChannelNotConnected);
      return;
    }

    Navigator.of(context).pushNamed('/qr-scanner');
  }

  @override
  void initState() {
    super.initState();
    // Restore the last sub-tab the user landed on. Large-mesh users
    // typically live in Channels; persisting the index lets them avoid
    // swiping back on every cold start. Read synchronously off the
    // already-loaded settings service when present; fall back to 0 so
    // first launches stay on Contacts.
    final settings = ref.read(settingsServiceProvider).value;
    // A pending sub-tab request (from the bottom-nav Messages tap when
    // there is unread) wins over the persisted default on a fresh build.
    final pending = ref.read(messagesSubtabRequestProvider);
    final initialIndex = (pending ?? settings?.messagesDefaultSubtab ?? 0)
        .clamp(0, 1);
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(_persistTabIndexIfChanged);
    if (pending != null) {
      // Constructing with `initialIndex` does not fire the listener, so the
      // persisted default is left untouched. Clear the consumed request after
      // the first frame (avoid mutating a provider during build/init).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(messagesSubtabRequestProvider.notifier).clear();
      });
    }
  }

  void _persistTabIndexIfChanged() {
    // TabController fires the listener on every index/indexIsChanging
    // tick; we only persist when the index stabilises on a new value.
    if (_tabController.indexIsChanging) return;
    // An auto-switch to the unread sub-tab must not clobber the user's
    // chosen default; only user-driven swipes persist. Consume the flag
    // here, at the settle event, so it covers the whole animateTo.
    if (_suppressDefaultPersist) {
      _suppressDefaultPersist = false;
      return;
    }
    final settings = ref.read(settingsServiceProvider).value;
    if (settings == null) return;
    if (settings.messagesDefaultSubtab == _tabController.index) return;
    unawaited(settings.setMessagesDefaultSubtab(_tabController.index));
  }

  @override
  void dispose() {
    _tabController.removeListener(_persistTabIndexIfChanged);
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Handle a sub-tab request that arrives while the container is already
    // mounted (tapping Messages while already on it does not rebuild, so
    // initState's pending-request path does not run). Null transitions are
    // our own clears and are ignored.
    ref.listen<int?>(messagesSubtabRequestProvider, (prev, next) {
      if (next == null || !mounted) return;
      final target = next.clamp(0, 1);
      if (_tabController.index != target) {
        // Suppress persistence for this programmatic switch. The flag is
        // consumed when the animation settles (see _persistTabIndexIfChanged),
        // not on the next frame, so it outlives the animateTo duration.
        _suppressDefaultPersist = true;
        _tabController.animateTo(target);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(messagesSubtabRequestProvider.notifier).clear();
      });
    });

    final unreadDmCount = ref.watch(unreadDmCountProvider);
    final unreadChannelCount = ref.watch(unreadChannelCountProvider);
    final connectionStateAsync = ref.watch(connectionStateProvider);
    final currentConnectionState = connectionStateAsync.when(
      data: (state) => state,
      loading: () => DeviceConnectionState.connecting,
      error: (error, stack) => DeviceConnectionState.error,
    );
    final isConnected =
        currentConnectionState == DeviceConnectionState.connected;

    return HelpTourController(
      topicId: 'message_routing',
      stepKeys: const {},
      child: GlassScaffold(
        resizeToAvoidBottomInset: false,
        // Freeze the outer scrollview. Each tab body is its own
        // CustomScrollView; allowing the outer to bounce would drag
        // the inner viewport (including the pinned search/filter
        // chips) out from under the app bar+tabs. Inner scrollables
        // own the bounce now.
        physics: const ClampingScrollPhysics(),
        leading: const HamburgerMenuButton(),
        centerTitle: true,
        title: context.l10n.messagesContainerTitle,
        actions: [
          const DeviceStatusButton(),
          MessagingPopupMenu(
            isConnected: isConnected,
            onAddChannel: () => _showAddChannelScreen(isConnected),
            onScanChannel: () => _openChannelScanner(isConnected),
          ),
        ],
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
                      Text(context.l10n.messagesContactsTab),
                      _TabBadge(unreadCount: unreadDmCount),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.l10n.messagesChannelsTab),
                      _TabBadge(unreadCount: unreadChannelCount),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Use hasScrollBody: true because each TabBarView child contains
        // its own CustomScrollView. hasScrollBody: false would force
        // intrinsic dimension computation which CustomScrollView cannot
        // provide, causing a null check crash in RenderViewportBase.
        slivers: [
          SliverFillRemaining(
            hasScrollBody: true,
            child: TabBarView(
              controller: _tabController,
              children: const [
                MessagingScreen(embedded: true),
                ChannelsScreen(embedded: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Unread indicator for a tab: a small red pill with the unread count. It
/// renders only when there is unread content, so a tab with no badge means
/// nothing to act on (and the badge clears once the content is read). Owns
/// its own leading gap so the spacing vanishes with it.
class _TabBadge extends StatelessWidget {
  final int unreadCount;

  const _TabBadge({this.unreadCount = 0});

  @override
  Widget build(BuildContext context) {
    if (unreadCount <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: AppTheme.spacing6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        constraints: const BoxConstraints(minWidth: 20),
        decoration: BoxDecoration(
          color: AccentColors.red,
          borderRadius: BorderRadius.circular(AppTheme.radius10),
        ),
        child: Text(
          unreadCount > 99 ? '99+' : '$unreadCount',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: SemanticColors.onAccent,
          ),
        ),
      ),
    );
  }
}
