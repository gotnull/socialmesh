// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'notification_parts.dart';
import 'notification_policy.dart';
import 'notification_template.dart';
import 'text_measurement.dart';

/// Orchestrates notification rendering with policy enforcement.
///
/// The [NotificationRenderer] takes a [NotificationSpec] (template tiers),
/// a map of resolved variable values, and a [NotificationPolicy], then
/// produces a [NotificationParts] that is guaranteed to satisfy the policy.
///
/// ## Rendering pipeline
///
/// 1. **Variable pre-trim** - each variable value is capped per its
///    [VariablePolicy.maxGraphemes]. Missing or empty values get their
///    configured fallback.
///
/// 2. **Tier walk** - starting from the richest tier, resolve all
///    `{{variable}}` placeholders. If the result fits the policy, return it.
///
/// 3. **Deterministic reduction** - if the resolved text exceeds the policy:
///    a. Drop optional variables (lowest priority first) by replacing them
///       with empty strings.
///    b. Apply per-field truncation ([safeTruncateAtWord]).
///    c. Move to the next tier.
///
/// 4. **Safe fallback** - if all tiers fail, emit the spec's hard-coded
///    fallback message (guaranteed to fit any policy).
///
/// The deep-link and data payload are always preserved regardless of text
/// reduction.
class NotificationRenderer {
  /// Render a notification from [spec] using [variables] under [policy].
  ///
  /// [variables] maps variable names (without `{{ }}`) to their runtime
  /// values. Unknown variables are left as-is if they have no fallback in
  /// the policy.
  ///
  /// Returns a [RenderResult] containing the final [NotificationParts] and
  /// metadata about which tier was used and whether reduction occurred.
  static RenderResult render({
    required NotificationSpec spec,
    required Map<String, String> variables,
    NotificationPolicy policy = NotificationPolicy.strictest,
  }) {
    // Step 1: Pre-trim variable values per their policies
    final trimmedVars = _preTrimVariables(variables, policy);

    // Step 2: Walk tiers from richest to most compact
    for (final tier in spec.tiers) {
      final title = _resolveTemplate(tier.titleTemplate, trimmedVars);
      final body = _resolveTemplate(tier.bodyTemplate, trimmedVars);
      final subtitle = tier.subtitleTemplate != null
          ? _resolveTemplate(tier.subtitleTemplate!, trimmedVars)
          : null;

      // Check if it fits the policy as-is
      if (_fitsPolicy(title, body, subtitle, policy)) {
        return RenderResult(
          parts: NotificationParts(
            title: title,
            body: body,
            subtitle: subtitle,
            deepLink: spec.deepLinkTemplate != null
                ? _resolveTemplate(spec.deepLinkTemplate!, trimmedVars)
                : null,
          ),
          tierUsed: tier.level,
          reductionApplied: false,
        );
      }

      // Step 2b: Try per-field truncation BEFORE dropping any variables.
      // This preserves all content - just trimmed - instead of losing
      // entire variable values.
      final truncTitle = _truncateField(title, policy.title);
      final truncBody = _truncateField(body, policy.body);
      final truncSubtitle = subtitle != null
          ? _truncateField(subtitle, policy.subtitle)
          : null;

      if (_fitsPolicy(truncTitle, truncBody, truncSubtitle, policy)) {
        return RenderResult(
          parts: NotificationParts(
            title: truncTitle,
            body: truncBody,
            subtitle: truncSubtitle,
            deepLink: spec.deepLinkTemplate != null
                ? _resolveTemplate(spec.deepLinkTemplate!, trimmedVars)
                : null,
          ),
          tierUsed: tier.level,
          reductionApplied: true,
        );
      }

      // Step 3a: Deterministic reduction - drop lowest-priority vars first
      final reduced = _applyReduction(
        tier: tier,
        variables: trimmedVars,
        policy: policy,
      );
      if (reduced != null) {
        return RenderResult(
          parts: reduced.copyWith(
            deepLink: spec.deepLinkTemplate != null
                ? _resolveTemplate(spec.deepLinkTemplate!, trimmedVars)
                : null,
          ),
          tierUsed: tier.level,
          reductionApplied: true,
        );
      }

      // This tier can't fit even after reduction - try next tier
    }

    // Step 4: All tiers exhausted - emit safe fallback
    final fallbackTitle = _truncateField(spec.fallbackTitle, policy.title);
    final fallbackBody = _truncateField(spec.fallbackBody, policy.body);

    return RenderResult(
      parts: NotificationParts(
        title: fallbackTitle,
        body: fallbackBody,
        deepLink: spec.deepLinkTemplate != null
            ? _resolveTemplate(spec.deepLinkTemplate!, trimmedVars)
            : null,
      ),
      tierUsed: null, // fallback - no tier
      reductionApplied: true,
    );
  }

  /// Pre-trim each variable value per its [VariablePolicy].
  static Map<String, String> _preTrimVariables(
    Map<String, String> variables,
    NotificationPolicy policy,
  ) {
    final result = <String, String>{};
    for (final entry in variables.entries) {
      final varPolicy =
          policy.variablePolicies[entry.key] ?? VariablePolicy.standard;
      var value = entry.value;

      // Apply fallback for empty values
      if (value.isEmpty) {
        value = varPolicy.fallback;
      }

      // Trim to per-variable max
      value = safeTruncateGraphemes(value, varPolicy.maxGraphemes);

      result[entry.key] = value;
    }

    // Also inject fallbacks for variables that are completely missing
    for (final entry in policy.variablePolicies.entries) {
      if (!result.containsKey(entry.key) && entry.value.fallback.isNotEmpty) {
        result[entry.key] = entry.value.fallback;
      }
    }

    return result;
  }

