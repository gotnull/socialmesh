// SPDX-License-Identifier: GPL-3.0-or-later
/// Configuration for admin/debug features.
/// These features are controlled via the debug settings screen,
/// accessed by secret 7-tap gesture + PIN. No env vars used for security.
class AdminConfig {
  AdminConfig._();

  // Mutable state controlled via debug settings screen
  static bool _isEnabled = false;
  static bool _premiumUpsellEnabled = false;

  /// Whether admin/debug mode is enabled.
  /// Set via debug settings screen after secret gesture unlock.
  static bool get isEnabled => _isEnabled;

  /// Update admin mode (called from settings provider initialization).
  static void setEnabled(bool value) {
    _isEnabled = value;
  }

  /// Whether premium upsell mode is enabled.
  /// When true, users can explore premium features with upsell on actions.
  static bool get premiumUpsellEnabled => _premiumUpsellEnabled;

  /// Update premium upsell mode (called from settings provider initialization).
  static void setPremiumUpsellEnabled(bool value) {
    _premiumUpsellEnabled = value;
  }

  /// Whether to show the animated mesh node playground in settings.
  static bool get showMeshNodePlayground => isEnabled;

  /// Whether to show the test push notification button.
  static bool get showTestNotification => isEnabled;

  /// Whether to show the automation debug panel button.
  static bool get showAutomationDebug => isEnabled;

  /// Whether to show export/import automation debug features.
  static bool get showAutomationExport => isEnabled;
}
