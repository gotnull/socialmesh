// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileCopyrightText: 2025-2026 gotnull (developer@socialmesh.app)

// D42-A: MeshCore path overlay (app-local).
//
// Captures the rendered shape of a single saved or active path so the
// map screen can draw it as a polyline + hop markers. Path bytes are
// opaque routing identifiers (each byte is the first byte of the
// receiving repeater's 32-byte ed25519 pubkey, per upstream firmware
// behaviour), so per-hop geographic coordinates come from the local
// contact list - never from the path bytes themselves. Hops with no
// matching contact (or no `hasLocation` on the matched contact) are
// surfaced with `latLng == null` so the map can omit them from the
// polyline without "guessing" a position.
//
// Privacy:
//   - Hop labels are 2-char hex (one byte). The full pubkey is never
//     part of a label.
//   - Hop `displayName` is set ONLY when the resolver matched a
//     contact whose name is already user-visible in the contacts
//     list. We never invent a name from the byte.
//   - Bytes themselves are surfaced as the same 2-char hex label.

import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

import '../services/meshcore/protocol/meshcore_messages.dart';
import 'meshcore_contact.dart';

/// What kind of path the overlay represents. The map can show the
/// `source` as a small chip if useful.
enum MeshCorePathOverlaySource {
  /// Built from the contact's live firmware path (or pathOverrideBytes).
  active,

  /// Built from a saved entry in the per-contact D39-A path history.
  history,
}

extension MeshCorePathOverlaySourceWire on MeshCorePathOverlaySource {
  String get wire {
    switch (this) {
      case MeshCorePathOverlaySource.active:
        return 'active';
      case MeshCorePathOverlaySource.history:
        return 'history';
    }
  }
}

/// One hop on a rendered path overlay.
class MeshCorePathOverlayHop {
  /// The wire byte for this hop (0..255).
  final int byte;

  /// 2-char lowercase hex label suitable for a marker badge.
  final String label;

  /// Resolved position when a local contact with matching pubkey
  /// prefix AND a known location was found. Null otherwise; the map
  /// MUST NOT render a marker for null-position hops.
  final LatLng? latLng;

  /// Display name from the resolved contact, when present. Already
  /// user-visible. Null when no contact matched or the matched
  /// contact has no name.
  final String? displayName;

  const MeshCorePathOverlayHop({
    required this.byte,
    required this.label,
    this.latLng,
    this.displayName,
  });

  bool get hasLocation => latLng != null;

  @override
  String toString() =>
      'MeshCorePathOverlayHop(byte=$byte, label=$label, '
      'hasLocation=$hasLocation)'; // lint-allow: hardcoded-string
}

/// A single in-flight path overlay. Held by the
/// `meshCorePathOverlayProvider` and consumed by `MeshCoreMapScreen`.
class MeshCorePathOverlay {
  /// Origin endpoint - typically the local device. Null when the
  /// local device has no known location.
  final LatLng? originLatLng;

  /// Target endpoint - the contact at the far end of the path. Null
  /// when the target contact has no known location.
  final LatLng? targetLatLng;

  /// Ordered hop list, origin → target. Hops with `latLng == null`
  /// are surfaced but omitted from the rendered polyline.
  final List<MeshCorePathOverlayHop> hops;

  /// Where this overlay was built from.
  final MeshCorePathOverlaySource source;

  /// Contact pubkey hex this overlay belongs to. Used by widgets to
  /// re-resolve when the contact list updates.
  final String contactPubKeyHex;

  /// True when the source bytes came from `MeshCoreContact
  /// .pathOverrideBytes` (D34c-B-A forced override) rather than the
  /// live firmware path. The map may surface a small "Forced" chip.
  final bool isForced;

  const MeshCorePathOverlay({
    required this.originLatLng,
    required this.targetLatLng,
    required this.hops,
    required this.source,
    required this.contactPubKeyHex,
    this.isForced = false,
  });

  /// Number of resolved (renderable) hops.
  int get knownHopCount => hops.where((h) => h.hasLocation).length;

  /// Total hops in the path, regardless of resolution.
  int get totalHopCount => hops.length;

  /// True iff there is enough coordinate data to draw at least one
  /// polyline segment. Used to gate the "No path data to show on
  /// map" snackbar.
  bool get hasDrawableData {
    final pts = drawablePoints();
    return pts.length >= 2;
  }

  /// Compute the polyline points the map should draw. Filters out
  /// hops with null `latLng`. Includes `originLatLng` and
  /// `targetLatLng` when present.
  List<LatLng> drawablePoints() {
    final pts = <LatLng>[];
    if (originLatLng != null) pts.add(originLatLng!);
    for (final h in hops) {
      if (h.latLng != null) pts.add(h.latLng!);
    }
    if (targetLatLng != null) pts.add(targetLatLng!);
    return pts;
  }

