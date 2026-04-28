// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/material.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/animations.dart';
import '../../../core/widgets/bottom_action_bar.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../../services/backup/device_config_backup_service.dart';
import '../../../services/backup/device_config_bundle.dart';

/// Bottom-sheet body for picking which sections of a [DeviceConfigBundle]
/// to apply to the connected device. The caller hosts this inside an
/// [AppBottomSheet.showScrollable] and provides the [ScrollController] so
/// drag-to-dismiss works (per CLAUDE.md gray-area rule).
///
/// Pops with the resulting [RestoreReport] (or null if dismissed without
/// applying).
class DeviceConfigRestoreSheet extends StatefulWidget {
  final DeviceConfigBundle bundle;
  final int? connectedNodeNum;
  final ScrollController scrollController;
  final Future<RestoreReport> Function(RestoreSelection) onRestore;

  const DeviceConfigRestoreSheet({
    super.key,
    required this.bundle,
    required this.scrollController,
    required this.onRestore,
    this.connectedNodeNum,
  });

  @override
  State<DeviceConfigRestoreSheet> createState() =>
      _DeviceConfigRestoreSheetState();
}

class _DeviceConfigRestoreSheetState extends State<DeviceConfigRestoreSheet> {
  late RestoreSelection _selection = RestoreSelection(
    channels: widget.bundle.channels.isNotEmpty,
    radio:
        widget.bundle.lora != null ||
        widget.bundle.device != null ||
        widget.bundle.position != null ||
        widget.bundle.power != null ||
        widget.bundle.network != null ||
        widget.bundle.display != null ||
        widget.bundle.bluetooth != null,
    modules: widget.bundle.moduleConfigBytes.isNotEmpty,
    owner: widget.bundle.owner != null,
  );

  bool _restoring = false;

  bool get _nodeMismatch =>
      widget.bundle.nodeNum != null &&
      widget.connectedNodeNum != null &&
      widget.bundle.nodeNum != widget.connectedNodeNum;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing24,
            AppTheme.spacing12,
            AppTheme.spacing24,
            AppTheme.spacing8,
          ),
          child: Text(
            l10n.dataExportDeviceConfigRestoreSheetTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: context.textPrimary,
            ),
          ),
        ),
        Expanded(
          child: ListView(
            controller: widget.scrollController,
            padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
            children: [
              _Body(l10n.dataExportDeviceConfigRestoreSheetBody),
              if (_nodeMismatch)
                _MismatchBanner(
                  message: l10n.dataExportDeviceConfigRestoreNodeMismatch,
                ),
              _MetaCard(bundle: widget.bundle),
              _SectionHeader(
                text: l10n.dataExportDeviceConfigRestoreSheetTitle
                    .toUpperCase(),
              ),
              _ToggleRow(
                label: l10n.dataExportDeviceConfigRestoreToggleChannels,
                caption: l10n.dataExportDeviceConfigRestoreChannelsCount(
                  widget.bundle.channels.length,
                ),
                value: _selection.channels,
                enabled: !_restoring && widget.bundle.channels.isNotEmpty,
                onChanged: (v) => setState(
                  () => _selection = _selection.copyWith(channels: v),
                ),
              ),
              _Divider(),
              _ToggleRow(
                label: l10n.dataExportDeviceConfigRestoreToggleRadio,
                caption: _radioCaption(l10n),
                value: _selection.radio,
                enabled: !_restoring && _hasRadio,
                onChanged: (v) =>
                    setState(() => _selection = _selection.copyWith(radio: v)),
              ),
              _Divider(),
              _ToggleRow(
                label: l10n.dataExportDeviceConfigRestoreToggleModules,
                caption: l10n.dataExportDeviceConfigRestoreModulesCount(
                  widget.bundle.moduleConfigBytes.length,
                ),
                value: _selection.modules,
                enabled:
                    !_restoring && widget.bundle.moduleConfigBytes.isNotEmpty,
                onChanged: (v) => setState(
                  () => _selection = _selection.copyWith(modules: v),
                ),
              ),
              _Divider(),
              _ToggleRow(
                label: l10n.dataExportDeviceConfigRestoreToggleOwner,
                caption: widget.bundle.owner != null
                    ? l10n.dataExportDeviceConfigRestoreRadioPresent
                    : l10n.dataExportDeviceConfigRestoreRadioMissing,
                value: _selection.owner,
                enabled: !_restoring && widget.bundle.owner != null,
                onChanged: (v) =>
                    setState(() => _selection = _selection.copyWith(owner: v)),
              ),
            ],
          ),
        ),
        BottomActionBar(
          child: _ApplyButton(
            enabled: _selection.any && !_restoring,
            busy: _restoring,
            onPressed: _onApply,
            label: context.l10n.dataExportDeviceConfigRestoreApplyBtn,
          ),
        ),
      ],
    );
  }

  bool get _hasRadio =>
      widget.bundle.lora != null ||
      widget.bundle.device != null ||
      widget.bundle.position != null ||
      widget.bundle.power != null ||
      widget.bundle.network != null ||
      widget.bundle.display != null ||
      widget.bundle.bluetooth != null;

  String _radioCaption(dynamic l10n) {
    return _hasRadio
        ? l10n.dataExportDeviceConfigRestoreRadioPresent as String
        : l10n.dataExportDeviceConfigRestoreRadioMissing as String;
  }

  Future<void> _onApply() async {
    if (!_selection.any || _restoring) return;
    setState(() => _restoring = true);
    try {
      final report = await widget.onRestore(_selection);
      if (!mounted) return;
      Navigator.of(context).pop(report);
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }
}

