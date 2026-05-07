// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// MeshCore Channel edit sheet (D31).
//
// Canonical inner-settings UI for adding or editing a channel slot
// on a connected MeshCore companion radio. Wraps a single firmware
// command (`CMD_SET_CHANNEL` = 0x20) — there is no separate edit-vs-add
// opcode at the pinned SHA, so this sheet is reused for both flows
// via the [mode] flag.
//
// PSK input modes (D31 scope):
//   - paste hex (32 hex chars = 16 raw bytes)
//   - paste full channel code (`name:pskHex`) — the share/import
//     format already used by D29's QR share/import. The "Paste from
//     channel code" button surfaces this without forcing the user to
//     split it manually.
//
// Out of D31 scope (deferred to a follow-up):
//   - random PSK generation
//   - derive PSK from passphrase
//   - QR scan-and-fill (existing scanner already lands at the
//     channels screen which then routes here pre-populated)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../core/widgets/settings_primitives.dart';
import '../../../models/meshcore_channel.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../utils/snackbar.dart';

/// Whether the sheet is opened to add a new slot or edit an existing one.
enum MeshCoreChannelEditMode { add, edit }

/// Open the channel edit sheet.
///
/// `existing` populates the form when editing. When [mode] is
/// [MeshCoreChannelEditMode.add] the sheet picks the lowest unused
/// slot from [occupiedSlots] (defaults to 0 when none are occupied).
Future<void> showMeshCoreChannelEditSheet({
  required BuildContext context,
  required MeshCoreChannelEditMode mode,
  MeshCoreChannel? existing,
  Set<int> occupiedSlots = const {},
  int slotCapacity = 8,
}) {
  return AppBottomSheet.showScrollable<void>(
    context: context,
    initialChildSize: 0.85,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (controller) => _MeshCoreChannelEditSheet(
      scrollController: controller,
      mode: mode,
      existing: existing,
      occupiedSlots: occupiedSlots,
      slotCapacity: slotCapacity,
    ),
  );
}

class _MeshCoreChannelEditSheet extends ConsumerStatefulWidget {
  final ScrollController scrollController;
  final MeshCoreChannelEditMode mode;
  final MeshCoreChannel? existing;
  final Set<int> occupiedSlots;
  final int slotCapacity;

  const _MeshCoreChannelEditSheet({
    required this.scrollController,
    required this.mode,
    required this.existing,
    required this.occupiedSlots,
    required this.slotCapacity,
  });

  @override
  ConsumerState<_MeshCoreChannelEditSheet> createState() =>
      _MeshCoreChannelEditSheetState();
}

