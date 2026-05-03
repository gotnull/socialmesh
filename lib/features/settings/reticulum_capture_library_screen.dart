// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/animated_empty_state.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/settings_primitives.dart';
import '../../providers/reticulum_providers.dart';
import '../../services/protocol/reticulum/reticulum_capture_classifier.dart';
import '../../services/protocol/reticulum/reticulum_capture_library.dart';
import '../../utils/snackbar.dart';
import 'reticulum_capture_detail_screen.dart';

class ReticulumCaptureLibraryScreen extends ConsumerStatefulWidget {
  const ReticulumCaptureLibraryScreen({super.key});

  @override
  ConsumerState<ReticulumCaptureLibraryScreen> createState() =>
      _ReticulumCaptureLibraryScreenState();
}

class _ReticulumCaptureLibraryScreenState
    extends ConsumerState<ReticulumCaptureLibraryScreen>
    with LifecycleSafeMixin {
  bool _importing = false;

  Future<void> _refresh() async {
    HapticFeedback.selectionClick();
    await ref.read(reticulumCaptureListProvider.notifier).refresh();
  }

  Future<void> _import() async {
    if (_importing) return;
    HapticFeedback.selectionClick();
    // Capture the notifier handle before any await so we never touch
    // `ref` after the file-picker dispose lifecycle.
    final notifier = ref.read(reticulumCaptureListProvider.notifier);
    safeSetState(() => _importing = true);
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.any,
        withData: false,
        allowMultiple: false,
      );
      if (picked == null || picked.files.isEmpty) return;
      final path = picked.files.single.path;
      if (path == null) return;
      final result = await notifier.importFromFile(path);
      if (!mounted) return;
      _surfaceImportResult(result, picked.files.single.name);
    } finally {
      if (mounted) safeSetState(() => _importing = false);
    }
  }

  void _surfaceImportResult(
    ReticulumCaptureImportResult result,
    String sourceName,
  ) {
    switch (result) {
      case ReticulumCaptureImportSuccess():
        showSuccessSnackBar(
          context,
          context.l10n.reticulumLibraryImportSuccess(sourceName),
        );
        break;
      case ReticulumCaptureImportDuplicate():
        showInfoSnackBar(
          context,
          context.l10n.reticulumLibraryImportDuplicate(sourceName),
        );
        break;
      case ReticulumCaptureImportRejected(:final reason):
        switch (reason) {
          case ReticulumCaptureImportRejectionReason.invalidMagic:
            showErrorSnackBar(
              context,
              context.l10n.reticulumLibraryImportInvalid,
            );
            break;
          case ReticulumCaptureImportRejectionReason.unsupportedVersion:
            showErrorSnackBar(
              context,
              context.l10n.reticulumLibraryImportUnsupported,
            );
            break;
          case ReticulumCaptureImportRejectionReason.ioError:
            showErrorSnackBar(
              context,
              context.l10n.reticulumLibraryImportError,
            );
            break;
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(reticulumCaptureListProvider);
    return GlassScaffold(
      title: context.l10n.reticulumLibraryTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: context.l10n.reticulumLibraryRefresh,
          onPressed: _refresh,
        ),
      ],
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
          sliver: SliverList.list(
            children: [
              SettingsSectionHeader(
                title: context.l10n.reticulumLibrarySectionCaptures,
              ),
              entriesAsync.when(
                data: (entries) => entries.isEmpty
                    ? _EmptyState()
                    : _CaptureList(entries: entries),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppTheme.spacing24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) {
                  AppLogging.reticulum('library_list_error error=$e');
                  return Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing16),
                    child: Text(
                      context.l10n.reticulumLibraryImportError,
                      style: TextStyle(color: AppTheme.errorRed),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppTheme.spacing16),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                ),
                child: _GradientActionButton(
                  label: context.l10n.reticulumLibraryImport,
                  icon: Icons.file_open_outlined,
                  onPressed: _importing ? null : _import,
                ),
              ),
              const SizedBox(height: AppTheme.spacing24),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing24),
      child: AnimatedEmptyState(
        config: AnimatedEmptyStateConfig(
          icons: const [
            Icons.folder_open_outlined,
            Icons.archive_outlined,
            Icons.inventory_2_outlined,
            Icons.storage_outlined,
          ],
          taglines: [
            context.l10n.reticulumLibraryEmptyTagline1,
            context.l10n.reticulumLibraryEmptyTagline2,
            context.l10n.reticulumLibraryEmptyTagline3,
          ],
          titlePrefix: context.l10n.reticulumLibraryEmptyTitlePrefix,
          titleKeyword: context.l10n.reticulumLibraryEmptyTitleKeyword,
          titleSuffix: context.l10n.reticulumLibraryEmptyTitleSuffix,
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _CaptureList extends StatelessWidget {
  const _CaptureList({required this.entries});
  final List<ReticulumCaptureEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final entry in entries) _CaptureTile(entry: entry)],
    );
  }
}

class _CaptureTile extends StatelessWidget {
  const _CaptureTile({required this.entry});
  final ReticulumCaptureEntry entry;

  String _formatTimestamp(int? ms, BuildContext context) {
    if (ms == null) return context.l10n.reticulumLibraryNoTimestamp;
    return DateTime.fromMillisecondsSinceEpoch(ms).toLocal().toIso8601String();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing4,
      ),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          onTap: () {
            HapticFeedback.selectionClick();
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ReticulumCaptureDetailScreen(
                  checksum: entry.metadata.checksumSha256,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing12,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.filename,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    _KindBadge(kind: entry.metadata.captureKind),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing4),
                Wrap(
                  spacing: AppTheme.spacing12,
                  runSpacing: AppTheme.spacing4,
                  children: [
                    _MetaChip(
                      icon: Icons.list_outlined,
                      label: context.l10n.reticulumLibraryRecords(
                        entry.metadata.recordCount,
                      ),
                    ),
                    _MetaChip(
                      icon: Icons.account_tree_outlined,
                      label: context.l10n.reticulumLibrarySources(
                        entry.metadata.distinctSources.length,
                      ),
                    ),
                    _MetaChip(
                      icon: Icons.fingerprint,
                      label: entry.checksumShortPrefix,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spacing4),
                Text(
                  _formatTimestamp(entry.metadata.firstSeenMs, context),
                  style: TextStyle(fontSize: 11, color: context.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _KindBadge extends StatelessWidget {
  const _KindBadge({required this.kind});
  final ReticulumCaptureKind kind;

  @override
  Widget build(BuildContext context) {
    final (label, color) = _styleFor(context, kind);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radius8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }

  (String, Color) _styleFor(BuildContext context, ReticulumCaptureKind k) {
    switch (k) {
      case ReticulumCaptureKind.harness:
        return (
          context.l10n.reticulumLibraryKindHarness,
          AppTheme.warningYellow,
        );
      case ReticulumCaptureKind.realCandidate:
        return (context.l10n.reticulumLibraryKindReal, context.accentColor);
      case ReticulumCaptureKind.invalid:
        return (context.l10n.reticulumLibraryKindInvalid, AppTheme.errorRed);
      case ReticulumCaptureKind.unsupportedVersion:
        return (
          context.l10n.reticulumLibraryKindUnsupported,
          AppTheme.warningYellow,
        );
    }
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: context.textTertiary),
        const SizedBox(width: AppTheme.spacing4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: context.textTertiary),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spacing12,
            horizontal: AppTheme.spacing16,
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                context.accentColor.withValues(alpha: disabled ? 0.4 : 1.0),
                context.accentColor.withValues(alpha: disabled ? 0.3 : 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(AppTheme.radius12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
