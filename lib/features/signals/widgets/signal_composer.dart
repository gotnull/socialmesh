// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../providers/file_transfer_providers.dart';
import '../../../providers/signal_providers.dart';
import '../../../services/protocol/socialmesh/sm_constants.dart';
import '../../../services/signal_service.dart';
import '../../../core/l10n/l10n_extension.dart';
import '../../../utils/snackbar.dart';
import '../../file_transfer/widgets/file_transfer_card.dart';
import 'ttl_selector.dart';

/// Inline signal composer widget (for embedding in other screens).
class SignalComposer extends ConsumerStatefulWidget {
  const SignalComposer({super.key, this.onSignalCreated, this.compact = false});

  final VoidCallback? onSignalCreated;
  final bool compact;

  @override
  ConsumerState<SignalComposer> createState() => _SignalComposerState();
}

class _SignalComposerState extends ConsumerState<SignalComposer>
    with LifecycleSafeMixin<SignalComposer> {
  final TextEditingController _controller = TextEditingController();
  int _ttlMinutes = SignalTTL.defaultTTL;
  bool _isSubmitting = false;

  // File attachment state.
  String? _attachedFilename;
  String? _attachedMimeType;
  Uint8List? _attachedFileBytes;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _hasAttachment => _attachedFileBytes != null;

  bool get _canSubmit =>
      (_controller.text.trim().isNotEmpty || _hasAttachment) &&
      _controller.text.length <= 140 &&
      !_isSubmitting;

  Future<void> _submit() async {
    if (!_canSubmit) return;

    safeSetState(() => _isSubmitting = true);

    try {
      final l10n = context.l10n;

      // Send file attachment if present.
      if (_hasAttachment) {
        final ctx = context;
        final transferNotifier = ref.read(fileTransferStateProvider.notifier);
        final transfer = await transferNotifier.sendFile(
          filename: _attachedFilename!,
          mimeType: _attachedMimeType ?? 'application/octet-stream',
          fileBytes: _attachedFileBytes!,
        );

        if (transfer == null && ctx.mounted) {
          showErrorSnackBar(ctx, l10n.signalFileTransferFailed);
          return;
        }
      }

      // Send signal text if present.
      if (_controller.text.trim().isNotEmpty) {
        final notifier = ref.read(signalFeedProvider.notifier);
        await notifier.createSignal(
          content: _controller.text.trim(),
          ttlMinutes: _ttlMinutes,
        );
      }

      _controller.clear();
      safeSetState(() {
        _attachedFilename = null;
        _attachedMimeType = null;
        _attachedFileBytes = null;
      });
      widget.onSignalCreated?.call();
    } finally {
      safeSetState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickFile() async {
    final l10n = context.l10n;
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    Uint8List? bytes = file.bytes;
    if (bytes == null && file.path != null) {
      bytes = await File(file.path!).readAsBytes();
    }
    if (bytes == null) return;

    if (bytes.length > SmFileTransferLimits.maxFileSize) {
      if (!mounted) return;
      showWarningSnackBar(
        context,
        l10n.signalFileTooLarge(SmFileTransferLimits.maxFileSize ~/ 1024),
      );
      return;
    }

    safeSetState(() {
      _attachedFilename = file.name;
      _attachedMimeType = _guessMimeType(file.name);
      _attachedFileBytes = bytes;
    });
  }

  void _removeAttachment() {
    safeSetState(() {
      _attachedFilename = null;
      _attachedMimeType = null;
      _attachedFileBytes = null;
    });
  }

  String _guessMimeType(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    return switch (ext) {
      'txt' => 'text/plain',
      'json' => 'application/json',
      'csv' => 'text/csv',
      'gpx' => 'application/gpx+xml', // lint-allow: hardcoded-string
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'pdf' => 'application/pdf',
      'zip' => 'application/zip',
      _ => 'application/octet-stream',
    };
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompact(context);
    }
    return _buildFull(context);
  }

  Widget _buildCompact(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_isSubmitting,
              maxLength: 140,
              style: TextStyle(color: context.textPrimary),
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: context.l10n.signalSendASignal,
                hintStyle: TextStyle(color: context.textTertiary),
                border: InputBorder.none,
                isDense: true,
                counterText: '',
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          if (AppFeatureFlags.isFileTransferEnabled) ...[
            IconButton(
              onPressed: _isSubmitting ? null : _pickFile,
              icon: Icon(
                Icons.attach_file,
                size: 20,
                color: _hasAttachment
                    ? context.accentColor
                    : context.textTertiary,
              ),
              tooltip: context.l10n.signalAttachFile,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: AppTheme.spacing8),
          ],
          IconButton(
            onPressed: _canSubmit ? _submit : null,
            icon: _isSubmitting
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.accentColor,
                    ),
                  )
                : Icon(
                    Icons.sensors,
                    color: _canSubmit
                        ? context.accentColor
                        : context.textTertiary,
                  ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius16),
        border: Border.all(color: context.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Input
          TextField(
            controller: _controller,
            enabled: !_isSubmitting,
            maxLines: 3,
            maxLength: 140,
            maxLengthEnforcement: MaxLengthEnforcement.enforced,
            textCapitalization: TextCapitalization.sentences,
            inputFormatters: [LengthLimitingTextInputFormatter(140)],
            style: TextStyle(color: context.textPrimary),
            decoration: InputDecoration(
              hintText: context.l10n.signalWhatAreYouSignaling,
              hintStyle: TextStyle(color: context.textTertiary),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              counterText: '',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppTheme.spacing12),

          // TTL selector
          Text(
            context.l10n.signalFadesIn,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppTheme.spacing6),
          TTLSelector(
            selectedMinutes: _ttlMinutes,
            onChanged: _isSubmitting
                ? null
                : (minutes) => setState(() => _ttlMinutes = minutes),
          ),

          // File attachment preview
          if (AppFeatureFlags.isFileTransferEnabled && _hasAttachment) ...[
            const SizedBox(height: AppTheme.spacing12),
            FileAttachmentPreview(
              filename: _attachedFilename!,
              mimeType: _attachedMimeType ?? 'application/octet-stream',
              fileSize: _attachedFileBytes!.length,
              chunkCount:
                  (_attachedFileBytes!.length /
                          SmFileTransferLimits.defaultChunkSize)
                      .ceil(),
              onRemove: _isSubmitting ? null : _removeAttachment,
            ),
          ],

          const SizedBox(height: AppTheme.spacing12),

          // Attach file button (gated behind file transfer feature flag)
          if (AppFeatureFlags.isFileTransferEnabled)
            Row(
              children: [
                TextButton.icon(
                  onPressed: _isSubmitting ? null : _pickFile,
                  icon: Icon(
                    Icons.attach_file,
                    size: 16,
                    color: _isSubmitting
                        ? context.textTertiary
                        : context.accentColor,
                  ),
                  label: Text(
                    context.l10n.signalAttachFile,
                    style: TextStyle(
                      color: _isSubmitting
                          ? context.textTertiary
                          : context.accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing8,
                      vertical: AppTheme.spacing4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const Spacer(),
                Text(
                  context.l10n.signalMaxFileSize(
                    SmFileTransferLimits.maxFileSize ~/ 1024,
                  ),
                  style: TextStyle(color: context.textTertiary, fontSize: 10),
                ),
              ],
            ),
          const SizedBox(height: AppTheme.spacing16),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _canSubmit ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: context.accentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: context.border.withValues(alpha: 0.3),
                disabledForegroundColor: context.textTertiary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius12),
                ),
              ),
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sensors, size: 18),
              label: Text(
                _isSubmitting
                    ? context.l10n.signalSendingLabel
                    : context.l10n.signalSendSignal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
