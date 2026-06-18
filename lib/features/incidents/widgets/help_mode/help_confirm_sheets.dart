// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Confirmation sheets for the two distinct terminal actions on a help
/// request: "I'm safe" (resolve) and "Cancel request" (false alarm). They are
/// visually and semantically separate and each returns a bool.
library;

import 'package:flutter/material.dart';

import '../../../../core/l10n/l10n_extension.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/primary_gradient_button.dart';

/// Confirms "I'm safe" (resolve). Returns true if confirmed.
Future<bool> showResolveConfirmSheet(BuildContext context) async {
  final l10n = context.l10n;
  final result = await AppBottomSheet.showScrollable<bool>(
    context: context,
    title: l10n.helpModeImSafe,
    initialChildSize: 0.4,
    minChildSize: 0.3,
    maxChildSize: 0.6,
    builder: (controller) => _ConfirmBody(
      scrollController: controller,
      message: l10n.helpModeImSafeConfirm,
      confirmLabel: l10n.helpModeImSafe,
      confirmIcon: Icons.verified_user,
      confirmColor: AppTheme.successGreen,
    ),
  );
  return result ?? false;
}

/// Confirms "Cancel request" (false alarm). Returns true if confirmed.
Future<bool> showCancelConfirmSheet(BuildContext context) async {
  final l10n = context.l10n;
  final result = await AppBottomSheet.showScrollable<bool>(
    context: context,
    title: l10n.helpModeCancelRequest,
    initialChildSize: 0.4,
    minChildSize: 0.3,
    maxChildSize: 0.6,
    builder: (controller) => _ConfirmBody(
      scrollController: controller,
      message: l10n.helpModeCancelConfirm,
      confirmLabel: l10n.helpModeCancelRequest,
      confirmIcon: Icons.cancel_outlined,
      confirmColor: AppTheme.errorRed,
    ),
  );
  return result ?? false;
}

class _ConfirmBody extends StatelessWidget {
  final ScrollController scrollController;
  final String message;
  final String confirmLabel;
  final IconData confirmIcon;
  final Color confirmColor;

  const _ConfirmBody({
    required this.scrollController,
    required this.message,
    required this.confirmLabel,
    required this.confirmIcon,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing24,
      ),
      children: [
        Text(message, style: context.bodyMutedStyle),
        const SizedBox(height: AppTheme.spacing24),
        PrimaryGradientButton(
          label: confirmLabel,
          icon: confirmIcon,
          accentColor: confirmColor,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: AppTheme.spacing8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.l10n.helpModeKeepRequest),
        ),
      ],
    );
  }
}
