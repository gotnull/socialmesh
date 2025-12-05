import 'package:flutter_dotenv/flutter_dotenv.dart';

/// RevenueCat configuration loaded from environment variables
class RevenueCatConfig {
  RevenueCatConfig._();

  /// iOS API Key from RevenueCat dashboard
  static String get iosApiKey => dotenv.env['REVENUECAT_IOS_API_KEY'] ?? '';

  /// Android API Key from RevenueCat dashboard
  static String get androidApiKey =>
      dotenv.env['REVENUECAT_ANDROID_API_KEY'] ?? '';

  // ============================================================================
  // ENTITLEMENT IDS
  // These must match what you configure in RevenueCat dashboard
  // ============================================================================

  /// Entitlement ID for Premium tier access
  static const String premiumEntitlementId = 'premium';

  /// Entitlement ID for Pro tier access
  static const String proEntitlementId = 'pro';

  // ============================================================================
  // PRODUCT IDS
  // These must match your App Store Connect / Google Play Console product IDs
  // ============================================================================

  /// Premium monthly subscription product ID
  static const String premiumMonthlyProductId = 'socialmesh_premium_monthly';

  /// Premium yearly subscription product ID
  static const String premiumYearlyProductId = 'socialmesh_premium_yearly';

  /// Pro monthly subscription product ID
  static const String proMonthlyProductId = 'socialmesh_pro_monthly';

  /// Pro yearly subscription product ID
  static const String proYearlyProductId = 'socialmesh_pro_yearly';

  /// Theme pack non-consumable product ID
  static const String themePackProductId = 'socialmesh_theme_pack';

  /// Ringtone pack non-consumable product ID
  static const String ringtonePackProductId = 'socialmesh_ringtone_pack';

  /// Widget pack non-consumable product ID
  static const String widgetPackProductId = 'socialmesh_widget_pack';

  // ============================================================================
  // OFFERING IDS
  // ============================================================================

  /// Default offering ID
  static const String defaultOfferingId = 'default';

  /// Check if RevenueCat is configured
  static bool get isConfigured {
    // Check based on platform
    return iosApiKey.isNotEmpty || androidApiKey.isNotEmpty;
  }
}
