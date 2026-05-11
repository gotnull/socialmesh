// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D39-A - per-contact path history sheet.
//
// Opens from the Path History tile on a chat or repeater contact
// detail screen. Lists every saved-from-trace path for the target
// contact, newest-used first, with a two-step activation confirm
// and a View / Delete long-press menu.
//
// Privacy:
//   - Row composition: hop count, age, source badge, optional stale +
//     active markers. NO raw path bytes on the row.
//   - View sub-sheet shows the raw path bytes in hex - same surface
//     the contact-detail routing card already exposes. Never a full
//     pubkey for any hop (the bytes ARE the hops; one byte per hop).
//   - Logging stays on the notifier; this widget emits nothing.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/section_header.dart';
import '../../../models/meshcore_contact.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/meshcore/storage/meshcore_path_history_store.dart';
import '../../../utils/snackbar.dart';

/// 7-day threshold for the "stale" chip on a saved path row. Paths
/// older than this still activate, but the row warns first.
const Duration kMeshCorePathHistoryStaleAge = Duration(days: 7);

Future<void> showMeshCorePathHistorySheet(
  BuildContext context, {
  required MeshCoreContact contact,
}) {
  return AppBottomSheet.showScrollable<void>(
    context: context,
    initialChildSize: 0.85,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (controller) =>
        _PathHistorySheet(contact: contact, scrollController: controller),
  );
}

class _PathHistorySheet extends ConsumerWidget {
  final MeshCoreContact contact;
  final ScrollController scrollController;

  const _PathHistorySheet({
    required this.contact,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final entries = ref.watch(
      meshCorePathHistoryProvider(contact.publicKeyHex),
    );
    final activeBytes = contact.path;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing16,
            AppTheme.spacing16,
            AppTheme.spacing8,
          ),
          child: SectionTitle(title: l10n.meshcorePathHistoryTitle),
        ),
        const Divider(height: 1),
        Expanded(
          child: entries.isEmpty
              ? _EmptyState(l10n: l10n)
              : ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacing8,
                  ),
                  itemCount: entries.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppTheme.spacing4),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return _PathHistoryRow(
                      contact: contact,
                      entry: entry,
                      isActive: _bytesEq(entry.bytes, activeBytes),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing8,
            AppTheme.spacing16,
            AppTheme.spacing16,
          ),
          child: Text(
            l10n.meshcorePathHistoryFooter,
            style: TextStyle(color: context.textTertiary, fontSize: 12),
          ),
        ),
      ],
    );
  }

  static bool _bytesEq(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _EmptyState extends StatelessWidget {
  final dynamic l10n;
  const _EmptyState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing24),
        child: Text(
          l10n.meshcorePathHistoryEmpty,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textTertiary),
        ),
      ),
    );
  }
}

class _PathHistoryRow extends ConsumerWidget {
  final MeshCoreContact contact;
  final MeshCorePathHistoryEntry entry;
  final bool isActive;

  const _PathHistoryRow({
    required this.contact,
    required this.entry,
    required this.isActive,
  });

  bool get _isStale =>
      DateTime.now().difference(entry.lastUsedAt) >
      kMeshCorePathHistoryStaleAge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return InkWell(
      onTap: () => _confirmActivate(context, ref),
      onLongPress: () => _openRowOptions(context, ref),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
        padding: const EdgeInsets.all(AppTheme.spacing12),
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border, width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: context.background,
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              child: Center(
                child: Text(
                  '${entry.len}',
                  style: TextStyle(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.meshcorePathHistoryHopCount(entry.len),
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing2),
                  Text(
                    _formatAge(context, entry.lastUsedAt),
                    style: TextStyle(
                      color: context.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing4),
                  Wrap(
                    spacing: AppTheme.spacing6,
                    runSpacing: AppTheme.spacing4,
                    children: [
                      _Badge(
                        label: _sourceLabel(l10n, entry.source),
                        color: AccentColors.purple,
                      ),
                      if (isActive)
                        _Badge(
                          label: l10n.meshcorePathHistoryActiveBadge,
                          color: AccentColors.green,
                        ),
                      if (_isStale)
                        _Badge(
                          label: l10n.meshcorePathHistoryStaleBadge,
                          color: AccentColors.slate,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: context.textTertiary),
          ],
        ),
      ),
    );
  }

  String _sourceLabel(dynamic l10n, MeshCorePathSource source) {
    switch (source) {
      case MeshCorePathSource.trace:
        return l10n.meshcorePathHistorySourceTrace as String;
      case MeshCorePathSource.manual:
        return l10n.meshcorePathHistorySourceManual as String;
    }
  }

  String _formatAge(BuildContext context, DateTime when) {
    final l10n = context.l10n;
    final delta = DateTime.now().difference(when);
    if (delta.inSeconds < 60) return l10n.meshcorePathHistoryAgeJustNow;
    if (delta.inMinutes < 60) {
      return l10n.meshcorePathHistoryAgeMinutes(delta.inMinutes);
    }
    if (delta.inHours < 24) {
      return l10n.meshcorePathHistoryAgeHours(delta.inHours);
    }
    return l10n.meshcorePathHistoryAgeDays(delta.inDays);
  }

  Future<void> _confirmActivate(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await AppBottomSheet.showConfirm(
      context: context,
      title: l10n.meshcorePathHistoryActivateConfirmTitle,
      message: l10n.meshcorePathHistoryActivateConfirmMessage,
      confirmLabel: l10n.meshcorePathHistoryActivateConfirmAction,
    );
    if (confirmed != true) return;
    HapticFeedback.selectionClick();
    final ok = await ref
        .read(meshCorePathHistoryProvider(contact.publicKeyHex).notifier)
        .activate(entry.id);
    if (!context.mounted) return;
    if (ok) {
      showSuccessSnackBar(context, l10n.meshcorePathHistoryActivateSuccess);
    } else {
      showErrorSnackBar(context, l10n.meshcorePathHistoryActivateFailed);
    }
  }

  Future<void> _openRowOptions(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    await AppBottomSheet.showActions<void>(
      context: context,
      actions: [
        BottomSheetAction(
          icon: Icons.visibility_rounded,
          label: l10n.meshcorePathHistoryViewBytesAction,
          onTap: () => _openViewSheet(context),
        ),
        BottomSheetAction(
          icon: Icons.delete_rounded,
          label: l10n.meshcorePathHistoryDeleteAction,
          isDestructive: true,
          onTap: () => _delete(context, ref),
        ),
      ],
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    await ref
        .read(meshCorePathHistoryProvider(contact.publicKeyHex).notifier)
        .delete(entry.id);
    if (!context.mounted) return;
    showSuccessSnackBar(context, l10n.meshcorePathHistoryDeleted);
  }

  Future<void> _openViewSheet(BuildContext context) async {
    final l10n = context.l10n;
    final hex = _bytesToHex(entry.bytes);
    await AppBottomSheet.show<void>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title: l10n.meshcorePathHistoryViewTitle),
          const SizedBox(height: AppTheme.spacing12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppTheme.spacing12),
            decoration: BoxDecoration(
              color: context.background,
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              border: Border.all(color: context.border, width: 1),
            ),
            child: Text(
              hex,
              style: TextStyle(
                color: context.textPrimary,
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            l10n.meshcorePathHistoryViewHopCount(entry.len),
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppTheme.radius4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
