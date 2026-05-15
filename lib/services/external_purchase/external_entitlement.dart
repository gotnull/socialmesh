// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
//
// Models for the external (fallback) purchase pipeline. The shapes here
// mirror the Cloud Functions in backend/functions/src/external_checkout.ts.
// Wire compatibility is enforced by the unit tests in
// test/services/external_purchase/external_entitlement_test.dart.

/// Provider that fulfilled an external entitlement.
///
/// Distinct from the App Store / Play Store / RevenueCat path — these
/// are off-store payment providers (or `manual` for support-issued
/// unlock codes). Stored as a tag on every entitlement so admin tools
/// can filter and revoke per-provider if needed.
enum ExternalProvider {
  buymeacoffee,
  stripe,
  nowpayments,
  manual,
  unknown;

  static ExternalProvider fromWire(String? value) {
    switch (value) {
      case 'buymeacoffee':
        return ExternalProvider.buymeacoffee;
      case 'stripe':
        return ExternalProvider.stripe;
      case 'nowpayments':
        return ExternalProvider.nowpayments;
      case 'manual':
        return ExternalProvider.manual;
      default:
        return ExternalProvider.unknown;
    }
  }

  String toWire() => name == 'unknown' ? 'unknown' : name;
}

/// Status of an external entitlement.
///
/// Only `active` entitlements unlock features. `revoked` and `expired`
/// are kept for audit / refund flows but do not contribute to the
/// effective entitlement set.
enum ExternalEntitlementStatus {
  active,
  revoked,
  expired,
  unknown;

  static ExternalEntitlementStatus fromWire(String? value) {
    switch (value) {
      case 'active':
        return ExternalEntitlementStatus.active;
      case 'revoked':
        return ExternalEntitlementStatus.revoked;
      case 'expired':
        return ExternalEntitlementStatus.expired;
      default:
        return ExternalEntitlementStatus.unknown;
    }
  }
}

/// A single external entitlement.
///
/// One per `productId` per owner. Buying complete_pack produces seven
/// of these (one for the bundle itself, one for each individual pack).
class ExternalEntitlement {
  final String productId;
  final ExternalEntitlementStatus status;
  final ExternalProvider provider;
  final DateTime grantedAt;
  final DateTime lastVerifiedAt;
  final String? sessionId;

  const ExternalEntitlement({
    required this.productId,
    required this.status,
    required this.provider,
    required this.grantedAt,
    required this.lastVerifiedAt,
    this.sessionId,
  });

  bool get isActive => status == ExternalEntitlementStatus.active;

