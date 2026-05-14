// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D46-A: confirmation sheet between paste/parse and commit on the
// contact-import flow. Renders the parsed preview (name, 8-char
// pubkey fingerprint, last-seen, GPS, format provenance) so the user
// can verify they're adding the right contact before the firmware
// sees the `CMD_IMPORT_CONTACT` (or D29 fallback) frame.
//
// Privacy: NEVER renders the full 64-char pubkey hex. Fingerprint is
// 8 chars, sourced from `MeshCoreContactImportPreview.pubKeyFingerprint8`.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/info_table.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/meshcore_contact_import_preview.dart';
import '../../../providers/meshcore_providers.dart';

/// Opens the import confirmation sheet for [preview]. Returns:
///   - `true` when commit succeeded
///   - `false` when commit failed
///   - `null` when the user dismissed the sheet without confirming
///
/// The caller surfaces the success / failure snackbar; doing it here
/// would require holding the about-to-be-popped sheet context past
/// the navigator pop and leaks tickers in widget tests.
Future<bool?> showMeshCoreContactImportSheet(
  BuildContext context, {
  required MeshCoreContactImportPreview preview,
}) {
  return AppBottomSheet.show<bool>(
    context: context,
    child: _ContactImportSheet(preview: preview),
  );
}

class _ContactImportSheet extends ConsumerStatefulWidget {
  final MeshCoreContactImportPreview preview;

  const _ContactImportSheet({required this.preview});

  @override
  ConsumerState<_ContactImportSheet> createState() =>
      _ContactImportSheetState();
}

class _ContactImportSheetState extends ConsumerState<_ContactImportSheet>
    with LifecycleSafeMixin<_ContactImportSheet> {
  bool _committing = false;

  Future<void> _confirm() async {
    if (_committing) return;
    setState(() => _committing = true);
    final navigator = Navigator.of(context);
    final ok = await ref
        .read(meshCoreContactsProvider.notifier)
        .commitContactImport(widget.preview);
    if (!mounted) return;
    // Bubble the result up to the caller — they own the snackbar +
    // any downstream navigation.
    navigator.pop(ok);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final p = widget.preview;
    final contact = p.contact;
    final isModern = p.format == MeshCoreContactImportFormat.modern;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionTitle(title: l10n.meshcoreContactImportConfirmTitle),
        const SizedBox(height: AppTheme.spacing12),
        InfoTable(
          rows: [
            InfoTableRow(
              label: l10n.meshcoreContactImportRowName,
              value: contact.name.isEmpty ? '-' : contact.name,
            ),
            InfoTableRow(
              label: l10n.meshcoreContactImportRowPubkey,
              value: p.pubKeyFingerprint8,
            ),
            InfoTableRow(
              label: l10n.meshcoreContactImportRowLastSeen,
              value: isModern
                  ? _formatLastSeen(contact.lastSeen)
                  : l10n.meshcoreContactImportLastSeenUnknown,
            ),
            InfoTableRow(
              label: l10n.meshcoreContactImportRowLocation,
              value: (contact.latitude != null && contact.longitude != null)
                  ? '${contact.latitude!.toStringAsFixed(4)}, '
                        '${contact.longitude!.toStringAsFixed(4)}'
                  : l10n.meshcoreContactImportLocationUnknown,
            ),
            InfoTableRow(
              label: l10n.meshcoreContactImportRowFormat,
              value: isModern
                  ? l10n.meshcoreContactImportConfirmFormatFull
                  : l10n.meshcoreContactImportConfirmFormatLegacy,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing16),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const ValueKey('meshcore-contact-import-confirm'),
            onPressed: _committing ? null : _confirm,
            child: _committing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.meshcoreContactImportConfirmAction),
          ),
        ),
      ],
    );
  }

  static String _formatLastSeen(DateTime when) {
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${when.year}-${pad(when.month)}-${pad(when.day)} '
        '${pad(when.hour)}:${pad(when.minute)}';
  }
}
