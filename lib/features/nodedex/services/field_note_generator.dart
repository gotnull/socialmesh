// SPDX-License-Identifier: GPL-3.0-or-later

// Field Note Generator — deterministic single-line observations.
//
// Generates a short, evocative field-journal-style note for a node
// based on its identity seed (nodeNum), primary trait, and history.
// The note is fully deterministic: the same inputs always produce
// the same note. No randomness, no network, no side effects.
//
// Notes read like entries in a naturalist's field journal:
//   "First logged at dusk. Signal steady, bearing north."
//   "Intermittent presence. Appears without pattern."
//   "Fixed installation. Consistent signal for 14 days."
//
// The generator uses the node number hash to select from template
// families, then fills in concrete values from the entry data.
// This ensures visual variety across nodes while maintaining
// determinism within each node's identity.

import '../models/nodedex_entry.dart';
import 'sigil_generator.dart';

/// Deterministic field note generator for NodeDex entries.
///
/// All methods are static, pure, and side-effect-free.
/// The same inputs always produce the same output.
class FieldNoteGenerator {
  FieldNoteGenerator._();

  // ---------------------------------------------------------------------------
  // Template families — grouped by trait
  // ---------------------------------------------------------------------------

  static const List<String> _wandererTemplates = [
    'Recorded across {regions} regions. No fixed bearing.',
    'Passes through without settling. {positions} positions logged.',
    'Transient signal. Observed moving through {regions} zones.',
    'Migratory pattern suspected. Range up to {distance}.',
    'Appears at different coordinates each session.',
    'No anchor point detected. Drift confirmed across {regions} regions.',
    'Logged at {positions} positions. Path unclear.',
    'Signal origin shifts between sessions.',
  ];

  static const List<String> _beaconTemplates = [
    'Steady signal. {rate} sightings per day.',
    'Persistent presence on the mesh. Always broadcasting.',
    'Reliable and consistent. Last heard {lastSeen}.',
    'High availability. {encounters} encounters recorded.',
    'Continuous operation confirmed. Signal rarely drops.',
    'Always-on presence. Dependable reference point.',
    'Broadcasting consistently. {rate} daily observations.',
    'Fixed rhythm. Predictable timing across sessions.',
  ];

  static const List<String> _ghostTemplates = [
    'Rarely observed. Last confirmed sighting {lastSeen}.',
    'Elusive. {encounters} encounters over {age} days.',
    'Signal appears briefly then vanishes. Pattern unknown.',
    'Intermittent trace only. Insufficient data for profile.',
    'Faint and sporadic. Presence cannot be relied upon.',
    'Appears without warning. Disappears without trace.',
    'Low encounter density. Behavior difficult to classify.',
    'Detected at the margins. Observation window narrow.',
  ];

  static const List<String> _sentinelTemplates = [
    'Fixed position. Monitoring for {age} days.',
    'Stationary installation. Signal consistent and strong.',
    'Guardian presence. {encounters} observations from one location.',
    'Long-lived post. First observed {firstSeen}.',
    'No position variance. Infrastructure signature confirmed.',
    'Holding position. Reliable since first contact.',
    'Static deployment. Best signal {snr} dB SNR.',
    'Permanent fixture. Observed continuously for {age} days.',
  ];

  static const List<String> _relayTemplates = [
    'Forwarding traffic. Router role confirmed.',
    'Active relay node. Channel utilization elevated.',
    'Infrastructure role: traffic forwarding observed.',
    'Router signature detected. High airtime usage.',
    'Mesh backbone element. Facilitates connectivity.',
    'Relay behavior consistent across {encounters} sessions.',
    'Traffic handler. Forwarding pattern stable.',
    'Network infrastructure. Routing confirmed by role.',
  ];

  static const List<String> _courierTemplates = [
    'High message volume. {messages} messages across {encounters} encounters.',
    'Data carrier. Message-to-encounter ratio elevated.',
    'Active in message exchange. Courier behavior likely.',
    'Carries data between mesh segments. {messages} messages logged.',
    'Message density suggests deliberate data transport.',
    'Communication-heavy node. {messages} exchanges recorded.',
    'Frequent messenger. Moves data across the network.',
    'Delivery pattern observed. Messages outpace encounters.',
  ];

  static const List<String> _anchorTemplates = [
    'Hub node. Co-seen with {coSeen} other nodes.',
    'Social center of local mesh. Many connections.',
    'Persistent hub. {coSeen} nodes observed in proximity.',
    'Anchor point for nearby nodes. Fixed and well-connected.',
    'Central to local topology. High co-seen density.',
    'Gravitational center. Other nodes cluster around this one.',
    'Infrastructure anchor. {coSeen} peers linked.',
    'Mesh nexus. Stable presence with broad connectivity.',
  ];

  static const List<String> _drifterTemplates = [
    'Timing unpredictable. Appears and fades without pattern.',
    'Irregular intervals between sightings.',
    'No consistent schedule. Drift behavior confirmed.',
    'Appears sporadically but not rarely. Timing erratic.',
    'Signal comes and goes. No rhythm detected.',
    'Present but unreliable. Intervals vary widely.',
    'Observation timing scattered. No periodicity found.',
    'Intermittent but active. Schedule defies prediction.',
  ];

