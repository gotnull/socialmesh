// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
// lint-allow: scaffold — immersive fullscreen black gallery overlay

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../providers/app_providers.dart';
import '../../../services/file_transfer/file_transfer_engine.dart';
import '../../nodes/node_display_name_resolver.dart';
import '../../nodedex/widgets/tappable_sigil_avatar.dart';

/// A fullscreen gallery view for file transfer images.
///
/// Supports two image sources:
/// - In-memory [Uint8List] bytes (from [FileTransferState.fileBytes])
/// - On-disk file path (from [FileTransferState.savedFilePath])
///
/// Follows the same immersive gallery pattern as [SignalGalleryView]:
/// black background, pinch-to-zoom via [InteractiveViewer], animated
/// top bar with close button and filename pill, animated bottom overlay
/// with node info / direction / file metadata badges, tap to toggle
/// overlays, and fade transition on entry.
class FileTransferImageGallery extends ConsumerStatefulWidget {
  const FileTransferImageGallery._({required this.transfer});

  /// The full transfer state — used to render metadata in the overlay.
  final FileTransferState transfer;

  /// Returns `true` if the given transfer is a completed image that can be
  /// displayed in the gallery.
  static bool canShow(FileTransferState transfer) {
    if (transfer.state != TransferState.complete) return false;
    if (!transfer.mimeType.toLowerCase().startsWith('image/')) return false;
    final hasBytes =
        transfer.fileBytes != null && transfer.fileBytes!.isNotEmpty;
    final hasPath = transfer.savedFilePath != null;
    return hasBytes || hasPath;
  }

  /// Shows a fullscreen image gallery for the given [transfer].
  ///
  /// The transfer must be a completed image transfer. Call [canShow] first
  /// to verify eligibility. Returns immediately if the transfer cannot be
  /// shown.
  static void show(
    BuildContext context, {
    required FileTransferState transfer,
  }) {
    if (!canShow(transfer)) return;

    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            FileTransferImageGallery._(transfer: transfer),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
        opaque: false,
        barrierColor: Colors.black87,
      ),
    );
  }

  @override
  ConsumerState<FileTransferImageGallery> createState() =>
      _FileTransferImageGalleryState();
}

