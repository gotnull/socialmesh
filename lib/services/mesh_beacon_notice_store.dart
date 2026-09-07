// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/logging.dart';
import 'protocol/protocol_service.dart';

/// Remembers reviewed offers per radio, without persisting channel keys.
class MeshBeaconNoticeStore {
  MeshBeaconNoticeStore(this._prefs, {required String radioScope})
    : _key = 'mesh_beacon_reviewed_$radioScope' {
    _reviewed.addAll(_prefs.getStringList(_key) ?? const []);
  }

  final SharedPreferences _prefs;
  final String _key;
  final Set<String> _reviewed = {};
  Future<void> _save = Future.value();

  // Receipt time and announcement text are deliberately excluded: a repeated
  // announcement of the same offer is not a new invitation.
  String _identity(MeshBeaconEvent beacon) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            beacon.senderNodeId,
            beacon.offerChannelName,
            beacon.offerChannelPsk,
            beacon.offerRegion?.value,
            beacon.offerPreset?.value,
          ]),
        ),
      )
      .toString();

  List<MeshBeaconEvent> pending(Iterable<MeshBeaconEvent> beacons) {
    final seen = <String>{..._reviewed};
    return List.unmodifiable(
      beacons.where((beacon) {
        if (!beacon.hasChannelOffer && !beacon.hasRadioOffer) return false;
        return seen.add(_identity(beacon));
      }),
    );
  }

  /// Acknowledge only the caller's displayed snapshot, never later arrivals.
  Future<void> dismiss(Iterable<MeshBeaconEvent> displayed) {
    _reviewed.addAll(displayed.map(_identity));
    final snapshot = _reviewed.toList(growable: false);
    _save = _save.then((_) async {
      try {
        await _prefs.setStringList(_key, snapshot);
      } catch (e) {
        AppLogging.storage('Failed to save reviewed Mesh Beacon offers: $e');
      }
    });
    return _save;
  }
}