  static const List<String> _unknownTemplates = [
    'Recently discovered. Observation in progress.',
    'New contact. Insufficient data for classification.',
    'First logged {firstSeen}. Awaiting further signals.',
    'Identity recorded. Behavioral profile pending.',
    'Initial entry. More encounters needed for assessment.',
    'Cataloged. No behavioral pattern yet established.',
    'Signal acknowledged. Classification deferred.',
    'Entry created. Monitoring initiated.',
  ];

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Generate a deterministic field note for a node.
  ///
  /// The note is a single line of text suitable for display in the
  /// NodeDex detail header. It reads like a field journal observation.
  ///
  /// [entry] — the NodeDex entry with encounter history.
  /// [trait] — the primary inferred trait for template selection.
  ///
  /// Returns a non-empty string. Always deterministic.
  static String generate({
    required NodeDexEntry entry,
    required NodeTrait trait,
  }) {
    final templates = _templatesForTrait(trait);

    // Use the sigil hash to deterministically pick a template index.
    // This ensures the same node always gets the same template.
    final hash = SigilGenerator.mix(entry.nodeNum);
    final templateIndex = _extractBits(hash, 0, 16) % templates.length;
    final template = templates[templateIndex];

    return _fillTemplate(template, entry);
  }

  // ---------------------------------------------------------------------------
  // Template selection
  // ---------------------------------------------------------------------------

  static List<String> _templatesForTrait(NodeTrait trait) {
    return switch (trait) {
      NodeTrait.wanderer => _wandererTemplates,
      NodeTrait.beacon => _beaconTemplates,
      NodeTrait.ghost => _ghostTemplates,
      NodeTrait.sentinel => _sentinelTemplates,
      NodeTrait.relay => _relayTemplates,
      NodeTrait.courier => _courierTemplates,
      NodeTrait.anchor => _anchorTemplates,
      NodeTrait.drifter => _drifterTemplates,
      NodeTrait.unknown => _unknownTemplates,
    };
  }

  // ---------------------------------------------------------------------------
  // Template interpolation
  // ---------------------------------------------------------------------------

  static String _fillTemplate(String template, NodeDexEntry entry) {
    var result = template;

    if (result.contains('{regions}')) {
      result = result.replaceAll('{regions}', entry.regionCount.toString());
    }

    if (result.contains('{positions}')) {
      result = result.replaceAll(
        '{positions}',
        entry.distinctPositionCount.toString(),
      );
    }

    if (result.contains('{encounters}')) {
      result = result.replaceAll(
        '{encounters}',
        entry.encounterCount.toString(),
      );
    }

    if (result.contains('{messages}')) {
      result = result.replaceAll('{messages}', entry.messageCount.toString());
    }

    if (result.contains('{coSeen}')) {
      result = result.replaceAll('{coSeen}', entry.coSeenCount.toString());
    }

    if (result.contains('{age}')) {
      final days = entry.age.inDays;
      result = result.replaceAll('{age}', days.toString());
    }

    if (result.contains('{distance}')) {
      result = result.replaceAll(
        '{distance}',
        _formatDistance(entry.maxDistanceSeen),
      );
    }

    if (result.contains('{rate}')) {
      final ageDays = entry.age.inHours / 24.0;
      final rate = ageDays > 0.01
          ? (entry.encounterCount / ageDays).toStringAsFixed(1)
          : entry.encounterCount.toString();
      result = result.replaceAll('{rate}', rate);
    }

    if (result.contains('{lastSeen}')) {
      result = result.replaceAll(
        '{lastSeen}',
        _formatRelativeTime(entry.timeSinceLastSeen),
      );
    }

    if (result.contains('{firstSeen}')) {
      result = result.replaceAll('{firstSeen}', _formatDate(entry.firstSeen));
    }

    if (result.contains('{snr}')) {
      result = result.replaceAll('{snr}', entry.bestSnr?.toString() ?? '?');
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers
  // ---------------------------------------------------------------------------

  static String _formatDistance(double? meters) {
    if (meters == null) return 'unknown range';
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)}km';
    }
    return '${meters.round()}m';
  }

  static String _formatRelativeTime(Duration duration) {
    if (duration.inMinutes < 1) return 'moments ago';
    if (duration.inMinutes < 60) return '${duration.inMinutes}m ago';
    if (duration.inHours < 24) return '${duration.inHours}h ago';
    if (duration.inDays == 1) return 'yesterday';
    if (duration.inDays < 30) return '${duration.inDays}d ago';
    final months = duration.inDays ~/ 30;
    if (months == 1) return '1 month ago';
    return '$months months ago';
  }

  static String _formatDate(DateTime date) {
    // Produce a compact date like "12 Mar" or "5 Jan 2024"
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final now = DateTime.now();
    final month = months[date.month - 1];
    if (date.year == now.year) {
      return '${date.day} $month';
    }
    return '${date.day} $month ${date.year}';
  }

  // ---------------------------------------------------------------------------
  // Hash utilities (mirrors SigilGenerator for consistency)
  // ---------------------------------------------------------------------------

  static int _extractBits(int hash, int offset, int count) {
    return (hash >> offset) & ((1 << count) - 1);
  }
}
