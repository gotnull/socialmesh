import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// RevenueCat configuration loaded from environment variables
///
/// ## Sandbox / Test Store Setup:
///
/// ### iOS (StoreKit Testing):
/// 1. In Xcode, create a StoreKit Configuration file (.storekit)
/// 2. Add your products matching the IDs below
/// 3. Edit scheme > Run > Options > StoreKit Configuration > Select your file
/// 4. Run the app - purchases will use the local test store
///
/// ### iOS (Sandbox Apple ID):
/// 1. Create a Sandbox Tester in App Store Connect > Users and Access > Sandbox
/// 2. Sign out of App Store on device (Settings > App Store > Sign Out)
/// 3. When making a purchase, sign in with sandbox account
///
/// ### Android (License Testing):
/// 1. Add tester emails in Google Play Console > Setup > License Testing
/// 2. Use a test track (internal/closed) for testing
///
/// ### RevenueCat Dashboard:
/// - View sandbox transactions in RevenueCat Dashboard > Customers
/// - Filter by "Sandbox" environment to see test purchases
class RevenueCatConfig {
  RevenueCatConfig._();

  /// iOS API Key from RevenueCat dashboard
  static String get iosApiKey => dotenv.env['REVENUECAT_IOS_API_KEY'] ?? '';

  /// Android API Key from RevenueCat dashboard
  static String get androidApiKey =>
      dotenv.env['REVENUECAT_ANDROID_API_KEY'] ?? '';

  // ============================================================================
  // PRODUCT IDS
  // Loaded from .env - set USE_TEST_PRODUCTS=true for testing, false for production
  // ============================================================================

  /// Whether to use test product IDs (from .env or defaults to kDebugMode)
  static bool get useTestProducts {
    final envValue = dotenv.env['USE_TEST_PRODUCTS'];
    if (envValue != null) {
      return envValue.toLowerCase() == 'true';
    }
    return kDebugMode;
  }

  /// Theme pack non-consumable product ID
  static String get themePackProductId => useTestProducts
      ? (dotenv.env['TEST_THEME_PACK_PRODUCT_ID'] ?? 'prod343db31c03')
      : (dotenv.env['PROD_THEME_PACK_PRODUCT_ID'] ?? 'prod0da6d733fd');

  /// Ringtone pack non-consumable product ID
  static String get ringtonePackProductId => useTestProducts
      ? (dotenv.env['TEST_RINGTONE_PACK_PRODUCT_ID'] ?? 'prodc9564f9449')
      : (dotenv.env['PROD_RINGTONE_PACK_PRODUCT_ID'] ?? 'prod1a7cd06c47');

  /// Widget pack non-consumable product ID
  static String get widgetPackProductId => useTestProducts
      ? (dotenv.env['TEST_WIDGET_PACK_PRODUCT_ID'] ?? 'proda8f14c695a')
      : (dotenv.env['PROD_WIDGET_PACK_PRODUCT_ID'] ?? 'prod69bcb2bd24');

  /// Automations pack non-consumable product ID
  static String get automationsPackProductId => useTestProducts
      ? (dotenv.env['TEST_AUTOMATIONS_PACK_PRODUCT_ID'] ?? 'prode6eb12f2dc')
      : (dotenv.env['PROD_AUTOMATIONS_PACK_PRODUCT_ID'] ?? 'prod67adcb1f11');

  /// IFTTT integration non-consumable product ID
  static String get iftttPackProductId => useTestProducts
      ? (dotenv.env['TEST_IFTTT_PACK_PRODUCT_ID'] ?? 'prod5249ea0504')
      : (dotenv.env['PROD_IFTTT_PACK_PRODUCT_ID'] ?? 'prod50d4fc8254');

  /// Get all product IDs as a list
  static List<String> get allProductIds => [
    themePackProductId,
    ringtonePackProductId,
    widgetPackProductId,
    automationsPackProductId,
    iftttPackProductId,
  ];

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