class _FileTransferImageGalleryState
    extends ConsumerState<FileTransferImageGallery>
    with SingleTickerProviderStateMixin {
  late AnimationController _overlayController;
  late Animation<Offset> _overlaySlideAnimation;
  late Animation<double> _overlayFadeAnimation;
  bool _overlayVisible = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _overlayController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _overlaySlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _overlayController,
            curve: Curves.easeOutCubic,
          ),
        );

    _overlayFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _overlayController, curve: Curves.easeOut),
    );

    // Start overlay animation after a brief delay
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (mounted) _overlayController.forward();
    });
  }

  @override
  void dispose() {
    _overlayController.dispose();
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _toggleOverlay() {
    HapticFeedback.lightImpact();
    setState(() => _overlayVisible = !_overlayVisible);
    if (_overlayVisible) {
      _overlayController.forward();
    } else {
      _overlayController.reverse();
    }
  }

  Widget _buildImage() {
    final bytes = widget.transfer.fileBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return SizedBox.expand(
        child: Image.memory(
          bytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        ),
      );
    }

    final path = widget.transfer.savedFilePath;
    if (path != null) {
      return SizedBox.expand(
        child: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
        ),
      );
    }

    return _buildErrorWidget();
  }

  Widget _buildErrorWidget() {
    return const Icon(
      Icons.broken_image_outlined,
      size: 64,
      color: Colors.white38,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Full-screen image with pinch-to-zoom
          GestureDetector(
            onTap: _toggleOverlay,
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(child: _buildImage()),
            ),
          ),

          // Top bar overlay with close button and filename pill
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, -1),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _overlayController,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: FadeTransition(
                  opacity: _overlayFadeAnimation,
                  child: _TopBar(
                    filename: widget.transfer.filename,
                    onClose: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ),
          ),

          // Bottom info overlay with node info and metadata badges
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _overlaySlideAnimation,
              child: FadeTransition(
                opacity: _overlayFadeAnimation,
                child: _BottomInfoOverlay(transfer: widget.transfer),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Top bar
// ---------------------------------------------------------------------------

class _TopBar extends StatelessWidget {
  const _TopBar({required this.filename, required this.onClose});

  final String filename;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Close button
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: onClose,
          ),
          const Spacer(),
          // Filename pill
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppTheme.radius16),
              ),
              child: Text(
                filename,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          const Spacer(),
          // Placeholder for symmetry
          const SizedBox(width: AppTheme.spacing48),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom info overlay
// ---------------------------------------------------------------------------

class _BottomInfoOverlay extends ConsumerWidget {
  const _BottomInfoOverlay({required this.transfer});

  final FileTransferState transfer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nodes = ref.watch(nodesProvider);
    final isOutbound = transfer.direction == TransferDirection.outbound;

    // Resolve the peer node (target for outbound, source for inbound)
    final peerNodeNum = isOutbound
        ? transfer.targetNodeNum
        : transfer.sourceNodeNum;
    String? peerName;
    String? peerShort;
    if (peerNodeNum != null) {
      final node = nodes[peerNodeNum];
      final hexId = peerNodeNum.toRadixString(16).toUpperCase();
      final shortHex = hexId.length >= 4
          ? hexId.substring(hexId.length - 4)
          : hexId;
      peerName = node != null
          ? NodeDisplayNameResolver.resolve(
              nodeNum: peerNodeNum,
              longName: node.longName,
              shortName: node.shortName,
            )
          : '!$hexId'; // lint-allow: hardcoded-string
      peerShort = node?.shortName ?? shortHex;
    }

    // Direction subtitle
    final directionText = peerName != null
        ? (isOutbound
              ? context.l10n.fileTransferGalleryToNode(peerName)
              : context.l10n.fileTransferGalleryFromNode(peerName))
        : null;

    // Transfer duration
    final durationText = _formatDuration(context, transfer);

    // File size
    final sizeText = _formatBytes(transfer.totalBytes);

    // SHA-256 hash snippet (first 12 hex chars)
    final hashHex = transfer.sha256Hash
        .take(6)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();

    // File extension
    final ext = transfer.filename.contains('.')
        ? transfer.filename.split('.').last.toUpperCase()
        : null;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.85),
            Colors.black.withValues(alpha: 0.6),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            48,
            AppTheme.spacing16,
            AppTheme.spacing16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Author / node row
              Row(
                children: [
                  // Sigil avatar for the peer node — tap opens NodeDex.
                  if (peerNodeNum != null)
                    TappableSigilAvatar(nodeNum: peerNodeNum, size: 40)
                  else
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isOutbound ? Icons.arrow_upward : Icons.arrow_downward,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  const SizedBox(width: AppTheme.spacing12),

                  // Node info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Node name or "Mesh Transfer" fallback
                        Text(
                          peerName ??
                              context.l10n.fileTransferGalleryMeshTransfer,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing2),
                        // Subtitle row: direction + short name
                        Row(
                          children: [
                            if (directionText != null)
                              Text(
                                directionText,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                ),
                              ),
                            if (directionText != null && peerShort != null)
                              Text(
                                ' · ', // lint-allow: hardcoded-string
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.5),
                                  fontSize: 12,
                                ),
                              ),
                            if (peerShort != null) ...[
                              Icon(
                                Icons.router,
                                size: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: AppTheme.spacing4),
                              Text(
                                peerShort,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Details button
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(context.l10n.fileTransferGalleryViewDetails),
                        const SizedBox(width: AppTheme.spacing4),
                        const Icon(Icons.arrow_forward_ios, size: 12),
                      ],
                    ),
                  ),
                ],
              ),

              // Filename
              const SizedBox(height: AppTheme.spacing12),
              Text(
                transfer.filename,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),

              // MIME type subtitle
              const SizedBox(height: AppTheme.spacing2),
              Text(
                transfer.mimeType,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                ),
              ),

              // Info badges
              const SizedBox(height: AppTheme.spacing12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Direction badge
                  _InfoBadge(
                    icon: isOutbound
                        ? Icons.arrow_upward
                        : Icons.arrow_downward,
                    label: isOutbound
                        ? context.l10n.fileTransferGallerySentBadge
                        : context.l10n.fileTransferGalleryReceivedBadge,
                    color: isOutbound
                        ? AppTheme.primaryBlue
                        : AppTheme.primaryPurple,
                  ),

                  // File size badge
                  _InfoBadge(
                    icon: Icons.straighten,
                    label: context.l10n.fileTransferGallerySizeBadge(sizeText),
                    color: AccentColors.cyan,
                  ),

                  // File extension badge
                  if (ext != null)
                    _InfoBadge(
                      icon: Icons.insert_drive_file_outlined,
                      label: ext,
                      color: Colors.white70,
                    ),

                  // Chunk info badge
                  _InfoBadge(
                    icon: Icons.grid_view,
                    label: context.l10n.fileTransferGalleryChunksBadge(
                      transfer.completedChunks.length.toString(),
                      transfer.chunkCount.toString(),
                    ),
                    color: AccentColors.green,
                  ),

                  // Duration badge (only when completed)
                  if (durationText != null)
                    _InfoBadge(
                      icon: Icons.schedule,
                      label: context.l10n.fileTransferGalleryDurationBadge(
                        durationText,
                      ),
                      color: AccentColors.yellow,
                    ),

                  // SHA-256 hash badge
                  if (hashHex.isNotEmpty)
                    _InfoBadge(
                      icon: Icons.fingerprint,
                      label: context.l10n.fileTransferGalleryHashBadge(hashHex),
                      color: Colors.white54,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Format the transfer duration from creation to completion.
  String? _formatDuration(BuildContext context, FileTransferState t) {
    final completed = t.completedAt;
    if (completed == null) return null;
    final duration = completed.difference(t.createdAt);
    if (duration.isNegative) return null;

    if (duration.inHours > 0) {
      return context.l10n.fileTransferGalleryDurationHours(
        duration.inHours,
        duration.inMinutes.remainder(60),
      );
    }
    if (duration.inMinutes > 0) {
      return context.l10n.fileTransferGalleryDurationMinutes(
        duration.inMinutes,
      );
    }
    return context.l10n.fileTransferGalleryDurationSeconds(
      duration.inSeconds.clamp(1, 59),
    );
  }

  /// Format a byte count to a human-readable string.
  static String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B'; // lint-allow: hardcoded-string
    }
    final kb = bytes / 1024.0;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB'; // lint-allow: hardcoded-string
    }
    final mb = kb / 1024.0;
    return '${mb.toStringAsFixed(1)} MB'; // lint-allow: hardcoded-string
  }
}

// ---------------------------------------------------------------------------
// Info badge — matches the signal gallery pattern
// ---------------------------------------------------------------------------

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppTheme.spacing4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
