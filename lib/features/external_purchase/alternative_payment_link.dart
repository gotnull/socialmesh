// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/l10n/l10n_extension.dart';
import '../../core/theme.dart';
import '../../services/haptic_service.dart';
import 'buy_me_a_coffee_handoff_sheet.dart';

/// Subtle "Alternative payment" affordance shown beneath a primary store
/// purchase CTA. Low-emphasis on purpose: store purchase remains the
/// canonical path; this is the additive fallback for users who can't or
/// won't transact via Google Play / App Store.
///
/// Visual contract:
///   - Coffee icon (12pt) + underlined "Alternative payment" label,
///     both in `context.textSecondary`. Never the accent color — that
///     would compete with the primary CTA.
///   - Left-aligned, with shrink-wrapped tap target.
///
/// Wiring contract:
///   - On tap, opens [showBuyMeACoffeeHandoffSheet] for [productId].
///   - The sheet itself never grants entitlements; it only surfaces
///     the reference code and opens the external checkout URL. Unlock
///     happens later via the deep-link → polling pipeline.
class AlternativePaymentLink extends ConsumerWidget {
  final String productId;

  const AlternativePaymentLink({super.key, required this.productId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Hard kill switch — when EXTERNAL_PURCHASE_ENABLED is off in
    // .env, the entire BMC fallback path is invisible. Returning a
    // zero-sized SizedBox keeps any surrounding `Column.children`
    // layout stable without rendering the link.
    if (!AppFeatureFlags.isExternalPurchaseEnabled) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () {
            ref.haptics.buttonTap();
            showBuyMeACoffeeHandoffSheet(context, productId: productId);
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: context.textSecondary,
          ),
          icon: Icon(
            Icons.coffee_outlined,
            size: 14,
            color: context.textSecondary,
          ),
          label: Text(
            context.l10n.alternativePayment,
            style: TextStyle(
              fontSize: 12,
              color: context.textSecondary,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ),
    );
  }
}
