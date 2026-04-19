// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:io';

import '../../../core/l10n/l10n_extension.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/logging.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bar_overflow_menu.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/glass_scaffold.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/node_selector_sheet.dart';
import '../../../core/widgets/search_filter_header.dart';
import '../../../core/widgets/status_filter_chip.dart';
import '../../../providers/file_transfer_providers.dart';
import '../../../services/file_transfer/file_transfer_engine.dart';
import '../../../services/haptic_service.dart';
import '../../../utils/snackbar.dart';
import '../widgets/file_content_preview.dart';
import '../widgets/file_transfer_card.dart';
import '../widgets/file_transfer_image_gallery.dart';

/// Dedicated screen for viewing and managing all file transfers.
///
/// Shows active, completed, and failed transfers. Allows users to
/// cancel active transfers, save/share completed files, and purge
/// expired entries.
///
/// When [embedded] is true, renders without its own GlassScaffold
/// so it can be used as a tab child in [FileTransfersContainerScreen].
class FileTransfersScreen extends ConsumerStatefulWidget {
  const FileTransfersScreen({
    super.key,
    this.embedded = false,
    this.onSwitchToContacts,
  });

  /// Used when embedded in tabs.
  final bool embedded;

  /// When non-null and [embedded] is true, the empty-state button
  /// navigates to the Contacts tab instead of launching a file picker.
  final VoidCallback? onSwitchToContacts;

  @override
  ConsumerState<FileTransfersScreen> createState() =>
      _FileTransfersScreenState();
}

