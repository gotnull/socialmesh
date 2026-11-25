// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/ico_help_system.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/file_transfer_providers.dart';
import '../../../providers/help_providers.dart';
import '../../../services/haptic_service.dart';
import '../../../utils/snackbar.dart';
import '../../navigation/main_shell.dart';
import 'file_transfer_contacts_screen.dart';
import 'file_transfers_screen.dart';

/// Container screen that holds both Transfers and Contacts in tabs.
///
/// Follows the same pattern as [MessagesContainerScreen] for a unified
/// "File Transfers" experience with tab navigation.
class FileTransfersContainerScreen extends ConsumerStatefulWidget {
  const FileTransfersContainerScreen({super.key});

  @override
  ConsumerState<FileTransfersContainerScreen> createState() =>
      _FileTransfersContainerScreenState();
}

class _FileTransfersContainerScreenState
    extends ConsumerState<FileTransfersContainerScreen>
    with SingleTickerProviderStateMixin, LifecycleSafeMixin {
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
    final transferState = ref.watch(fileTransferStateProvider);
    final fileCount = transferState.sortedTransfers.length;
    final activeCount = transferState.activeTransfers.length;
    final pendingCount = ref.watch(pendingTransferCountProvider);
    final nodes = ref.watch(nodesProvider);
    final myNodeNum = ref.watch(myNodeNumProvider);
    final contactCount = nodes.values
        .where((n) => n.nodeNum != myNodeNum)
        .length;

    final route = ModalRoute.of(context);
    final canPop = route != null ? !route.isFirst : Navigator.canPop(context);

    return HelpTourController(
      topicId: 'file_transfer_overview',
      stepKeys: const {},
      child: GlassScaffold(
        resizeToAvoidBottomInset: false,
        leading: canPop ? const BackButton() : const HamburgerMenuButton(),
        centerTitle: true,
        title: context.l10n.fileTransferContainerTitle,
        actions: [
          const DeviceStatusButton(),
          AppBarOverflowMenu<String>(
            onSelected: _handleOverflowAction,
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'clear_done',
                child: ListTile(
                  leading: Icon(
                    Icons.cleaning_services_outlined,
                    color: context.textSecondary,
                    size: 20,
                  ),
                  title: Text(context.l10n.fileTransferContainerClearCompleted),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<String>(
                value: 'purge',
                child: ListTile(
                  leading: Icon(
                    Icons.delete_sweep_outlined,
                    color: context.textSecondary,
                    size: 20,
                  ),
                  title: Text(context.l10n.fileTransferContainerPurgeExpired),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'help',
                child: ListTile(
                  leading: Icon(
                    Icons.help_outline,
                    color: context.textSecondary,
                    size: 20,
                  ),
                  title: Text(context.l10n.fileTransferContainerMenuHelp),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
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
                      Text(context.l10n.fileTransferTabContacts),
                      const SizedBox(width: AppTheme.spacing6),
                      _TabBadge(count: contactCount),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.l10n.fileTransferTabFiles),
                      const SizedBox(width: AppTheme.spacing6),
                      _TabBadge(
                        count: fileCount,
                        showDot: activeCount > 0 || pendingCount > 0,
                      ),
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
              children: [
                const FileTransferContactsScreen(),
                FileTransfersScreen(
                  embedded: true,
                  onSwitchToContacts: () => _tabController.animateTo(0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleOverflowAction(String value) {
    switch (value) {
      case 'clear_done':
        _clearTerminal();
      case 'purge':
        _purgeExpired();
      case 'help':
        ref.read(helpProvider.notifier).startTour('file_transfer_overview');
    }
  }

  Future<void> _clearTerminal() async {
    final haptics = ref.read(hapticServiceProvider);
    final notifier = ref.read(fileTransferStateProvider.notifier);

    await haptics.trigger(HapticType.light);
    if (!mounted) return;

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.fileTransferContainerClearTitle,
      message: context.l10n.fileTransferContainerClearMessage,
      confirmLabel: context.l10n.fileTransferContainerClearCompleted,
      isDestructive: true,
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final count = await notifier.clearTerminalTransfers();
    if (!mounted) return;

    showSuccessSnackBar(
      context,
      context.l10n.fileTransferContainerCleared(count),
    );
  }

  Future<void> _purgeExpired() async {
    final haptics = ref.read(hapticServiceProvider);
    final notifier = ref.read(fileTransferStateProvider.notifier);

    await haptics.trigger(HapticType.light);
    if (!mounted) return;

    await notifier.purgeExpired();
    if (!mounted) return;

    showSuccessSnackBar(context, context.l10n.fileTransferContainerPurged);
  }
}

// ---------------------------------------------------------------------------
// Tab badge showing count and optional activity dot
// ---------------------------------------------------------------------------

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
        borderRadius: BorderRadius.circular(AppTheme.radius10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: AccentColors.cyan,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppTheme.spacing4),
          ],
          Text(
            context.formatCount(count),
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
