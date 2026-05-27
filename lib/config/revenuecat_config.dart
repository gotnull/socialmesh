// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'dart:io' show Platform;

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
  // ============================================================================

  /// Theme pack non-consumable product ID
  static String get themePackProductId =>
      dotenv.env['THEME_PACK_PRODUCT_ID'] ?? 'theme_pack';

  /// Ringtone pack non-consumable product ID
  static String get ringtonePackProductId =>
      dotenv.env['RINGTONE_PACK_PRODUCT_ID'] ?? 'ringtone_pack';

  /// Widget pack non-consumable product ID
  static String get widgetPackProductId =>
      dotenv.env['WIDGET_PACK_PRODUCT_ID'] ?? 'widget_pack';

  /// Automations pack non-consumable product ID
  static String get automationsPackProductId =>
      dotenv.env['AUTOMATIONS_PACK_PRODUCT_ID'] ?? 'automations_pack';

  /// IFTTT integration non-consumable product ID
  static String get iftttPackProductId =>
      dotenv.env['IFTTT_PACK_PRODUCT_ID'] ?? 'ifttt_pack';

  /// Translation pack non-consumable product ID
  static String get translationPackProductId =>
      dotenv.env['TRANSLATION_PACK_PRODUCT_ID'] ?? 'translation_pack';

  /// Complete Pack bundle - all features at a discount
  static String get completePackProductId =>
      dotenv.env['COMPLETE_PACK_PRODUCT_ID'] ?? 'complete_pack';

  /// Community Pack 10 - shared premium access for up to 10 members.
  /// Maps to the org-checkout backend; gated by
  /// `AppFeatureFlags.isCommunityPackEnabled` until the matching Stripe
  /// SKU is live.
  static String get communityPack10ProductId =>
      dotenv.env['COMMUNITY_PACK_10_PRODUCT_ID'] ?? 'community_pack_10';

  /// Community Pack 20 - shared premium access for up to 20 members.
  /// Same gating + backend wiring as `communityPack10ProductId`.
  static String get communityPack20ProductId =>
      dotenv.env['COMMUNITY_PACK_20_PRODUCT_ID'] ?? 'community_pack_20';

  /// Get all product IDs as a list
  static List<String> get allProductIds => [
    themePackProductId,
    ringtonePackProductId,
    widgetPackProductId,
    automationsPackProductId,
    iftttPackProductId,
    translationPackProductId,
    completePackProductId,
  ];

  // ============================================================================
  // OFFERING IDS
  // ============================================================================

  /// Default offering ID
  static const String defaultOfferingId = 'default';

  /// Check if RevenueCat is configured for the current platform
  static bool get isConfigured {
    return currentPlatformApiKey.isNotEmpty;
  }

  /// Get the API key for the current platform (iOS or Android)
  static String get currentPlatformApiKey {
    return Platform.isIOS ? iosApiKey : androidApiKey;
  }

  /// Check if configured for iOS specifically
  static bool get isConfiguredForIOS => iosApiKey.isNotEmpty;

  /// Check if configured for Android specifically
  static bool get isConfiguredForAndroid => androidApiKey.isNotEmpty;
}
