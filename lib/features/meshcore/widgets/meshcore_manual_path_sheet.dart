// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D34c-B-B: manual N-hop path entry sheet.
//
// Reached from the Contact Detail "Routing" action sheet via the
// "Set custom path..." entry. Lets the power user type a
// comma-separated list of pubkey-prefix hex bytes that the firmware
// should route the target contact's outbound traffic through. Each
// hop = 1 byte = the first byte of a repeater's public key.
//
// Wire surface: zero new constants. On apply, the parsed bytes flow
// into `MeshCoreContactsNotifier.setContactPathFromManualEntry`
// which rides the existing `addUpdateContact` path; the only
// distinction from the saved-trace flow is the
// `MeshCorePathSource.manual` history label.
//
// Async safety: ConsumerStatefulWidget + LifecycleSafeMixin. The
// apply flow checks `mounted` after the firmware await before
// touching context.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_extension.dart';
import '../../../core/safety/lifecycle_mixin.dart';
import '../../../core/theme.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/primary_gradient_button.dart';
import '../../../models/meshcore_contact.dart';
import '../../../providers/meshcore_providers.dart';
import '../../../services/meshcore/routing/meshcore_manual_path_parser.dart';
import '../../../utils/snackbar.dart';

const int _kManualPathInputMaxLength = 200;

/// D34c-B-B: open the manual N-hop path sheet for [contact]. Returns
/// true on a successful apply, false on cancel / failure.
Future<bool> showMeshCoreManualPathSheet(
  BuildContext context, {
  required MeshCoreContact contact,
}) async {
  final result = await AppBottomSheet.showScrollable<bool>(
    context: context,
    initialChildSize: 0.85,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (controller) =>
        _ManualPathSheet(contact: contact, scrollController: controller),
  );
  return result ?? false;
}

class _ManualPathSheet extends ConsumerStatefulWidget {
  final MeshCoreContact contact;
  final ScrollController scrollController;

  const _ManualPathSheet({
    required this.contact,
    required this.scrollController,
  });

  @override
  ConsumerState<_ManualPathSheet> createState() => _ManualPathSheetState();
}

