// SPDX-License-Identifier: GPL-3.0-or-later

/// Configuration for TAK position publishing.
///
/// Controls whether the local node's position is published to the TAK
/// Gateway as a CoT SA event, and at what interval.
class TakPublishConfig {
  /// Whether position publishing is enabled.
  final bool enabled;

  /// Publish interval in seconds.
  final int intervalSeconds;

  /// User-specified callsign override. If null, uses the node's long name.
  final String? callsignOverride;

  const TakPublishConfig({
    this.enabled = false,
    this.intervalSeconds = 60,
    this.callsignOverride,
  });

  /// The effective callsign: override if set, otherwise the provided fallback.
  String effectiveCallsign(String fallback) =>
      (callsignOverride != null && callsignOverride!.trim().isNotEmpty)
      ? callsignOverride!.trim()
      : fallback;

  TakPublishConfig copyWith({
    bool? enabled,
    int? intervalSeconds,
    String? callsignOverride,
  }) {
    return TakPublishConfig(
      enabled: enabled ?? this.enabled,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      callsignOverride: callsignOverride ?? this.callsignOverride,
    );
  }
}
