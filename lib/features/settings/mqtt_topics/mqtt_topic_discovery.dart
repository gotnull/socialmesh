// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Broker topic strings and map-report payloads turned into per-root
// activity, plus the region/state/city ladder of suggested roots.

import 'dart:convert';
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

import '../../../core/safe_lat_lng.dart';
import '../../../core/units/geo_distance.dart';
import '../../../generated/meshtastic/mqtt.pb.dart' as mqtt_pb;
import '../../../generated/meshtastic/portnums.pbenum.dart';
import 'mqtt_root_topic.dart';

/// What a broker topic carries.
sealed class MqttTopicKind {
  const MqttTopicKind();
}

/// `<root>/2/e/<channel>/!<hex>`: a packet a gateway uplinked.
class MqttPacketTopic extends MqttTopicKind {
  final String channel;
  final String gateway;
  const MqttPacketTopic({required this.channel, required this.gateway});
}

/// `<root>/2/map/`: a map report.
class MqttMapReportTopic extends MqttTopicKind {
  const MqttMapReportTopic();
}

/// One parsed broker topic.
class MqttTopicObservation {
  final String root;
  final MqttTopicKind kind;
  const MqttTopicObservation(this.root, this.kind);
}

final RegExp _topicPattern = RegExp(
  r'^(msh(?:/[^/]+)+)/2/(?:e/([^/]+)/(![0-9a-f]+)|map/)$',
);

/// Whole string trimmed, split on `/`, each segment trimmed, empty segments
/// dropped, rejoined, and the trailing `/` that map topics carry put back.
/// A root with a trailing slash or space cannot be saved, so its traffic is
/// credited to the spelling that can. Repeated segments stay as they are:
/// `msh/US/US/FL` is a real root with its own traffic.
String normalizeMqttTopic(String topic) {
  final trimmed = topic.trim();
  final joined = mqttTopicSegments(trimmed).join('/');
  return trimmed.endsWith('/') ? '$joined/' : joined;
}

/// The root and kind of [topic], or null for anything that is not a `2/e`
/// or `2/map` topic (uppercase hex, `/1/c/`, `/2/json/`, foreign roots).
MqttTopicObservation? parseMqttTopic(String topic) {
  final match = _topicPattern.firstMatch(normalizeMqttTopic(topic));
  if (match == null) return null;
  final root = match.group(1)!;
  final channel = match.group(2);
  final gateway = match.group(3);
  if (channel != null && gateway != null) {
    return MqttTopicObservation(
      root,
      MqttPacketTopic(channel: channel, gateway: gateway),
    );
  }
  return MqttTopicObservation(root, const MqttMapReportTopic());
}

/// `!%08x` of a node number, the spelling the topic suffix uses.
String mqttNodeId(int nodeNum) =>
    '!${(nodeNum & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0')}';

/// The parts of a plaintext map report the finder uses.
class MqttMapReportSummary {
  /// The envelope's gateway id, or the sender's node id when it is empty.
  final String reporter;

  /// Null when the report carries no position.
  final LatLng? position;
  final int onlineLocalNodes;

  const MqttMapReportSummary({
    required this.reporter,
    required this.position,
    required this.onlineLocalNodes,
  });
}

/// The map report in [envelope], or null for encrypted packets, other
/// portnums and parse errors.
MqttMapReportSummary? mqttMapReport(mqtt_pb.ServiceEnvelope envelope) {
  if (!envelope.hasPacket() || !envelope.packet.hasDecoded()) return null;
  final data = envelope.packet.decoded;
  if (data.portnum != PortNum.MAP_REPORT_APP) return null;
  final mqtt_pb.MapReport report;
  try {
    report = mqtt_pb.MapReport.fromBuffer(data.payload);
  } on Exception {
    return null;
  }
  final reporter = envelope.gatewayId.isEmpty
      ? mqttNodeId(envelope.packet.from)
      : envelope.gatewayId;
  final hasPosition = !(report.latitudeI == 0 && report.longitudeI == 0);
  return MqttMapReportSummary(
    reporter: reporter,
    position: hasPosition
        ? safeLatLng(report.latitudeI / 1e7, report.longitudeI / 1e7)
        : null,
    onlineLocalNodes: report.numOnlineLocalNodes,
  );
}

/// The level a suggested root sits at.
enum MqttLadderLevel { region, state, city }

/// One suggested root: the region, the state and the city around the user.
class MqttLadderRung {
  final MqttLadderLevel level;

  /// For example `msh/ANZ/VIC`.
  final String topic;

  /// The region's name, or the place name the geocoder gave.
  final String placeName;

  const MqttLadderRung({
    required this.level,
    required this.topic,
    required this.placeName,
  });
}

