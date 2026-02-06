// SPDX-License-Identifier: GPL-3.0-or-later

// NodeDex Import/Export Sheet — file-based import with preview and conflict
// resolution UI.
//
// Export flow:
//   1. User taps Export → JSON is written to a temp file and shared via
//      the system share sheet (share_plus).
//
// Import flow:
//   1. User taps Import → file picker opens for .json files
//   2. JSON is parsed and previewed (new entries, merges, conflicts)
//   3. User reviews the preview and selects a merge strategy
//   4. If conflicts exist, user can resolve them individually or pick
//      a blanket strategy (keep local / prefer import)
//   5. Import is applied and a summary is shown
//
// This widget is presented via AppBottomSheet.show() from the NodeDex
// main screen's action menu.

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../utils/snackbar.dart';
import '../models/import_preview.dart';
import '../providers/nodedex_providers.dart';

// =============================================================================
// Export Action
// =============================================================================

/// Shows the export action sheet and handles file sharing.
///
/// Call this from the NodeDex screen's action menu.
Future<void> showNodeDexExportSheet({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  // Capture before async.
  final messenger = ScaffoldMessenger.of(context);
  final box = context.findRenderObject() as RenderBox?;
  final sharePosition = box != null
      ? box.localToGlobal(Offset.zero) & box.size
      : const Rect.fromLTWH(0, 0, 100, 100);

  final notifier = ref.read(nodeDexProvider.notifier);

  final json = await notifier.exportJson();
  if (json == null || json.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Nothing to export — NodeDex is empty')),
    );
    return;
  }

  try {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().toIso8601String().split('T').first;
    final fileName = 'nodedex_export_$timestamp.json';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(json);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: fileName,
      text: 'Socialmesh NodeDex Export',
      sharePositionOrigin: sharePosition,
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

// =============================================================================
// Import Flow Entry Point
// =============================================================================

/// Picks a JSON file and shows the import preview sheet.
///
/// Call this from the NodeDex screen's action menu.
Future<void> startNodeDexImport({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  // Capture before async.
  final navigator = Navigator.of(context);
  final messenger = ScaffoldMessenger.of(context);

  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    String? jsonString;

    if (file.bytes != null) {
      jsonString = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      jsonString = await File(file.path!).readAsString();
    }

    if (jsonString == null || jsonString.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Failed to read file')),
      );
      return;
    }

    // Parse the JSON.
    final notifier = ref.read(nodeDexProvider.notifier);
    final entries = notifier.parseImportJson(jsonString);

    if (entries.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No valid NodeDex entries found in file')),
      );
      return;
    }

    // Build preview.
    final preview = await notifier.previewImport(entries);

    if (!navigator.mounted) return;

    // Show the preview sheet.
    await AppBottomSheet.show<void>(
      context: navigator.context,
      child: _ImportPreviewSheet(preview: preview),
    );
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
  }
}

// =============================================================================
// Import Preview Sheet
// =============================================================================

class _ImportPreviewSheet extends ConsumerStatefulWidget {
  final ImportPreview preview;

  const _ImportPreviewSheet({required this.preview});

  @override
  ConsumerState<_ImportPreviewSheet> createState() =>
      _ImportPreviewSheetState();
}

