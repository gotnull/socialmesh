// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// The MQTT root topic rules that the firmware and the broker impose.

import 'dart:convert';

/// The firmware's root buffer: 32 bytes including the terminator
/// (`MQTTConfig.root max_size:32` in the nanopb options).
const int kMqttRootTopicByteCap = 31;

/// The first rule a root topic breaks, in the order they are checked.
enum MqttRootTopicProblem {
  empty,
  whitespace,
  nonAscii,
  wildcard,
  leadingSlash,
  trailingSlash,
  emptySegment,
  endsWithVersion,
  tooLong,
}

/// Whitespace trimmed at both ends, runs of `/` collapsed to one, and one
/// trailing `/` dropped. Used only on the custom topic field before it is
/// validated; the form's own field is never rewritten.
String sanitizeMqttRootTopic(String text) {
  var result = text.trim();
  while (result.contains('//')) {
    result = result.replaceAll('//', '/');
  }
  if (result.endsWith('/')) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}

/// The first rule [root] breaks, or null when the radio accepts it as typed.
MqttRootTopicProblem? mqttRootTopicProblem(String root) {
  if (root.isEmpty) return MqttRootTopicProblem.empty;
  final units = root.runes;
  if (units.any((r) => r <= 0x20 || r == 0x7F)) {
    return MqttRootTopicProblem.whitespace;
  }
  if (units.any((r) => r > 0x7E)) return MqttRootTopicProblem.nonAscii;
  if (root.contains('+') || root.contains('#')) {
    return MqttRootTopicProblem.wildcard;
  }
  if (root.startsWith('/')) return MqttRootTopicProblem.leadingSlash;
  if (root.endsWith('/')) return MqttRootTopicProblem.trailingSlash;
  if (root.contains('//')) return MqttRootTopicProblem.emptySegment;
  if (root.split('/').last == '2') return MqttRootTopicProblem.endsWithVersion;
  if (utf8.encode(root).length > kMqttRootTopicByteCap) {
    return MqttRootTopicProblem.tooLong;
  }
  return null;
}

/// [root] split on `/`, each segment trimmed, empty segments dropped.
List<String> mqttTopicSegments(String root) =>
    root.split('/').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

/// Segment-wise, case-insensitive prefix: `msh/US/WA` is a prefix of
/// `msh/US/WA/seattle` but not of `msh/US/WAX`.
bool mqttRootHasPrefix(String root, String prefix) {
  final rootSegments = mqttTopicSegments(root);
  final prefixSegments = mqttTopicSegments(prefix);
  if (prefixSegments.length > rootSegments.length) return false;
  for (var i = 0; i < prefixSegments.length; i++) {
    if (rootSegments[i].toLowerCase() != prefixSegments[i].toLowerCase()) {
      return false;
    }
  }
  return true;
}

/// Case-insensitive equality of two roots.
bool mqttRootsMatch(String a, String b) => a.toLowerCase() == b.toLowerCase();