  factory ExternalEntitlement.fromJson(Map<String, dynamic> json) {
    return ExternalEntitlement(
      productId: json['productId'] as String,
      status: ExternalEntitlementStatus.fromWire(json['status'] as String?),
      provider: ExternalProvider.fromWire(json['provider'] as String?),
      grantedAt: DateTime.parse(json['grantedAt'] as String),
      lastVerifiedAt: DateTime.parse(json['lastVerifiedAt'] as String),
      sessionId: json['sessionId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'status': status.name,
    'provider': provider.toWire(),
    'grantedAt': grantedAt.toIso8601String(),
    'lastVerifiedAt': lastVerifiedAt.toIso8601String(),
    'sessionId': sessionId,
  };

  ExternalEntitlement copyWith({
    String? productId,
    ExternalEntitlementStatus? status,
    ExternalProvider? provider,
    DateTime? grantedAt,
    DateTime? lastVerifiedAt,
    String? sessionId,
  }) {
    return ExternalEntitlement(
      productId: productId ?? this.productId,
      status: status ?? this.status,
      provider: provider ?? this.provider,
      grantedAt: grantedAt ?? this.grantedAt,
      lastVerifiedAt: lastVerifiedAt ?? this.lastVerifiedAt,
      sessionId: sessionId ?? this.sessionId,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExternalEntitlement &&
          productId == other.productId &&
          status == other.status &&
          provider == other.provider &&
          grantedAt == other.grantedAt &&
          lastVerifiedAt == other.lastVerifiedAt &&
          sessionId == other.sessionId;

  @override
  int get hashCode => Object.hash(
    productId,
    status,
    provider,
    grantedAt,
    lastVerifiedAt,
    sessionId,
  );

  @override
  String toString() =>
      'ExternalEntitlement(productId: $productId, status: $status, provider: $provider)';
}

/// Status of an in-flight external checkout session.
///
/// `pending` is the initial state created by `createExternalCheckout`.
/// The webhook flips it to `paid` (success) or leaves it pending until
/// the lazy expiry kicks in on the next `getCheckoutStatus` read.
enum CheckoutStatus {
  pending,
  paid,
  failed,
  expired,
  unknown;

  static CheckoutStatus fromWire(String? value) {
    switch (value) {
      case 'pending':
        return CheckoutStatus.pending;
      case 'paid':
        return CheckoutStatus.paid;
      case 'failed':
        return CheckoutStatus.failed;
      case 'expired':
        return CheckoutStatus.expired;
      default:
        return CheckoutStatus.unknown;
    }
  }

  bool get isTerminal =>
      this == CheckoutStatus.paid ||
      this == CheckoutStatus.failed ||
      this == CheckoutStatus.expired;
}

// Provider that owns a checkout session. Determines which confirmation
// surface the UI uses (Stripe Payment Sheet vs BMC handoff URL).
enum CheckoutProvider {
  stripe,
  buymeacoffee;

  static CheckoutProvider fromWire(String? raw) {
    switch (raw) {
      case 'stripe':
        return CheckoutProvider.stripe;
      case 'buymeacoffee':
      // Older deploys (Chunk A / B) didn't return `provider`; default
      // to BMC for safety since checkoutUrl is populated for that path.
      case null:
        return CheckoutProvider.buymeacoffee;
      default:
        throw ArgumentError('Unsupported checkout provider: $raw');
    }
  }
}

/// Result of `createExternalCheckout` — everything the UI needs to
/// hand the user off to the chosen provider and later confirm the
/// unlock.
///
/// Two provider flows produce different field populations:
///   • BMC: `checkoutUrl` is the hosted page; `clientSecret` /
///     `paymentIntentId` / `publishableKey` are empty.
///   • Stripe (PaymentIntent + native Payment Sheet): `checkoutUrl`
///     is empty; the three Stripe fields carry the payload.
class CheckoutSessionDescriptor {
  final String sessionId;
  final String checkoutUrl;
  // Stripe-only. Empty for BMC.
  final String clientSecret;
  // Stripe-only. Empty for BMC.
  final String paymentIntentId;
  // Stripe-only. Empty for BMC.
  final String publishableKey;
  final String returnDeepLink;
  final String referenceCode;
  final double expectedAmount;
  final String currency;
  final DateTime expiresAt;
  final CheckoutProvider provider;

  const CheckoutSessionDescriptor({
    required this.sessionId,
    required this.checkoutUrl,
    required this.clientSecret,
    required this.paymentIntentId,
    required this.publishableKey,
    required this.returnDeepLink,
    required this.referenceCode,
    required this.expectedAmount,
    required this.currency,
    required this.expiresAt,
    required this.provider,
  });

  factory CheckoutSessionDescriptor.fromJson(Map<String, dynamic> json) {
    return CheckoutSessionDescriptor(
      sessionId: json['sessionId'] as String,
      checkoutUrl: (json['checkoutUrl'] as String?) ?? '',
      clientSecret: (json['clientSecret'] as String?) ?? '',
      paymentIntentId: (json['paymentIntentId'] as String?) ?? '',
      publishableKey: (json['publishableKey'] as String?) ?? '',
      returnDeepLink: json['returnDeepLink'] as String,
      referenceCode: json['referenceCode'] as String,
      expectedAmount: (json['expectedAmount'] as num).toDouble(),
      currency: json['currency'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      provider: CheckoutProvider.fromWire(json['provider'] as String?),
    );
  }
}

/// Result of `getCheckoutStatus` polling.
class CheckoutSessionStatus {
  final String sessionId;
  final CheckoutStatus status;
  final String productId;
  final List<String> grantedProductIds;
  final DateTime lastUpdatedAt;

  const CheckoutSessionStatus({
    required this.sessionId,
    required this.status,
    required this.productId,
    required this.grantedProductIds,
    required this.lastUpdatedAt,
  });

  factory CheckoutSessionStatus.fromJson(Map<String, dynamic> json) {
    return CheckoutSessionStatus(
      sessionId: json['sessionId'] as String,
      status: CheckoutStatus.fromWire(json['status'] as String?),
      productId: json['productId'] as String,
      grantedProductIds: (json['grantedProductIds'] as List)
          .map((e) => e as String)
          .toList(),
      lastUpdatedAt: DateTime.parse(json['lastUpdatedAt'] as String),
    );
  }
}