class _ImportPreviewSheetState extends ConsumerState<_ImportPreviewSheet>
    with LifecycleSafeMixin<_ImportPreviewSheet> {
  MergeStrategy _strategy = MergeStrategy.keepLocal;
  bool _showConflictDetails = false;
  bool _isImporting = false;

  /// Per-entry conflict resolutions (when reviewing individually).
  final Map<int, ConflictResolution> _resolutions = {};

  @override
  Widget build(BuildContext context) {
    final preview = widget.preview;

    if (preview.isEmpty) {
      return _buildEmpty(context);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        _buildHeader(context),

        const SizedBox(height: 16),

        // Summary stats
        _buildSummary(context, preview),

        const SizedBox(height: 16),

        // Conflict section (if any)
        if (preview.hasConflicts) ...[
          _buildConflictSection(context, preview),
          const SizedBox(height: 16),
        ],

        // Strategy selector
        if (preview.hasConflicts) ...[
          _buildStrategySelector(context),
          const SizedBox(height: 16),
        ],

        // Conflict details (expandable)
        if (_showConflictDetails && preview.hasConflicts) ...[
          _buildConflictDetails(context, preview),
          const SizedBox(height: 16),
        ],

        // Import button
        _buildImportButton(context, preview),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.inbox_outlined,
          size: 48,
          color: context.textTertiary.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 12),
        Text(
          'Nothing to import',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'The file contains no valid NodeDex entries.',
          style: TextStyle(fontSize: 13, color: context.textTertiary),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: context.accentColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.file_download_outlined,
            size: 20,
            color: context.accentColor,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Import Preview',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Review before applying',
                style: TextStyle(fontSize: 12, color: context.textTertiary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(BuildContext context, ImportPreview preview) {
    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryCell(
                  icon: Icons.add_circle_outline,
                  label: 'New',
                  value: '${preview.newEntryCount}',
                  color: AppTheme.successGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCell(
                  icon: Icons.merge_outlined,
                  label: 'Merge',
                  value: '${preview.mergeEntryCount}',
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryCell(
                  icon: Icons.warning_amber_outlined,
                  label: 'Conflicts',
                  value: '${preview.conflictCount}',
                  color: preview.hasConflicts
                      ? AppTheme.warningYellow
                      : context.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${preview.totalImported} entries in file',
            style: TextStyle(fontSize: 11, color: context.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildConflictSection(BuildContext context, ImportPreview preview) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warningYellow.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.warningYellow.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppTheme.warningYellow),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Some entries have conflicting data',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _buildConflictSummaryText(preview),
            style: TextStyle(fontSize: 12, color: context.textSecondary),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _showConflictDetails = !_showConflictDetails);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _showConflictDetails ? 'Hide details' : 'Show details',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.accentColor,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  _showConflictDetails ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: context.accentColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _buildConflictSummaryText(ImportPreview preview) {
    final parts = <String>[];
    if (preview.socialTagConflictCount > 0) {
      parts.add(
        '${preview.socialTagConflictCount} classification '
        '${preview.socialTagConflictCount == 1 ? "conflict" : "conflicts"}',
      );
    }
    if (preview.userNoteConflictCount > 0) {
      parts.add(
        '${preview.userNoteConflictCount} note '
        '${preview.userNoteConflictCount == 1 ? "conflict" : "conflicts"}',
      );
    }
    if (parts.isEmpty) return 'Conflicts detected in user-owned fields.';
    return '${parts.join(" and ")}. Choose how to resolve below.';
  }

  Widget _buildStrategySelector(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Merge Strategy',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        _StrategyOption(
          icon: Icons.shield_outlined,
          title: 'Keep Local',
          description: 'Your classifications and notes stay unchanged',
          isSelected: _strategy == MergeStrategy.keepLocal,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _strategy = MergeStrategy.keepLocal);
          },
        ),
        const SizedBox(height: 8),
        _StrategyOption(
          icon: Icons.file_download_outlined,
          title: 'Prefer Import',
          description: 'Use imported classifications and notes where different',
          isSelected: _strategy == MergeStrategy.preferImport,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _strategy = MergeStrategy.preferImport);
          },
        ),
        const SizedBox(height: 8),
        _StrategyOption(
          icon: Icons.tune_outlined,
          title: 'Review Each',
          description: 'Decide per conflict which value to keep',
          isSelected: _strategy == MergeStrategy.reviewConflicts,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() {
              _strategy = MergeStrategy.reviewConflicts;
              _showConflictDetails = true;
            });
          },
        ),
      ],
    );
  }

  Widget _buildConflictDetails(BuildContext context, ImportPreview preview) {
    final conflicting = preview.conflictingEntries;
    if (conflicting.isEmpty) return const SizedBox.shrink();

    final isDark = context.isDarkMode;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conflicting Entries',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          ...conflicting.map(
            (entry) => _ConflictEntryRow(
              entry: entry,
              strategy: _strategy,
              resolution: _resolutions[entry.nodeNum],
              onResolutionChanged: (resolution) {
                setState(() {
                  _resolutions[entry.nodeNum] = resolution;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportButton(BuildContext context, ImportPreview preview) {
    final canImport = !_isImporting && preview.hasChanges;
    final unresolvedCount = _unresolvedConflictCount(preview);
    final needsResolution =
        _strategy == MergeStrategy.reviewConflicts && unresolvedCount > 0;

    return Column(
      children: [
        if (needsResolution)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '$unresolvedCount '
              '${unresolvedCount == 1 ? "conflict" : "conflicts"} '
              'unresolved — using "Keep Local" as default',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.warningYellow,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: canImport ? () => _applyImport(preview) : null,
            icon: _isImporting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.file_download_done_outlined),
            label: Text(
              _isImporting
                  ? 'Importing...'
                  : 'Import ${preview.totalImported} '
                        '${preview.totalImported == 1 ? "entry" : "entries"}',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: context.accentColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  int _unresolvedConflictCount(ImportPreview preview) {
    if (_strategy != MergeStrategy.reviewConflicts) return 0;
    return preview.conflictingEntries.where((e) {
      final r = _resolutions[e.nodeNum];
      if (r == null) return true;
      // Check if all conflicting fields have been resolved.
      if (e.socialTagConflict != null && r.useSocialTagFromImport == null) {
        return true;
      }
      if (e.userNoteConflict != null && r.useUserNoteFromImport == null) {
        return true;
      }
      return false;
    }).length;
  }

  Future<void> _applyImport(ImportPreview preview) async {
    // Capture before async.
    final notifier = ref.read(nodeDexProvider.notifier);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    safeSetState(() => _isImporting = true);

    try {
      final count = await notifier.importWithStrategy(
        preview: preview,
        strategy: _strategy,
        resolutions: _resolutions,
      );

      if (!mounted) return;

      navigator.pop();

      if (count > 0) {
        showSuccessSnackBar(
          messenger.context,
          'Imported $count ${count == 1 ? "entry" : "entries"}',
        );
      } else {
        showInfoSnackBar(messenger.context, 'Nothing new to import');
      }
    } catch (e) {
      if (!mounted) return;
      safeSetState(() => _isImporting = false);
      showErrorSnackBar(context, 'Import failed: $e');
    }
  }
}

// =============================================================================
// Summary Cell
// =============================================================================

class _SummaryCell extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCell({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: context.textTertiary),
        ),
      ],
    );
  }
}

// =============================================================================
// Strategy Option
// =============================================================================

class _StrategyOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _StrategyOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final accent = context.accentColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? accent.withValues(alpha: 0.08)
              : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? accent.withValues(alpha: 0.3)
                : context.border.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? accent : context.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? accent : context.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(fontSize: 11, color: context.textTertiary),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 18, color: accent)
            else
              Icon(
                Icons.radio_button_unchecked,
                size: 18,
                color: context.textTertiary.withValues(alpha: 0.4),
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Conflict Entry Row
// =============================================================================

class _ConflictEntryRow extends StatelessWidget {
  final EntryMergePreview entry;
  final MergeStrategy strategy;
  final ConflictResolution? resolution;
  final ValueChanged<ConflictResolution> onResolutionChanged;

  const _ConflictEntryRow({
    required this.entry,
    required this.strategy,
    this.resolution,
    required this.onResolutionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Node header
          Row(
            children: [
              Icon(
                Icons.hexagon_outlined,
                size: 14,
                color: context.accentColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.displayName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '!${entry.nodeNum.toRadixString(16).toUpperCase().padLeft(4, '0')}',
                style: TextStyle(
                  fontSize: 10,
                  color: context.textTertiary,
                  fontFamily: AppTheme.fontFamily,
                ),
              ),
            ],
          ),

          // Social tag conflict
          if (entry.socialTagConflict != null) ...[
            const SizedBox(height: 8),
            _FieldConflictRow(
              label: 'Classification',
              localValue:
                  entry.socialTagConflict!.localValue?.displayLabel ?? 'None',
              importedValue:
                  entry.socialTagConflict!.importedValue?.displayLabel ??
                  'None',
              useImport: _resolvedTagChoice,
              canResolve: strategy == MergeStrategy.reviewConflicts,
              onToggle: (useImport) {
                HapticFeedback.selectionClick();
                onResolutionChanged(
                  ConflictResolution(
                    nodeNum: entry.nodeNum,
                    useSocialTagFromImport: useImport,
                    useUserNoteFromImport: resolution?.useUserNoteFromImport,
                  ),
                );
              },
            ),
          ],

          // User note conflict
          if (entry.userNoteConflict != null) ...[
            const SizedBox(height: 8),
            _FieldConflictRow(
              label: 'Note',
              localValue: _truncate(
                entry.userNoteConflict!.localValue ?? 'None',
                60,
              ),
              importedValue: _truncate(
                entry.userNoteConflict!.importedValue ?? 'None',
                60,
              ),
              useImport: _resolvedNoteChoice,
              canResolve: strategy == MergeStrategy.reviewConflicts,
              onToggle: (useImport) {
                HapticFeedback.selectionClick();
                onResolutionChanged(
                  ConflictResolution(
                    nodeNum: entry.nodeNum,
                    useSocialTagFromImport: resolution?.useSocialTagFromImport,
                    useUserNoteFromImport: useImport,
                  ),
                );
              },
            ),
          ],

          // Divider between entries
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Divider(height: 1),
          ),
        ],
      ),
    );
  }

  bool? get _resolvedTagChoice {
    if (strategy == MergeStrategy.keepLocal) return false;
    if (strategy == MergeStrategy.preferImport) return true;
    return resolution?.useSocialTagFromImport;
  }

  bool? get _resolvedNoteChoice {
    if (strategy == MergeStrategy.keepLocal) return false;
    if (strategy == MergeStrategy.preferImport) return true;
    return resolution?.useUserNoteFromImport;
  }

  String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }
}

