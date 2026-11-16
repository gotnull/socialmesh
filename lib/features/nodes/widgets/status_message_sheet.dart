// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/utils/utf8_byte_length_formatter.dart';
import '../../../core/widgets/app_bottom_sheet.dart';

/// The firmware's limit on a status message, in UTF-8 bytes.
const int kStatusMessageMaxBytes = 80;

/// Edits the status message the connected radio broadcasts to the mesh.
/// Save stays disabled until the text differs from [initialStatus]; saving
/// an empty field clears the status.
class StatusMessageSheet extends StatefulWidget {
  const StatusMessageSheet({
    super.key,
    required this.initialStatus,
    required this.onSave,
  });

  final String initialStatus;
  final ValueChanged<String> onSave;

  @override
  State<StatusMessageSheet> createState() => _StatusMessageSheetState();
}

class _StatusMessageSheetState extends State<StatusMessageSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialStatus,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BottomSheetHeader(
          icon: Icons.chat_bubble_outline,
          title: l10n.nodeDetailStatusMessageTitle,
          subtitle: l10n.nodeDetailStatusMessageDescription,
        ),
        const SizedBox(height: AppTheme.spacing24),
        BottomSheetTextField(
          controller: _controller,
          label: l10n.nodeDetailStatusMessageFieldLabel,
          maxLength: kStatusMessageMaxBytes,
          inputFormatters: const [
            Utf8ByteLengthFormatter(kStatusMessageMaxBytes),
          ],
          autofocus: true,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AppTheme.spacing24),
        BottomSheetButtons(
          cancelLabel: l10n.commonCancel,
          confirmLabel: l10n.commonSave,
          isConfirmEnabled: _controller.text != widget.initialStatus,
          onConfirm: () {
            widget.onSave(_controller.text);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