class _Body extends StatelessWidget {
  final String text;
  const _Body(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing24,
        0,
        AppTheme.spacing24,
        AppTheme.spacing12,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: context.textSecondary,
          height: 1.4,
        ),
      ),
    );
  }
}

class _MismatchBanner extends StatelessWidget {
  final String message;
  const _MismatchBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        0,
        AppTheme.spacing16,
        AppTheme.spacing12,
      ),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: AccentColors.yellow.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius12),
        border: Border.all(color: AccentColors.yellow.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, color: AccentColors.yellow, size: 18),
          const SizedBox(width: AppTheme.spacing8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: context.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaCard extends StatelessWidget {
  final DeviceConfigBundle bundle;
  const _MetaCard({required this.bundle});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = <Widget>[];
    if (bundle.deviceMetadata != null) {
      rows.add(
        _MetaRow(
          label: l10n.dataExportDeviceConfigRestoreFromMetadata(
            bundle.deviceMetadata!,
          ),
        ),
      );
    }
    rows.add(
      _MetaRow(
        label: l10n.dataExportDeviceConfigRestoreCreatedAt(
          bundle.createdAt.toLocal().toIso8601String(),
        ),
      ),
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  const _MetaRow({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing4),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: context.textTertiary),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing16,
        AppTheme.spacing8,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: context.textTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final String caption;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.label,
    required this.caption,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing2,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(AppTheme.radius12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: enabled ? context.textPrimary : context.textTertiary,
                  ),
                ),
                SizedBox(height: AppTheme.spacing2),
                Text(
                  caption,
                  style: TextStyle(fontSize: 12, color: context.textTertiary),
                ),
              ],
            ),
          ),
          ThemedSwitch(value: value, onChanged: enabled ? onChanged : null),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(height: AppTheme.spacing4);
  }
}

class _ApplyButton extends StatelessWidget {
  final bool enabled;
  final bool busy;
  final VoidCallback onPressed;
  final String label;

  const _ApplyButton({
    required this.enabled,
    required this.busy,
    required this.onPressed,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: context.accentColor,
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radius12),
          ),
        ),
        child: busy
            ? LoadingIndicator(size: 18)
            : Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: SemanticColors.onAccent,
                ),
              ),
      ),
    );
  }
}
