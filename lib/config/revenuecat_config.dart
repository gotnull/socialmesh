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
  // PRODUCT IDS
  // These must match your App Store Connect / Google Play Console product IDs
  // ============================================================================

  /// Theme pack non-consumable product ID
  static const String themePackProductId = 'prod0da6d733fd';

  /// Ringtone pack non-consumable product ID
  static const String ringtonePackProductId = 'prod1a7cd06c47';

  /// Widget pack non-consumable product ID
  static const String widgetPackProductId = 'prod69bcb2bd24';

  /// Automations pack non-consumable product ID
  static const String automationsPackProductId = 'prod67adcb1f11';

  /// IFTTT integration non-consumable product ID
  static const String iftttPackProductId = 'prod50d4fc8254';

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
