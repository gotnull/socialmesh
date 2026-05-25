// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Org checkout sheet - self-serve group / community license purchase
// entry point. Mirrors the redeem-unlock-code sheet shape, but
// instead of redeeming a code the user enters a licenseOrgId, the
// sheet calls `service.createCheckout(productId, subjectKind: 'org',
// licenseOrgId: <slug>)`, and the resulting descriptor is handed off
// to the same Stripe Payment Sheet flow the personal-pack purchase
// uses.
//
// Scope guard (slice 9):
//   - No seat allocation here. Even after a successful payment, the
//     buyer is NOT a member of the new license org and has no seat.
//     Members arrive via seat codes (slice 4b) which an admin mints
//     separately.
//   - No admin / seat-management UI. This sheet is the buyer surface
//     ONLY.
//   - Feature-flag gated by [AppFeatureFlags.isGroupLicensingEnabled].
//     With the flag off, [showOrgCheckoutSheet] is a quiet no-op so a
//     stray call site never lands a half-built sheet on screen.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_stripe/flutter_stripe.dart' as stripe;

import '../../core/constants.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../providers/external_purchase_providers.dart';
import '../../services/external_purchase/external_entitlement.dart';
import '../../services/external_purchase/external_purchase_service.dart';
import '../../services/haptic_service.dart';

/// Hand-off invoked after `createCheckout` returns a descriptor.
/// Production passes the descriptor to the Stripe Payment Sheet and
/// kicks the existing confirmation overlay. Tests inject a stub so
/// they can verify the createCheckout payload without touching the
/// Stripe SDK.
typedef OrgCheckoutLauncher =
    Future<void> Function(
      WidgetRef ref,
      ExternalPurchaseService service,
      CheckoutSessionDescriptor descriptor,
    );

/// Outcome of a sheet session, returned to the caller via the
/// `Navigator.pop` value. Lets test rigs and future entry-point
/// surfaces branch on the result.
enum OrgCheckoutOutcome { success, canceled, error }

