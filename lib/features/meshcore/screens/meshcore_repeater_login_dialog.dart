// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D49-A: repeater admin login dialog.
//
// Shown from the contact-detail screen via the "Admin login" tile
// (visible only when `contact.type == MeshCoreAdvType.repeater`).
// The dialog wraps `MeshCoreSession.sendLogin` and bubbles the
// outcome up via `Navigator.pop` so the caller (which still owns
// a valid BuildContext after the pop) can surface the snackbar +
// route into the admin hub.
//
// Wire-format pin: `[0x1A][pubkey:32 B][password utf-8][0x00]`.
// See `MeshCoreSession.sendLogin` for the listener pattern.
//
// Password storage: D49-A keeps passwords session-only (memory).
// `flutter_secure_storage` per-contact persistence is a separate
// slice with its own UX review.

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
import 'meshcore_repeater_hub_screen.dart';

const int _kMeshCoreRepeaterPasswordMaxLength = 64;

/// D49-A: open the repeater admin login dialog. On successful admin
/// authentication, navigates the caller into [MeshCoreRepeaterHubScreen]
/// and shows a success snackbar. Guest success surfaces the guest
/// snackbar but does NOT navigate (the hub is admin-only).
/// Failure / timeout surfaces an error snackbar; the caller can
/// reopen the dialog to retry.
///
/// Returns `true` if any successful outcome (admin or guest) was
/// reached, `false` on cancel / fail / timeout.
Future<bool> showMeshCoreRepeaterLoginDialog(
  BuildContext context, {
  required MeshCoreContact contact,
}) async {
  final loginResult = await AppBottomSheet.show<_LoginSheetResult>(
    context: context,
    child: _MeshCoreRepeaterLoginSheet(contact: contact),
  );
  if (!context.mounted) return false;
  final l10n = context.l10n;
  if (loginResult == null) return false; // cancelled
  final result = loginResult.result;
  if (!result.delivered) {
    showErrorSnackBar(context, l10n.meshcoreRepeaterAdminLoginFailed);
    return false;
  }
  showSuccessSnackBar(
    context,
    result.isAdmin
        ? l10n.meshcoreRepeaterAdminLoginSuccess
        : l10n.meshcoreRepeaterAdminLoginSuccessGuest,
  );
  if (result.isAdmin) {
    // D49-D2: hand the typed password forward to the hub so the
    // admin settings + CLI screens can do auto re-login on session
    // timeout. Password is in-memory only; closing the hub drops it.
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MeshCoreRepeaterHubScreen(
          contact: contact,
          password: loginResult.password,
        ),
      ),
    );
  }
  return true;
}

// D49-D2: tuple carrying the firmware's login outcome PLUS the
// password the user typed in. The wrapper above forwards the
// password into the hub; nothing else reads it.
class _LoginSheetResult {
  final MeshCoreLoginResult result;
  final String password;
  const _LoginSheetResult({required this.result, required this.password});
}

class _MeshCoreRepeaterLoginSheet extends ConsumerStatefulWidget {
  final MeshCoreContact contact;
  const _MeshCoreRepeaterLoginSheet({required this.contact});

  @override
  ConsumerState<_MeshCoreRepeaterLoginSheet> createState() =>
      _MeshCoreRepeaterLoginSheetState();
}

class _MeshCoreRepeaterLoginSheetState
    extends ConsumerState<_MeshCoreRepeaterLoginSheet>
    with LifecycleSafeMixin<_MeshCoreRepeaterLoginSheet> {
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
    navigator.pop(_LoginSheetResult(result: result, password: password));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.meshcoreRepeaterAdminLoginTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing4),
        Text(
          l10n.meshcoreRepeaterAdminLoginSubtitle(widget.contact.name),
          style: TextStyle(color: context.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: AppTheme.spacing16),
        TextField(
          key: const ValueKey('meshcore-repeater-login-password'),
          controller: _passwordController,
          autofocus: true,
          obscureText: true,
          maxLength: _kMeshCoreRepeaterPasswordMaxLength,
          enabled: !_busy,
          inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'[ ]'))],
          onSubmitted: (_) => _busy ? null : _onSubmit(),
          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
          style: TextStyle(color: context.textPrimary),
          decoration: InputDecoration(
            labelText: l10n.meshcoreRepeaterAdminLoginPasswordLabel,
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
                key: const ValueKey('meshcore-repeater-login-submit'),
                label: l10n.meshcoreRepeaterAdminLoginAction,
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
