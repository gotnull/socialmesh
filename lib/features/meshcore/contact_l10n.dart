// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import '../../l10n/app_localizations.dart';
import '../../models/meshcore_contact.dart';

/// Localized display labels for [MeshCoreContact].
///
/// The model's static [MeshCoreAdvType.label] returns ASCII strings on
/// purpose — it's used by `toString()`, search filtering, and debug
/// surfaces that must not depend on a live `BuildContext`. Use this
/// extension whenever the label is rendered to the user.
extension MeshCoreContactL10n on MeshCoreContact {
  String localizedTypeLabel(AppLocalizations l10n) {
    switch (type) {
      case MeshCoreAdvType.chat:
        return l10n.meshcoreChatNode;
      case MeshCoreAdvType.repeater:
        return l10n.meshcoreRepeaterNode;
      case MeshCoreAdvType.room:
        return l10n.meshcoreRoomNode;
      case MeshCoreAdvType.sensor:
        return l10n.meshcoreSensorNode;
      default:
        return l10n.meshcoreUnknown;
    }
  }

  /// Localized routing path summary.
  ///
  /// Mirrors the structure of [MeshCoreContact.pathLabel] but resolves the
  /// human-readable copy through ARB so non-English locales render correctly.
  /// The model's [pathLabel] returns ASCII on purpose (used by `toString()`
  /// and any non-display caller) — keep both in sync at the structural level.
  String localizedPathLabel(AppLocalizations l10n) {
    final override = pathOverride;
    if (override != null) {
      if (override < 0) return l10n.meshcorePathFloodForced;
      if (override == 0) return l10n.meshcorePathDirectForced;
      return l10n.meshcorePathHopsForced(override);
    }
    if (pathLength < 0) return l10n.meshcorePathFlood;
    if (pathLength == 0) return l10n.meshcorePathDirect;
    return l10n.meshcorePathHops(pathLength);
  }
}
