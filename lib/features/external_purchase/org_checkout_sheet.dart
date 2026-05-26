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

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import 'stripe_payment_sheet_launcher.dart';

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

/// Slug shape rules (slice 7 backend mirror): lowercase a-z, 0-9,
/// hyphens, 3..64 chars, no leading / trailing hyphen, no double
/// hyphens. Reserved-namespace and banned-word checks live ONLY on
/// the server (slice 10b): the client used to mirror the reserved
/// list, but that put two sources of truth in play and made every
/// future banned-word addition a coordinated release. The server now
/// returns a structured `details.reason` on rejection so the sheet can
/// still render a specific message without owning the list.
final RegExp _licenseOrgIdPattern = RegExp(r'^[a-z0-9]([a-z0-9-]*[a-z0-9])?$');

const int _licenseOrgIdMinLength = 3;
const int _licenseOrgIdMaxLength = 64;

/// Input formatter that lowercases input as the user types so the
/// visible field state matches what gets sent. Without this, users
/// typing "Acme" see "Acme" but the server gets "acme" - confusing
/// when the helper text says "lowercase letters only".
class _LowercaseTextFormatter extends TextInputFormatter {
  const _LowercaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final lower = newValue.text.toLowerCase();
    if (lower == newValue.text) return newValue;
    return newValue.copyWith(text: lower);
  }
}

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
    AppLogging.groupLicensing(
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
  void initState() {
    super.initState();
    // Drive button enabled / disabled state from the text field.
    // Keeps the Continue-to-payment CTA off until the input passes
    // slug + reserved-namespace validation, mirroring the slice 7
    // backend rules so users never tap into a guaranteed-reject
    // round-trip.
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    // Repaint so the disabled-state recomputes against the new text.
    // Also clear any stale error from a previous failed submit -
    // the user is now editing, the old error no longer matches the
    // current text.
    if (_errorMessage != null) {
      safeSetState(() {
        _errorMessage = null;
      });
    } else if (mounted) {
      safeSetState(() {});
    }
  }

  // Slug shape validation only: length + pattern. Reserved namespace
  // + banned-word checks live on the server (slice 10b) so this sheet
  // does not duplicate that list. Returns null when the shape is
  // unusable; otherwise the normalised slug to send.
  String? _validateLicenseOrgId(String raw) {
    final trimmed = raw.trim().toLowerCase();
    if (trimmed.length < _licenseOrgIdMinLength) return null;
    if (trimmed.length > _licenseOrgIdMaxLength) return null;
    if (!_licenseOrgIdPattern.hasMatch(trimmed)) return null;
    return trimmed;
  }

  // Returns true when the current input is shape-valid for
  // submission. Cheap to call from build() every paint.
  bool get _isInputValid => _validateLicenseOrgId(_controller.text) != null;

  // Inline error for shape-only failures. Length-only failures stay
  // silent so the field doesn't flash an error after the first
  // keystroke. Pattern violations show a specific message so the user
  // knows what to change. Reserved-namespace and banned-word errors
  // are server-only now and arrive via the submit catch path.
  String? _inputErrorMessage(BuildContext context) {
    final trimmed = _controller.text.trim().toLowerCase();
    if (trimmed.isEmpty) return null;
    if (trimmed.length < _licenseOrgIdMinLength) return null;
    if (trimmed.length > _licenseOrgIdMaxLength) {
      return context.l10n.orgCheckoutOrgIdInvalid;
    }
    if (!_licenseOrgIdPattern.hasMatch(trimmed)) {
      return context.l10n.orgCheckoutOrgIdInvalid;
    }
    return null;
  }

  // Map a server-side rejection reason (carried on
  // `FunctionsException.details.reason`) to a user-facing message.
  // Unknown / missing reasons fall back to the generic error so the
  // sheet never goes blank when the backend ships a new rejection
  // category ahead of a client release.
  String _serverErrorMessage(BuildContext context, Object? reason) {
    switch (reason) {
      case 'license-org-taken':
        return context.l10n.orgCheckoutOrgIdTaken;
      case 'license-org-suspended':
        return context.l10n.orgCheckoutOrgIdSuspended;
      case 'license-org-id-reserved-exact':
      case 'license-org-id-reserved-prefix':
      case 'license-org-id-reserved-substring':
        return context.l10n.orgCheckoutOrgIdReserved;
      case 'license-org-id-banned-word':
        return context.l10n.orgCheckoutOrgIdBannedWord;
      case 'license-org-id-malformed':
        return context.l10n.orgCheckoutOrgIdInvalid;
      case 'org-pack-requires-signin':
      case 'org-pack-requires-permanent-account':
        return context.l10n.orgCheckoutSignInRequired;
      default:
        return context.l10n.orgCheckoutError;
    }
  }

  Future<void> _submit() async {
    final slug = _validateLicenseOrgId(_controller.text);
    if (slug == null) {
      safeSetState(() {
        _errorMessage =
            _inputErrorMessage(context) ?? context.l10n.orgCheckoutOrgIdInvalid;
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
      AppLogging.groupLicensing(
        '[OrgCheckoutSheet] descriptor received sessionId=${descriptor.sessionId} '
        'paymentIntentId=${descriptor.paymentIntentId} '
        'hasClientSecret=${descriptor.clientSecret.isNotEmpty}',
      );
      final launcher = widget.launcher ?? _defaultLauncher;
      await launcher(ref, service, descriptor);
      if (!mounted) return;
      ref.haptics.success();
      Navigator.of(context).pop(OrgCheckoutOutcome.success);
    } on FirebaseFunctionsException catch (e) {
      // Slice 10b: server returns structured `details.reason` so the
      // sheet can render a specific message per rejection path
      // (taken / suspended / reserved / banned / malformed) without
      // owning the lists itself.
      final details = e.details;
      final reason = details is Map ? details['reason'] : null;
      AppLogging.groupLicensing(
        '[OrgCheckoutSheet] checkout rejected code=${e.code} reason=$reason',
      );
      if (!mounted) return;
      ref.haptics.error();
      safeSetState(() {
        _submitting = false;
        _errorMessage = _serverErrorMessage(context, reason);
      });
    } catch (e) {
      AppLogging.groupLicensing('[OrgCheckoutSheet] checkout failed: $e');
      if (!mounted) return;
      ref.haptics.error();
      safeSetState(() {
        _submitting = false;
        _errorMessage = context.l10n.orgCheckoutError;
      });
    }
  }

  // Default launcher: delegates to the shared Stripe Payment Sheet
  // helper so wallet config (Apple Pay / Google Pay / Link) stays in
  // lockstep with the personal-pack chooser. Both flows must offer
  // the same payment methods, otherwise users see a worse surface
  // when buying a group license than buying the same product
  // personally.
  Future<void> _defaultLauncher(
    WidgetRef _,
    ExternalPurchaseService service,
    CheckoutSessionDescriptor descriptor,
  ) async {
    await launchStripePaymentSheet(descriptor: descriptor);
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
          inputFormatters: const [_LowercaseTextFormatter()],
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
            // Server errors (set on submit failure) take precedence over
            // inline input errors. Once the user starts editing,
            // _onTextChanged clears _errorMessage so the inline
            // _inputErrorMessage path takes back over.
            errorText: _errorMessage ?? _inputErrorMessage(context),
            errorMaxLines: 3,
            counterText: '',
          ),
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: context.textPrimary,
            fontFamily: AppTheme.fontFamily,
          ),
          onSubmitted: (_) =>
              (_submitting || !_isInputValid) ? null : _submit(),
        ),
        const SizedBox(height: AppTheme.spacing20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            // Disabled until the user has typed a slug that passes
            // every client-side check (length / pattern / non-reserved).
            // Server still re-validates; this gate just prevents
            // round-trips guaranteed to fail.
            onPressed: (_submitting || !_isInputValid) ? null : _submit,
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