class _FileTransfersScreenState extends ConsumerState<FileTransfersScreen>
    with LifecycleSafeMixin {
  _TransferFilter _filter = _TransferFilter.all;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final transferState = ref.watch(fileTransferStateProvider);
    final transfers = _filteredTransfers(transferState);

    final bodyContent = CustomScrollView(
      // When embedded inside a TabBarView that is itself inside
      // GlassScaffold's outer CustomScrollView, the inner scroll must:
      //  - use ClampingScrollPhysics to avoid bounce-fighting with the
      //    outer BouncingScrollPhysics (kGlassScrollPhysics),
      //  - set primary: false so it doesn't compete for the
      //    PrimaryScrollController.
      // Without this, a short list (e.g. 1 file) causes the card to
      // stick behind the pinned search header with no way to scroll down.
      physics: widget.embedded ? const ClampingScrollPhysics() : null,
      primary: !widget.embedded,
      slivers: [
        // Top padding
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing8)),

        // Pinned search + filter controls
        SliverPersistentHeader(
          pinned: true,
          delegate: SearchFilterHeaderDelegate(
            searchController: _searchController,
            searchQuery: _searchQuery,
            onSearchChanged: (value) {
              safeSetState(() => _searchQuery = value);
            },
            hintText: context.l10n.fileTransferSearchHint,
            textScaler: MediaQuery.textScalerOf(context),
            rebuildKey: Object.hashAll([
              _filter,
              transferState.sortedTransfers.length,
              transferState.activeTransfers.length,
            ]),
            filterChips: _buildFilterChips(transferState),
          ),
        ),

        // Transfer list or empty state
        if (transferState.isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (transfers.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final transfer = transfers[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
                  child: FileTransferCard(
                    transfer: transfer,
                    onTap: () => _showTransferDetail(transfer),
                    onInfo: () => _showInfoSheet(transfer),
                    onCancel:
                        transfer.isActive &&
                            transfer.state != TransferState.offerPending
                        ? () => _cancelTransfer(transfer)
                        : null,
                    onAccept: transfer.state == TransferState.offerPending
                        ? () => _acceptTransfer(transfer)
                        : null,
                    onReject: transfer.state == TransferState.offerPending
                        ? () => _rejectTransfer(transfer)
                        : null,
                    onShare: transfer.state == TransferState.complete
                        ? () => _shareFile(transfer)
                        : null,
                    onDelete: !transfer.isActive
                        ? () => _deleteTransfer(transfer)
                        : null,
                  ),
                );
              }, childCount: transfers.length),
            ),
          ),

        // Bottom spacing
        const SliverToBoxAdapter(child: SizedBox(height: AppTheme.spacing24)),
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
      child: GlassScaffold(
        resizeToAvoidBottomInset: false,
        title: context.l10n.fileTransferTitle,
        actions: [
          AppBarOverflowMenu<String>(
            onSelected: (value) => _handleOverflowAction(value),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                value: 'pick_file',
                child: ListTile(
                  leading: Icon(
                    Icons.attach_file,
                    color: context.accentColor,
                    size: 20,
                  ),
                  title: Text(context.l10n.fileTransferSendFile),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem<String>(
                value: 'clear_done',
                child: ListTile(
                  leading: Icon(
                    Icons.cleaning_services_outlined,
                    color: context.textSecondary,
                    size: 20,
                  ),
                  title: Text(context.l10n.fileTransferClearCompleted),
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
                  title: Text(context.l10n.fileTransferPurgeExpired),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
        slivers: [SliverFillRemaining(hasScrollBody: true, child: bodyContent)],
      ),
    );
  }

  List<Widget> _buildFilterChips(FileTransferListState transferState) {
    final activeCount = transferState.activeTransfers.length;
    final allCount = transferState.sortedTransfers.length;
    final inboundCount = transferState.sortedTransfers
        .where((t) => t.direction == TransferDirection.inbound)
        .length;
    final outboundCount = transferState.sortedTransfers
        .where((t) => t.direction == TransferDirection.outbound)
        .length;
    final doneCount = transferState.sortedTransfers
        .where(
          (t) =>
              t.state == TransferState.complete ||
              t.state == TransferState.failed ||
              t.state == TransferState.cancelled,
        )
        .length;

    return [
      StatusFilterChip(
        label: context.l10n.fileTransferFilterAll,
        count: allCount,
        isSelected: _filter == _TransferFilter.all,
        onTap: () => safeSetState(() => _filter = _TransferFilter.all),
      ),
      StatusFilterChip(
        label: context.l10n.fileTransferFilterActive,
        count: activeCount,
        color: AccentColors.cyan,
        isSelected: _filter == _TransferFilter.active,
        onTap: () => safeSetState(() => _filter = _TransferFilter.active),
      ),
      StatusFilterChip(
        label: context.l10n.fileTransferFilterDone,
        count: doneCount,
        color: SemanticColors.success,
        icon: Icons.check_circle_outline,
        isSelected: _filter == _TransferFilter.completed,
        onTap: () => safeSetState(() => _filter = _TransferFilter.completed),
      ),
      StatusFilterChip(
        label: context.l10n.fileTransferFilterReceived,
        count: inboundCount,
        color: AppTheme.primaryPurple,
        icon: Icons.arrow_downward,
        isSelected: _filter == _TransferFilter.inbound,
        onTap: () => safeSetState(() => _filter = _TransferFilter.inbound),
      ),
      StatusFilterChip(
        label: context.l10n.fileTransferFilterSent,
        count: outboundCount,
        color: AppTheme.primaryBlue,
        icon: Icons.arrow_upward,
        isSelected: _filter == _TransferFilter.outbound,
        onTap: () => safeSetState(() => _filter = _TransferFilter.outbound),
      ),
    ];
  }

  List<FileTransferState> _filteredTransfers(FileTransferListState state) {
    var all = state.sortedTransfers;

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      all = all.where((t) {
        return t.filename.toLowerCase().contains(query) ||
            t.fileIdHex.toLowerCase().contains(query) ||
            t.mimeType.toLowerCase().contains(query) ||
            (t.targetNodeNum != null &&
                '!${t.targetNodeNum!.toRadixString(16)}'.toLowerCase().contains(
                  query,
                )) ||
            (t.sourceNodeNum != null &&
                '!${t.sourceNodeNum!.toRadixString(16)}'.toLowerCase().contains(
                  query,
                ));
      }).toList();
    }

    // Apply category filter
    switch (_filter) {
      case _TransferFilter.all:
        return all;
      case _TransferFilter.active:
        return all.where((t) => t.isActive).toList();
      case _TransferFilter.completed:
        return all
            .where(
              (t) =>
                  t.state == TransferState.complete ||
                  t.state == TransferState.failed ||
                  t.state == TransferState.cancelled,
            )
            .toList();
      case _TransferFilter.inbound:
        return all
            .where((t) => t.direction == TransferDirection.inbound)
            .toList();
      case _TransferFilter.outbound:
        return all
            .where((t) => t.direction == TransferDirection.outbound)
            .toList();
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.swap_vert_outlined, size: 80, color: context.textTertiary),
          const SizedBox(height: AppTheme.spacing24),
          Text(
            _filter == _TransferFilter.all
                ? context.l10n.fileTransferEmptyTitle
                : context.l10n.fileTransferEmptyFilterTitle(_filter.label),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: context.textSecondary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            _filter == _TransferFilter.all
                ? widget.embedded
                      ? context.l10n.fileTransferEmptyDescriptionContacts
                      : context.l10n.fileTransferEmptyDescriptionOverflow
                : context.l10n.fileTransferNoMatchFilter,
            textAlign: TextAlign.center,
            style: context.bodySecondaryStyle?.copyWith(
              color: context.textTertiary,
            ),
          ),
          if (_filter == _TransferFilter.all) ...[
            const SizedBox(height: AppTheme.spacing24),
            if (widget.embedded && widget.onSwitchToContacts != null)
              FilledButton.icon(
                onPressed: widget.onSwitchToContacts,
                icon: const Icon(Icons.people_outline),
                label: Text(context.l10n.fileTransferGoToContacts),
              )
            else
              FilledButton.icon(
                onPressed: _pickAndSendFile,
                icon: const Icon(Icons.attach_file),
                label: Text(context.l10n.fileTransferSendAFile),
              ),
          ],
        ],
      ),
    );
  }

  void _handleOverflowAction(String value) {
    switch (value) {
      case 'pick_file':
        _pickAndSendFile();
      case 'clear_done':
        _clearTerminal();
      case 'purge':
        _purgeExpired();
    }
  }

  Future<void> _pickAndSendFile() async {
    final haptics = ref.read(hapticServiceProvider);
    final notifier = ref.read(fileTransferStateProvider.notifier);

    await haptics.trigger(HapticType.medium);
    if (!mounted) return;

    // Step 1: Pick destination node
    final selection = await NodeSelectorSheet.show(
      context,
      title: context.l10n.fileTransferSendToNode,
      allowBroadcast: false,
    );
    final nodeNum = selection?.nodeNum;
    if (nodeNum == null) return;
    if (!mounted) return;

    // Step 2: Pick file and send
    final transfer = await notifier.pickAndSendFile(targetNodeNum: nodeNum);

    if (!mounted) return;
    if (transfer != null) {
      showSuccessSnackBar(
        context,
        context.l10n.fileTransferStarted(transfer.filename),
      );
    }
  }

  void _cancelTransfer(FileTransferState transfer) async {
    final haptics = ref.read(hapticServiceProvider);
    final notifier = ref.read(fileTransferStateProvider.notifier);

    await haptics.trigger(HapticType.light);
    if (!mounted) return;

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.fileTransferCancelTitle,
      message: context.l10n.fileTransferCancelMessage(transfer.filename),
      confirmLabel: context.l10n.fileTransferCancelConfirm,
      isDestructive: true,
    );

    if (confirmed != true) return;
    if (!mounted) return;

    notifier.cancelTransfer(transfer.fileIdHex);
    showSuccessSnackBar(context, context.l10n.fileTransferCancelled);
  }

  Future<void> _shareFile(FileTransferState transfer) async {
    final haptics = ref.read(hapticServiceProvider);
    final notifier = ref.read(fileTransferStateProvider.notifier);

    await haptics.trigger(HapticType.light);
    if (!mounted) return;

    AppLogging.fileTransfer(
      'User sharing file: ${transfer.fileIdHex} (${transfer.filename})',
    );

    // If already saved, share directly without re-writing.
    String? path = transfer.savedFilePath;
    if (path != null && !File(path).existsSync()) path = null;

    if (path == null) {
      path = await notifier.saveReceivedFile(transfer.fileIdHex);
      if (!mounted) return;
    }

    if (path == null) {
      showErrorSnackBar(
        context,
        context.l10n.fileTransferCouldNotSaveForSharing,
      );
      return;
    }

    await Share.shareXFiles([XFile(path)], text: transfer.filename);
  }

  Future<void> _purgeExpired() async {
    final haptics = ref.read(hapticServiceProvider);
    final notifier = ref.read(fileTransferStateProvider.notifier);

    await haptics.trigger(HapticType.light);
    if (!mounted) return;

    await notifier.purgeExpired();
    if (!mounted) return;

    showSuccessSnackBar(context, context.l10n.fileTransferExpiredPurged);
  }

  Future<void> _clearTerminal() async {
    final haptics = ref.read(hapticServiceProvider);
    final notifier = ref.read(fileTransferStateProvider.notifier);

    await haptics.trigger(HapticType.light);
    if (!mounted) return;

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.fileTransferClearTitle,
      message: context.l10n.fileTransferClearMessage,
      confirmLabel: context.l10n.fileTransferClearConfirm,
      isDestructive: true,
    );

    if (confirmed != true) return;
    if (!mounted) return;

    final count = await notifier.clearTerminalTransfers();
    if (!mounted) return;

    showSuccessSnackBar(context, context.l10n.fileTransferClearedCount(count));
  }

  Future<void> _deleteTransfer(FileTransferState transfer) async {
    final haptics = ref.read(hapticServiceProvider);
    final notifier = ref.read(fileTransferStateProvider.notifier);

    await haptics.trigger(HapticType.light);
    if (!mounted) return;

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.fileTransferDeleteTitle,
      message: context.l10n.fileTransferDeleteMessage(transfer.filename),
      confirmLabel: context.l10n.fileTransferDeleteConfirm,
      isDestructive: true,
    );

    if (confirmed != true) return;
    if (!mounted) return;

    await notifier.deleteTransfer(transfer.fileIdHex);
    if (!mounted) return;

    showSuccessSnackBar(
      context,
      context.l10n.fileTransferDeleted(transfer.filename),
    );
  }

  void _acceptTransfer(FileTransferState transfer) {
    final haptics = ref.read(hapticServiceProvider);
    final notifier = ref.read(fileTransferStateProvider.notifier);

    haptics.trigger(HapticType.medium);
    notifier.acceptTransfer(transfer.fileIdHex);
    showSuccessSnackBar(
      context,
      context.l10n.fileTransferAccepted(transfer.filename),
    );
  }

  void _rejectTransfer(FileTransferState transfer) async {
    final haptics = ref.read(hapticServiceProvider);
    final notifier = ref.read(fileTransferStateProvider.notifier);

    await haptics.trigger(HapticType.light);
    if (!mounted) return;

    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: context.l10n.fileTransferRejectTitle,
      message: context.l10n.fileTransferRejectMessage(transfer.filename),
      confirmLabel: context.l10n.fileTransferRejectConfirm,
      isDestructive: true,
    );

    if (confirmed != true) return;
    if (!mounted) return;

    notifier.rejectTransfer(transfer.fileIdHex);
    showSuccessSnackBar(context, context.l10n.fileTransferRejected);
  }

  void _showTransferDetail(FileTransferState transfer) {
    // For completed image transfers, open the fullscreen gallery for a
    // proper viewing experience (pinch-to-zoom, immersive black background).
    if (FileTransferImageGallery.canShow(transfer)) {
      FileTransferImageGallery.show(context, transfer: transfer);
      return;
    }

    // For completed non-image transfers with content, open the bottom sheet.
    // FileContentPreview handles both in-memory bytes and a saved path on disk.
    if (transfer.state == TransferState.complete) {
      final canPreview =
          (transfer.fileBytes != null && transfer.fileBytes!.isNotEmpty) ||
          transfer.savedFilePath != null;
      if (canPreview) {
        FileContentPreview.show(context: context, transfer: transfer);
        return;
      }
    }
    // No previewable content — fall back to the detail sheet.
    _showInfoSheet(transfer);
  }

  void _showInfoSheet(FileTransferState transfer) {
    final isOutbound = transfer.direction == TransferDirection.outbound;
    final rows = <InfoTableRow>[
      InfoTableRow(
        label: context.l10n.fileTransferInfoDirection,
        value: isOutbound
            ? context.l10n.fileTransferInfoDirectionSent
            : context.l10n.fileTransferInfoDirectionReceived,
        icon: isOutbound ? Icons.arrow_upward : Icons.arrow_downward,
        iconColor: isOutbound ? AppTheme.primaryBlue : AppTheme.primaryPurple,
      ),
      InfoTableRow(
        label: context.l10n.fileTransferInfoStatus,
        value: _transferStateLabel(transfer.state),
        icon: _transferStateIcon(transfer.state, isOutbound),
        iconColor: _transferStateColor(context, transfer.state),
      ),
      InfoTableRow(
        label: context.l10n.fileTransferInfoSize,
        value: _formatTransferSize(transfer.totalBytes),
        icon: Icons.storage,
      ),
      InfoTableRow(
        label: context.l10n.fileTransferInfoMimeType,
        value: transfer.mimeType,
        icon: Icons.description_outlined,
      ),
      InfoTableRow(
        label: context.l10n.fileTransferInfoChunks,
        value: '${transfer.completedChunks.length}/${transfer.chunkCount}',
        icon: Icons.grid_view,
      ),
      InfoTableRow(
        label: context.l10n.fileTransferInfoChunkSize,
        value: '${transfer.chunkSize} B',
        icon: Icons.straighten,
      ),
      if (transfer.targetNodeNum != null)
        InfoTableRow(
          label: context.l10n.fileTransferInfoTargetNode,
          value: '!${transfer.targetNodeNum!.toRadixString(16)}',
          icon: Icons.tag,
        ),
      if (transfer.sourceNodeNum != null)
        InfoTableRow(
          label: context.l10n.fileTransferInfoSourceNode,
          value: '!${transfer.sourceNodeNum!.toRadixString(16)}',
          icon: Icons.tag,
        ),
      InfoTableRow(
        label: context.l10n.fileTransferInfoCreated,
        value: _formatTransferDateTime(transfer.createdAt),
        icon: Icons.schedule,
      ),
      InfoTableRow(
        label: context.l10n.fileTransferInfoExpires,
        value: _formatTransferDateTime(transfer.expiresAt),
        icon: Icons.timer_off_outlined,
      ),
      if (transfer.completedAt != null)
        InfoTableRow(
          label: context.l10n.fileTransferInfoCompleted,
          value: _formatTransferDateTime(transfer.completedAt!),
          icon: Icons.check_circle_outline,
          iconColor: SemanticColors.success,
        ),
      if (transfer.failReason != null)
        InfoTableRow(
          label: context.l10n.fileTransferInfoFailure,
          value: transfer.failReason!.name,
          icon: Icons.error_outline,
          iconColor: SemanticColors.error,
        ),
      if (transfer.nackRounds > 0)
        InfoTableRow(
          label: context.l10n.fileTransferInfoNackRounds,
          value: '${transfer.nackRounds}',
          icon: Icons.sync_problem,
          iconColor: SemanticColors.warning,
        ),
      InfoTableRow(
        label: context.l10n.fileTransferInfoTransferId,
        value: transfer.fileIdHex.substring(
          0,
          transfer.fileIdHex.length.clamp(0, 16),
        ),
        icon: Icons.fingerprint,
      ),
    ];
    InfoTableSheet.show(
      context: context,
      title: transfer.filename,
      sectionLabel: context.l10n.fileTransferDetailsSection,
      rows: rows,
      footer: transfer.isActive
          ? _TransferProgressFooter(transfer: transfer)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Filter bar
// ---------------------------------------------------------------------------

enum _TransferFilter {
  all('All'),
  active('Active'),
  completed('Done'),
  inbound('Received'),
  outbound('Sent');

  const _TransferFilter(this.label);
  final String label;
}

// ---------------------------------------------------------------------------
// File-scope helpers for the transfer detail sheet
// ---------------------------------------------------------------------------

String _transferStateLabel(TransferState state) => switch (state) {
  TransferState.created => 'Preparing',
  TransferState.offerSent => 'Offer Sent',
  TransferState.offerPending => 'Pending Acceptance',
  TransferState.chunking => 'Transferring',
  TransferState.waitingMissing => 'Recovering',
  TransferState.complete => 'Complete',
  TransferState.failed => 'Failed',
  TransferState.cancelled => 'Cancelled',
  TransferState.awaitingAccept => 'Awaiting Accept',
};

IconData _transferStateIcon(TransferState state, bool isOutbound) =>
    switch (state) {
      TransferState.created ||
      TransferState.offerSent ||
      TransferState.awaitingAccept => Icons.schedule,
      TransferState.offerPending => Icons.inbox,
      TransferState.chunking => isOutbound ? Icons.upload : Icons.download,
      TransferState.waitingMissing => Icons.sync_problem,
      TransferState.complete => Icons.check_circle_outline,
      TransferState.failed => Icons.error_outline,
      TransferState.cancelled => Icons.cancel_outlined,
    };

Color _transferStateColor(BuildContext context, TransferState state) =>
    switch (state) {
      TransferState.created ||
      TransferState.offerSent ||
      TransferState.awaitingAccept ||
      TransferState.cancelled => context.textTertiary,
      TransferState.offerPending ||
      TransferState.waitingMissing => SemanticColors.warning,
      TransferState.chunking => context.accentColor,
      TransferState.complete => SemanticColors.success,
      TransferState.failed => SemanticColors.error,
    };

String _formatTransferSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  return '${(bytes / 1024.0).toStringAsFixed(1)} KB';
}

String _formatTransferDateTime(DateTime dt) {
  return '${dt.month}/${dt.day} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Progress footer for active transfers
// ---------------------------------------------------------------------------

class _TransferProgressFooter extends StatelessWidget {
  const _TransferProgressFooter({required this.transfer});

  final FileTransferState transfer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radius4),
          child: LinearProgressIndicator(
            value: transfer.progress,
            minHeight: 6,
            backgroundColor: context.border.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation(context.accentColor),
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${(transfer.progress * 100).toStringAsFixed(0)}%',
            style: TextStyle(color: context.textTertiary, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
