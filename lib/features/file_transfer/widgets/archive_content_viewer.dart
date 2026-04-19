// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../services/archive/archive_models.dart';
import '../../../services/file_transfer/file_transfer_engine.dart';
import '../providers/archive_providers.dart';
import 'file_content_preview.dart';

/// Displays archive (ZIP) contents in a scrollable bottom sheet.
///
/// Shows a summary banner and a list of entries with type badges,
/// sizes, and action buttons for supported entries.
class ArchiveContentViewer {
  ArchiveContentViewer._();

  /// Shows the archive content viewer for a completed ZIP transfer.
  ///
  /// [bytes] are the raw archive bytes (from memory or disk).
  /// [transfer] is the file transfer state for metadata.
  static void show({
    required BuildContext context,
    required Uint8List bytes,
    required FileTransferState transfer,
  }) {
    AppBottomSheet.showScrollable<void>(
      context: context,
      title: transfer.filename,
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      builder: (scrollController) {
        return _ArchiveContentBody(
          archiveBytes: bytes,
          transfer: transfer,
          scrollController: scrollController,
        );
      },
    );
  }
}

class _ArchiveContentBody extends ConsumerStatefulWidget {
  const _ArchiveContentBody({
    required this.archiveBytes,
    required this.transfer,
    required this.scrollController,
  });

  final Uint8List archiveBytes;
  final FileTransferState transfer;
  final ScrollController scrollController;

  @override
  ConsumerState<_ArchiveContentBody> createState() =>
      _ArchiveContentBodyState();
}