class _MeshCoreChannelEditSheetState
    extends ConsumerState<_MeshCoreChannelEditSheet>
    with LifecycleSafeMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _pskController;
  late int _selectedSlot;
  bool _saving = false;

  bool get _isEdit => widget.mode == MeshCoreChannelEditMode.edit;

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _pskController = TextEditingController(text: widget.existing?.pskHex ?? '');

    if (_isEdit && widget.existing != null) {
      _selectedSlot = widget.existing!.index;
    } else {
      _selectedSlot = _firstFreeSlot();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _pskController.dispose();
    super.dispose();
  }

  int _firstFreeSlot() {
    for (int i = 0; i < widget.slotCapacity; i++) {
      if (!widget.occupiedSlots.contains(i)) return i;
    }
    return 0;
  }

  String? _validateName(String? value, AppLocalizations l10n) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return l10n.meshcoreChannelEditNameRequired;
    if (trimmed.codeUnits.length > 32) {
      return l10n.meshcoreChannelEditNameTooLong;
    }
    return null;
  }

  String? _validatePsk(String? value, AppLocalizations l10n) {
    final trimmed = (value ?? '').replaceAll(' ', '').trim();
    if (trimmed.isEmpty) return l10n.meshcoreChannelEditPskRequired;
    if (trimmed.length != 32) return l10n.meshcoreChannelEditPskBadLength;
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(trimmed)) {
      return l10n.meshcoreChannelEditPskBadHex;
    }
    return null;
  }

  Uint8List? _parsePsk(String hex) {
    final clean = hex.replaceAll(' ', '').trim();
    if (clean.length != 32) return null;
    final out = Uint8List(16);
    for (int i = 0; i < 16; i++) {
      final byte = int.tryParse(clean.substring(i * 2, i * 2 + 2), radix: 16);
      if (byte == null) return null;
      out[i] = byte;
    }
    return out;
  }

  /// Try to interpret the PSK field as a full channel code
  /// (`name:pskHex`). If it parses cleanly, replace the name field with
  /// the parsed name and the PSK field with the parsed PSK hex. No-op
  /// if the field doesn't contain a `:` or doesn't parse.
  void _tryImportChannelCode() {
    final raw = _pskController.text.trim();
    if (!raw.contains(':')) return;
    final parsed = parseChannelCode(raw, index: _selectedSlot);
    if (parsed == null) {
      showErrorSnackBar(
        context,
        context.l10n.meshcoreChannelEditCodeImportFailed,
      );
      return;
    }
    setState(() {
      _nameController.text = parsed.name;
      _pskController.text = parsed.pskHex;
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final name = _nameController.text.trim();
    final psk = _parsePsk(_pskController.text);
    if (psk == null) {
      showErrorSnackBar(context, l10n.meshcoreChannelEditPskBadHex);
      return;
    }

    setState(() => _saving = true);
    final notifier = ref.read(meshCoreChannelsProvider.notifier);

    final ok = _isEdit
        ? await notifier.editChannel(index: _selectedSlot, name: name, psk: psk)
        : await notifier.addChannel(index: _selectedSlot, name: name, psk: psk);

    if (!mounted) return;
    if (ok) {
      safeNavigatorPop();
      showSuccessSnackBar(
        context,
        _isEdit
            ? l10n.meshcoreChannelEditSavedSuccess(name)
            : l10n.meshcoreChannelEditAddedSuccess(name),
      );
    } else {
      safeSetState(() => _saving = false);
      showErrorSnackBar(context, l10n.meshcoreChannelEditSaveFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = AccentColors.purple;

    return Form(
      key: _formKey,
      child: ListView(
        controller: widget.scrollController,
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing8,
              AppTheme.spacing16,
              AppTheme.spacing4,
            ),
            child: Text(
              _isEdit
                  ? l10n.meshcoreChannelEditTitleEdit
                  : l10n.meshcoreChannelEditTitleAdd,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              0,
              AppTheme.spacing16,
              AppTheme.spacing16,
            ),
            child: Text(
              l10n.meshcoreChannelEditHint,
              style: TextStyle(fontSize: 13, color: context.textTertiary),
            ),
          ),

          SettingsSectionHeader(title: l10n.meshcoreChannelEditSlotSection),
          SettingsTile(
            icon: Icons.numbers_rounded,
            iconColor: accent,
            title: l10n.meshcoreChannelEditSlotLabel,
            subtitle: l10n.meshcoreChannelEditSlotSubtitle(_selectedSlot),
            trailing: _isEdit
                ? null
                : Icon(Icons.chevron_right, color: context.textTertiary),
            onTap: (_isEdit || _saving) ? null : () => _openSlotPicker(l10n),
          ),

          SettingsSectionHeader(title: l10n.meshcoreChannelEditNameSection),
          FieldGroupCard(
            child: TextFormField(
              controller: _nameController,
              maxLength: 32,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              style: TextStyle(color: context.textPrimary),
              validator: (v) => _validateName(v, l10n),
              decoration: InputDecoration(
                labelText: l10n.meshcoreChannelEditNameLabel,
                labelStyle: TextStyle(color: context.textSecondary),
                hintText: l10n.meshcoreChannelEditNameHint,
                hintStyle: TextStyle(color: SemanticColors.muted),
                filled: true,
                fillColor: context.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(color: context.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(color: context.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radius8),
                  borderSide: BorderSide(color: accent),
                ),
                prefixIcon: Icon(
                  Icons.tag_rounded,
                  color: context.textSecondary,
                ),
                counterText: '',
              ),
            ),
          ),

          SettingsSectionHeader(title: l10n.meshcoreChannelEditPskSection),
          FieldGroupCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _pskController,
                  maxLength: 200,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  style: TextStyle(
                    color: context.textPrimary,
                    fontFamily: AppTheme.fontFamily,
                  ),
                  // PSK is treated as sensitive and the firmware never
                  // surfaces it back in plaintext logs (D29 redaction).
                  // We don't auto-mask the field because the user
                  // explicitly pasted it and needs to verify they
                  // typed/pasted the right value.
                  validator: (v) => _validatePsk(v, l10n),
                  decoration: InputDecoration(
                    labelText: l10n.meshcoreChannelEditPskLabel,
                    labelStyle: TextStyle(color: context.textSecondary),
                    hintText: l10n.meshcoreChannelEditPskHint,
                    hintStyle: TextStyle(color: SemanticColors.muted),
                    helperText: l10n.meshcoreChannelEditPskHelper,
                    helperStyle: TextStyle(
                      color: context.textTertiary,
                      fontSize: 12,
                    ),
                    helperMaxLines: 3,
                    filled: true,
                    fillColor: context.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      borderSide: BorderSide(color: context.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      borderSide: BorderSide(color: context.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                      borderSide: BorderSide(color: accent),
                    ),
                    prefixIcon: Icon(
                      Icons.vpn_key_rounded,
                      color: context.textSecondary,
                    ),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: AppTheme.spacing12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _tryImportChannelCode,
                  icon: const Icon(Icons.content_paste_go_rounded),
                  label: Text(l10n.meshcoreChannelEditImportFromCode),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: accent,
                    side: BorderSide(color: context.border),
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spacing12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radius8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing24,
              AppTheme.spacing16,
              AppTheme.spacing16,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    child: Text(l10n.meshcoreCancel),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: PrimaryGradientButton(
                    label: _saving
                        ? l10n.meshcoreChannelEditSaving
                        : l10n.meshcoreChannelEditSave,
                    icon: Icons.check_rounded,
                    accentColor: accent,
                    onPressed: _saving ? null : _save,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppTheme.spacing16),
        ],
      ),
    );
  }

  void _openSlotPicker(AppLocalizations l10n) async {
    final picked = await AppBottomSheet.show<int>(
      context: context,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing4,
              AppTheme.spacing16,
              AppTheme.spacing12,
            ),
            child: Text(
              l10n.meshcoreChannelEditPickSlotTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: context.textPrimary,
              ),
            ),
          ),
          for (int i = 0; i < widget.slotCapacity; i++)
            InkWell(
              onTap: () => Navigator.of(context).pop(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing12,
                ),
                child: Row(
                  children: [
                    Icon(
                      i == _selectedSlot
                          ? Icons.radio_button_checked
                          : Icons.radio_button_unchecked,
                      color: i == _selectedSlot
                          ? AccentColors.purple
                          : context.textSecondary,
                    ),
                    const SizedBox(width: AppTheme.spacing16),
                    Text(
                      l10n.meshcoreChannelEditSlotSubtitle(i),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (widget.occupiedSlots.contains(i))
                      Text(
                        l10n.meshcoreChannelEditSlotOccupied,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.errorRed,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
    if (picked != null && mounted) {
      safeSetState(() => _selectedSlot = picked);
    }
  }
}
