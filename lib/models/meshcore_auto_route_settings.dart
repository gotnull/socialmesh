// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D48-A1: per-device auto-route rotation policy. Pure value type;
// persisted via `meshCoreAutoRouteSettingsProvider`.
//
// Wire-compat (behavioural, not wire) with meshcore-open's
// `AppSettings` auto-route block (lines 37-42 of their
// `app_settings.dart`). Same five parameters, same defaults, same
// valid ranges so users moving between the two apps see consistent
// rotation behaviour.
//
// Auto-route rotation is a purely app-side algorithm; the firmware
// has no concept of "route weight." Rotation happens by the app
// mutating the contact's stored `out_path` between retry attempts
// via `CMD_ADD_UPDATE_CONTACT 0x09`. D48-A1 ships the settings +
// schema + pure helpers; D48-A2 will wire the orchestrator.

class MeshCoreAutoRouteSettings {
  // Defaults match meshcore-open exactly.
  static const double defaultMaxRouteWeight = 5.0;
  static const double defaultInitialRouteWeight = 3.0;
  static const double defaultRouteWeightSuccessIncrement = 0.5;
  static const double defaultRouteWeightFailureDecrement = 0.2;

  /// D48-A2: total attempt count including the initial send. Last
  /// attempt is always flood. Default 3 (2 saved-path retries + 1
  /// flood fallback) is airtime-conservative; meshcore-open defaults
  /// to 5. Range [1, 8].
  static const int defaultMaxRetries = 3;

  /// D48-A2: per-attempt wait for the `PUSH_CODE_SEND_CONFIRMED 0x82`
  /// delivery ack before treating the attempt as failed. 8 s matches
  /// the order-of-magnitude of meshcore-open's adaptive estimator
  /// while staying simple. Range [3, 30].
  static const int defaultRetryTimeoutSeconds = 8;

  // Valid ranges enforced at setter time. Slider widgets clamp;
  // direct assignments via tests are also clamped by the notifier.
  static const double minWeight = 0.0;
  static const double maxWeight = 10.0;
  static const double minIncrement = 0.0;
  static const double maxIncrement = 2.0;
  static const int minMaxRetries = 1;
  static const int maxMaxRetries = 8;
  static const int minRetryTimeoutSeconds = 3;
  static const int maxRetryTimeoutSeconds = 30;

  /// Master toggle. Off ⇒ retries reuse the current path (current
  /// SocialMesh behaviour, no rotation).
  final bool enabled;

  /// Upper clamp on a path's `routeWeight` after a success.
  final double maxRouteWeight;

  /// Starting weight for a newly-discovered path.
  final double initialRouteWeight;

  /// Added to a path's weight on successful delivery.
  final double routeWeightSuccessIncrement;

  /// Subtracted from a path's weight on failure. When the result is
  /// ≤ 0 the path is evicted from the rotation pool.
  final double routeWeightFailureDecrement;

  /// D48-A2: total attempt count (initial + retries). The last
  /// attempt always uses flood (`pathLength = -1`).
  final int maxRetries;

  /// D48-A2: per-attempt wait for `PUSH_CODE_SEND_CONFIRMED 0x82`.
  final int retryTimeoutSeconds;

  const MeshCoreAutoRouteSettings({
    this.enabled = false,
    this.maxRouteWeight = defaultMaxRouteWeight,
    this.initialRouteWeight = defaultInitialRouteWeight,
    this.routeWeightSuccessIncrement = defaultRouteWeightSuccessIncrement,
    this.routeWeightFailureDecrement = defaultRouteWeightFailureDecrement,
    this.maxRetries = defaultMaxRetries,
    this.retryTimeoutSeconds = defaultRetryTimeoutSeconds,
  });

  /// Factory-reset defaults; matches meshcore-open's first-run state.
  const MeshCoreAutoRouteSettings.defaults() : this();

  MeshCoreAutoRouteSettings copyWith({
    bool? enabled,
    double? maxRouteWeight,
    double? initialRouteWeight,
    double? routeWeightSuccessIncrement,
    double? routeWeightFailureDecrement,
    int? maxRetries,
    int? retryTimeoutSeconds,
  }) {
    return MeshCoreAutoRouteSettings(
      enabled: enabled ?? this.enabled,
      maxRouteWeight: maxRouteWeight ?? this.maxRouteWeight,
      initialRouteWeight: initialRouteWeight ?? this.initialRouteWeight,
      routeWeightSuccessIncrement:
          routeWeightSuccessIncrement ?? this.routeWeightSuccessIncrement,
      routeWeightFailureDecrement:
          routeWeightFailureDecrement ?? this.routeWeightFailureDecrement,
      maxRetries: maxRetries ?? this.maxRetries,
      retryTimeoutSeconds: retryTimeoutSeconds ?? this.retryTimeoutSeconds,
    );
  }

  /// Clamp [v] to the weight range. Used by the notifier on setter
  /// calls and by widget tests that don't go through a `Slider`.
  static double clampWeight(double v) {
    if (v.isNaN) return minWeight;
    if (v < minWeight) return minWeight;
    if (v > maxWeight) return maxWeight;
    return v;
  }

  /// Clamp [v] to the increment / decrement range.
  static double clampIncrement(double v) {
    if (v.isNaN) return minIncrement;
    if (v < minIncrement) return minIncrement;
    if (v > maxIncrement) return maxIncrement;
    return v;
  }

  /// D48-A2: clamp [v] to the maxRetries range.
  static int clampMaxRetries(int v) {
    if (v < minMaxRetries) return minMaxRetries;
    if (v > maxMaxRetries) return maxMaxRetries;
    return v;
  }

  /// D48-A2: clamp [v] to the retry-timeout range.
  static int clampRetryTimeoutSeconds(int v) {
    if (v < minRetryTimeoutSeconds) return minRetryTimeoutSeconds;
    if (v > maxRetryTimeoutSeconds) return maxRetryTimeoutSeconds;
    return v;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MeshCoreAutoRouteSettings &&
          other.enabled == enabled &&
          other.maxRouteWeight == maxRouteWeight &&
          other.initialRouteWeight == initialRouteWeight &&
          other.routeWeightSuccessIncrement == routeWeightSuccessIncrement &&
          other.routeWeightFailureDecrement == routeWeightFailureDecrement &&
          other.maxRetries == maxRetries &&
          other.retryTimeoutSeconds == retryTimeoutSeconds;

  @override
  int get hashCode => Object.hash(
    enabled,
    maxRouteWeight,
    initialRouteWeight,
    routeWeightSuccessIncrement,
    routeWeightFailureDecrement,
    maxRetries,
    retryTimeoutSeconds,
  );
}
