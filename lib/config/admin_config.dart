import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration for admin/debug features.
/// These features are hidden behind .env flags and are only
/// available for development and testing purposes.
class AdminConfig {
  AdminConfig._();

  /// Whether admin/debug mode is enabled.
  /// Set ADMIN_DEBUG_MODE=true in .env to enable.
  static bool get isEnabled {
    final value = dotenv.env['ADMIN_DEBUG_MODE']?.toLowerCase();
    return value == 'true' || value == '1';
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
