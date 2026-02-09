// SPDX-License-Identifier: GPL-3.0-or-later

/// Topic builder utility for the Global Layer (MQTT) feature.
///
/// The [TopicBuilder] takes topic template patterns (e.g.
/// `{root}/chat/{channel}`) and resolves them into concrete MQTT
/// topic strings using values from the user's [GlobalLayerConfig].
///
/// It also validates topic strings against MQTT specification rules
/// and provides helpers for the Topic Builder UI in the setup wizard.
library;

import 'mqtt_constants.dart';

/// Result of a topic validation check.
class TopicValidationResult {
  /// Whether the topic is valid.
  final bool isValid;

  /// Human-readable error message if invalid, `null` if valid.
  final String? error;

  const TopicValidationResult.valid() : isValid = true, error = null;

  const TopicValidationResult.invalid(this.error) : isValid = false;

  @override
  String toString() => isValid ? 'Valid' : 'Invalid: $error';
}

/// A resolved topic with its template metadata preserved.
class ResolvedTopic {
  /// The original template pattern (e.g. `{root}/chat/{channel}`).
  final String pattern;

  /// The resolved topic string (e.g. `msh/chat/primary`).
  final String topic;

  /// Human-readable label for this topic (from the template).
  final String label;

  /// The placeholder values that were substituted.
  final Map<String, String> substitutions;

  const ResolvedTopic({
    required this.pattern,
    required this.topic,
    required this.label,
    required this.substitutions,
  });

  @override
  String toString() => 'ResolvedTopic($label: $topic)';
}

/// Builds and validates MQTT topic strings from templates and user config.
///
/// This class is stateless and operates purely on inputs. It does not
/// read from or write to any storage or provider.
class TopicBuilder {
  TopicBuilder._();

  // ---------------------------------------------------------------------------
  // Placeholder constants
  // ---------------------------------------------------------------------------

  /// Placeholder for the user-defined topic root.
  static const String rootPlaceholder = '{root}';

  /// Placeholder for a channel name.
  static const String channelPlaceholder = '{channel}';

  /// Placeholder for a node identifier.
  static const String nodeIdPlaceholder = '{nodeId}';

  /// All recognised placeholders.
  static const List<String> allPlaceholders = [
    rootPlaceholder,
    channelPlaceholder,
    nodeIdPlaceholder,
  ];

  // ---------------------------------------------------------------------------
  // Topic resolution
  // ---------------------------------------------------------------------------

  /// Resolves a single template pattern into a concrete topic string.
  ///
  /// [pattern] is the template (e.g. `{root}/chat/{channel}`).
  /// [values] maps placeholder names (without braces) to their values
  /// (e.g. `{'root': 'msh', 'channel': 'primary'}`).
  ///
  /// Any placeholder without a corresponding value in [values] is left
  /// as-is in the output, allowing partial resolution for preview.
  static String resolve(String pattern, Map<String, String> values) {
    var result = pattern;
    for (final entry in values.entries) {
      result = result.replaceAll('{${entry.key}}', entry.value);
    }
    return result;
  }

  /// Resolves a template pattern using standard config values.
  ///
  /// This is a convenience wrapper around [resolve] that maps
  /// commonly needed fields into the placeholder map.
  static String resolveWithConfig({
    required String pattern,
    required String topicRoot,
    String? channel,
    String? nodeId,
  }) {
    final values = <String, String>{
      'root': topicRoot.isNotEmpty
          ? topicRoot
          : GlobalLayerConstants.defaultTopicRoot,
    };
    if (channel != null && channel.isNotEmpty) {
      values['channel'] = channel;
    }
    if (nodeId != null && nodeId.isNotEmpty) {
      values['nodeId'] = nodeId;
    }
    return resolve(pattern, values);
  }

  /// Resolves a [TopicTemplate] into a [ResolvedTopic] with metadata.
  static ResolvedTopic resolveTemplate({
    required TopicTemplate template,
    required String topicRoot,
    String? channel,
    String? nodeId,
  }) {
    final values = <String, String>{
      'root': topicRoot.isNotEmpty
          ? topicRoot
          : GlobalLayerConstants.defaultTopicRoot,
    };
    if (channel != null && channel.isNotEmpty) {
      values['channel'] = channel;
    }
    if (nodeId != null && nodeId.isNotEmpty) {
      values['nodeId'] = nodeId;
    }

    return ResolvedTopic(
      pattern: template.pattern,
      topic: resolve(template.pattern, values),
      label: template.label,
      substitutions: values,
    );
  }