  // ---------------------------------------------------------------------------
  // Pure resolvers
  // ---------------------------------------------------------------------------

  /// Build an overlay from a contact's live firmware path (or its
  /// `pathOverrideBytes` when that field is non-null). Returns null
  /// for flood paths (no fixed route).
  static MeshCorePathOverlay? fromContact({
    required MeshCoreContact target,
    required List<MeshCoreContact> contacts,
    required MeshCoreSelfInfo? selfInfo,
  }) {
    // Flood path - no overlay possible. pathOverride takes precedence.
    final override = target.pathOverride;
    final overrideBytes = target.pathOverrideBytes;
    final Uint8List? bytes;
    final bool isForced;
    if (override != null) {
      if (override < 0) {
        // pathOverride == -1 is "Force Flood" - no fixed path.
        return null;
      }
      // override >= 0: prefer the explicit forced bytes when present.
      if (overrideBytes != null) {
        bytes = overrideBytes;
        isForced = true;
      } else {
        // Force Direct (override == 0) with no bytes - draw self→target.
        bytes = Uint8List(0);
        isForced = true;
      }
    } else {
      if (target.pathLength < 0) return null;
      // pathLength >= 0: use the live firmware path bytes.
      bytes = target.path;
      isForced = false;
    }

    return _resolve(
      target: target,
      contacts: contacts,
      selfInfo: selfInfo,
      hopBytes: bytes,
      source: MeshCorePathOverlaySource.active,
      isForced: isForced,
    );
  }

  /// Build an overlay from a saved [hopBytes] sequence (D39-A path
  /// history entry).
  static MeshCorePathOverlay? fromHistory({
    required MeshCoreContact target,
    required List<MeshCoreContact> contacts,
    required MeshCoreSelfInfo? selfInfo,
    required Uint8List hopBytes,
  }) {
    if (hopBytes.length > 64) return null;
    return _resolve(
      target: target,
      contacts: contacts,
      selfInfo: selfInfo,
      hopBytes: hopBytes,
      source: MeshCorePathOverlaySource.history,
      isForced: false,
    );
  }

  static MeshCorePathOverlay _resolve({
    required MeshCoreContact target,
    required List<MeshCoreContact> contacts,
    required MeshCoreSelfInfo? selfInfo,
    required Uint8List hopBytes,
    required MeshCorePathOverlaySource source,
    required bool isForced,
  }) {
    // Build a byte → best-contact map (collision tiebreaker = newest
    // lastSeen). Empty / no-location contacts are skipped during the
    // lookup, not pre-filtered, so collisions still pick the most
    // recent local entry.
    final byByte = <int, MeshCoreContact>{};
    for (final c in contacts) {
      if (c.publicKey.isEmpty) continue;
      if (!c.hasLocation) continue;
      final b = c.publicKey.first;
      final prev = byByte[b];
      if (prev == null || c.lastSeen.isAfter(prev.lastSeen)) {
        byByte[b] = c;
      }
    }

    final hops = <MeshCorePathOverlayHop>[];
    for (final b in hopBytes) {
      final match = byByte[b];
      hops.add(
        MeshCorePathOverlayHop(
          byte: b,
          label: _hex2(b),
          latLng: match != null
              ? LatLng(match.latitude!, match.longitude!)
              : null,
          displayName: match?.displayName.isNotEmpty == true
              ? match!.displayName
              : null,
        ),
      );
    }

    final origin = _selfLatLng(selfInfo);
    final targetLatLng = target.hasLocation
        ? LatLng(target.latitude!, target.longitude!)
        : null;

    return MeshCorePathOverlay(
      originLatLng: origin,
      targetLatLng: targetLatLng,
      hops: List.unmodifiable(hops),
      source: source,
      contactPubKeyHex: target.publicKeyHex,
      isForced: isForced,
    );
  }

  static LatLng? _selfLatLng(MeshCoreSelfInfo? info) {
    if (info == null) return null;
    final rawLat = info.latitude;
    final rawLng = info.longitude;
    if (rawLat == null || rawLng == null) return null;
    // SELF_INFO encodes lat/lon as int32 in 1e7 scale (matches
    // `MeshCoreContactInfo.latitudeDegrees` / `longitudeDegrees`).
    final lat = rawLat / 1e7;
    final lng = rawLng / 1e7;
    if (!lat.isFinite || !lng.isFinite) return null;
    // The "no location" sentinel in MeshCore advertisements is
    // (0, 0). Treat exact zero as unknown so we don't draw a polyline
    // through Null Island.
    if (lat == 0.0 && lng == 0.0) return null;
    return LatLng(lat, lng);
  }

  static String _hex2(int byte) =>
      byte.toRadixString(16).padLeft(2, '0').toLowerCase();
}
