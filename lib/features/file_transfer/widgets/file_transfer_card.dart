// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';

import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../providers/app_providers.dart';
import '../../../services/file_transfer/file_transfer_engine.dart';
import '../../../services/voice/voice_mime.dart';
import '../../nodes/node_display_name_resolver.dart';

/// A card widget for displaying a file transfer (sending or receiving).
///
/// Follows the NodeDex visual language: rounded containers with subtle borders,
/// icon-bearing metric chips, and clean information hierarchy.
class FileTransferCard extends ConsumerWidget {
  const FileTransferCard({
    super.key,
    required this.transfer,
    this.onTap,
    this.onCancel,
    this.onRetry,
    this.onShare,
    this.onAccept,
    this.onReject,
    this.onDelete,
    this.onInfo,
    this.compact = false,
  });

  final FileTransferState transfer;
  final VoidCallback? onTap;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onShare;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onDelete;
  final VoidCallback? onInfo;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusColor = _statusColor(context);
    return BouncyTap(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius16),
          border: Border.all(
            color: transfer.isActive
                ? statusColor.withValues(alpha: 0.35)
                : context.border.withValues(alpha: 0.15),
            width: transfer.isActive ? 1.0 : 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: transfer.isActive
                  ? statusColor.withValues(alpha: 0.08)
                  : Colors.transparent,
              blurRadius: 14,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: compact
            ? Padding(
                padding: const EdgeInsets.all(AppTheme.spacing10),
                child: _buildCompact(context),
              )
            : Padding(
                padding: const EdgeInsets.all(AppTheme.spacing16),
                child: _buildFull(context, ref),
              ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Compact layout (used in signal feed embeds)
  // ---------------------------------------------------------------------------

  Widget _buildCompact(BuildContext context) {
    return Row(
      children: [
        _FileTypeIcon(mimeType: transfer.mimeType, size: 28),
        const SizedBox(width: AppTheme.spacing8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transfer.filename,
                style: TextStyle(
                  color: context.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: AppTheme.spacing2),
              Text(
                _statusText(context),
                style: TextStyle(color: _statusColor(context), fontSize: 11),
              ),
            ],
          ),
        ),
        if (transfer.isActive)
          SizedBox(
            width: 32,
            height: 32,
            child: _ProgressRing(progress: transfer.progress),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Full layout (NodeDex-style)
  // ---------------------------------------------------------------------------

  Widget _buildFull(BuildContext context, WidgetRef ref) {
    // Resolve node display name
    final nodes = ref.watch(nodesProvider);
    String? nodeName;
    if (transfer.direction == TransferDirection.outbound &&
        transfer.targetNodeNum != null) {
      final node = nodes[transfer.targetNodeNum!];
      nodeName = NodeDisplayNameResolver.resolve(
        nodeNum: transfer.targetNodeNum!,
        longName: node?.longName,
        shortName: node?.shortName,
      );
    } else if (transfer.direction == TransferDirection.inbound &&
        transfer.sourceNodeNum != null) {
      final node = nodes[transfer.sourceNodeNum!];
      nodeName = NodeDisplayNameResolver.resolve(
        nodeNum: transfer.sourceNodeNum!,
        longName: node?.longName,
        shortName: node?.shortName,
      );
    }

    final metaText = _buildMetadataText(context, nodeName);
    final statusColor = _statusColor(context);
    final chunkSize = _formatBytes(transfer.chunkSize);
    final isVoice =
        VoiceMime.isVoiceMessage(transfer.mimeType) ||
        VoiceMime.hasVoiceExtension(transfer.filename);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header row: icon + filename + subtitle + direction badge ──
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FileTypeIcon(mimeType: transfer.mimeType, size: 40),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    transfer.filename,
                    style: TextStyle(
                      color: context.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    metaText,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTheme.spacing8),
            _DirectionBadge(direction: transfer.direction),
          ],
        ),

        const SizedBox(height: AppTheme.spacing10),

        // ── Metric chips: status, voice/mime, chunks, chunk size ──
        Wrap(
          spacing: AppTheme.spacing6,
          runSpacing: AppTheme.spacing6,
          children: [
            _StatusChip(
              icon: _statusIcon,
              label: _statusText(context),
              color: statusColor,
            ),
            if (isVoice)
              _VoiceMediaChip()
            else
              _MetricChip(
                icon: Icons.description_outlined,
                value: transfer.mimeType,
              ),
            if (transfer.isActive)
              _MetricChip(
                icon: Icons.grid_view,
                value: context.l10n.fileTransferCardChunksProgress(
                  transfer.completedChunks.length.toString(),
                  transfer.chunkCount.toString(),
                ),
              )
            else
              _MetricChip(
                icon: Icons.grid_view,
                value: context.l10n.fileTransferCardChunksTotal(
                  transfer.chunkCount.toString(),
                ),
              ),
            _MetricChip(
              icon: Icons.straighten,
              value: context.l10n.fileTransferCardChunkSize(chunkSize),
            ),
          ],
        ),

        // ── Animated progress bar (active transfers only) ──
        if (transfer.isActive) ...[
          const SizedBox(height: AppTheme.spacing10),
          _AnimatedTransferProgress(
            progress: transfer.progress,
            color: statusColor,
            state: transfer.state,
          ),
        ],

        // ── Timestamp row (NodeDex discovery-age style) ──
        const SizedBox(height: AppTheme.spacing8),
        _TimestampRow(
          label: _relativeTime(
            context,
            transfer.completedAt ?? transfer.createdAt,
          ),
        ),

        // ── Action buttons ──
        if (_showActions) ...[
          Padding(
            padding: const EdgeInsets.only(top: AppTheme.spacing8),
            child: Divider(
              height: 1,
              color: context.border.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          _ActionRow(
            transfer: transfer,
            onCancel: onCancel,
            onRetry: onRetry,
            onShare: onShare,
            onAccept: onAccept,
            onReject: onReject,
            onDelete: onDelete,
            onInfo: onInfo,
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool get _showActions =>
      onCancel != null ||
      onRetry != null ||
      onShare != null ||
      onAccept != null ||
      onReject != null ||
      onDelete != null ||
      onInfo != null;

  String _statusText(BuildContext context) {
    switch (transfer.state) {
      case TransferState.created:
        return context.l10n.fileTransferStatusPreparing;
      case TransferState.offerSent:
        return context.l10n.fileTransferStatusOfferSent;
      case TransferState.offerPending:
        return context.l10n.fileTransferStatusOfferPending;
      case TransferState.chunking:
        final pct = (transfer.progress * 100).toStringAsFixed(0);
        return transfer.direction == TransferDirection.outbound
            ? context.l10n.fileTransferStatusSending(pct)
            : context.l10n.fileTransferStatusReceiving(pct);
      case TransferState.waitingMissing:
        return context.l10n.fileTransferStatusRecovering;
      case TransferState.complete:
        return context.l10n.fileTransferStatusComplete;
      case TransferState.failed:
        return _failReasonText(context);
      case TransferState.cancelled:
        return context.l10n.fileTransferStatusCancelled;
    }
  }

  String _failReasonText(BuildContext context) {
    switch (transfer.failReason) {
      case TransferFailReason.oversized:
        return context.l10n.fileTransferFailReasonOversized;
      case TransferFailReason.timeout:
        return context.l10n.fileTransferFailReasonTimeout;
      case TransferFailReason.invalid:
        return context.l10n.fileTransferFailReasonInvalid;
      case TransferFailReason.userCancelled:
        return context.l10n.fileTransferStatusCancelled;
      case TransferFailReason.rateLimited:
        return context.l10n.fileTransferFailReasonRateLimited;
      case TransferFailReason.hashMismatch:
        return context.l10n.fileTransferFailReasonHashMismatch;
      case TransferFailReason.maxRetries:
        return context.l10n.fileTransferFailReasonMaxRetries;
      case TransferFailReason.expired:
        return context.l10n.fileTransferFailReasonExpired;
      case null:
        return context.l10n.fileTransferStatusFailed;
    }
  }

  IconData get _statusIcon {
    switch (transfer.state) {
      case TransferState.created:
      case TransferState.offerSent:
        return Icons.schedule;
      case TransferState.offerPending:
        return Icons.inbox;
      case TransferState.chunking:
        return transfer.direction == TransferDirection.outbound
            ? Icons.upload
            : Icons.download;
      case TransferState.waitingMissing:
        return Icons.sync_problem;
      case TransferState.complete:
        return Icons.check_circle;
      case TransferState.failed:
        return Icons.error_outline;
      case TransferState.cancelled:
        return Icons.cancel_outlined;
    }
  }

  Color _statusColor(BuildContext context) {
    switch (transfer.state) {
      case TransferState.created:
      case TransferState.offerSent:
        return context.textTertiary;
      case TransferState.offerPending:
        return SemanticColors.warning;
      case TransferState.chunking:
        return context.accentColor;
      case TransferState.waitingMissing:
        return SemanticColors.warning;
      case TransferState.complete:
        return SemanticColors.success;
      case TransferState.failed:
        return SemanticColors.error;
      case TransferState.cancelled:
        return context.textTertiary;
    }
  }

  String get _fileSizeText {
    if (transfer.totalBytes < 1024) {
      return '${transfer.totalBytes} B';
    }
    final kb = transfer.totalBytes / 1024.0;
    return '${kb.toStringAsFixed(1)} KB';
  }

  String _relativeTime(BuildContext context, DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return context.l10n.fileTransferTimeJustNow;
    if (diff.inMinutes < 60) {
      return context.l10n.fileTransferTimeMinutesAgo(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return context.l10n.fileTransferTimeHoursAgo(diff.inHours);
    }
    if (diff.inDays < 7) {
      return context.l10n.fileTransferTimeDaysAgo(diff.inDays);
    }
    return context.l10n.fileTransferTimeDate(
      dt.month.toString(),
      dt.day.toString(),
    );
  }

  String _buildMetadataText(BuildContext context, String? nodeName) {
    final parts = <String>[_fileSizeText];
    if (transfer.direction == TransferDirection.outbound) {
      if (nodeName != null) {
        parts.add(context.l10n.fileTransferMetaNodeTo(nodeName));
      } else if (transfer.targetNodeNum != null) {
        parts.add(
          context.l10n.fileTransferMetaNodeTo(
            '!${transfer.targetNodeNum!.toRadixString(16)}',
          ),
        );
      }
    } else {
      if (nodeName != null) {
        parts.add(context.l10n.fileTransferMetaNodeFrom(nodeName));
      } else if (transfer.sourceNodeNum != null) {
        parts.add(
          context.l10n.fileTransferMetaNodeFrom(
            '!${transfer.sourceNodeNum!.toRadixString(16)}',
          ),
        );
      }
    }
    return parts.join(' · ');
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024.0;
    return '${kb.toStringAsFixed(1)} KB';
  }
}

// =============================================================================
// Sub-widgets — NodeDex-style components
// =============================================================================

// -----------------------------------------------------------------------------
// File type icon
// -----------------------------------------------------------------------------

class _FileTypeIcon extends StatelessWidget {
  const _FileTypeIcon({required this.mimeType, this.size = 36});

  final String mimeType;
  final double size;

  @override
  Widget build(BuildContext context) {
    return FileTypeIcon(mimeType: mimeType, size: size);
  }
}

/// Icon widget that displays a visual indicator for a file's MIME type.
///
/// Shows an appropriate icon and color based on the file type category.
/// Used in file transfer cards, attachment previews, and file lists.
class FileTypeIcon extends StatelessWidget {
  const FileTypeIcon({super.key, required this.mimeType, this.size = 36});

  final String mimeType;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: iconColor(context).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
      ),
      child: Icon(icon, size: size * 0.55, color: iconColor(context)),
    );
  }

  /// The icon to display for this MIME type.
  IconData get icon {
    final mime = mimeType.toLowerCase();

    // Images
    if (mime.startsWith('image/')) return Icons.image;

    // Text types
    if (mime == 'text/csv') return Icons.table_chart;
    if (mime == 'text/html') return Icons.code;
    if (mime == 'text/markdown') return Icons.article;
    if (mime.startsWith('text/')) return Icons.description;

    // Geospatial
    if (mime.contains('gpx')) return Icons.route;
    if (mime.contains('kml') || mime.contains('kmz')) return Icons.map;

    // Data formats
    if (mime.contains('json')) return Icons.data_object;
    if (mime.contains('xml')) return Icons.code;
    if (mime.contains('yaml') || mime.contains('yml')) return Icons.settings;
    if (mime.contains('protobuf')) return Icons.memory;

    // Documents
    if (mime.contains('pdf')) return Icons.picture_as_pdf;

    // Archives
    if (mime.contains('zip') ||
        mime.contains('gzip') ||
        mime.contains('tar') ||
        mime.contains('7z') ||
        mime.contains('rar')) {
      return Icons.folder_zip;
    }

    // Audio
    if (mime.startsWith('audio/')) return Icons.audiotrack;

    // Video
    if (mime.startsWith('video/')) return Icons.videocam;

    // Firmware / binary
    if (mime.contains('firmware') || mime.contains('octet-stream')) {
      return Icons.memory;
    }

    return Icons.insert_drive_file;
  }

  /// The accent color for this MIME type.
  Color iconColor(BuildContext context) {
    final mime = mimeType.toLowerCase();

    if (mime.startsWith('image/')) return AppTheme.primaryMagenta;
    if (mime == 'text/csv') return AccentColors.orange;
    if (mime == 'text/html') return AccentColors.red;
    if (mime.startsWith('text/')) return AppTheme.primaryBlue;
    if (mime.contains('json')) return AppTheme.primaryPurple;
    if (mime.contains('xml') || mime.contains('yaml')) {
      return AppTheme.primaryPurple;
    }
    if (mime.contains('gpx') || mime.contains('kml') || mime.contains('kmz')) {
      return SemanticColors.success;
    }
    if (mime.contains('pdf')) return AccentColors.red;
    if (mime.contains('zip') || mime.contains('gzip') || mime.contains('tar')) {
      return AccentColors.orange;
    }
    if (mime.startsWith('audio/')) return AccentColors.cyan;
    if (mime.startsWith('video/')) return AppTheme.primaryMagenta;

    return context.accentColor;
  }
}

// -----------------------------------------------------------------------------
// Direction badge — matches NodeDex trust / social-tag badge style
// -----------------------------------------------------------------------------

class _DirectionBadge extends StatelessWidget {
  const _DirectionBadge({required this.direction});

  final TransferDirection direction;

  @override
  Widget build(BuildContext context) {
    final isOutbound = direction == TransferDirection.outbound;
    final color = isOutbound ? AppTheme.primaryBlue : AppTheme.primaryPurple;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOutbound ? Icons.arrow_upward : Icons.arrow_downward,
            size: 11,
            color: color,
          ),
          const SizedBox(width: AppTheme.spacing3),
          Text(
            isOutbound
                ? context.l10n.fileTransferDirectionSent
                : context.l10n.fileTransferDirectionReceived,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Status chip — colored chip with icon, matching NodeDex trait badge style
// -----------------------------------------------------------------------------

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Metric chip — NodeDex _MetricChip: icon + monospace value, subtle border
// -----------------------------------------------------------------------------

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final color = context.textTertiary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: AppTheme.spacing3),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
              fontFamily: AppTheme.fontFamily,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Timestamp row — NodeDex _DiscoveryAgeBadge style
// -----------------------------------------------------------------------------

class _TimestampRow extends StatelessWidget {
  const _TimestampRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.schedule,
          size: 10,
          color: context.textTertiary.withValues(alpha: 0.5),
        ),
        const SizedBox(width: AppTheme.spacing3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: context.textTertiary.withValues(alpha: 0.6),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Animated progress bar – smooth interpolation between chunk updates
// -----------------------------------------------------------------------------

/// Wraps [_TransferProgressBar] with smooth interpolated progress animation.
///
/// When [progress] changes (e.g. a new chunk arrives), the bar animates from
/// the current displayed position to the new target using [Curves.easeOut].
/// This removes the janky per-chunk step jumps without sacrificing accuracy —
/// the animation always lands on the real reported value.
class _AnimatedTransferProgress extends StatefulWidget {
  const _AnimatedTransferProgress({
    required this.progress,
    required this.color,
    required this.state,
  });

  final double progress;
  final Color color;
  final TransferState state;

  @override
  State<_AnimatedTransferProgress> createState() =>
      _AnimatedTransferProgressState();
}

class _AnimatedTransferProgressState extends State<_AnimatedTransferProgress>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curved;

  // Tracks the visual start / end for each interpolation segment.
  double _fromProgress = 0;
  double _toProgress = 0;

  @override
  void initState() {
    super.initState();
    _fromProgress = widget.progress;
    _toProgress = widget.progress;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _curved = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void didUpdateWidget(_AnimatedTransferProgress old) {
    super.didUpdateWidget(old);
    if (widget.progress != old.progress) {
      // Begin the new segment from the current visual position so rapid
      // consecutive updates feel smooth rather than re-starting from 0.
      _fromProgress = _currentProgress;
      _toProgress = widget.progress;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    _controller.dispose();
    super.dispose();
  }

  double get _currentProgress {
    return _fromProgress + (_toProgress - _fromProgress) * _curved.value;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => _TransferProgressBar(
        progress: _currentProgress,
        color: widget.color,
        state: widget.state,
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Progress bar
// -----------------------------------------------------------------------------

class _TransferProgressBar extends StatelessWidget {
  const _TransferProgressBar({
    required this.progress,
    required this.color,
    required this.state,
  });

  final double progress;
  final Color color;
  final TransferState state;

  @override
  Widget build(BuildContext context) {
    // During NACK recovery show an indeterminate indicator to accurately
    // convey "working but unknown completion time".
    final isIndeterminate = state == TransferState.waitingMissing;
    return Container(
      height: 6,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.22),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radius3),
        child: LinearProgressIndicator(
          value: isIndeterminate ? null : progress,
          minHeight: 6,
          backgroundColor: context.border.withValues(alpha: 0.3),
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Voice media badge chip
// -----------------------------------------------------------------------------

/// A specialised chip that visually identifies a transfer as a voice/audio
/// message, replacing the generic MIME-type chip for codec2 files.
class _VoiceMediaChip extends StatelessWidget {
  const _VoiceMediaChip();

  @override
  Widget build(BuildContext context) {
    const color = AccentColors.cyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(color: color.withValues(alpha: 0.30), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic, size: 11, color: color),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            context.l10n.fileTransferVoiceBadge,
            style: const TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Progress ring (compact mode)
// -----------------------------------------------------------------------------

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CircularProgressIndicator(
          value: progress,
          strokeWidth: 2.5,
          backgroundColor: context.border.withValues(alpha: 0.3),
          valueColor: AlwaysStoppedAnimation(context.accentColor),
        ),
        Text(
          '${(progress * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            color: context.textSecondary,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Action row — uses ink-well buttons with haptic feedback
// -----------------------------------------------------------------------------

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.transfer,
    this.onCancel,
    this.onRetry,
    this.onShare,
    this.onAccept,
    this.onReject,
    this.onDelete,
    this.onInfo,
  });

  final FileTransferState transfer;
  final VoidCallback? onCancel;
  final VoidCallback? onRetry;
  final VoidCallback? onShare;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onDelete;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Pending offer: accept / reject
        if (transfer.state == TransferState.offerPending) ...[
          if (onReject != null)
            _ActionButton(
              label: context.l10n.fileTransferActionReject,
              icon: Icons.close,
              color: SemanticColors.error,
              onTap: onReject!,
            ),
          if (onAccept != null) ...[
            const SizedBox(width: AppTheme.spacing8),
            _ActionButton(
              label: context.l10n.fileTransferActionAccept,
              icon: Icons.check,
              color: SemanticColors.success,
              onTap: onAccept!,
            ),
          ],
        ],
        // Active transfer: cancel
        if (transfer.isActive &&
            transfer.state != TransferState.offerPending &&
            onCancel != null)
          _ActionButton(
            label: context.l10n.fileTransferActionCancel,
            icon: Icons.close,
            color: SemanticColors.error,
            onTap: onCancel!,
          ),
        if (transfer.state == TransferState.failed && onRetry != null) ...[
          const SizedBox(width: AppTheme.spacing8),
          _ActionButton(
            label: context.l10n.fileTransferActionRetry,
            icon: Icons.refresh,
            color: context.accentColor,
            onTap: onRetry!,
          ),
        ],
        if (transfer.state == TransferState.complete) ...[
          if (onShare != null) ...[
            const SizedBox(width: AppTheme.spacing8),
            _ActionButton(
              label: context.l10n.fileTransferActionShare,
              icon: Icons.share,
              color: context.accentColor,
              onTap: onShare!,
            ),
          ],
        ],
        // Info button — always available when provided
        if (onInfo != null) ...[
          const SizedBox(width: AppTheme.spacing8),
          _ActionButton(
            label: context.l10n.fileTransferActionInfo,
            icon: Icons.info_outline,
            color: context.textSecondary,
            onTap: onInfo!,
          ),
        ],
        // Delete button for terminal transfers
        if (!transfer.isActive && onDelete != null) ...[
          const SizedBox(width: AppTheme.spacing8),
          _ActionButton(
            label: context.l10n.fileTransferActionDelete,
            icon: Icons.delete_outline,
            color: SemanticColors.error,
            onTap: onDelete!,
          ),
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Action button — subtle ink-well tap target
// -----------------------------------------------------------------------------

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing8,
            vertical: AppTheme.spacing4,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: AppTheme.spacing4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
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

// =============================================================================
// Attachment preview card (composer)
// =============================================================================

/// Attachment preview card shown in the composer before sending.
class FileAttachmentPreview extends StatelessWidget {
  const FileAttachmentPreview({
    super.key,
    required this.filename,
    required this.mimeType,
    required this.fileSize,
    required this.chunkCount,
    this.onRemove,
  });

  final String filename;
  final String mimeType;
  final int fileSize;
  final int chunkCount;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing10),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius10),
        border: Border.all(color: context.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          _FileTypeIcon(mimeType: mimeType, size: 32),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  filename,
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppTheme.spacing2),
                Text(
                  context.l10n.fileTransferAttachmentMeta(
                    fileSize,
                    chunkCount.toString(),
                  ),
                  style: TextStyle(color: context.textTertiary, fontSize: 11),
                ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              onPressed: onRemove,
              icon: Icon(Icons.close, size: 16, color: context.textTertiary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }
}