  /// Resolves all built-in templates with the given config values.
  ///
  /// Returns a list of [ResolvedTopic] instances, one per template.
  /// Templates that still contain unresolved placeholders are included
  /// but can be identified by checking for `{` in the topic string.
  static List<ResolvedTopic> resolveAllTemplates({
    required String topicRoot,
    String? channel,
    String? nodeId,
  }) {
    return TopicTemplate.builtIn
        .map(
          (t) => resolveTemplate(
            template: t,
            topicRoot: topicRoot,
            channel: channel,
            nodeId: nodeId,
          ),
        )
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // Topic validation
  // ---------------------------------------------------------------------------

  /// Validates an MQTT topic string according to the MQTT 3.1.1 spec.
  ///
  /// Rules enforced:
  /// - Must not be empty.
  /// - Must not exceed [GlobalLayerConstants.maxTopicLength] bytes in UTF-8.
  /// - Must not contain the null character (U+0000).
  /// - Wildcards (`+`, `#`) are only allowed in subscribe topics, not publish.
  /// - `#` must be the last character and preceded by `/` (or be the only char).
  /// - `+` must occupy an entire level (surrounded by `/` or at start/end).
  static TopicValidationResult validateTopic(
    String topic, {
    bool allowWildcards = false,
  }) {
    if (topic.isEmpty) {
      return const TopicValidationResult.invalid('Topic must not be empty.');
    }

    if (topic.contains('\u0000')) {
      return const TopicValidationResult.invalid(
        'Topic must not contain the null character.',
      );
    }

    // Check UTF-8 byte length
    final byteLength = topic.codeUnits.length;
    if (byteLength > GlobalLayerConstants.maxTopicLength) {
      return TopicValidationResult.invalid(
        'Topic exceeds maximum length of '
        '${GlobalLayerConstants.maxTopicLength} bytes '
        '(current: $byteLength).',
      );
    }

    // Wildcard checks
    if (!allowWildcards) {
      if (topic.contains(GlobalLayerConstants.singleLevelWildcard)) {
        return const TopicValidationResult.invalid(
          'Publish topics must not contain the "+" wildcard. '
          'Use a specific value instead.',
        );
      }
      if (topic.contains(GlobalLayerConstants.multiLevelWildcard)) {
        return const TopicValidationResult.invalid(
          'Publish topics must not contain the "#" wildcard. '
          'Use a specific value instead.',
        );
      }
    } else {
      // Validate wildcard placement for subscribe topics
      final multiWildcardResult = _validateMultiLevelWildcard(topic);
      if (!multiWildcardResult.isValid) return multiWildcardResult;

      final singleWildcardResult = _validateSingleLevelWildcard(topic);
      if (!singleWildcardResult.isValid) return singleWildcardResult;
    }

    return const TopicValidationResult.valid();
  }

  /// Validates a topic root (the user-configurable prefix).
  ///
  /// The root has additional constraints beyond normal topics:
  /// - No wildcards allowed.
  /// - No leading or trailing separators.
  /// - No consecutive separators.
  /// - Must not exceed [GlobalLayerConstants.maxTopicRootLength].
  static TopicValidationResult validateTopicRoot(String root) {
    if (root.isEmpty) {
      return const TopicValidationResult.invalid(
        'Topic root must not be empty.',
      );
    }

    if (root.length > GlobalLayerConstants.maxTopicRootLength) {
      return TopicValidationResult.invalid(
        'Topic root exceeds maximum length of '
        '${GlobalLayerConstants.maxTopicRootLength} characters.',
      );
    }

    if (root.contains(GlobalLayerConstants.singleLevelWildcard) ||
        root.contains(GlobalLayerConstants.multiLevelWildcard)) {
      return const TopicValidationResult.invalid(
        'Topic root must not contain wildcards.',
      );
    }

    if (root.contains('\u0000')) {
      return const TopicValidationResult.invalid(
        'Topic root must not contain the null character.',
      );
    }

    final sep = GlobalLayerConstants.topicSeparator;

    if (root.startsWith(sep)) {
      return const TopicValidationResult.invalid(
        'Topic root must not start with a separator.',
      );
    }

    if (root.endsWith(sep)) {
      return const TopicValidationResult.invalid(
        'Topic root must not end with a separator.',
      );
    }

    if (root.contains('$sep$sep')) {
      return const TopicValidationResult.invalid(
        'Topic root must not contain consecutive separators.',
      );
    }

    return const TopicValidationResult.valid();
  }

  // ---------------------------------------------------------------------------
  // Placeholder analysis
  // ---------------------------------------------------------------------------

  /// Returns the list of unresolved placeholders in a topic string.
  ///
  /// Useful for determining which additional inputs are needed from the
  /// user before a template can be fully resolved.
  static List<String> unresolvedPlaceholders(String topic) {
    final result = <String>[];
    for (final placeholder in allPlaceholders) {
      if (topic.contains(placeholder)) {
        result.add(placeholder);
      }
    }
    return result;
  }

  /// Whether a topic string is fully resolved (no remaining placeholders).
  static bool isFullyResolved(String topic) {
    return unresolvedPlaceholders(topic).isEmpty;
  }

  /// Returns a human-readable description of what a placeholder represents.
  static String placeholderDescription(String placeholder) {
    return switch (placeholder) {
      rootPlaceholder => 'Your topic root prefix (e.g. "msh")',
      channelPlaceholder => 'The mesh channel name (e.g. "LongFast")',
      nodeIdPlaceholder => 'The node identifier (e.g. "!a1b2c3d4")',
      _ => 'Unknown placeholder',
    };
  }

  // ---------------------------------------------------------------------------
  // Test topics
  // ---------------------------------------------------------------------------

  /// Generates a safe test topic for connection verification.
  ///
  /// The test topic uses the user's root but appends a dedicated
  /// `$test` suffix to avoid polluting real topic channels.
  static String buildTestTopic(String topicRoot) {
    final root = topicRoot.isNotEmpty
        ? topicRoot
        : GlobalLayerConstants.defaultTopicRoot;
    return '$root${GlobalLayerConstants.testTopicSuffix}';
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Validates multi-level wildcard (#) placement.
  static TopicValidationResult _validateMultiLevelWildcard(String topic) {
    final hashIndex = topic.indexOf(GlobalLayerConstants.multiLevelWildcard);
    if (hashIndex == -1) return const TopicValidationResult.valid();

    // # must be the last character
    if (hashIndex != topic.length - 1) {
      return const TopicValidationResult.invalid(
        'The "#" wildcard must be the last character in the topic.',
      );
    }

    // # must be preceded by / or be the only character
    if (topic.length > 1 &&
        topic[hashIndex - 1] != GlobalLayerConstants.topicSeparator[0]) {
      return const TopicValidationResult.invalid(
        'The "#" wildcard must be preceded by "/" or be the only character.',
      );
    }

    // Only one # is allowed
    if (topic.indexOf(GlobalLayerConstants.multiLevelWildcard) !=
        topic.lastIndexOf(GlobalLayerConstants.multiLevelWildcard)) {
      return const TopicValidationResult.invalid(
        'Only one "#" wildcard is allowed per topic.',
      );
    }

    return const TopicValidationResult.valid();
  }

  /// Validates single-level wildcard (+) placement.
  static TopicValidationResult _validateSingleLevelWildcard(String topic) {
    final sep = GlobalLayerConstants.topicSeparator;
    final levels = topic.split(sep);

    for (var i = 0; i < levels.length; i++) {
      final level = levels[i];
      if (level.contains(GlobalLayerConstants.singleLevelWildcard) &&
          level != GlobalLayerConstants.singleLevelWildcard) {
        return TopicValidationResult.invalid(
          'The "+" wildcard must occupy an entire topic level. '
          'Found "$level" at level ${i + 1}.',
        );
      }
    }

    return const TopicValidationResult.valid();
  }
}
