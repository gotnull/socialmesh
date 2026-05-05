// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Buy Me a Coffee handoff sheet.
//
// User flow this sheet implements:
//   1. User taps "Alternative payment" on a pack tile.
//   2. createExternalCheckout returns a sessionId, checkoutUrl, and a
//      reference code (SM-XXXX-XXXX).
//   3. This sheet appears, showing the reference code prominently with
//      a one-tap copy button — that's the strongest hint we can give
//      Buy Me a Coffee for unambiguous matching.
//   4. User taps "Open Buy Me a Coffee" → external browser launches.
//   5. User pastes the reference into the BMC support note, completes
//      payment, and BMC's redirect comes back as
//      socialmesh://purchase-return?sessionId=…
//   6. The deep-link handler hands the sessionId to
//      ExternalPurchaseService.handleDeepLink, which kicks off the
//      polling state machine. The "Confirming your unlock…" overlay
//      (mounted in the app shell) takes over from there.
//
// CRITICAL: this sheet itself never grants entitlements. Its only job
// is to surface the reference code and open the external URL. Entitlement
// state changes only when the BMC webhook lands.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/logging.dart';
import '../../core/safety/lifecycle_mixin.dart';
import '../../core/theme.dart';
import '../../core/widgets/app_bottom_sheet.dart';
import '../../models/subscription_models.dart';
import '../../providers/external_purchase_providers.dart';
import '../../services/external_purchase/external_entitlement.dart';
import '../../services/haptic_service.dart';
import '../../utils/snackbar.dart';

/// Open the Buy Me a Coffee handoff sheet for [productId].
///
/// Returns when the sheet is dismissed (either by the user, by the
/// "Open Buy Me a Coffee" tap, or by an error). The actual unlock
/// confirmation arrives later via the deep-link → polling pipeline,
/// not the sheet's return value.
Future<void> showBuyMeACoffeeHandoffSheet(
  BuildContext context, {
  required String productId,
}) {
  return AppBottomSheet.show<void>(
    context: context,
    isDismissible: true,
    child: _BuyMeACoffeeHandoffBody(productId: productId),
  );
}

class _BuyMeACoffeeHandoffBody extends ConsumerStatefulWidget {
  final String productId;
  const _BuyMeACoffeeHandoffBody({required this.productId});

  @override
  ConsumerState<_BuyMeACoffeeHandoffBody> createState() =>
      _BuyMeACoffeeHandoffBodyState();
}

class _BuyMeACoffeeHandoffBodyState
    extends ConsumerState<_BuyMeACoffeeHandoffBody>
    with LifecycleSafeMixin<_BuyMeACoffeeHandoffBody> {
  bool _loading = true;
  CheckoutSessionDescriptor? _descriptor;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _createCheckout();
  }

  Future<void> _createCheckout() async {
    try {
      final service = await ref.read(externalPurchaseServiceProvider.future);
      if (!mounted) return;
      final descriptor = await service.createCheckout(widget.productId);
      if (!mounted) return;
      safeSetState(() {
        _descriptor = descriptor;
        _loading = false;
        _errorMessage = null;
      });
    } catch (e) {
      AppLogging.purchase('[BMCHandoffSheet] createCheckout failed: $e');
      if (!mounted) return;
      safeSetState(() {
        _loading = false;
        _errorMessage = context.l10n.couldNotOpenCheckout;
      });
    }
  }

  Future<void> _copyCode() async {
    final descriptor = _descriptor;
    if (descriptor == null) return;
    ref.haptics.buttonTap();
    await Clipboard.setData(ClipboardData(text: descriptor.referenceCode));
    if (!mounted) return;
    showSuccessSnackBar(context, context.l10n.referenceCodeCopied);
  }

  Future<void> _openCheckout() async {
    final descriptor = _descriptor;
    if (descriptor == null) return;
    ref.haptics.buttonTap();

    AppLogging.purchase(
      '[BMCHandoffSheet] checkout_opened sessionId=${descriptor.sessionId} '
      'productId=${widget.productId}',
    );

    final uri = Uri.tryParse(descriptor.checkoutUrl);
    if (uri == null) {
      if (!mounted) return;
      showErrorSnackBar(context, context.l10n.couldNotOpenCheckout);
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!mounted) return;
    if (!ok) {
      showErrorSnackBar(context, context.l10n.couldNotOpenCheckout);
      return;
    }
    // Dismiss the sheet — the user is now in the browser. The
    // confirmation overlay will take over once the deep-link return
    // arrives.
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppTheme.spacing8),
        Center(
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              color: context.accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.coffee, color: context.accentColor, size: 36),
          ),
        ),
        const SizedBox(height: AppTheme.spacing16),
        Text(
          context.l10n.buyMeACoffeeHandoffTitle,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        Text(
          context.l10n.buyMeACoffeeHandoffBody,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: context.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppTheme.spacing24),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppTheme.spacing24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_errorMessage != null)
          _ErrorPanel(
            message: _errorMessage!,
            onRetry: () {
              safeSetState(() {
                _loading = true;
                _errorMessage = null;
              });
              _createCheckout();
            },
          )
        else
          _ReadyPanel(
            descriptor: _descriptor!,
            onCopyCode: _copyCode,
            onOpenCheckout: _openCheckout,
            packName: _resolvePackName(widget.productId),
          ),
        const SizedBox(height: AppTheme.spacing16),
      ],
    );
  }
}

