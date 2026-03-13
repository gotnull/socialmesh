// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';
import 'dart:io';

import '../../../core/l10n/l10n_extension.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme.dart';
import '../../../utils/snackbar.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../services/file_transfer/file_transfer_engine.dart';
import '../../../services/voice/voice_mime.dart';
import 'voice_attachment_card.dart';

/// Displays a file content preview in a scrollable bottom sheet.
///
/// Selects the appropriate viewer based on the file's MIME type:
/// - `text/*` and `application/json`: Scrollable text with syntax coloring
/// - `image/*`: Rendered image with zoom support
/// - `application/gpx+xml`, `application/vnd.google-earth.kml+xml`: Text
/// - Other: Hex dump preview with "save to view" message
class FileContentPreview {
  FileContentPreview._();

  /// Shows a file content preview for the given transfer.
  ///
  /// Uses in-memory [FileTransferState.fileBytes] when available, or falls
  /// back to loading from [FileTransferState.savedFilePath] on disk.
  /// Returns early if neither source is available.
  static void show({
    required BuildContext context,
    required FileTransferState transfer,
  }) {
    final hasBytes =
        transfer.fileBytes != null && transfer.fileBytes!.isNotEmpty;
    final hasPath = transfer.savedFilePath != null;
    if (!hasBytes && !hasPath) return;

    AppBottomSheet.showScrollable<void>(
      context: context,
      title: transfer.filename,
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      builder: (scrollController) {
        if (hasBytes) {
          return _resolveViewer(transfer)(scrollController);
        }
        // Bytes not in memory — load from disk asynchronously.
        return _DiskFileLoader(
          path: transfer.savedFilePath!,
          mimeType: transfer.mimeType,
          filename: transfer.filename,
          scrollController: scrollController,
        );
      },
    );
  }

  /// Resolves the appropriate viewer widget builder for the transfer.
  static Widget Function(ScrollController) _resolveViewer(
    FileTransferState transfer,
  ) {
    final mime = transfer.mimeType.toLowerCase();
    final bytes = transfer.fileBytes!;

    if (VoiceMime.isVoiceMessage(mime) ||
        VoiceMime.hasVoiceExtension(transfer.filename)) {
      return (_) => _VoiceViewer(
        bytes: bytes,
        filename: transfer.filename,
        totalBytes: transfer.totalBytes,
        receivedAt: transfer.createdAt,
      );
    }

    if (mime.startsWith('image/')) {
      return (controller) =>
          _ImageViewer(bytes: bytes, scrollController: controller);
    }

    if (mime.startsWith('text/') ||
        mime.contains('json') ||
        mime.contains('xml') ||
        mime.contains('gpx') ||
        mime.contains('kml') ||
        mime.contains('csv')) {
      return (controller) => _TextViewer(
        bytes: bytes,
        mimeType: mime,
        scrollController: controller,
      );
    }

    // Binary fallback: hex dump
    return (controller) => _HexViewer(
      bytes: bytes,
      filename: transfer.filename,
      scrollController: controller,
    );
  }
}

// ---------------------------------------------------------------------------
// Voice viewer
// ---------------------------------------------------------------------------

class _VoiceViewer extends StatelessWidget {
  const _VoiceViewer({
    required this.bytes,
    required this.filename,
    required this.totalBytes,
    required this.receivedAt,
  });