class _ArchiveContentBodyState extends ConsumerState<_ArchiveContentBody> {
  @override
  void initState() {
    super.initState();
    // Kick off inspection after first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(archiveInspectionProvider.notifier)
          .inspect(
            archiveBytes: widget.archiveBytes,
            archiveFilename: widget.transfer.filename,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final inspectionState = ref.watch(archiveInspectionProvider);

    if (inspectionState.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacing40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (inspectionState.error != null) {
      return _ErrorView(message: inspectionState.error!);
    }

    final manifest = inspectionState.manifest;
    if (manifest == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacing40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (!manifest.isValid) {
      return _RejectedArchiveView(manifest: manifest);
    }

    return _ArchiveEntryList(
      manifest: manifest,
      archiveBytes: widget.archiveBytes,
      transfer: widget.transfer,
      scrollController: widget.scrollController,
    );
  }
}

// ---------------------------------------------------------------------------
// Archive entry list with summary banner
// ---------------------------------------------------------------------------

class _ArchiveEntryList extends ConsumerWidget {
  const _ArchiveEntryList({
    required this.manifest,
    required this.archiveBytes,
    required this.transfer,
    required this.scrollController,
  });

  final ArchiveManifest manifest;
  final Uint8List archiveBytes;
  final FileTransferState transfer;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      children: [
        // Archive metadata bar
        _ArchiveMetadataBar(manifest: manifest),
        const SizedBox(height: AppTheme.spacing12),

        // Summary banner
        _SummaryBanner(manifest: manifest),
        const SizedBox(height: AppTheme.spacing16),

        // Section header
        Text(
          l10n.archiveContentsHeader,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),

        // Entry rows
        for (var i = 0; i < manifest.entries.length; i++) ...[
          _ArchiveEntryRow(
            entry: manifest.entries[i],
            entryIndex: i,
            archiveBytes: archiveBytes,
            transfer: transfer,
          ),
          if (i < manifest.entries.length - 1)
            Divider(color: context.border.withValues(alpha: 0.2), height: 1),
        ],

        const SizedBox(height: AppTheme.spacing16),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Archive metadata bar
// ---------------------------------------------------------------------------

class _ArchiveMetadataBar extends StatelessWidget {
  const _ArchiveMetadataBar({required this.manifest});

  final ArchiveManifest manifest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Row(
      children: [
        _MetadataChip(
          icon: Icons.storage,
          label: _formatSize(manifest.archiveSize),
        ),
        const SizedBox(width: AppTheme.spacing8),
        _MetadataChip(
          icon: Icons.folder_zip_outlined,
          label: l10n.archiveEntryCount(manifest.entryCount),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Summary banner
// ---------------------------------------------------------------------------

class _SummaryBanner extends StatelessWidget {
  const _SummaryBanner({required this.manifest});

  final ArchiveManifest manifest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final counts = manifest.categoryCounts;
    final parts = <String>[];

    final imageCount = counts['image'] ?? 0;
    if (imageCount > 0) {
      parts.add(l10n.archiveSummaryImages(imageCount));
    }
    final voiceCount = counts['voice'] ?? 0;
    if (voiceCount > 0) {
      parts.add(l10n.archiveSummaryVoice(voiceCount));
    }
    final textCount = counts['text'] ?? 0;
    if (textCount > 0) {
      parts.add(l10n.archiveSummaryText(textCount));
    }
    final otherCount = counts['other'] ?? 0;
    if (otherCount > 0) {
      parts.add(l10n.archiveSummaryOther(otherCount));
    }
    final unsupportedCount = counts['unsupported'] ?? 0;
    if (unsupportedCount > 0) {
      parts.add(l10n.archiveSummaryUnsupported(unsupportedCount));
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.accentColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(color: context.accentColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 18,
            color: context.accentColor,
          ),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              parts.join(', '),
              style: TextStyle(color: context.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual entry row
// ---------------------------------------------------------------------------

class _ArchiveEntryRow extends ConsumerWidget {
  const _ArchiveEntryRow({
    required this.entry,
    required this.entryIndex,
    required this.archiveBytes,
    required this.transfer,
  });

  final ArchiveEntry entry;
  final int entryIndex;
  final Uint8List archiveBytes;
  final FileTransferState transfer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // File type icon
          _EntryTypeIcon(mimeType: entry.mimeType, status: entry.status),
          const SizedBox(width: AppTheme.spacing12),

          // Filename and size
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.filename,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: entry.status == ArchiveEntryStatus.supported
                        ? context.textPrimary
                        : context.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTheme.spacing2),
                Row(
                  children: [
                    Text(
                      _formatSize(entry.uncompressedSize),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.textTertiary,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    _StatusBadge(status: entry.status),
                  ],
                ),
              ],
            ),
          ),

          // Action buttons
          ..._buildActions(context, ref),
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context, WidgetRef ref) {
    final actions = <Widget>[];
    final l10n = context.l10n;

    for (final action in entry.actions) {
      switch (action) {
        case ArchiveEntryAction.preview:
          actions.add(
            _ActionButton(
              icon: Icons.visibility_outlined,
              label: l10n.archiveActionPreview,
              onTap: () => _onPreview(context, ref),
            ),
          );
        case ArchiveEntryAction.play:
          actions.add(
            _ActionButton(
              icon: Icons.play_arrow_outlined,
              label: l10n.archiveActionPlay,
              onTap: () => _onPreview(context, ref),
            ),
          );
        case ArchiveEntryAction.save:
          actions.add(
            _ActionButton(
              icon: Icons.save_alt_outlined,
              label: l10n.archiveActionSave,
              onTap: () => _onSave(context, ref),
            ),
          );
      }
    }

    return actions;
  }

  void _onPreview(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    final bytes = ref
        .read(archiveInspectionProvider.notifier)
        .extractEntry(archiveBytes: archiveBytes, entryIndex: entryIndex);
    if (bytes == null || !context.mounted) return;

    // Build a synthetic transfer state for the entry preview.
    final syntheticTransfer = FileTransferState(
      fileIdHex: '${transfer.fileIdHex}_entry_$entryIndex',
      fileId: transfer.fileId,
      direction: transfer.direction,
      state: TransferState.complete,
      filename: entry.filename,
      mimeType: entry.mimeType,
      totalBytes: bytes.length,
      chunkSize: transfer.chunkSize,
      chunkCount: 1,
      sha256Hash: transfer.sha256Hash,
      completedChunks: const {0},
      nackRounds: 0,
      createdAt: transfer.createdAt,
      expiresAt: transfer.expiresAt,
      fileBytes: bytes,
    );

    FileContentPreview.show(context: context, transfer: syntheticTransfer);
  }

  void _onSave(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    final bytes = ref
        .read(archiveInspectionProvider.notifier)
        .extractEntry(archiveBytes: archiveBytes, entryIndex: entryIndex);
    if (bytes == null || !context.mounted) return;

    // Build synthetic transfer for the existing save flow.
    final syntheticTransfer = FileTransferState(
      fileIdHex: '${transfer.fileIdHex}_entry_$entryIndex',
      fileId: transfer.fileId,
      direction: transfer.direction,
      state: TransferState.complete,
      filename: entry.filename,
      mimeType: entry.mimeType,
      totalBytes: bytes.length,
      chunkSize: transfer.chunkSize,
      chunkCount: 1,
      sha256Hash: transfer.sha256Hash,
      completedChunks: const {0},
      nackRounds: 0,
      createdAt: transfer.createdAt,
      expiresAt: transfer.expiresAt,
      fileBytes: bytes,
    );

    FileContentPreview.show(context: context, transfer: syntheticTransfer);
  }
}

// ---------------------------------------------------------------------------
// Entry type icon
// ---------------------------------------------------------------------------

class _EntryTypeIcon extends StatelessWidget {
  const _EntryTypeIcon({required this.mimeType, required this.status});

  final String mimeType;
  final ArchiveEntryStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status) {
      ArchiveEntryStatus.blocked => (Icons.block, SemanticColors.error),
      ArchiveEntryStatus.tooLarge => (
        Icons.warning_amber,
        SemanticColors.warning,
      ),
      ArchiveEntryStatus.nestedArchive => (
        Icons.folder_zip,
        SemanticColors.warning,
      ),
      ArchiveEntryStatus.unsupported => (
        Icons.help_outline,
        SemanticColors.disabled,
      ),
      ArchiveEntryStatus.supported => _iconForMime(mimeType),
    };

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Icon(icon, size: 18, color: color),
    );
  }

  (IconData, Color) _iconForMime(String mime) {
    if (mime.startsWith('image/')) {
      return (Icons.image_outlined, SemanticColors.info);
    }
    if (mime == 'audio/x-codec2' || mime.startsWith('audio/')) {
      return (Icons.audiotrack_outlined, AccentColors.purple);
    }
    if (mime.startsWith('text/') ||
        mime.contains('json') ||
        mime.contains('xml')) {
      return (Icons.description_outlined, SemanticColors.success);
    }
    return (Icons.insert_drive_file_outlined, SemanticColors.disabled);
  }
}

// ---------------------------------------------------------------------------
// Status badge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final ArchiveEntryStatus status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final (label, color) = switch (status) {
      ArchiveEntryStatus.supported => (
        l10n.archiveStatusSupported,
        SemanticColors.success,
      ),
      ArchiveEntryStatus.unsupported => (
        l10n.archiveStatusUnsupported,
        SemanticColors.disabled,
      ),
      ArchiveEntryStatus.tooLarge => (
        l10n.archiveStatusTooLarge,
        SemanticColors.warning,
      ),
      ArchiveEntryStatus.blocked => (
        l10n.archiveStatusBlocked,
        SemanticColors.error,
      ),
      ArchiveEntryStatus.nestedArchive => (
        l10n.archiveStatusNested,
        SemanticColors.warning,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action button
// ---------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: AppTheme.spacing4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radius6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: context.accentColor),
              const SizedBox(width: AppTheme.spacing4),
              Text(
                label,
                style: TextStyle(
                  color: context.accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Metadata chip (same style as file_content_preview.dart)
// ---------------------------------------------------------------------------

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: context.border.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radius6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: context.textTertiary),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            label,
            style: TextStyle(
              color: context.textTertiary,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rejected archive view
// ---------------------------------------------------------------------------

class _RejectedArchiveView extends StatelessWidget {
  const _RejectedArchiveView({required this.manifest});

  final ArchiveManifest manifest;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final message = switch (manifest.rejectReason) {
      ArchiveRejectReason.encrypted => l10n.archiveRejectEncrypted,
      ArchiveRejectReason.corrupt => l10n.archiveRejectCorrupt,
      ArchiveRejectReason.tooManyEntries => l10n.archiveRejectTooManyEntries,
      ArchiveRejectReason.totalSizeTooLarge =>
        l10n.archiveRejectTotalSizeTooLarge,
      null => l10n.archiveRejectCorrupt,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            manifest.isEncrypted ? Icons.lock_outline : Icons.warning_amber,
            size: 64,
            color: SemanticColors.warning,
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: AppTheme.spacing8),
          Text(
            l10n.archiveRejectSaveHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error view
// ---------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.broken_image_outlined,
            size: 64,
            color: context.textTertiary,
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024.0;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
  final mb = kb / 1024.0;
  return '${mb.toStringAsFixed(1)} MB';
}