/// Slug rules (slice 7 backend mirror): lowercase a-z, 0-9, hyphens,
/// 3..64 chars, no leading / trailing hyphen, no double hyphens.
final RegExp _licenseOrgIdPattern = RegExp(r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?$');

const int _licenseOrgIdMinLength = 3;
const int _licenseOrgIdMaxLength = 64;

/// Open the org checkout sheet. Returns the outcome (canceled when
/// the user dismisses without submitting; success when the Payment
/// Sheet flow completed; error on backend / Stripe failure).
///
/// No-op (returns canceled) when group licensing is disabled. Future
/// UI surfaces can call this unconditionally - the flag check stays
/// here so call sites do not duplicate the gate.
Future<OrgCheckoutOutcome> showOrgCheckoutSheet(
  BuildContext context, {
  required String productId,
  OrgCheckoutLauncher? launcher,
}) async {
  if (!AppFeatureFlags.isGroupLicensingEnabled) {
    AppLogging.purchase(
      '[OrgCheckoutSheet] group licensing disabled - sheet suppressed',
    );
    return OrgCheckoutOutcome.canceled;
  }
  final result = await AppBottomSheet.show<OrgCheckoutOutcome>(
    context: context,
    isDismissible: true,
    child: _OrgCheckoutBody(productId: productId, launcher: launcher),
  );
  return result ?? OrgCheckoutOutcome.canceled;
}

class _OrgCheckoutBody extends ConsumerStatefulWidget {
  final String productId;
  final OrgCheckoutLauncher? launcher;

  const _OrgCheckoutBody({required this.productId, this.launcher});

  @override
  ConsumerState<_OrgCheckoutBody> createState() => _OrgCheckoutBodyState();
}

class _OrgCheckoutBodyState extends ConsumerState<_OrgCheckoutBody>
    with LifecycleSafeMixin<_OrgCheckoutBody> {
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

  // Mirrors the slice 7 server-side slug rule but only validates -
  // the server is still the source of truth. Returns null when the
  // input is unusable; otherwise a normalised slug we can send.
  String? _validateLicenseOrgId(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.length < _licenseOrgIdMinLength) return null;
    if (trimmed.length > _licenseOrgIdMaxLength) return null;
    if (!_licenseOrgIdPattern.hasMatch(trimmed)) return null;
    return trimmed;
  }

  Future<void> _submit() async {
    final slug = _validateLicenseOrgId(_controller.text);
    if (slug == null) {
      safeSetState(() {
        _errorMessage = context.l10n.orgCheckoutOrgIdInvalid;
      });
      ref.haptics.error();
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
      final descriptor = await service.createCheckout(
        widget.productId,
        provider: 'stripe',
        subjectKind: 'org',
        licenseOrgId: slug,
      );
      if (!mounted) return;
      AppLogging.purchase(
        '[OrgCheckoutSheet] descriptor received sessionId=${descriptor.sessionId} '
        'paymentIntentId=${descriptor.paymentIntentId} '
        'hasClientSecret=${descriptor.clientSecret.isNotEmpty}',
      );
      final launcher = widget.launcher ?? _defaultLauncher;
      await launcher(ref, service, descriptor);
      if (!mounted) return;
      ref.haptics.success();
      Navigator.of(context).pop(OrgCheckoutOutcome.success);
    } catch (e) {
      AppLogging.purchase('[OrgCheckoutSheet] checkout failed: $e');
      if (!mounted) return;
      ref.haptics.error();
      safeSetState(() {
        _submitting = false;
        _errorMessage = context.l10n.orgCheckoutError;
      });
    }
  }

  // Default launcher: drive the Stripe Payment Sheet and kick the
  // existing confirmation overlay via `service.handleDeepLink`. Lives
  // alongside the widget so the personal-pack launcher
  // (payment_method_chooser_sheet.dart) stays untouched - both
  // launchers converge on the same `service` + `confirmationStream`
  // downstream.
  Future<void> _defaultLauncher(
    WidgetRef _,
    ExternalPurchaseService service,
    CheckoutSessionDescriptor descriptor,
  ) async {
    if (descriptor.provider != CheckoutProvider.stripe ||
        descriptor.clientSecret.isEmpty) {
      throw StateError(
        'Org checkout returned a non-Stripe descriptor: '
        'provider=${descriptor.provider}',
      );
    }
    if (descriptor.publishableKey.isNotEmpty &&
        descriptor.publishableKey != stripe.Stripe.publishableKey) {
      stripe.Stripe.publishableKey = descriptor.publishableKey;
      await stripe.Stripe.instance.applySettings();
    }
    await stripe.Stripe.instance.initPaymentSheet(
      paymentSheetParameters: stripe.SetupPaymentSheetParameters(
        paymentIntentClientSecret: descriptor.clientSecret,
        merchantDisplayName: 'SocialMesh',
        returnURL: 'socialmesh://stripe-redirect',
      ),
    );
    await stripe.Stripe.instance.presentPaymentSheet();
    // Wake the confirmation overlay - polls for the webhook landing.
    service.handleDeepLink(descriptor.sessionId);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppTheme.spacing8),
        Text(
          context.l10n.orgCheckoutSheetTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        Text(
          context.l10n.orgCheckoutSheetBody,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: context.textSecondary,
            height: 1.4,
            fontFamily: AppTheme.fontFamily,
          ),
        ),
        const SizedBox(height: AppTheme.spacing24),
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          enabled: !_submitting,
          maxLength: _licenseOrgIdMaxLength,
          textCapitalization: TextCapitalization.none,
          decoration: InputDecoration(
            labelText: context.l10n.orgCheckoutOrgIdLabel,
            hintText: context.l10n.orgCheckoutOrgIdHint,
            helperText: context.l10n.orgCheckoutOrgIdHelp,
            helperMaxLines: 3,
            filled: true,
            fillColor: context.background,
            prefixIcon: Icon(
              Icons.groups_outlined,
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
            errorMaxLines: 3,
            counterText: '',
          ),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
            fontFamily: AppTheme.fontFamily,
          ),
          onSubmitted: (_) => _submitting ? null : _submit(),
        ),
        const SizedBox(height: AppTheme.spacing20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _submitting ? null : _submit,
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
                : Text(context.l10n.orgCheckoutSubmit),
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
      ],
    );
  }
}
