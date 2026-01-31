// SPDX-License-Identifier: GPL-3.0-or-later
import '../models/presence_confidence.dart';

const String kPresenceInferenceTooltip =
    'LoRa mesh has no offline signal. Status is inferred.';

String formatSeenAgo(Duration? age) {
  if (age == null) return 'unknown';
  if (age.inSeconds < 30) return 'just now';
  if (age.inMinutes < 1) return '${age.inSeconds}s';
  if (age.inMinutes < 60) return '${age.inMinutes}m';
  if (age.inHours < 24) return '${age.inHours}h';
  return '${age.inDays}d';
}

String presenceStatusText(PresenceConfidence confidence, Duration? age) {
  switch (confidence) {
    case PresenceConfidence.active:
      return 'Active';
    case PresenceConfidence.fading:
      return 'Seen ${formatSeenAgo(age)} ago';
    case PresenceConfidence.stale:
      return 'Inactive';
    case PresenceConfidence.unknown:
      return 'Unknown';
  }
}

double presenceOpacity(PresenceConfidence confidence) {
  switch (confidence) {
    case PresenceConfidence.active:
      return 1.0;
    case PresenceConfidence.fading:
      return 0.75;
    case PresenceConfidence.stale:
      return 0.55;
    case PresenceConfidence.unknown:
      return 0.4;
  }
}