class _ManualPathSheetState extends ConsumerState<_ManualPathSheet>
    with LifecycleSafeMixin<_ManualPathSheet> {
  final TextEditingController _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _appendContactPrefix(MeshCoreContact c) {
    final hex = c.publicKeyHex;
    if (hex.length < 2) return;
    final prefix = hex.substring(0, 2).toUpperCase();
    final current = _controller.text;
    final separator = current.isEmpty || current.endsWith(',') ? '' : ',';
    final next = '$current$separator$prefix,';
    _controller.text = next;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: _controller.text.length),
    );
    setState(() {});
    HapticFeedback.selectionClick();
  }

  void _clear() {
    _controller.clear();
    setState(() {});
    HapticFeedback.selectionClick();
  }

  Future<void> _apply() async {
    final l10n = context.l10n;
    final parsed = parseManualPathHexPrefixes(_controller.text);
    if (parsed.isInvalidToken) {
      showErrorSnackBar(
        context,
        l10n.meshcoreManualPathInvalidToken(parsed.invalidToken ?? ''),
      );
      return;
    }
    if (parsed.isTooLong) {
      showErrorSnackBar(
        context,
        l10n.meshcoreManualPathTooLong(parsed.overflowLength ?? 0),
      );
      return;
    }
    final bytes = parsed.bytes ?? Uint8List(0);
    if (bytes.isEmpty) {
      // Treat empty as cancel rather than dispatching a zero-hop
      // override; the Contact Detail "Reset to Auto" action is the
      // explicit way to clear an override.
      safeNavigatorPop(false);
      return;
    }
    setState(() => _busy = true);
    HapticFeedback.mediumImpact();
    final ok = await ref
        .read(meshCoreContactsProvider.notifier)
        .setContactPathFromManualEntry(
          publicKeyHex: widget.contact.publicKeyHex,
          hopBytes: bytes,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    final name = widget.contact.displayName.isNotEmpty
        ? widget.contact.displayName
        : l10n.meshcoreContactUnknownName;
    if (ok) {
      showSuccessSnackBar(
        context,
        l10n.meshcoreManualPathApplySuccess(name, bytes.length),
      );
      safeNavigatorPop(true);
    } else {
      showErrorSnackBar(context, l10n.meshcoreManualPathApplyFailed(name));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parsed = parseManualPathHexPrefixes(_controller.text);
    final previewLines = _previewLines(parsed, l10n);
    final pickerContacts = ref
        .watch(meshCoreContactsProvider)
        .contacts
        .where((c) {
          // Only repeaters and rooms can act as path hops; chat-type
          // contacts are the leaves, not the routers.
          return c.type == MeshCoreAdvType.repeater ||
              c.type == MeshCoreAdvType.room;
        })
        .where((c) => c.publicKeyHex != widget.contact.publicKeyHex)
        .toList(growable: false);

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
          child: Text(
            l10n.meshcoreManualPathTitle(widget.contact.name),
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
            AppTheme.spacing12,
          ),
          child: Text(
            l10n.meshcoreManualPathHelper,
            style: TextStyle(color: context.textSecondary, fontSize: 13),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
          child: TextField(
            key: const ValueKey('meshcore-manual-path-input'),
            controller: _controller,
            enabled: !_busy,
            maxLength: _kManualPathInputMaxLength,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Fa-f, ]')),
            ],
            onChanged: (_) => setState(() {}),
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              color: context.textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              labelText: l10n.meshcoreManualPathInputLabel,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius8),
              ),
              filled: true,
              fillColor: context.background,
              prefixIcon: Icon(
                Icons.alt_route_rounded,
                color: context.textSecondary,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing8,
            AppTheme.spacing16,
            AppTheme.spacing12,
          ),
          child: previewLines,
        ),
        const Divider(height: 1),
        Expanded(
          child: pickerContacts.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spacing24),
                    child: Text(
                      l10n.meshcoreManualPathPickerEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.textTertiary),
                    ),
                  ),
                )
              : ListView.builder(
                  controller: widget.scrollController,
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacing8,
                  ),
                  itemCount: pickerContacts.length,
                  itemBuilder: (context, i) {
                    final c = pickerContacts[i];
                    final prefix = c.publicKeyHex.length >= 2
                        ? c.publicKeyHex.substring(0, 2).toUpperCase()
                        : '';
                    return ListTile(
                      key: ValueKey(
                        'meshcore-manual-path-picker-${c.publicKeyHex}',
                      ),
                      dense: true,
                      enabled: !_busy,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor: context.accentColor.withValues(
                          alpha: 0.18,
                        ),
                        child: Text(
                          prefix,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: context.accentColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      title: Text(
                        c.displayName,
                        style: TextStyle(color: context.textPrimary),
                      ),
                      onTap: _busy ? null : () => _appendContactPrefix(c),
                    );
                  },
                ),
        ),
        const Divider(height: 1),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const ValueKey('meshcore-manual-path-clear'),
                    onPressed: _busy ? null : _clear,
                    child: Text(l10n.meshcoreManualPathClear),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: PrimaryGradientButton(
                    key: const ValueKey('meshcore-manual-path-apply'),
                    label: l10n.meshcoreManualPathApply,
                    icon: Icons.check_rounded,
                    isLoading: _busy,
                    onPressed: _busy ? null : _apply,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _previewLines(MeshCoreManualPathParseResult parsed, dynamic l10n) {
    if (parsed.isInvalidToken) {
      return Text(
        l10n.meshcoreManualPathInvalidToken(parsed.invalidToken ?? '')
            as String,
        style: TextStyle(color: AppTheme.errorRed, fontSize: 12),
      );
    }
    if (parsed.isTooLong) {
      return Text(
        l10n.meshcoreManualPathTooLong(parsed.overflowLength ?? 0) as String,
        style: TextStyle(color: AppTheme.errorRed, fontSize: 12),
      );
    }
    final bytes = parsed.bytes ?? Uint8List(0);
    if (bytes.isEmpty) {
      return Text(
        l10n.meshcoreManualPathPreviewEmpty as String,
        style: TextStyle(color: context.textTertiary, fontSize: 12),
      );
    }
    final formatted = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' → ');
    return Text(
      l10n.meshcoreManualPathPreview(bytes.length, formatted) as String,
      style: TextStyle(
        color: context.textSecondary,
        fontSize: 12,
        fontFamily: AppTheme.fontFamily,
      ),
    );
  }
}
