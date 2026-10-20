// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

/// Template tier system for progressive notification fallback.
///
/// Each [NotificationTemplateTier] provides a title and body template at a
/// different level of detail. The renderer tries [full] first; if the
/// resolved text exceeds the active policy the next tier is tried, down to
/// [minimal] and finally a hard-coded safe default.
///
/// Templates use `{{variable}}` placeholders identical to the existing
/// automation variable system.
library;

/// A single template tier.
class NotificationTemplateTier {
  /// Unique tier identifier for logging / debugging.
  final TemplateTierLevel level;

  /// Title template (may contain `{{variables}}`).
  final String titleTemplate;

  /// Body template (may contain `{{variables}}`).
  final String bodyTemplate;

  /// Subtitle template (optional).
  final String? subtitleTemplate;

  const NotificationTemplateTier({
    required this.level,
    required this.titleTemplate,
    required this.bodyTemplate,
    this.subtitleTemplate,
  });

  @override
  String toString() =>
      'NotificationTemplateTier($level, title: "$titleTemplate", '
      'body: "$bodyTemplate")'; // lint-allow: hardcoded-string
}

/// Tier levels ordered from richest to most compact.
enum TemplateTierLevel {
  /// Full detail - all context variables included.
  full,

  /// Shortened - drops optional fields like snippet / location.
  short,

  /// Minimal - just the core fact (who + what happened).
  minimal,
}

/// A specification that bundles the template tiers for a particular
/// notification type.
///
/// Automations store a [NotificationSpec] (or reference one by type) so
/// the renderer knows which tiers to try.
class NotificationSpec {
  /// The ordered list of tiers to attempt, richest first.
  /// Must contain at least one tier.
  final List<NotificationTemplateTier> tiers;

  /// The absolute last-resort message if every tier fails.
  /// This string must be short enough to always fit any policy.
  final String fallbackTitle;
  final String fallbackBody;

  /// Optional deep-link pattern (may contain `{{variables}}`).
  final String? deepLinkTemplate;

  const NotificationSpec({
    required this.tiers,
    this.fallbackTitle = 'Alert',
    this.fallbackBody =
        'An automation was triggered.', // lint-allow: hardcoded-string
    this.deepLinkTemplate,
  });

  /// Convenience constructor for a single user-authored template.
  ///
  /// This is the primary path for user-defined automation notifications
  /// where the user provides title and body templates in the editor. The
  /// renderer wraps these as a FULL tier and generates SHORT and MINIMAL
  /// fallbacks automatically.
  factory NotificationSpec.fromUserTemplate({
    required String titleTemplate,
    required String bodyTemplate,
    String? subtitleTemplate,
    String? deepLinkTemplate,
    String fallbackTitle = 'Alert',
    String fallbackBody =
        'An automation was triggered.', // lint-allow: hardcoded-string
  }) {
    return NotificationSpec(
      tiers: [
        NotificationTemplateTier(
          level: TemplateTierLevel.full,
          titleTemplate: titleTemplate,
          bodyTemplate: bodyTemplate,
          subtitleTemplate: subtitleTemplate,
        ),
        // SHORT tier: keep title, truncate body to first sentence/line
        NotificationTemplateTier(
          level: TemplateTierLevel.short,
          titleTemplate: titleTemplate,
          bodyTemplate: _shortenBody(bodyTemplate),
        ),
        // MINIMAL tier: title only, minimal body
        NotificationTemplateTier(
          level: TemplateTierLevel.minimal,
          titleTemplate: titleTemplate,
          bodyTemplate: _minimalBody(bodyTemplate),
        ),
      ],
      fallbackTitle: fallbackTitle,
      fallbackBody: fallbackBody,
      deepLinkTemplate: deepLinkTemplate,
    );
  }

  /// Heuristic: keep only the first variable or first ~80 template chars.
  static String _shortenBody(String template) {
    // Find the first closing }} and keep up to there
    final firstVarEnd = template.indexOf('}}');
    if (firstVarEnd >= 0 && firstVarEnd < 80) {
      return template.substring(0, firstVarEnd + 2);
    }
    // Or just take the first 80 chars of the template
    if (template.length > 80) {
      return template.substring(0, 80);
    }
    return template;
  }

  /// Heuristic: just the first variable if present, otherwise first 30 chars.
  static String _minimalBody(String template) {
    final firstVarStart = template.indexOf('{{');
    final firstVarEnd = template.indexOf('}}');
    if (firstVarStart >= 0 && firstVarEnd > firstVarStart) {
      return template.substring(firstVarStart, firstVarEnd + 2);
    }
    if (template.length > 30) {
      return template.substring(0, 30);
    }
    return template;
  }

  @override
  String toString() =>
      'NotificationSpec(tiers: ${tiers.length}, '
      'fallback: "$fallbackTitle / $fallbackBody")'; // lint-allow: hardcoded-string
}
