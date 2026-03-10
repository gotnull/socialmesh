// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'package:flutter/services.dart';

import '../core/legal/age_group.dart';

/// Result returned by [AgeSignalService.fetchPlatformAgeSignal].
class AgeSignalResult {
  final AgeGroup ageGroup;
  final AgeSource source;

  const AgeSignalResult({required this.ageGroup, required this.source});

  /// Represents a state where no platform signal is available.
  static const AgeSignalResult unknown = AgeSignalResult(
    ageGroup: AgeGroup.unknown,
    source: AgeSource.unknown,
  );

  @override
  String toString() => 'AgeSignalResult(ageGroup=$ageGroup, source=$source)';
}

/// Abstraction over platform-provided age signals.
///
/// Currently scaffolded — always returns [AgeSignalResult.unknown].
///
/// Android integration path (when ready):
/// 1. Add `com.google.android.libraries.childrenssafety:age-verification`
///    (or the Play Age Signals equivalent) to `android/app/build.gradle.kts`.
/// 2. Implement `fetchAgeSignal` in [AgeSignalPlugin.kt] using the SDK.
/// 3. Remove the try/catch guard once the plugin is complete and tested.
///
/// iOS: Apple does not expose a comparable platform age signal API.
/// The channel handler on iOS will not be registered, so the catch block
/// returns [AgeSignalResult.unknown] transparently.
class AgeSignalService {
  static const _channel = MethodChannel('com.socialmesh/age_signal');

  /// Queries the native layer for a platform-provided age signal.
  ///
  /// Returns [AgeSignalResult.unknown] in all cases until the Android
  /// scaffolding is fully wired to a real Play Age Signals implementation.
  static Future<AgeSignalResult> fetchPlatformAgeSignal() async {
    try {
      final result = await _channel.invokeMapMethod<String, String>(
        'fetchAgeSignal',
      );
      if (result == null) return AgeSignalResult.unknown;
      return AgeSignalResult(
        ageGroup: AgeGroup.values.firstWhere(
          (g) => g.name == result['ageGroup'],
          orElse: () => AgeGroup.unknown,
        ),
        source: AgeSource.values.firstWhere(
          (s) => s.name == result['source'],
          orElse: () => AgeSource.unknown,
        ),
      );
    } catch (_) {
      return AgeSignalResult.unknown;
    }
  }
}