  final Uint8List bytes;
  final String filename;
  final int totalBytes;
  final DateTime receivedAt;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: VoiceAttachmentCard(
        c2Payload: bytes,
        cacheKey: '${filename}_$totalBytes',
        filename: filename,
        totalBytes: totalBytes,
        receivedAt: receivedAt,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Image viewer
// ---------------------------------------------------------------------------

class _ImageViewer extends StatelessWidget {
  const _ImageViewer({required this.bytes, required this.scrollController});

  final Uint8List bytes;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        children: [
          // File size indicator
          _FileSizeBar(bytes: bytes.length),
          const SizedBox(height: AppTheme.spacing16),

          // Image with interactive zoom
          ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stack) => _ErrorPlaceholder(
                  message: context.l10n.fileTransferImageDecodeError,
                ),
              ),
            ),
          ),

          const SizedBox(height: AppTheme.spacing12),
          Text(
            context.l10n.fileTransferPinchToZoom,
            style: TextStyle(color: context.textTertiary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Text viewer
// ---------------------------------------------------------------------------

class _TextViewer extends StatelessWidget {
  const _TextViewer({
    required this.bytes,
    required this.mimeType,
    required this.scrollController,
  });

  final Uint8List bytes;
  final String mimeType;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    String text;
    try {
      text = utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      text = String.fromCharCodes(bytes);
    }

    final isJson = mimeType.contains('json');
    if (isJson) {
      try {
        final parsed = jsonDecode(text);
        text = const JsonEncoder.withIndent('  ').convert(parsed);
      } catch (_) {
        // Keep raw text if JSON parsing fails
      }
    }

    final lineCount = '\n'.allMatches(text).length + 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Metadata bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: Row(
            children: [
              _FileSizeBar(bytes: bytes.length),
              const Spacer(),
              _MetadataChip(
                icon: Icons.format_list_numbered,
                label: context.l10n.fileTransferLineCount(lineCount),
              ),
              const SizedBox(width: AppTheme.spacing8),
              _CopyButton(text: text),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),

        // Text content
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
            decoration: BoxDecoration(
              color: context.background,
              borderRadius: BorderRadius.circular(AppTheme.radius10),
              border: Border.all(color: context.border.withValues(alpha: 0.3)),
            ),
            child: SelectionArea(
              child: ListView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(AppTheme.spacing12),
                itemCount: text.split('\n').length,
                itemBuilder: (context, index) {
                  final lines = text.split('\n');
                  return _NumberedLine(
                    lineNumber: index + 1,
                    text: lines[index],
                    isJson: isJson,
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hex viewer (binary fallback)
// ---------------------------------------------------------------------------

class _HexViewer extends StatelessWidget {
  const _HexViewer({
    required this.bytes,
    required this.filename,
    required this.scrollController,
  });

  final Uint8List bytes;
  final String filename;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    // Show first 256 bytes in hex dump
    final previewLength = bytes.length.clamp(0, 256);
    final hexLines = <String>[];
    final asciiLines = <String>[];

    for (var i = 0; i < previewLength; i += 16) {
      final end = (i + 16).clamp(0, previewLength);
      final chunk = bytes.sublist(i, end);

      final hex = chunk
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join(' ');
      hexLines.add('${i.toRadixString(16).padLeft(4, '0')}  $hex');

      final ascii = chunk.map((b) {
        return (b >= 32 && b < 127) ? String.fromCharCode(b) : '.';
      }).join();
      asciiLines.add(ascii);
    }

    return SingleChildScrollView(
      controller: scrollController,
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FileSizeBar(bytes: bytes.length),
          const SizedBox(height: AppTheme.spacing16),

          // Info banner
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: SemanticColors.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radius10),
              border: Border.all(
                color: SemanticColors.warning.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: SemanticColors.warning,
                ),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    context.l10n.fileTransferBinaryFileHint,
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.spacing16),

          // Hex dump
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: context.background,
              borderRadius: BorderRadius.circular(AppTheme.radius10),
              border: Border.all(color: context.border.withValues(alpha: 0.3)),
            ),
            child: SelectionArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < hexLines.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spacing2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              hexLines[i],
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11,
                                color: context.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing8),
                          Text(
                            asciiLines[i],
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              color: context.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (bytes.length > previewLength) ...[
                    const SizedBox(height: AppTheme.spacing8),
                    Text(
                      context.l10n.fileTransferMoreBytes(
                        bytes.length - previewLength,
                      ),
                      style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared sub-widgets
// ---------------------------------------------------------------------------

class _FileSizeBar extends StatelessWidget {
  const _FileSizeBar({required this.bytes});

  final int bytes;

  String get _formatted {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024.0;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024.0;
    return '${mb.toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return _MetadataChip(icon: Icons.storage, label: _formatted);
  }
}

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

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Clipboard.setData(ClipboardData(text: text));
        showInfoSnackBar(
          context,
          context.l10n.fileTransferCopiedToClipboard,
          duration: const Duration(seconds: 1),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: context.accentColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radius6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.copy, size: 12, color: context.accentColor),
            const SizedBox(width: AppTheme.spacing4),
            Text(
              context.l10n.fileTransferCopyAction,
              style: TextStyle(
                color: context.accentColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberedLine extends StatelessWidget {
  const _NumberedLine({
    required this.lineNumber,
    required this.text,
    required this.isJson,
  });

  final int lineNumber;
  final String text;
  final bool isJson;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 36,
          child: Text(
            lineNumber.toString(),
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: context.textTertiary.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.right,
          ),
        ),
        const SizedBox(width: AppTheme.spacing8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: isJson ? _jsonColor(context, text) : context.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  /// Basic JSON syntax coloring.
  Color _jsonColor(BuildContext context, String line) {
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('"') && trimmed.contains(':')) {
      return AppTheme.primaryBlue; // Keys
    }
    if (trimmed.startsWith('"')) {
      return SemanticColors.success; // String values
    }
    if (trimmed.startsWith(RegExp(r'[0-9\-]'))) {
      return AppTheme.primaryPurple; // Numbers
    }
    if (trimmed.startsWith('true') ||
        trimmed.startsWith('false') ||
        trimmed.startsWith('null')) {
      return AppTheme.primaryMagenta; // Booleans/null
    }
    return context.textSecondary;
  }
}

// ---------------------------------------------------------------------------
// Disk file loader (async bytes from savedFilePath)
// ---------------------------------------------------------------------------

class _DiskFileLoader extends StatefulWidget {
  const _DiskFileLoader({
    required this.path,
    required this.mimeType,
    required this.filename,
    required this.scrollController,
  });

  final String path;
  final String mimeType;
  final String filename;
  final ScrollController scrollController;

  @override
  State<_DiskFileLoader> createState() => _DiskFileLoaderState();
}

class _DiskFileLoaderState extends State<_DiskFileLoader> {
  Uint8List? _bytes;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await File(widget.path).readAsBytes();
      if (mounted) setState(() => _bytes = bytes);
    } catch (e) {
      if (mounted) {
        setState(
          () =>
              _error = context.l10n.fileTransferCouldNotReadFile(e.toString()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return _ErrorPlaceholder(message: _error!);
    }
    if (_bytes == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppTheme.spacing40),
          child: CircularProgressIndicator(),
        ),
      );
    }
    final mime = widget.mimeType.toLowerCase();
    if (mime.startsWith('image/')) {
      return _ImageViewer(
        bytes: _bytes!,
        scrollController: widget.scrollController,
      );
    }
    if (mime.startsWith('text/') ||
        mime.contains('json') ||
        mime.contains('xml') ||
        mime.contains('gpx') ||
        mime.contains('kml') ||
        mime.contains('csv')) {
      return _TextViewer(
        bytes: _bytes!,
        mimeType: mime,
        scrollController: widget.scrollController,
      );
    }
    return _HexViewer(
      bytes: _bytes!,
      filename: widget.filename,
      scrollController: widget.scrollController,
    );
  }
}

// ---------------------------------------------------------------------------
// Error placeholder
// ---------------------------------------------------------------------------

class _ErrorPlaceholder extends StatelessWidget {
  const _ErrorPlaceholder({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            style: TextStyle(color: context.textTertiary, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
