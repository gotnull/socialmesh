// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCore Messages container: holds Contacts and Channels in two
// sub-tabs, mirroring `MessagesContainerScreen` on the Meshtastic
// side. The parent shell exposes a single "Messages" entry in the
// bottom nav; folding Contacts + Channels into one container keeps
// the UI shape identical across protocols.
//
// The Channels child renders with `embedded: true` so it skips its
// own GlassScaffold app bar (this container owns the title + actions
// + tab bar). The Contacts child is the conversations-only
// `MeshCoreMessagingScreen`, which is always embedded by design.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../navigation/meshcore_shell.dart';
import 'meshcore_channels_screen.dart';
import 'meshcore_messaging_screen.dart';

class MeshCoreMessagesContainerScreen extends ConsumerStatefulWidget {
  const MeshCoreMessagesContainerScreen({super.key});

  @override
  ConsumerState<MeshCoreMessagesContainerScreen> createState() =>
      _MeshCoreMessagesContainerScreenState();
}

class _MeshCoreMessagesContainerScreenState
    extends ConsumerState<MeshCoreMessagesContainerScreen>
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
    // Mirrors `MessagesContainerScreen.build`: the TabBarView is
    // scrollable so it lives inside a SliverFillRemaining(
    // hasScrollBody: true) child — never in `GlassScaffold.body(body:)`
    // (lint enforces `no-scrollable-in-glass-body`).
    return GlassScaffold(
      resizeToAvoidBottomInset: false,
      leading: const MeshCoreHamburgerMenuButton(),
      centerTitle: true,
      title: context.l10n.messagesContainerTitle,
      actions: const [MeshCoreDeviceStatusButton()],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: context.border.withValues(alpha: 0.3)),
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
              Tab(text: context.l10n.messagesContactsTab),
              Tab(text: context.l10n.messagesChannelsTab),
            ],
          ),
        ),
      ),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: true,
          child: TabBarView(
            controller: _tabController,
            children: const [
              // Contacts sub-tab inside Messages: only contacts with
              // an active DM conversation. The full roster (every
              // discovered peer) lives on the standalone Nodes
              // top-level tab.
              MeshCoreMessagingScreen(),
              MeshCoreChannelsScreen(embedded: true),
            ],
          ),
        ),
      ],
    );
  }
}
