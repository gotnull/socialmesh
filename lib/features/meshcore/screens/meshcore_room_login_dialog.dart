// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-A: room (room-server contact) login dialog. Wire-identical to
// the repeater admin login dialog (`CMD_SEND_LOGIN 0x1A` is
// overloaded by target contact type) but launched from a
// room-server contact. Closes parity audit Row 21.
//
// Differences vs the repeater dialog:
//   - copy is room-flavoured ("Join", "Room password", etc.)
//   - on success the dialog closes without navigating anywhere;
//     the caller surfaces the snackbar.

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
import '../../../services/meshcore/protocol/meshcore_messages.dart';
import '../../../utils/snackbar.dart';

const int _kMeshCoreRoomPasswordMaxLength = 64;

/// D49-A: open the room login dialog. Returns `true` on successful
/// authentication (admin or guest), `false` on cancel / fail /
/// timeout. The caller owns post-login UX.
Future<bool> showMeshCoreRoomLoginDialog(
  BuildContext context, {
  required MeshCoreContact contact,
}) async {
  final result = await AppBottomSheet.show<MeshCoreLoginResult>(
    context: context,
    child: _MeshCoreRoomLoginSheet(contact: contact),
  );
  if (!context.mounted) return false;
  final l10n = context.l10n;
  if (result == null) return false;
  if (!result.delivered) {
    showErrorSnackBar(context, l10n.meshcoreRepeaterAdminLoginFailed);
    return false;
  }
  showSuccessSnackBar(context, l10n.meshcoreRoomLoginSuccess(contact.name));
  return true;
}

class _MeshCoreRoomLoginSheet extends ConsumerStatefulWidget {
  final MeshCoreContact contact;
  const _MeshCoreRoomLoginSheet({required this.contact});

  @override
  ConsumerState<_MeshCoreRoomLoginSheet> createState() =>
      _MeshCoreRoomLoginSheetState();
}

class _MeshCoreRoomLoginSheetState
    extends ConsumerState<_MeshCoreRoomLoginSheet>
    with LifecycleSafeMixin<_MeshCoreRoomLoginSheet> {
  final TextEditingController _passwordController = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onSubmit() async {
    final l10n = context.l10n;
    final password = _passwordController.text;
    if (password.isEmpty) {
      showErrorSnackBar(context, l10n.meshcoreRepeaterAdminLoginEmptyPassword);
      return;
    }
    final session = ref.read(meshCoreSessionProvider);
    if (session == null) {
      showErrorSnackBar(context, l10n.meshcoreNotConnectedToDevice);
      return;
    }
    setState(() => _busy = true);
    final navigator = Navigator.of(context);
    final result = await session.sendLogin(
      pubKey: widget.contact.publicKey,
      password: password,
    );
    if (!mounted) return;
    navigator.pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.meshcoreRoomLoginTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          l10n.meshcoreRoomLoginSubtitle(widget.contact.name),
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: AppTheme.spacing16),
        TextField(
          key: const ValueKey('meshcore-room-login-password'),
          controller: _passwordController,
          autofocus: true,
          obscureText: true,
          maxLength: _kMeshCoreRoomPasswordMaxLength,
          enabled: !_busy,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[ ]'))],
          onSubmitted: (_) => _busy ? null : _onSubmit(),
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            labelText: l10n.meshcoreRoomLoginPasswordLabel,
            labelStyle: TextStyle(color: context.textSecondary),
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
              borderSide: BorderSide(color: context.accentColor),
            ),
            prefixIcon: Icon(
              Icons.lock_outline_rounded,
              color: context.textSecondary,
            ),
            counterText: '',
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _busy ? null : () => safeNavigatorPop(null),
                child: Text(l10n.meshcoreCancel),
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: PrimaryGradientButton(
                key: const ValueKey('meshcore-room-login-submit'),
                label: l10n.meshcoreRoomLoginAction,
                icon: Icons.login_rounded,
                onPressed: _busy ? null : _onSubmit,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
