// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Per-channel, per-field notification length policy.
///
/// A [NotificationPolicy] defines the maximum visible grapheme-cluster
/// lengths and (optionally) payload byte budgets for each notification
/// field. Policies are pure configuration - no business logic - so they
/// can be swapped or extended without touching the renderer.
///
/// Predefined policies:
/// - [NotificationPolicy.ios] - measured on-device: ~256 visible chars
///   for body in expanded notification view.
/// - [NotificationPolicy.android] - BigTextStyle renders ~450-500 chars.
/// - [NotificationPolicy.strictest] - intersection of all platform limits
///   (the default for cross-platform local notifications).
library;

/// Limits for a single text field.
class FieldPolicy {
  /// Maximum visible grapheme clusters. `null` = unlimited.
  final int? maxGraphemes;

  /// Maximum UTF-8 bytes. `null` = unlimited.
  final int? maxBytes;

  const FieldPolicy({this.maxGraphemes, this.maxBytes});

  /// A field policy with no constraints.
  static const unconstrained = FieldPolicy();

  @override
  String toString() =>
      'FieldPolicy(maxGraphemes: $maxGraphemes, maxBytes: $maxBytes)';
}

/// Per-field truncation priority. Lower number = truncated first when
/// the notification exceeds policy limits.
///
/// During the deterministic reduction pass the renderer walks fields in
/// [ReductionPriority] order, dropping optional fields entirely before
/// applying per-field truncation.
enum ReductionPriority {
  /// Dropped first - supplementary context (snippet, preview).
  lowest,

  /// Dropped second - secondary identifiers.
  low,

  /// Truncated but not dropped.
  normal,

  /// Truncated last (title, primary identifier).
  high,
}

/// Configuration for how a variable value should be treated during
/// the reduction pass.
class VariablePolicy {
  /// Maximum grapheme clusters for this variable's resolved value.
  final int maxGraphemes;

  /// Reduction priority when the renderer needs to shed bytes.
  final ReductionPriority priority;

  /// Fallback value used when the variable is missing or empty.
  final String fallback;

  const VariablePolicy({
    this.maxGraphemes = 100,
    this.priority = ReductionPriority.normal,
    this.fallback = '',
  });

  /// Default variable policy - generous limit, normal priority.
  static const standard = VariablePolicy();

  @override
  String toString() =>
      'VariablePolicy(max: $maxGraphemes, priority: $priority, '
      'fallback: "$fallback")'; // lint-allow: hardcoded-string
}

/// The complete notification policy for a single delivery channel.
class NotificationPolicy {
  /// Human-readable label (e.g. "iOS local", "FCM push").
  final String channel;

  /// Visible-text limit for the title field.
  final FieldPolicy title;

  /// Visible-text limit for the body field.
  final FieldPolicy body;

  /// Visible-text limit for the subtitle field.
  final FieldPolicy subtitle;

  /// Maximum total UTF-8 bytes for the entire JSON payload.
  /// `null` means no payload-level cap (local notifications).
  final int? maxPayloadBytes;

  /// Per-variable override policies keyed by variable name
  /// (without the `{{ }}` delimiters).
  final Map<String, VariablePolicy> variablePolicies;

  const NotificationPolicy({
    required this.channel,
    this.title = const FieldPolicy(maxGraphemes: 100),
    this.body = const FieldPolicy(maxGraphemes: 250),
    this.subtitle = const FieldPolicy(maxGraphemes: 150),
    this.maxPayloadBytes,
    this.variablePolicies = const {},
  });

  /// iOS local notification policy.
  ///
  /// Measured on-device: expanded notification renders ~256 visible chars
  /// for body. We cap at 250 so our "…" suffix remains visible.
  /// Title renders 1-2 lines (~100 chars).
  static const ios = NotificationPolicy(
    channel: 'ios_local',
    title: FieldPolicy(maxGraphemes: 100),
    body: FieldPolicy(maxGraphemes: 250),
    subtitle: FieldPolicy(maxGraphemes: 150),
    variablePolicies: _defaultVariablePolicies,
  );