/// The region rung, then the state rung when [state] yields a segment, then
/// the city rung when the state rung exists and [city] yields one. Each rung
/// is trimmed from the end of its last segment until it fits the byte cap; a
/// rung whose last segment empties is dropped with anything below it.
List<MqttLadderRung> mqttTopicLadder({
  required String regionTopic,
  required String regionName,
  String? state,
  String? city,
}) {
  final rungs = [
    MqttLadderRung(
      level: MqttLadderLevel.region,
      topic: regionTopic,
      placeName: regionName,
    ),
  ];
  final stateSegment = state == null
      ? null
      : mqttTopicSegmentFromPlace(state, lowercase: false);
  final stateTopic = stateSegment == null
      ? null
      : _fitted(regionTopic, stateSegment);
  if (stateTopic == null) return rungs;
  rungs.add(
    MqttLadderRung(
      level: MqttLadderLevel.state,
      topic: stateTopic,
      placeName: state!,
    ),
  );
  final citySegment = city == null
      ? null
      : mqttTopicSegmentFromPlace(city, lowercase: true);
  final cityTopic = citySegment == null
      ? null
      : _fitted(stateTopic, citySegment);
  if (cityTopic == null) return rungs;
  rungs.add(
    MqttLadderRung(
      level: MqttLadderLevel.city,
      topic: cityTopic,
      placeName: city!,
    ),
  );
  return rungs;
}

String? _fitted(String base, String lastSegment) {
  var segment = lastSegment;
  while (segment.isNotEmpty &&
      utf8.encode('$base/$segment').length > kMqttRootTopicByteCap) {
    segment = segment.substring(0, segment.length - 1);
  }
  return segment.isEmpty ? null : '$base/$segment';
}

// Latin letters with diacritics folded to ASCII. Anything outside this
// table and outside [A-Za-z0-9_-] is dropped, so a name in a non-Latin
// script gets no rung rather than a romanisation the local mesh would not
// use.
const Map<String, String> _latinFold = {
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ā': 'a',
  'ă': 'a',
  'ą': 'a',
  'À': 'A',
  'Á': 'A',
  'Â': 'A',
  'Ã': 'A',
  'Ä': 'A',
  'Å': 'A',
  'Ā': 'A',
  'Ă': 'A',
  'Ą': 'A',
  'æ': 'ae',
  'Æ': 'AE',
  'ç': 'c',
  'ć': 'c',
  'ĉ': 'c',
  'ċ': 'c',
  'č': 'c',
  'Ç': 'C',
  'Ć': 'C',
  'Ĉ': 'C',
  'Ċ': 'C',
  'Č': 'C',
  'ď': 'd',
  'đ': 'd',
  'ð': 'd',
  'Ď': 'D',
  'Đ': 'D',
  'Ð': 'D',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ĕ': 'e',
  'ė': 'e',
  'ę': 'e',
  'ě': 'e',
  'È': 'E',
  'É': 'E',
  'Ê': 'E',
  'Ë': 'E',
  'Ē': 'E',
  'Ĕ': 'E',
  'Ė': 'E',
  'Ę': 'E',
  'Ě': 'E',
  'ĝ': 'g',
  'ğ': 'g',
  'ġ': 'g',
  'ģ': 'g',
  'Ĝ': 'G',
  'Ğ': 'G',
  'Ġ': 'G',
  'Ģ': 'G',
  'ĥ': 'h',
  'ħ': 'h',
  'Ĥ': 'H',
  'Ħ': 'H',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ĩ': 'i',
  'ī': 'i',
  'ĭ': 'i',
  'į': 'i',
  'ı': 'i',
  'Ì': 'I',
  'Í': 'I',
  'Î': 'I',
  'Ï': 'I',
  'Ĩ': 'I',
  'Ī': 'I',
  'Ĭ': 'I',
  'Į': 'I',
  'İ': 'I',
  'ĵ': 'j',
  'Ĵ': 'J',
  'ķ': 'k',
  'Ķ': 'K',
  'ĺ': 'l',
  'ļ': 'l',
  'ľ': 'l',
  'ŀ': 'l',
  'ł': 'l',
  'Ĺ': 'L',
  'Ļ': 'L',
  'Ľ': 'L',
  'Ŀ': 'L',
  'Ł': 'L',
  'ñ': 'n',
  'ń': 'n',
  'ņ': 'n',
  'ň': 'n',
  'Ñ': 'N',
  'Ń': 'N',
  'Ņ': 'N',
  'Ň': 'N',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'ō': 'o',
  'ŏ': 'o',
  'ő': 'o',
  'Ò': 'O',
  'Ó': 'O',
  'Ô': 'O',
  'Õ': 'O',
  'Ö': 'O',
  'Ø': 'O',
  'Ō': 'O',
  'Ŏ': 'O',
  'Ő': 'O',
  'œ': 'oe',
  'Œ': 'OE',
  'ŕ': 'r',
  'ŗ': 'r',
  'ř': 'r',
  'Ŕ': 'R',
  'Ŗ': 'R',
  'Ř': 'R',
  'ś': 's',
  'ŝ': 's',
  'ş': 's',
  'š': 's',
  'ș': 's',
  'Ś': 'S',
  'Ŝ': 'S',
  'Ş': 'S',
  'Š': 'S',
  'Ș': 'S',
  'ß': 'ss',
  'ţ': 't',
  'ť': 't',
  'ŧ': 't',
  'ț': 't',
  'Ţ': 'T',
  'Ť': 'T',
  'Ŧ': 'T',
  'Ț': 'T',
  'þ': 'th',
  'Þ': 'TH',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ũ': 'u',
  'ū': 'u',
  'ŭ': 'u',
  'ů': 'u',
  'ű': 'u',
  'ų': 'u',
  'Ù': 'U',
  'Ú': 'U',
  'Û': 'U',
  'Ü': 'U',
  'Ũ': 'U',
  'Ū': 'U',
  'Ŭ': 'U',
  'Ů': 'U',
  'Ű': 'U',
  'Ų': 'U',
  'ŵ': 'w',
  'Ŵ': 'W',
  'ý': 'y',
  'ÿ': 'y',
  'ŷ': 'y',
  'Ý': 'Y',
  'Ÿ': 'Y',
  'Ŷ': 'Y',
  'ź': 'z',
  'ż': 'z',
  'ž': 'z',
  'Ź': 'Z',
  'Ż': 'Z',
  'Ž': 'Z',
};

