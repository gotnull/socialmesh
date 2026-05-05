// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// "Confirming your unlock…" overlay.
//
// Mounted globally in the app shell so it can surface itself the
// instant a `socialmesh://purchase-return?sessionId=…` link arrives,
// without requiring the user to be on a specific screen. Pure listener
// over [externalConfirmationStreamProvider] — no business logic.
//
// Lifecycle:
//   - ConfirmationStage.idle      → renders nothing (just the child).
//   - ConfirmationStage.confirming → modal scrim + spinner + "Confirming…".
//   - ConfirmationStage.succeeded  → success card with pack name + Dismiss.
//   - ConfirmationStage.failed     → failure card + Dismiss.
//
// Dismiss returns the service to idle via
// `ExternalPurchaseService.acknowledgeConfirmation()` so a future deep
// link can re-trigger the overlay.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../models/subscription_models.dart';
import '../../providers/external_purchase_providers.dart';
import '../../services/external_purchase/external_purchase_service.dart';

/// Wraps [child] with a fullscreen overlay that surfaces external-purchase
/// confirmation states. Drop this in the MaterialApp `builder` so every
/// route inherits it.
class ConfirmingUnlockOverlay extends ConsumerWidget {
  final Widget child;

  const ConfirmingUnlockOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncState = ref.watch(externalConfirmationStreamProvider);
    final state = asyncState.maybeWhen(
      data: (s) => s,
      orElse: () => ConfirmationState.idle,
    );

    return Stack(
      children: [
        child,
        if (state.stage != ConfirmationStage.idle)
          Positioned.fill(child: _OverlayContent(state: state)),
      ],
    );
  }
}

class _OverlayContent extends ConsumerWidget {
  final ConfirmationState state;

  const _OverlayContent({required this.state});

  Future<void> _dismiss(WidgetRef ref) async {
    final service = await ref.read(externalPurchaseServiceProvider.future);
    service.acknowledgeConfirmation();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing24),
            child: Container(
              padding: const EdgeInsets.all(AppTheme.spacing24),
              constraints: const BoxConstraints(maxWidth: 360),
              decoration: BoxDecoration(
                color: context.card,
                borderRadius: BorderRadius.circular(AppTheme.radius16),
                border: Border.all(color: context.border),
              ),
              child: switch (state.stage) {
                ConfirmationStage.confirming => const _Confirming(),
                ConfirmationStage.succeeded => _Success(
                  state: state,
                  onDismiss: () => _dismiss(ref),
                ),
                ConfirmationStage.failed => _Failed(
                  onDismiss: () => _dismiss(ref),
                ),
                ConfirmationStage.idle => const SizedBox.shrink(),
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _Confirming extends StatelessWidget {
  const _Confirming();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            valueColor: AlwaysStoppedAnimation(context.accentColor),
          ),
        ),
        const SizedBox(height: AppTheme.spacing20),
        Text(
          context.l10n.confirmingUnlock,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing8),
        Text(
          context.l10n.paymentProcessing,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: context.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _Success extends StatelessWidget {
  final ConfirmationState state;
  final VoidCallback onDismiss;

  const _Success({required this.state, required this.onDismiss});

  String _resolveTitle(BuildContext context) {
    final productId = state.productId;
    if (productId != null) {
      final pack = OneTimePurchases.getByProductId(productId);
      if (pack != null) return context.l10n.unlockSuccess(pack.name);
      if (productId == 'complete_pack') {
        return context.l10n.unlockSuccess('Complete Pack');
      }
    }
    return context.l10n.unlockSuccessGeneric;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_rounded, size: 56, color: context.accentColor),
        const SizedBox(height: AppTheme.spacing16),
        Text(
          _resolveTitle(context),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
        const SizedBox(height: AppTheme.spacing20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onDismiss,
            style: FilledButton.styleFrom(
              backgroundColor: context.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radius12),
              ),
            ),
            child: Text(context.l10n.dismiss),
          ),
        ),
      ],
    );
  }
}

class _Failed extends StatelessWidget {
  final VoidCallback onDismiss;

  const _Failed({required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.error_outline_rounded, size: 56, color: AppTheme.errorRed),
        const SizedBox(height: AppTheme.spacing16),
        Text(
          context.l10n.paymentFailed,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: context.textPrimary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: AppTheme.spacing20),
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: onDismiss,
            child: Text(context.l10n.dismiss),
          ),
        ),
      ],
    );
  }
}