// =============================================================================
// Field Conflict Row
// =============================================================================

class _FieldConflictRow extends StatelessWidget {
  final String label;
  final String localValue;
  final String importedValue;
  final bool? useImport;
  final bool canResolve;
  final ValueChanged<bool> onToggle;

  const _FieldConflictRow({
    required this.label,
    required this.localValue,
    required this.importedValue,
    required this.useImport,
    required this.canResolve,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.textTertiary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            // Local value
            Expanded(
              child: _ConflictValueChip(
                label: 'Local',
                value: localValue,
                isSelected: useImport == false,
                color: AppTheme.primaryBlue,
                isDark: isDark,
                onTap: canResolve ? () => onToggle(false) : null,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.compare_arrows,
              size: 14,
              color: context.textTertiary.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 8),
            // Import value
            Expanded(
              child: _ConflictValueChip(
                label: 'Import',
                value: importedValue,
                isSelected: useImport == true,
                color: AppTheme.warningYellow,
                isDark: isDark,
                onTap: canResolve ? () => onToggle(true) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// Conflict Value Chip
// =============================================================================

class _ConflictValueChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isSelected;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;

  const _ConflictValueChip({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.color,
    required this.isDark,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.1)
              : (isDark ? Colors.white : Colors.black).withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.4)
                : context.border.withValues(alpha: 0.12),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? color : context.textTertiary,
                  ),
                ),
                if (isSelected) ...[
                  const Spacer(),
                  Icon(Icons.check, size: 12, color: color),
                ],
              ],
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                fontSize: 11,
                color: isSelected ? context.textPrimary : context.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