final RegExp _segmentAllowed = RegExp(r'[A-Za-z0-9_-]');

/// A topic segment from a place name: Latin diacritics folded to ASCII,
/// then only `[A-Za-z0-9_-]` kept, lowercased when asked. States keep the
/// geocoder's case (`VIC`); cities follow the community's lowercase
/// convention. Null when nothing is left.
/// `St. John's` -> `stjohns`, `München` -> `munchen`, `東京都` -> null.
String? mqttTopicSegmentFromPlace(String place, {required bool lowercase}) {
  final buffer = StringBuffer();
  for (final rune in place.runes) {
    final char = String.fromCharCode(rune);
    final folded = _latinFold[char] ?? char;
    for (final c in folded.split('')) {
      if (_segmentAllowed.hasMatch(c)) buffer.write(c);
    }
  }
  final result = buffer.toString();
  if (result.isEmpty) return null;
  return lowercase ? result.toLowerCase() : result;
}

/// Everything heard on one root during a sample.
class MqttRootActivity {
  static const int maxNodes = 256;
  static const int maxPositions = 32;
  static const int maxChannels = 32;

  int packets = 0;
  int mapReports = 0;

  /// Sender ids plus gateway ids, capped.
  final Set<String> nodes = {};

  /// Channel names from the topic, capped; a row shows the first three.
  final Set<String> channels = {};

  /// Map-reported positions by reporter, last report wins, capped.
  final Map<String, LatLng> positions = {};

  /// The largest online-local-node count any map report gave.
  int onlineLocalNodes = 0;

  /// The region stream was unsubscribed at its cap, so counts are a floor.
  bool truncated = false;

  int get nodeCount => nodes.length;
  int get messageCount => packets + mapReports;

  /// Metres to the closest map-reported position, or null.
  double? nearestDistance(LatLng? from) {
    if (from == null || positions.isEmpty) return null;
    double? best;
    for (final p in positions.values) {
      final d = distanceMetersBetween(from, p);
      if (best == null || d < best) best = d;
    }
    return best;
  }

  void recordKind(MqttTopicKind kind, {String? sender}) {
    switch (kind) {
      case MqttPacketTopic(:final channel, :final gateway):
        packets++;
        if (channels.contains(channel) || channels.length < maxChannels) {
          channels.add(channel);
        }
        _addNode(gateway);
        if (sender != null) _addNode(sender);
      case MqttMapReportTopic():
        mapReports++;
    }
  }

  void recordReport(MqttMapReportSummary report) {
    _addNode(report.reporter);
    final position = report.position;
    if (position != null &&
        (positions.containsKey(report.reporter) ||
            positions.length < maxPositions)) {
      positions[report.reporter] = position;
    }
    if (report.onlineLocalNodes > onlineLocalNodes) {
      onlineLocalNodes = report.onlineLocalNodes;
    }
  }

  void _addNode(String id) {
    if (nodes.contains(id) || nodes.length < maxNodes) nodes.add(id);
  }
}