class _ReadyPanel extends StatelessWidget {
  final CheckoutSessionDescriptor descriptor;
  final VoidCallback onCopyCode;
  final VoidCallback onOpenCheckout;
  final String? packName;

  const _ReadyPanel({
    required this.descriptor,
    required this.onCopyCode,
    required this.onOpenCheckout,
    required this.packName,
  });

  String _formatAmount() {
    final value = descriptor.expectedAmount.toStringAsFixed(2);
    final currency = descriptor.currency;
    if (currency == 'USD') return '\$$value';
    return '$value $currency';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Reference code card. This is the most important affordance
        // on the sheet — without it, BMC matching falls back to amount
        // + recency window, which is fragile.
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing16,
          ),
          decoration: BoxDecoration(
            color: context.background,
            borderRadius: BorderRadius.circular(AppTheme.radius12),
            border: Border.all(
              color: context.accentColor.withValues(alpha: 0.4),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.referenceCodeLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: context.textTertiary,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: AppTheme.spacing8),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      descriptor.referenceCode,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                        color: context.textPrimary,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onCopyCode,
                    tooltip: context.l10n.copyReferenceCode,
                    icon: Icon(Icons.copy_rounded, color: context.accentColor),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        // Expected amount + pack name (so user can sanity-check before
        // paying).
        Center(
          child: Text(
            packName != null
                ? '$packName · ${context.l10n.expectedAmountLabel(_formatAmount())}'
                : context.l10n.expectedAmountLabel(_formatAmount()),
            style: TextStyle(fontSize: 13, color: context.textSecondary),
          ),
        ),
        const SizedBox(height: AppTheme.spacing20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onOpenCheckout,
            icon: const Icon(Icons.open_in_new_rounded),
            label: Text(context.l10n.openBuyMeACoffee),
            style: FilledButton.styleFrom(
              backgroundColor: context.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorPanel({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 32),
        const SizedBox(height: AppTheme.spacing8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(color: context.textSecondary),
        ),
        const SizedBox(height: AppTheme.spacing16),
        TextButton(
          onPressed: onRetry,
          child: Text(context.l10n.externalPurchaseRetry),
        ),
      ],
    );
  }
}

String? _resolvePackName(String productId) {
  // complete_pack isn't in `getByProductId`'s scope (that map only
  // covers individual packs), so fall back to a literal lookup for it.
  final byProduct = OneTimePurchases.getByProductId(productId);
  if (byProduct != null) return byProduct.name;
  if (productId == 'complete_pack') return 'Complete Pack';
  return null;
}
