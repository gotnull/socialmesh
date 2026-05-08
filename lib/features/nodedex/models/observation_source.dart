// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// Observation Source — how a NodeDex observation reached the local radio.
//
// Stamped at ingest from MeshPacket / MeshNode metadata (via_mqtt + hops).
// Persisted on the canonical NodeDex entry as the latest observation's
// classification. Encounter-level history of this value is intentionally
// not persisted yet — see the v12 migration in nodedex_database.dart.

import 'package:socialmesh/l10n/app_localizations.dart';

/// Classification of how the latest observation of a node reached this device.
///
/// Values must round-trip cleanly through SQLite via [toStorageString] /
/// [fromStorageString]. New values must be appended; never reuse a string.
enum ObservationSource {
  /// Heard over LoRa RF, hops = 0, via_mqtt = false.
  directRf,

  /// Passed through an MQTT gateway at some point on its path.
  mqtt,

  /// Heard over LoRa RF but relayed (hops > 0). via_mqtt = false.
  indirectRf,

  /// Came from the device's NodeDB sync at reconnect, not a fresh
  /// live observation. Reserved — currently the live-encounter ingest
  /// path is the only writer, so this value is a placeholder for a
  /// future deviceDbSync stamping pass.
  nodeDb,

  /// via_mqtt was not present (legacy firmware) or other case where
  /// the path could not be classified. Honest fallback — never used
  /// to mean "we guessed RF".
  unknown;

  /// Stable string for SQLite persistence. Stable across schema versions.
  String get storageString {
    switch (this) {
      case ObservationSource.directRf:
        return 'direct_rf';
      case ObservationSource.mqtt:
        return 'mqtt';
      case ObservationSource.indirectRf:
        return 'indirect_rf';
      case ObservationSource.nodeDb:
        return 'node_db';
      case ObservationSource.unknown:
        return 'unknown';
    }
  }

  /// Reverse of [storageString]. Returns null for legacy NULL rows or
  /// for any string we don't recognise (forward-compat).
  static ObservationSource? fromStorageString(String? value) {
    if (value == null) return null;
    switch (value) {
      case 'direct_rf':
        return ObservationSource.directRf;
      case 'mqtt':
        return ObservationSource.mqtt;
      case 'indirect_rf':
        return ObservationSource.indirectRf;
      case 'node_db':
        return ObservationSource.nodeDb;
      case 'unknown':
        return ObservationSource.unknown;
      default:
        return null;
    }
  }

  /// Localized human-readable label for UI display.
  String label(AppLocalizations l10n) {
    switch (this) {
      case ObservationSource.directRf:
        return l10n.nodedexObservationSourceDirectRf;
      case ObservationSource.mqtt:
        return l10n.nodedexObservationSourceMqtt;
      case ObservationSource.indirectRf:
        return l10n.nodedexObservationSourceIndirectRf;
      case ObservationSource.nodeDb:
        return l10n.nodedexObservationSourceNodeDb;
      case ObservationSource.unknown:
        return l10n.nodedexObservationSourceUnknown;
    }
  }
}
