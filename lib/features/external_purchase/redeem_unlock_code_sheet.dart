// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Redeem unlock code sheet — SUPPORT FALLBACK ONLY.
//
// This is intentionally NOT discoverable from the primary purchase
// flow. It exists for cases where:
//   - A user paid via Buy Me a Coffee but the webhook didn't match
//     their session (rare; an unmatched payment is logged in
//     `external_payments` for manual reconciliation).
//   - Support / admin issues a one-off unlock for a verified payment.
//   - Beta testing or compensation grants.
//
// The sheet is reachable from a low-emphasis "Have an unlock code?"
// row at the bottom of the subscription screen. Anywhere it appears,
// the primary store CTAs remain the canonical purchase path.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../providers/external_purchase_providers.dart';
import '../../services/haptic_service.dart';
import '../../utils/snackbar.dart';

/// Open the redeem-unlock-code sheet. Returns when dismissed.
Future<void> showRedeemUnlockCodeSheet(BuildContext context) {
  return AppBottomSheet.show<void>(
    context: context,
    isDismissible: true,
    child: const _RedeemUnlockCodeBody(),
  );
}

class _RedeemUnlockCodeBody extends ConsumerStatefulWidget {
  const _RedeemUnlockCodeBody();

  @override
  ConsumerState<_RedeemUnlockCodeBody> createState() =>
      _RedeemUnlockCodeBodyState();
}

class _RedeemUnlockCodeBodyState extends ConsumerState<_RedeemUnlockCodeBody>
    with LifecycleSafeMixin<_RedeemUnlockCodeBody> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _controller.text.trim();
    if (code.isEmpty) {
      safeSetState(() {
        _errorMessage = context.l10n.redeemCodeInvalid;
      });
      return;
    }

    ref.haptics.buttonTap();
    safeSetState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final service = await ref.read(externalPurchaseServiceProvider.future);
      if (!mounted) return;
      final granted = await service.redeemCode(code);
      if (!mounted) return;
      ref.invalidate(externalEntitlementsProvider);
      AppLogging.purchase(
        '[RedeemUnlockCodeSheet] redeemed productCount=${granted.length}',
      );
      ref.haptics.success();
      safeNavigatorPop();
      showSuccessSnackBar(context, context.l10n.unlockSuccessGeneric);
    } catch (e) {
      AppLogging.purchase('[RedeemUnlockCodeSheet] redeem failed: $e');
      if (!mounted) return;
      ref.haptics.error();
      safeSetState(() {
        _submitting = false;
        _errorMessage = context.l10n.redeemCodeInvalid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // No outer Padding(viewInsets.bottom) — AppBottomSheet.show wraps in
    // showModalBottomSheet with isScrollControlled+useSafeArea, which
    // already pushes the sheet content above the keyboard. Adding our
    // own bottom-padding double-counts the keyboard inset and produces
    // the "tall sheet with empty space below the button" look.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppTheme.spacing8),
        Text(
          context.l10n.unlockCodeSheetTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        Text(
          context.l10n.unlockCodeSheetBody,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: context.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppTheme.spacing24),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          enabled: !_submitting,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [
            // Cap the realistic outer bound for SM-XXXX-XXXX +
            // generous future-proofing for longer support codes.
            LengthLimitingTextInputFormatter(32),
          ],
          maxLength: 32,
          decoration: InputDecoration(
            labelText: context.l10n.unlockCodeFieldLabel,
            hintText: context.l10n.unlockCodeFieldHint,
            filled: true,
            fillColor: context.background,
            prefixIcon: Icon(
              Icons.vpn_key_outlined,
              color: context.textSecondary,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radius8),
              borderSide: BorderSide(color: context.accentColor),
            ),
            errorText: _errorMessage,
            // Allow the error message to wrap to multiple lines instead
            // of truncating with an ellipsis. The default
            // `errorMaxLines: 1` was clipping "Check it and try again."
            // mid-sentence.
            errorMaxLines: 3,
            counterText: '',
          ),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: context.textPrimary,
            fontFamily: AppTheme.fontFamily,
          ),
          onSubmitted: (_) => _submitting ? null : _redeem(),
        ),
        const SizedBox(height: AppTheme.spacing20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _redeem,
            style: FilledButton.styleFrom(
              backgroundColor: context.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : Text(context.l10n.redeemCode),
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
      ],
    );
  }
}
