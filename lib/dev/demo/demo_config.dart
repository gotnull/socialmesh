// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)
import 'package:flutter/foundation.dart';

/// Demo mode configuration.
///
/// Demo mode is enabled via compile-time flag:
///   flutter run --dart-define=SOCIALMESH_DEMO=1
///
/// When enabled, the app runs with sample data and no backend dependencies.
/// Demo mode is only available in debug builds.
class DemoConfig {
  DemoConfig._();

  /// Raw value of the SOCIALMESH_DEMO dart-define, empty when unset.
  static const String _rawFlag = String.fromEnvironment('SOCIALMESH_DEMO');

  /// Whether demo mode is enabled via dart-define flag.
  /// Only evaluates to true in debug builds with SOCIALMESH_DEMO=1 (or
  /// SOCIALMESH_DEMO=true). Parsed from the raw string because
  /// `bool.fromEnvironment` accepts only the literal "true", which would
  /// leave the documented `=1` form permanently off.
  static const bool isEnabled =
      kDebugMode && (_rawFlag == '1' || _rawFlag == 'true');

  /// The same rule as [isEnabled] applies to the raw define, exposed so a
  /// test can pin the accepted spellings. Kept in step with the const
  /// expression above, which cannot call a method.
  @visibleForTesting
  static bool parseFlag(String raw) => raw == '1' || raw == 'true';

  /// Demo mode identifier for logging.
  static const String modeLabel = isEnabled ? '[DEMO]' : '';
}