  /// Android local notification policy.
  ///
  /// BigTextStyle renders ~450-500 visible chars for body.
  /// We cap at 450 for safety.
  static const android = NotificationPolicy(
    channel: 'android_local',
    title: FieldPolicy(maxGraphemes: 100),
    body: FieldPolicy(maxGraphemes: 450),
    subtitle: FieldPolicy(maxGraphemes: 200),
    variablePolicies: _defaultVariablePolicies,
  );

  /// APNs remote push policy (4 096-byte total payload).
  static const apnsRemote = NotificationPolicy(
    channel: 'apns_remote',
    title: FieldPolicy(maxGraphemes: 100, maxBytes: 200),
    body: FieldPolicy(maxGraphemes: 250, maxBytes: 2000),
    subtitle: FieldPolicy(maxGraphemes: 150, maxBytes: 400),
    maxPayloadBytes: 4096,
    variablePolicies: _defaultVariablePolicies,
  );

  /// FCM remote push policy (4 096-byte data message).
  static const fcmRemote = NotificationPolicy(
    channel: 'fcm_remote',
    title: FieldPolicy(maxGraphemes: 100, maxBytes: 200),
    body: FieldPolicy(maxGraphemes: 450, maxBytes: 2500),
    subtitle: FieldPolicy(maxGraphemes: 200, maxBytes: 500),
    maxPayloadBytes: 4096,
    variablePolicies: _defaultVariablePolicies,
  );

  /// The strictest intersection of iOS and Android local policies.
  /// Use this as the default for cross-platform local notifications.
  static const strictest = NotificationPolicy(
    channel: 'cross_platform_local',
    title: FieldPolicy(maxGraphemes: 100),
    body: FieldPolicy(maxGraphemes: 250),
    subtitle: FieldPolicy(maxGraphemes: 150),
    variablePolicies: _defaultVariablePolicies,
  );

  static const _defaultVariablePolicies = <String, VariablePolicy>{
    'node.name': VariablePolicy(
      maxGraphemes: 40,
      priority: ReductionPriority.high,
      fallback: 'Someone',
    ),
    'node.num': VariablePolicy(
      maxGraphemes: 16,
      priority: ReductionPriority.low,
      fallback: '',
    ),
    'battery': VariablePolicy(
      maxGraphemes: 5,
      priority: ReductionPriority.normal,
      fallback: '?%',
    ),
    'location': VariablePolicy(
      maxGraphemes: 50,
      priority: ReductionPriority.low,
      fallback: 'Unknown',
    ),
    'message': VariablePolicy(
      maxGraphemes: 200,
      priority: ReductionPriority.lowest,
      fallback: '',
    ),
    'time': VariablePolicy(
      maxGraphemes: 30,
      priority: ReductionPriority.normal,
      fallback: 'now',
    ),
    'sensor.name': VariablePolicy(
      maxGraphemes: 40,
      priority: ReductionPriority.normal,
      fallback: 'Unknown',
    ),
    'sensor.state': VariablePolicy(
      maxGraphemes: 20,
      priority: ReductionPriority.normal,
      fallback: 'unknown',
    ),
    'threshold': VariablePolicy(
      maxGraphemes: 10,
      priority: ReductionPriority.normal,
      fallback: '?%',
    ),
    'keyword': VariablePolicy(
      maxGraphemes: 50,
      priority: ReductionPriority.low,
      fallback: '',
    ),
    'zone.radius': VariablePolicy(
      maxGraphemes: 10,
      priority: ReductionPriority.low,
      fallback: '?m', // lint-allow: hardcoded-string
    ),
    'silent.duration': VariablePolicy(
      maxGraphemes: 15,
      priority: ReductionPriority.normal,
      fallback: '? min', // lint-allow: hardcoded-string
    ),
    'signal.threshold': VariablePolicy(
      maxGraphemes: 10,
      priority: ReductionPriority.low,
      fallback: '? dB', // lint-allow: hardcoded-string
    ),
    'channel.name': VariablePolicy(
      maxGraphemes: 30,
      priority: ReductionPriority.normal,
      fallback: 'Channel 0', // lint-allow: hardcoded-string
    ),
  };

  @override
  String toString() =>
      'NotificationPolicy(channel: "$channel", title: $title, '
      'body: $body, payload: $maxPayloadBytes)'; // lint-allow: hardcoded-string
}