/// A bounded per-root tally. A new root past [maxRoots] is dropped and
/// counted in [droppedRoots].
class MqttTopicTally {
  static const int maxRoots = 400;

  /// An envelope is well under this; anything bigger is not one.
  static const int maxEnvelopeBytes = 1024;

  final Map<String, MqttRootActivity> activity = {};
  int droppedRoots = 0;

  /// Parses [topic] (junk returns null), credits its root, reads the
  /// plaintext sender from the envelope when it parses, and decodes a map
  /// report on map topics. Returns the observation so the sampler can apply
  /// its region cap.
  MqttTopicObservation? record(String topic, Uint8List payload) {
    final observation = parseMqttTopic(topic);
    if (observation == null) return null;
    final root = observation.root;
    if (!activity.containsKey(root) && activity.length >= maxRoots) {
      droppedRoots++;
      return observation;
    }
    mqtt_pb.ServiceEnvelope? envelope;
    if (payload.length <= maxEnvelopeBytes) {
      try {
        envelope = mqtt_pb.ServiceEnvelope.fromBuffer(payload);
      } on Exception {
        envelope = null;
      }
    }
    String? sender;
    if (envelope != null && envelope.hasPacket() && envelope.packet.from != 0) {
      sender = mqttNodeId(envelope.packet.from);
    }
    final entry = activity.putIfAbsent(root, MqttRootActivity.new);
    entry.recordKind(observation.kind, sender: sender);
    if (observation.kind is MqttMapReportTopic && envelope != null) {
      final report = mqttMapReport(envelope);
      if (report != null) entry.recordReport(report);
    }
    return observation;
  }

  void markTruncated(String root) {
    activity.putIfAbsent(root, MqttRootActivity.new).truncated = true;
  }
}

/// A discovered root ranked for the "Active topics" list.
class MqttRankedRoot {
  final String root;
  final MqttRootActivity activity;

  /// How many ladder rungs are a prefix of [root].
  final int ladderDepth;

  /// Metres to its closest map-reported node, or null.
  final double? distance;

  const MqttRankedRoot({
    required this.root,
    required this.activity,
    required this.ladderDepth,
    required this.distance,
  });
}

/// The activity recorded for [rung], with the spelling the broker used, so
/// the row shows and fills the live topic. The rung's own spelling wins when
/// the broker carries it; otherwise the lowest case-insensitive match, so the
/// row does not flip between variants from one snapshot to the next.
({String topic, MqttRootActivity activity})? mqttActivityForRung(
  MqttLadderRung rung,
  Map<String, MqttRootActivity> activity,
) {
  final exact = activity[rung.topic];
  if (exact != null) return (topic: rung.topic, activity: exact);
  final matches =
      activity.keys.where((k) => mqttRootsMatch(k, rung.topic)).toList()
        ..sort();
  if (matches.isEmpty) return null;
  return (topic: matches.first, activity: activity[matches.first]!);
}

/// Discovered roots not shown on a rung, ranked: more ladder rungs as a
/// prefix first, then roots with a map-reported position by distance, then
/// node count, message count and name. Only the spelling a rung shows is
/// left out; another case variant of the same root is a separate topic on
/// the broker and keeps its own row.
List<MqttRankedRoot> rankMqttRoots(
  Map<String, MqttRootActivity> activity, {
  required List<MqttLadderRung> ladder,
  LatLng? from,
}) {
  final shown = {
    for (final rung in ladder) ?mqttActivityForRung(rung, activity)?.topic,
  };
  final roots = <MqttRankedRoot>[
    for (final MapEntry(key: root, value: entry) in activity.entries)
      if (!shown.contains(root) && mqttRootTopicProblem(root) == null)
        MqttRankedRoot(
          root: root,
          activity: entry,
          ladderDepth: ladder
              .where((rung) => mqttRootHasPrefix(root, rung.topic))
              .length,
          distance: entry.nearestDistance(from),
        ),
  ];
  roots.sort(_compareRanked);
  return roots;
}

int _compareRanked(MqttRankedRoot a, MqttRankedRoot b) {
  if (a.ladderDepth != b.ladderDepth) {
    return b.ladderDepth.compareTo(a.ladderDepth);
  }
  final da = a.distance;
  final db = b.distance;
  if (da != null && db != null && da != db) return da.compareTo(db);
  if (da != null && db == null) return -1;
  if (da == null && db != null) return 1;
  if (a.activity.nodeCount != b.activity.nodeCount) {
    return b.activity.nodeCount.compareTo(a.activity.nodeCount);
  }
  if (a.activity.messageCount != b.activity.messageCount) {
    return b.activity.messageCount.compareTo(a.activity.messageCount);
  }
  return a.root.toLowerCase().compareTo(b.root.toLowerCase());
}
