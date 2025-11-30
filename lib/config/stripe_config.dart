import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Stripe configuration loaded from environment variables
class StripeConfig {
  StripeConfig._();

  /// Stripe publishable key (safe for client-side)
  static String get publishableKey =>
      dotenv.env['STRIPE_PUBLISHABLE_KEY'] ?? '';

  /// API base URL for backend
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://api.protofluff.com';

  /// Stripe Price IDs
  static String get pricePremium =>
      dotenv.env['STRIPE_PRICE_PREMIUM'] ?? 'price_premium';

  static String get pricePro => dotenv.env['STRIPE_PRICE_PRO'] ?? 'price_pro';

  static String get priceEnterprise =>
      dotenv.env['STRIPE_PRICE_ENTERPRISE'] ?? 'price_enterprise';

  /// Check if Stripe is configured
  static bool get isConfigured =>
      publishableKey.isNotEmpty && publishableKey.startsWith('pk_');
}