  /// Replace all `{{var}}` placeholders in [template] with values from [vars].
  static String _resolveTemplate(String template, Map<String, String> vars) {
    var result = template;
    for (final entry in vars.entries) {
      result = result.replaceAll('{{${entry.key}}}', entry.value);
    }
    // Strip any remaining unresolved variables
    result = result.replaceAll(RegExp(r'\{\{[a-zA-Z_.]+\}\}'), '');
    // Clean up double spaces left by removed variables
    result = result.replaceAll(RegExp(r' {2,}'), ' ').trim();
    return result;
  }

  /// Check whether the resolved fields fit within [policy].
  static bool _fitsPolicy(
    String title,
    String body,
    String? subtitle,
    NotificationPolicy policy,
  ) {
    if (!_fieldFits(title, policy.title)) return false;
    if (!_fieldFits(body, policy.body)) return false;
    if (subtitle != null && !_fieldFits(subtitle, policy.subtitle)) {
      return false;
    }
    if (policy.maxPayloadBytes != null) {
      final totalBytes =
          utf8ByteLength(title) +
          utf8ByteLength(body) +
          (subtitle != null ? utf8ByteLength(subtitle) : 0);
      // Estimate ~200 bytes of JSON overhead for keys, braces, etc.
      if (totalBytes + 200 > policy.maxPayloadBytes!) return false;
    }
    return true;
  }

  /// Check whether a single field fits its [FieldPolicy].
  static bool _fieldFits(String text, FieldPolicy fieldPolicy) {
    if (fieldPolicy.maxGraphemes != null &&
        graphemeLength(text) > fieldPolicy.maxGraphemes!) {
      return false;
    }
    if (fieldPolicy.maxBytes != null &&
        utf8ByteLength(text) > fieldPolicy.maxBytes!) {
      return false;
    }
    return true;
  }

  /// Attempt deterministic reduction on a single tier.
  ///
  /// Returns [NotificationParts] if reduction succeeded, `null` if even
  /// with maximum reduction this tier can't fit.
  static NotificationParts? _applyReduction({
    required NotificationTemplateTier tier,
    required Map<String, String> variables,
    required NotificationPolicy policy,
  }) {
    // Build a list of droppable variables sorted by priority (lowest first)
    final droppables = <String>[];
    for (final priority in ReductionPriority.values) {
      for (final entry in policy.variablePolicies.entries) {
        if (entry.value.priority == priority &&
            variables.containsKey(entry.key)) {
          droppables.add(entry.key);
        }
      }
    }

    // Progressively drop variables and re-resolve
    var currentVars = Map<String, String>.from(variables);

    for (final varName in droppables) {
      currentVars[varName] = '';

      final title = _resolveTemplate(tier.titleTemplate, currentVars);
      final body = _resolveTemplate(tier.bodyTemplate, currentVars);
      final subtitle = tier.subtitleTemplate != null
          ? _resolveTemplate(tier.subtitleTemplate!, currentVars)
          : null;

      // Check raw fit first
      if (_fitsPolicy(title, body, subtitle, policy)) {
        return NotificationParts(title: title, body: body, subtitle: subtitle);
      }

      // Try per-field truncation after this drop - preserves remaining
      // variable content instead of dropping more variables entirely.
      final truncTitle = _truncateField(title, policy.title);
      final truncBody = _truncateField(body, policy.body);
      final truncSubtitle = subtitle != null
          ? _truncateField(subtitle, policy.subtitle)
          : null;

      if (_fitsPolicy(truncTitle, truncBody, truncSubtitle, policy)) {
        return NotificationParts(
          title: truncTitle,
          body: truncBody,
          subtitle: truncSubtitle,
        );
      }
    }

    // All variables dropped - try per-field truncation as last resort
    final title = _truncateField(
      _resolveTemplate(tier.titleTemplate, currentVars),
      policy.title,
    );
    final body = _truncateField(
      _resolveTemplate(tier.bodyTemplate, currentVars),
      policy.body,
    );
    final subtitle = tier.subtitleTemplate != null
        ? _truncateField(
            _resolveTemplate(tier.subtitleTemplate!, currentVars),
            policy.subtitle,
          )
        : null;

    if (_fitsPolicy(title, body, subtitle, policy)) {
      return NotificationParts(title: title, body: body, subtitle: subtitle);
    }

    return null; // This tier can't be made to fit
  }

  /// Truncate a field's text to meet its [FieldPolicy].
  static String _truncateField(String text, FieldPolicy fieldPolicy) {
    var result = text;

    // Truncate by grapheme count first
    if (fieldPolicy.maxGraphemes != null) {
      result = safeTruncateAtWord(result, fieldPolicy.maxGraphemes!);
    }

    // Then by byte count (if applicable)
    if (fieldPolicy.maxBytes != null) {
      result = safeTruncateBytes(result, fieldPolicy.maxBytes!);
    }

    return result;
  }
}

/// The result of a render operation, including metadata for debugging.
class RenderResult {
  /// The final notification content ready to send.
  final NotificationParts parts;

  /// Which template tier was used, or `null` if the safe fallback was used.
  final TemplateTierLevel? tierUsed;

  /// Whether any reduction (variable dropping or field truncation) was applied.
  final bool reductionApplied;

  const RenderResult({
    required this.parts,
    required this.tierUsed,
    required this.reductionApplied,
  });

  /// True if no tier was usable and the hard-coded fallback was emitted.
  bool get usedFallback => tierUsed == null;

  @override
  String toString() =>
      'RenderResult(tier: $tierUsed, reduced: $reductionApplied, '
      'parts: $parts)'; // lint-allow: hardcoded-string
}
