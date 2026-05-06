// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../core/widgets/glass_scaffold.dart';
import '../../core/widgets/info_table.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/settings_primitives.dart';
import '../../providers/reticulum_providers.dart';
import '../../services/protocol/reticulum/reticulum_capture_classifier.dart';
import '../../services/protocol/reticulum/reticulum_capture_library.dart';
import '../../services/protocol/reticulum/reticulum_capture_metadata.dart';
import '../../utils/snackbar.dart';

class ReticulumCaptureDetailScreen extends ConsumerStatefulWidget {
  const ReticulumCaptureDetailScreen({super.key, required this.checksum});

  final String checksum;

  @override
  ConsumerState<ReticulumCaptureDetailScreen> createState() =>
      _ReticulumCaptureDetailScreenState();
}

class _ReticulumCaptureDetailScreenState
    extends ConsumerState<ReticulumCaptureDetailScreen>
    with LifecycleSafeMixin {
  final _deviceModelController = TextEditingController();
  final _firmwareVersionController = TextEditingController();
  final _regionController = TextEditingController();
  final _channelIndexController = TextEditingController();
  final _notesController = TextEditingController();

  ReticulumCaptureSource? _source;
  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    _deviceModelController.dispose();
    _firmwareVersionController.dispose();
    _regionController.dispose();
    _channelIndexController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _hydrateOnce(ReticulumCaptureMetadata m) {
    if (_hydrated) return;
    _hydrated = true;
    _deviceModelController.text = m.deviceModel ?? '';
    _firmwareVersionController.text = m.firmwareVersion ?? '';
    _regionController.text = m.region ?? '';
    _channelIndexController.text = m.channelIndex?.toString() ?? '';
    _notesController.text = m.notes;
    _source = m.source;
  }

  Future<void> _save(ReticulumCaptureEntry entry) async {
    if (_saving) return;
    HapticFeedback.selectionClick();
    safeSetState(() => _saving = true);
    try {
      final notifier = ref.read(reticulumCaptureListProvider.notifier);
      final deviceModel = _deviceModelController.text.trim();
      final firmwareVersion = _firmwareVersionController.text.trim();
      final region = _regionController.text.trim();
      final channelText = _channelIndexController.text.trim();
      final channelIndex = channelText.isEmpty
          ? null
          : int.tryParse(channelText);

      await notifier.updateProvenance(
        entry,
        source: _source,
        deviceModel: deviceModel.isEmpty ? null : deviceModel,
        deviceModelExplicitNull: deviceModel.isEmpty,
        firmwareVersion: firmwareVersion.isEmpty ? null : firmwareVersion,
        firmwareVersionExplicitNull: firmwareVersion.isEmpty,
        region: region.isEmpty ? null : region,
        regionExplicitNull: region.isEmpty,
        channelIndex: channelIndex,
        channelIndexExplicitNull: channelText.isEmpty,
        notes: _notesController.text,
      );
      if (!mounted) return;
      showSuccessSnackBar(context, context.l10n.reticulumDetailSaveSuccess);
    } finally {
      if (mounted) safeSetState(() => _saving = false);
    }
  }

  Future<void> _share(ReticulumCaptureEntry entry) async {
    HapticFeedback.selectionClick();
    await Share.shareXFiles([XFile(entry.file.path)]);
  }

  Future<void> _confirmDelete(ReticulumCaptureEntry entry) async {
    HapticFeedback.selectionClick();
    final confirmed = await AppBottomSheet.show<bool>(
      context: context,
      child: _DeleteConfirmSheet(filename: entry.filename),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await ref.read(reticulumCaptureListProvider.notifier).delete(entry);
    safeNavigatorPop();
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsync = ref.watch(reticulumCaptureListProvider);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: GlassScaffold(
        title: context.l10n.reticulumDetailTitle,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing8),
            sliver: SliverList.list(
              children: [
                entriesAsync.when(
                  data: (entries) {
                    final entry = entries
                        .where(
                          (e) => e.metadata.checksumSha256 == widget.checksum,
                        )
                        .firstOrNull;
                    if (entry == null) {
                      // Capture was deleted/imported away while we were
                      // open; close the screen on the next frame.
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) Navigator.of(context).maybePop();
                      });
                      return const SizedBox.shrink();
                    }
                    _hydrateOnce(entry.metadata);
                    return _DetailBody(
                      entry: entry,
                      source: _source ?? entry.metadata.source,
                      onSourceChanged: (s) => safeSetState(() => _source = s),
                      deviceModelController: _deviceModelController,
                      firmwareVersionController: _firmwareVersionController,
                      regionController: _regionController,
                      channelIndexController: _channelIndexController,
                      notesController: _notesController,
                      saving: _saving,
                      onSave: () => _save(entry),
                      onShare: () => _share(entry),
                      onDelete: () => _confirmDelete(entry),
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppTheme.spacing24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (e, _) {
                    AppLogging.reticulum('library_detail_error error=$e');
                    return Padding(
                      padding: const EdgeInsets.all(AppTheme.spacing16),
                      child: Text(
                        context.l10n.reticulumLibraryImportError,
                        style: TextStyle(color: AppTheme.errorRed),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppTheme.spacing24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.entry,
    required this.source,
    required this.onSourceChanged,
    required this.deviceModelController,
    required this.firmwareVersionController,
    required this.regionController,
    required this.channelIndexController,
    required this.notesController,
    required this.saving,
    required this.onSave,
    required this.onShare,
    required this.onDelete,
  });

  final ReticulumCaptureEntry entry;
  final ReticulumCaptureSource source;
  final ValueChanged<ReticulumCaptureSource> onSourceChanged;
  final TextEditingController deviceModelController;
  final TextEditingController firmwareVersionController;
  final TextEditingController regionController;
  final TextEditingController channelIndexController;
  final TextEditingController notesController;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  String _ts(int? ms, BuildContext context) {
    if (ms == null) return context.l10n.reticulumLibraryNoTimestamp;
    return DateTime.fromMillisecondsSinceEpoch(ms).toLocal().toIso8601String();
  }

  String _kindLabel(BuildContext context) {
    switch (entry.metadata.captureKind) {
      case ReticulumCaptureKind.harness:
        return context.l10n.reticulumLibraryKindHarness;
      case ReticulumCaptureKind.realCandidate:
        return context.l10n.reticulumLibraryKindReal;
      case ReticulumCaptureKind.invalid:
        return context.l10n.reticulumLibraryKindInvalid;
      case ReticulumCaptureKind.unsupportedVersion:
        return context.l10n.reticulumLibraryKindUnsupported;
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = entry.metadata;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(title: context.l10n.reticulumDetailSectionSummary),
              InfoTable(
                rows: [
                  InfoTableRow(
                    label: context.l10n.reticulumDetailFilename,
                    value: entry.filename,
                    icon: Icons.description_outlined,
                  ),
                  InfoTableRow(
                    label: context.l10n.reticulumDetailKind,
                    value: _kindLabel(context),
                    icon: Icons.label_outlined,
                  ),
                  InfoTableRow(
                    label: context.l10n.reticulumDetailRecordCount,
                    value: '${m.recordCount}',
                    icon: Icons.list_outlined,
                  ),
                  InfoTableRow(
                    label: context.l10n.reticulumDetailFirstSeen,
                    value: _ts(m.firstSeenMs, context),
                    icon: Icons.schedule_outlined,
                  ),
                  InfoTableRow(
                    label: context.l10n.reticulumDetailLastSeen,
                    value: _ts(m.lastSeenMs, context),
                    icon: Icons.schedule,
                  ),
                  InfoTableRow(
                    label: context.l10n.reticulumDetailDistinctSources,
                    value: '${m.distinctSources.length}',
                    icon: Icons.account_tree_outlined,
                  ),
                  InfoTableRow(
                    label: context.l10n.reticulumDetailContainsHarness,
                    value: m.containsHarnessMagic
                        ? context.l10n.reticulumDetailTrue
                        : context.l10n.reticulumDetailFalse,
                    icon: Icons.fingerprint,
                  ),
                  InfoTableRow(
                    label: context.l10n.reticulumDetailChecksum,
                    value: m.checksumSha256,
                    icon: Icons.tag,
                  ),
                  InfoTableRow(
                    label: context.l10n.reticulumDetailCreatedAt,
                    value: m.createdAtIso,
                    icon: Icons.event_outlined,
                  ),
                  InfoTableRow(
                    label: context.l10n.reticulumDetailClassifiedAt,
                    value: m.classifiedAtIso,
                    icon: Icons.event_available_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        SettingsSectionHeader(
          title: context.l10n.reticulumDetailSectionProvenance,
        ),
        _SourcePicker(value: source, onChanged: onSourceChanged),
        const SizedBox(height: AppTheme.spacing12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: FieldGroupCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProvField(
                  controller: deviceModelController,
                  label: context.l10n.reticulumDetailDeviceModel,
                  hint: context.l10n.reticulumDetailDeviceModelHint,
                  icon: Icons.memory,
                  maxLength: 64,
                ),
                _ProvField(
                  controller: firmwareVersionController,
                  label: context.l10n.reticulumDetailFirmwareVersion,
                  hint: context.l10n.reticulumDetailFirmwareVersionHint,
                  icon: Icons.bolt_outlined,
                  maxLength: 64,
                ),
                _ProvField(
                  controller: regionController,
                  label: context.l10n.reticulumDetailRegion,
                  hint: context.l10n.reticulumDetailRegionHint,
                  icon: Icons.public,
                  maxLength: 16,
                ),
                _ProvField(
                  controller: channelIndexController,
                  label: context.l10n.reticulumDetailChannelIndex,
                  hint: context.l10n.reticulumDetailChannelIndexHint,
                  icon: Icons.format_list_numbered,
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                ),
                _ProvField(
                  controller: notesController,
                  label: context.l10n.reticulumDetailNotes,
                  hint: context.l10n.reticulumDetailNotesHint,
                  icon: Icons.notes_outlined,
                  maxLength: 256,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: _GradientActionButton(
            label: context.l10n.reticulumDetailSave,
            icon: saving ? Icons.hourglass_top : Icons.save_outlined,
            onPressed: saving ? null : onSave,
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        SettingsTile(
          icon: Icons.ios_share,
          title: context.l10n.reticulumDetailShare,
          subtitle: entry.file.path,
          onTap: onShare,
          trailing: Icon(Icons.chevron_right, color: context.textTertiary),
        ),
        SettingsTile(
          icon: Icons.delete_outline,
          iconColor: AppTheme.errorRed,
          title: context.l10n.reticulumDetailDelete,
          subtitle: entry.checksumShortPrefix,
          onTap: onDelete,
          trailing: Icon(Icons.chevron_right, color: context.textTertiary),
        ),
      ],
    );
  }
}

class _SourcePicker extends StatelessWidget {
  const _SourcePicker({required this.value, required this.onChanged});
  final ReticulumCaptureSource value;
  final ValueChanged<ReticulumCaptureSource> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Container(
        decoration: BoxDecoration(
          color: context.card,
          borderRadius: BorderRadius.circular(AppTheme.radius12),
          border: Border.all(color: context.border),
        ),
        child: Column(
          children: [
            _sourceRow(
              context,
              ReticulumCaptureSource.local,
              context.l10n.reticulumDetailSourceLocal,
            ),
            Divider(height: 1, color: context.border),
            _sourceRow(
              context,
              ReticulumCaptureSource.shared,
              context.l10n.reticulumDetailSourceShared,
            ),
            Divider(height: 1, color: context.border),
            _sourceRow(
              context,
              ReticulumCaptureSource.airdrop,
              context.l10n.reticulumDetailSourceAirdrop,
            ),
            Divider(height: 1, color: context.border),
            _sourceRow(
              context,
              ReticulumCaptureSource.manual,
              context.l10n.reticulumDetailSourceManual,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceRow(
    BuildContext context,
    ReticulumCaptureSource s,
    String label,
  ) {
    final selected = value == s;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(s);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing12,
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: selected ? context.accentColor : context.textSecondary,
              size: 20,
            ),
            const SizedBox(width: AppTheme.spacing12),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: context.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProvField extends StatelessWidget {
  const _ProvField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.maxLength,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final int maxLength;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
      child: TextField(
        controller: controller,
        maxLength: maxLength,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: TextStyle(color: context.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: context.background,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            borderSide: BorderSide(color: context.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius8),
            borderSide: BorderSide(color: context.accentColor),
          ),
          prefixIcon: Icon(icon, color: context.textSecondary),
          counterText: '',
        ),
      ),
    );
  }
}

class _DeleteConfirmSheet extends StatelessWidget {
  const _DeleteConfirmSheet({required this.filename});
  final String filename;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.reticulumDetailDeleteConfirm,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4),
          Text(
            filename,
            style: TextStyle(fontSize: 12, color: context.textTertiary),
          ),
          const SizedBox(height: AppTheme.spacing12),
          Text(
            context.l10n.reticulumDetailDeleteConfirmDescription,
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),
          const SizedBox(height: AppTheme.spacing16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(context.l10n.reticulumDetailDeleteCancel),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.errorRed,
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(context.l10n.reticulumDetailDeleteConfirmAction),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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
